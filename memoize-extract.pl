#!/usr/bin/env perl

# This file is a part of Memoize, a TeX package for externalization of
# graphics and memoization of compilation results in general, available at
# https://ctan.org/pkg/memoize and https://github.com/sasozivanovic/memoize.
#
# Copyright (c) 2020- Saso Zivanovic <saso.zivanovic@guest.arnes.si>
#
# This work may be distributed and/or modified under the conditions of the
# LaTeX Project Public License, either version 1.3c of this license or (at
# your option) any later version.  The latest version of this license is in
# https://www.latex-project.org/lppl.txt and version 1.3c or later is part of
# all distributions of LaTeX version 2008 or later.
#
# This work has the LPPL maintenance status `maintained'.
# The Current Maintainer of this work is Saso Zivanovic.
# 
# The files belonging to this work and covered by LPPL are listed in
# <texmf>/doc/generic/memoize/FILES.

my $PROG = 'memoize-extract.pl';
my $VERSION = '2023/12/01 v1.1.0-wip';

use strict;
use File::Basename qw/basename/;
use Getopt::Long;
use File::Spec::Functions qw/canonpath splitpath catpath splitdir catdir catfile rootdir
    file_name_is_absolute/;
use File::Path qw(make_path);
# We will set up the error log before trying to import the PDF processing library.

# Declare variables for command-line argument and environments (needed by subs defined
# before we parse arguments).
our ($pdf_file, $prune, $keep, $format, $force, $quiet, $pdf_library, $print_version, $mkdir, $help);
our ($openin_any, $openout_any, $texmfoutput, $texmf_output_directory);

# \subsubsection{Messages}

# The messages are written both to the extraction log and the terminal (we output to
# stdout rather than stderr so that messages on the TeX terminal and document |.log|
# appear in chronological order).  Messages are automatically adapted to the TeX
# |--format|.

# The format of the messages.  It depends on the given |--format|; the last entry is for t
# the terminal output.
    
my %ERROR = (
    latex   => '\PackageError{memoize (perl-based extraction)}{$short}{$long}',
    plain   => '\errhelp{$long}\errmessage{memoize (perl-based extraction): $short}',
    context => '\errhelp{$long}\errmessage{memoize (perl-based extraction): $short}',
    ''      => '$header$short. $long');

my %WARNING = (
    latex   => '\PackageWarning{memoize (perl-based extraction)}{$texindent$text}',
    plain   => '\message{memoize (perl-based extraction) Warning: $texindent$text}',
    context => '\message{memoize (perl-based extraction) Warning: $texindent$text}',
    ''      => '$header$indent$text.');

my %INFO = (
    latex   => '\PackageInfo{memoize (perl-based extraction)}{$texindent$text}',
    plain   => '\message{memoize (perl-based extraction): $texindent$text}',
    context => '\message{memoize (perl-based extraction): $texindent$text}',
    ''      => '$header$indent$text.');

# Some variables used in the message routines; note that |header| will be redefined once
# we parse the arguments.

my $exit_code = 0;
my $log;
my $header = '';
my $indent = '';
my $texindent = '';

# The message routines.

sub error {
    my ($short, $long) = @_;
    if (! $quiet) {
	$_ = $ERROR{''};
	s/\$header/$header/;
	s/\$short/$short/;
	s/\$long/$long/;
	print(STDOUT "$_\n");
    }
    if ($log) {
	$long =~ s/\\/\\string\\/g;
	$_ = $ERROR{$format};
	s/\$short/$short/;
	s/\$long/$long/;
	print(LOG "$_\n");
    }
    $exit_code = 11;
    endinput();
}

sub warning {
    my $text = shift;
    if ($log) {
	$_ = $WARNING{$format};
	s/\$texindent/$texindent/;
	s/\$text/$text/;
	print(LOG "$_\n");
    }
    if (! $quiet) {
	$_ = $WARNING{''};
	s/\$header/$header/;
	s/\$indent/$indent/;
	s/\$text/$text/;
	print(STDOUT "$_\n");
    }
    $exit_code = 10;
}

sub info {
    my $text = shift;
    if ($text && ! $quiet) {
	$_ = $INFO{''};
	s/\$header/$header/;
	s/\$indent/$indent/;
	s/\$text/$text/;
	print(STDOUT "$_\n");
	if ($log) {
	    $_ = $INFO{$format};
	    s/\$texindent/$texindent/;
	    s/\$text/$text/;
	    print(LOG "$_\n");
	}
    }
}

# Mark the log as complete and exit.
sub endinput {
    if ($log) {
	print(LOG "\\endinput\n");
	close(LOG);
    }
    exit $exit_code;
}

sub die_handler {
    stderr_to_warning();
    my $text = shift;
    chomp($text);
    error("Perl error: $text", '');
}

sub warn_handler {
    my $text = shift;
    chomp($text);
    warning("Perl warning: $text");
}

# This is used to print warning messages from PDF::Builder, which are output to STDERR.
my $stderr;
sub stderr_to_warning {
    if ($stderr) {
	my $w = '  Perl info: ';
	my $nl = '';
	for (split(/\n/, $stderr)) {
	    /(^\s*)(.*?)(\s*)$/;
	    $w .= ($1 ? ' ' : $nl) . $2;
	    $nl = "\n";
	}
	warning("$w");
	$stderr = '';
    }
}

# \subsubsection{Permission-related functions}

# We will need these variables below.  Note that we only support Unix and Windows.
my $on_windows = $^O eq 'MSWin32';
my $dirsep = $on_windows ? '\\' : '/';

# |paranoia_in|/|out| should work exactly as |kpsewhich -safe-in-name|/|-safe-out-name|.
sub paranoia_in {
    my ($f, $remark) = @_;
    error("I'm not allowed to read from '$f' (openin_any = $openin_any)", $remark)
	unless _paranoia($f, $openin_any);
}

sub paranoia_out {
    my ($f, $remark) = @_;
    error("I'm not allowed to write to '$f' (openin_any = $openout_any)", $remark)
	unless _paranoia($f, $openout_any);
}

sub _paranoia {
    my ($f, $mode) = @_;
    return if (! $f);
    my ($volume, $dir, $basename) = splitpath($f);
    my @dir = splitdir($dir);
    return ($mode =~ /^[ay1]$/
	    || (! (!$on_windows && $basename =~ /^\./ && !($basename =~ /^\.tex$/))
		&&
		($mode =~ /^[rn0]$/
		 ||
		 (!grep(/^\.\.$/, @dir)
		  &&
		  $basename ne '..'
		  &&
		  (!file_name_is_absolute($f)
		   ||
		   is_ancestor($texmf_output_directory, $f)
		   ||
		   is_ancestor($texmfoutput, $f)
		  )))));
}

# On Windows, we disallow ``semi-absolute'' filenames, i.e.\ filenames starting with the
# |\| but lacking the drive.  |File::Spec|'s function |file_name_is_absolute| returns 2 if
# the path is absolute with a volume, 1 if it's absolute with no volume, and 0 otherwise.
# After a filename was sanitized using this function, |file_name_is_absolute| will work as
# we want it to.
sub sanitize_filename {
    if ($on_windows) {
	my $f = shift;
	my $a = file_name_is_absolute($f);
	my ($v, $d, $n) = splitpath($f);
	if ($a == 1 || ($a == 0 && $v) ) {
	    error("\"Semi-absolute\" filenames are disallowed: $f",
		  "The path must either both contain the drive letter and " .
		  "start with '\\', or none of these; paths like 'C:foo\\bar' " .
		  "and '\\foo\\bar' are disallowed");
	}
    }
}

sub access_in {
    return -r shift;
}

sub access_out {
    my $f = shift;
    my $exists;
    eval { $exists = -e $f };
    # Presumably, we get this error when the parent directory is not executable.
    return if ($@);
    if ($exists) {
        # An existing file should be writable, and if it's a directory, it should also be
        # executable.
	my $rw = -w $f; my $rd = -d $f; my $rx = -x $f;
	return -w $f && (! -d $f || -x $f);
    } else {
        # For a non-existing file, the parent directory should be writable.  (This is the
        # only place where function |parent| is used, so it's ok that it returns the
        # logical parent.)
	my $p = parent($f);
	return -w $p;
    }
}

# This function finds the location for an input file, respecting |TEXMF_OUTPUT_DIRECTORY|
# and |TEXMFOUTPUT|, and the permissions in the filesystem.  It returns an absolute file
# as-is.  For a relative file, it tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current
# directory (always), and |TEXMFOUTPUT| directory (if defined), in this order.  The first
# readable file found is returned; if no readable file is found, the file in the current
# directory is returned.
sub find_in {
    my $f = shift;
    sanitize_filename($f);
    return $f if file_name_is_absolute($f);
    for my $df (
	$texmf_output_directory ? join_paths($texmf_output_directory, $f) : undef,
	$f,
	$texmfoutput ? join_paths($texmfoutput, $f) : undef) {
	return $df if $df && -r $df;
    }
    return $f;
}

# This function finds the location for an output file, respecting |TEXMF_OUTPUT_DIRECTORY|
# and |TEXMFOUTPUT|, and the permissions in the filesystem.  It returns an absolute file
# as-is.  For a relative file, it tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current
# directory (unless |TEXMF_OUTPUT_DIRECTORY| is defined), and |TEXMFOUTPUT| directory (if
# defined), in this order.  The first writable file found is returned; if no writable file
# is found, the file in either the current or the output directory is returned.
sub find_out {
    my $f = shift;
    sanitize_filename($f);
    return $f if file_name_is_absolute($f);
    for my $df (
	$texmf_output_directory ? join_paths($texmf_output_directory, $f) : undef,
	$texmf_output_directory ? undef : $f,
	$texmfoutput ? join_paths($texmfoutput, $f) : undef) {
	return $df if $df && access_out($df);
    }
    return $texmf_output_directory ? join_paths($texmf_output_directory, $f) : $f;
}

# We next define some filename-related utilities matching what Python offers out of the
# box.

# Note that on Windows, which has no concept of symlinks, |..| is resolved to the parent.
# This affects subs |join_paths|, |parent|, |is_ancestor|, and consequently |find_in|,
# |find_out|, . The resolution is implemented by |File::Spec|'s canonpath.

sub name {
    my $path = shift;
    my ($volume, $dir, $filename) = splitpath($path);
    return $filename;
}

sub suffix {
    my $path = shift;
    my ($volume, $dir, $filename) = splitpath($path);
    $filename =~ /\.[^.]*$/;
    return $&;
}

sub with_suffix {
    my ($path, $suffix) = @_;
    my ($volume, $dir, $filename) = splitpath($path);
    if ($filename =~ s/\.[^.]*$/$suffix/) {
	return catpath($volume, $dir, $filename);
    } else {
	return catpath($volume, $dir, $filename . $suffix);
    }
}

sub with_name {
    my ($path, $name) = @_;
    my ($volume, $dir, $filename) = splitpath($path);
    my ($v,$d,$f) = splitpath($name);
    die "Runtime error in with_name: '$name' should not contain the directory component"
	unless $v eq '' && $d eq '' && $f eq $name;
    return catpath($volume, $dir, $name);
}

sub join_paths {
    my ($path1, $path2) = @_;
    return $path2 if !$path1 || file_name_is_absolute($path2);
    my ($volume1, $dir1, $filename1) = splitpath($path1, 'no_file');
    my ($volume2, $dir2, $filename2) = splitpath($path2);
    # this should never happen
    die if $volume2;
    return catpath($volume1, catdir($dir1, $dir2), $filename2);
}

# The logical parent.  Almost the same as |pathlib.parent| in Python, the differences only
# arise due to |canonpath|, which e.g.\ eliminates |.| components.
sub parent {
    # Use |canonpath| to eliminate the final |/|.
    my $path = canonpath(shift);
    #print("canonpath: $path\n");
    if ($path =~ /\Q$dirsep\E/) {
	my $parent = $path =~ s/\Q$dirsep\E[^\Q$dirsep\E]+$//r;
	return $parent ? $parent : $dirsep;
    } else {
	return '.';
    }
}

# This function assumes that both paths are absolute; ancestor may be '', signaling a
# non-path.
sub is_ancestor {
    my ($ancestor, $descendant) = @_;
    return if ! $ancestor;
    $ancestor = catfile(canonpath($ancestor),'');
    $ancestor .= $dirsep unless $ancestor =~ /\Q$dirsep\E$/;
    $descendant = canonpath($descendant);
    return $descendant =~ /^\Q$ancestor/;
}

# A paranoid |Path.mkdir|.  The given folder is preprocessed by |find_out|.
sub make_directory {
    my $folder = find_out(shift);
    if (! -d $folder) {
	paranoia_out($folder);
        # Using |make_path| is fine because we know that
        # |TEXMF_OUTPUT_DIRECTORY|/|TEXMFOUTPUT|, if given, exists, and that ``folder''
        # contains no |..|.
	make_path($folder);
	# This does not get logged when the function is invoked via |--mkdir|, as it is
        # not clear what the log name should be.
	info("Created directory $folder");
    }
}

sub unquote {
    shift =~ s/"(.*?)"/\1/rg;
}

# \subsubsection{Kpathsea}

# Get the values of |openin_any|, |openout_any|, |TEXMFOUTPUT| and
# |TEXMF_OUTPUT_DIRECTORY|.

my $kpsewhich_query = 'openin_any=\$openin_any,openout_any=\$openout_any,TEXMFOUTPUT=\$TEXMFOUTPUT';
my $kpsewhich_output = `kpsewhich -expand-var=$kpsewhich_query`;
my $TEXMFOUTPUT;
# When the variables are not expanded, we assume we're running MiKTeX.
if ($kpsewhich_output eq "$kpsewhich_query\n") {
    $kpsewhich_query = 'initexmf --show-config-value=[Core]AllowUnsafeInputFiles ' .
	'--show-config-value=[Core]AllowUnsafeOutputFiles';
    $kpsewhich_output = `$kpsewhich_query`;
    $kpsewhich_output =~ /^(.*)\n(.*)\n/m;
    $openin_any = $1 eq 'true' ? 'a' : 'p';
    $openout_any = $2 eq 'true' ? 'a' : 'p';
    $TEXMFOUTPUT = '';
# Otherwise, we're running TeXLive.
} else {
    $kpsewhich_output =~ /^openin_any=(.*),openout_any=(.*),TEXMFOUTPUT=(.*)/;
    ($openin_any, $openout_any, $TEXMFOUTPUT) = @{^CAPTURE};
}
if (! $kpsewhich_output) {
    # Unfortunately, this warning can't make it into the log.  But then again, the chances
    # of a missing |kpsewhich| are very slim, and its absence would show all over the
    # place anyway.  We don't bother throwing a different warning for MiKTeX.
    warning('I failed to execute "kpsewhich"; assuming openin_any = openout_any = "p" ' .
	    '(i.e. restricting all file operations to non-hidden files in the current ' .
	    'directory of its subdirectories).');
    # In absence of |kpathsea| information, we get very paranoid, but still try to get
    # |TEXMFOUTPUT| from an environment variable.
    ($openin_any, $openout_any, $TEXMFOUTPUT) = ('p', 'p', $ENV{'TEXMFOUTPUT'});
}

# An output directory should exist, and may not point to the root on Linux. On Windows, it
# may point to the root, because being absolute also implies containing the drive; see
# |sanitize_filename|.  The returned path is canonized.
sub sanitize_output_dir {
    return unless my $d = shift;
    $d = canonpath($d);
    sanitize_filename($d);
    # On Windows, |rootdir| returns |\|, so it cannot possibly match |$d|.
    return $d if -d $d && $d ne rootdir();
}

$texmfoutput = sanitize_output_dir($TEXMFOUTPUT);
$texmf_output_directory = sanitize_output_dir($ENV{'TEXMF_OUTPUT_DIRECTORY'});

# We don't delve into the real script when loaded from the testing code.
return 1 if caller;

# \subsubsection{Arguments}

my $usage = "usage: $PROG [-h] [-P PDF] [-p] [-k] [-F {latex,plain,context}] [-f] " .
    "[-L {PDF::API2,PDF::Builder}] [-q] [-m] [-V] mmz\n";
my $Help = <<END;
Extract extern pages produced by package Memoize out of the document PDF.

positional arguments:
  mmz                   the record file produced by Memoize: doc.mmz when compiling doc.tex
                        (doc and doc.tex are accepted as well)

options:
  -h, --help            show this help message and exit
  -P PDF, --pdf PDF     extract from file PDF
  -p, --prune           remove the extern pages after extraction
  -k, --keep            do not mark externs as extracted
  -F, --format {latex,plain,context}
                        the format of the TeX document invoking extraction
  -f, --force           extract even if the size-check fails
  -q, --quiet           describe what's happening
  -L, --library {PDF::API2, PDF::Builder}
                        which PDF library to use for extraction (default: PDF::API2)
  -m, --mkdir           create a directory (and exit); mmz argument is interpreted as directory name
  -V, --version         show program's version number and exit

For details, see the man page or the Memoize documentation.
END

my @valid_libraries = ('PDF::API2', 'PDF::Builder');
Getopt::Long::Configure ("bundling");
GetOptions(
    "pdf|P=s"   => \$pdf_file,
    "prune|p"   => \$prune,
    "keep|k"    => \$keep,
    "format|F=s" => \$format,
    "force|f" => \$force,
    "quiet|q" => \$quiet,
    "library|L=s" => \$pdf_library,
    "mkdir|m"   => \$mkdir,
    "version|V"  => \$print_version,
    "help|h|?"  => \$help,
    ) or die $usage;

if ($help) {print("$usage\n$Help"); exit 0}

if ($print_version) { print("$PROG of Memoize $VERSION\n"); exit 0 }

die "${usage}$PROG: error: the following arguments are required: mmz\n" unless @ARGV == 1;

die "${usage}$PROG: error: argument -F/--format: invalid choice: '$format' " .
    "(choose from 'latex', 'plain', 'context')\n"
    unless grep $_ eq $format, ('', 'latex', 'plain', 'context');

die "${usage}$PROG: error: argument -L/--library: invalid choice: '$pdf_library' " .
    "(choose from " . join(", ", @valid_libraries) . ")\n"
    if $pdf_library && ! grep $_ eq $pdf_library, @valid_libraries;

$header = $format ? basename($0) . ': ' : '';

# start a new line in the TeX terminal output
print("\n") if $format;

# \subsubsection{Initialization}

# With |--mkdir|, argument |mmz| is interpreted as the directory to create.
if ($mkdir) {
    make_directory($ARGV[0]);
    exit 0;
}

# Normalize the |mmz| argument into a |.mmz| filename.
my $mmz_file = $ARGV[0];
$mmz_file = with_suffix($mmz_file, '.mmz') if suffix($mmz_file) eq '.tex';
$mmz_file = with_name($mmz_file, name($mmz_file) . '.mmz') if suffix($mmz_file) ne '.mmz';

# Once we have the |.mmz| filename, we can open the log.
if ($format) {
    my $_log = find_out(with_suffix($mmz_file, '.mmz.log'));
    paranoia_out($_log);
    info("Logging to '$_log'");
    $log = $_log;
    open LOG, ">$log";
}

# Now that we have opened the log file, we can try loading the PDF processing library.
if ($pdf_library) {
    eval "use $pdf_library";
    error("Perl module '$pdf_library' was not found",
	  'Have you followed the instructions is section 1.1 of the manual?') if ($@);
} else {
    for (@valid_libraries) {
	eval "use $_";
	if (!$@) {
	    $pdf_library = $_;
	    last;
	}
    }
    if (!$pdf_library) {
	error("No suitable Perl module for PDF processing was found, options are " .
	      join(", ", @valid_libraries),
	      'Have you followed the instructions is section 1.1 of the manual?');
    }
}

# Catch any errors in the script and output them to the log.
$SIG{__DIE__} = \&die_handler;
$SIG{__WARN__} = \&warn_handler;
close(STDERR);
open(STDERR, ">", \$stderr);

# Find the |.mmz| file we will read, but retain the original filename in
# |$given_mmz_file|, as we will still need it.
my $given_mmz_file = $mmz_file;
$mmz_file = find_in($mmz_file, 1);
if (! -e $mmz_file) {
    info("File '$given_mmz_file' does not exist, assuming there's nothing to do");
    endinput();
}
paranoia_in($mmz_file);
paranoia_out($mmz_file, 'I would have to rewrite this file unless option --keep is given.')
    unless $keep;

# Determine the PDF filename: it is either given via |--pdf|, or constructed from the
# |.mmz| filename.
$pdf_file = with_suffix($given_mmz_file, '.pdf') if !$pdf_file;
$pdf_file = find_in($pdf_file);
paranoia_in($pdf_file);
paranoia_out($pdf_file,
	     'I would have to rewrite this file because option --prune was given.')
    if $prune;

# Various initializations.
my $pdf;
my %extern_pages;
my $new_mmz;
my $tolerance = 0.01;
info("Extracting new externs listed in '$mmz_file' from '$pdf_file' using Perl module $pdf_library");
my $done_message = "Done (there was nothing to extract)";
$indent = '  ';
$texindent = '\space\space ';
my $dir_to_make;
# We cannot process the .mmz file using in-place editing. It fails when the file is
# writable but its parent directory is not.

# \subsubsection{Process \texttt{.mmz}}

open (MMZ, $mmz_file);
while (<MMZ>) {
    my $mmz_line = $_;
    if (/^\\mmzPrefix *{(?P<prefix>)}/) {
	# Found |\mmzPrefix|: create the extern directory, but only later, if an extern
	# file is actually produced.  We parse the prefix in two steps because we have to
	# unquote the entire prefix.
	my $prefix = unquote($+{prefix});
	warning("Cannot parse line '$mmz_line'") unless
	    $prefix =~ /(?P<dir_prefix>.*\/)?(?P<name_prefix>.*?)/;
	$dir_to_make = $+{dir_prefix};
    } elsif (/^\\mmzNewExtern *{(?P<extern_path>.*?)}{(?P<page_n>[0-9]+)}{(?P<expected_width>[0-9.]*)pt}{(?P<expected_height>[0-9.]*)pt}/) {
	# Found |\mmzNewExtern|: extract the extern page into an extern file.
	$done_message = "Done";
	my $ok = 1;
	my %m_ne = %+;
	# The extern filename, as specified in |.mmz|:
	my $extern_file = unquote($m_ne{extern_path});
	# We parse the extern filename in a separate step because we have to unquote the
	# entire path.
	warning("Cannot parse line '$mmz_line'") unless
	    $extern_file =~ /(?P<dir_prefix>.*\/)?(?P<name_prefix>.*?)(?P<code_md5sum>[0-9A-F]{32})-(?P<context_md5sum>[0-9A-F]{32})(?:-[0-9]+)?.pdf/;
	# The actual extern filename:
	my $extern_file_out = find_out($extern_file);
	paranoia_out($extern_file_out);
	my $page = $m_ne{page_n};
	# Check whether c-memo and cc-memo exist (in any input directory).
	my $c_memo = with_name($extern_file, $+{name_prefix} . $+{code_md5sum} . '.memo');
	my $cc_memo = with_name($extern_file, $+{name_prefix} . $+{code_md5sum} .
				'-' . $+{context_md5sum} . '.memo');
	my $c_memo_in = find_in($c_memo);
	my $cc_memo_in = find_in($cc_memo);
	if ((! access_in($c_memo_in) || ! access_in($cc_memo_in)) && !$force) {
	    warning("I refuse to extract page $page into extern '$extern_file', " .
		    "because the associated c-memo '$c_memo' and/or " .
		    "cc-memo '$cc_memo' does not exist");
	    $ok = '';
	}
	# Load the PDF.  We only do this now so that we don't load it if there is nothing
	# to extract.
	if ($ok && ! $pdf) {
	    if (!access_in($pdf_file)) {
		warning("Cannot open '$pdf_file'", '');
		endinput();
	    }
	    # Temporarily disable error handling, so that we can catch the error ourselves.
	    $SIG{__DIE__} = undef; $SIG{__WARN__} = undef;
	    # All safe, |paranoia_in| was already called above.
	    eval { $pdf = $pdf_library->open($pdf_file, msgver => 0) };
	    $SIG{__DIE__} = \&die_handler; $SIG{__WARN__} = \&warn_handler;
	    error("File '$pdf_file' seems corrupted. " .
		  "Perhaps you have to load Memoize earlier in the preamble",
		  "In particular, Memoize must be loaded before TikZ library " .
		  "'fadings' and any package deploying it, and in Beamer, " .
		  "load Memoize by writing \\RequirePackage{memoize} before " .
		  "\\documentclass{beamer}. " .
		  "This was the error thrown by Perl:" . "\n$@") if $@;
	}
	# Does the page exist?
	if ($ok && $page > (my $n_pages = $pdf->page_count())) {
	    error("I cannot extract page $page from '$pdf_file', as it contains only " .
		  "$n_pages page" . ($n_pages > 1 ? 's' : ''), '');
	}
	if ($ok) {
	    # Import the page into the extern PDF (no disk access yet).
	    my $extern = $pdf_library->new(outver => $pdf->version);
	    $extern->import_page($pdf, $page);
	    my $extern_page = $extern->open_page(1);
	    # Check whether the page size matches the |.mmz| expectations.
	    my ($x0, $y0, $x1, $y1) = $extern_page->get_mediabox();
	    my $width_pt = ($x1 - $x0) / 72 * 72.27;
	    my $height_pt = ($y1 - $y0) / 72 * 72.27;
	    my $expected_width_pt = $m_ne{expected_width};
	    my $expected_height_pt = $m_ne{expected_height};
	    if ((abs($width_pt - $expected_width_pt) > $tolerance
		|| abs($height_pt - $expected_height_pt) > $tolerance) && !$force) {
		warning("I refuse to extract page $page from $pdf_file, because its size " .
			"(${width_pt}pt x ${height_pt}pt) is not what I expected " .
			"(${expected_width_pt}pt x ${expected_height_pt}pt)");
	    } else {
		# All tests were successful, let's create the extern file.  First, the containing
		# directory, if necessary.
		if ($dir_to_make) {
		    make_directory($dir_to_make);
		    $dir_to_make = undef;
		}
		# Now the extern file.  Note that |paranoia_out| was already called above.
		info("Page $page --> $extern_file_out");
		$extern->saveas($extern_file_out);
		# This page will get pruned.
		$extern_pages{$page} = 1 if $prune;
		# Comment out this |\mmzNewExtern|.
		$new_mmz .= '%' unless $keep;
	    }
	}
    }
    $new_mmz .= $mmz_line unless $keep;
    stderr_to_warning();
}
close(MMZ);
$indent = '';
$texindent = '';
info($done_message);

# Write out the |.mmz| file with |\mmzNewExtern| lines commented out. (All safe,
# |paranoia_out| was already called above.)
if (!$keep) {
    open(MMZ, ">", $mmz_file);
    print MMZ $new_mmz;
    close(MMZ);
}

# Remove the extracted pages from the original PDF. (All safe, |paranoia_out| was
# already called above.)
if ($prune and keys(%extern_pages) != 0) {
    my $pruned_pdf = $pdf_library->new();
    for (my $n = 1; $n <= $pdf->page_count(); $n++) {
	if (! $extern_pages{$n}) {
	    $pruned_pdf->import_page($pdf, $n);
	}
    }
    $pruned_pdf->save($pdf_file);
    info("The following extern pages were pruned out of the PDF: " .
	  join(",", sort(keys(%extern_pages))));
}

endinput();

# Local Variables:
# fill-column: 90
# after-save-hook: pl2dtx
# End:
