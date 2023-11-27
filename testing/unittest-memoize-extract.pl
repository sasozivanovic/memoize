#!/bin/env perl

use strict;
use File::Basename;
use lib dirname (__FILE__);
use memoize_extract;
use File::Path qw/remove_tree/;
use Scalar::Util qw/reftype/;
use Cwd qw/getcwd realpath/;

my $on_windows = $^O eq 'MSWin32';
my $dirsep = $on_windows ? '\\' : '/';

my ($original_texmf_output_directory, $original_texmfoutput, $original_openin_any, $original_openout_any);
my $batch = 0;
my $n = 0;

sub test { # only for string arguments
    $n += 1;
    my $func = shift;
    my $expected_result = pop;
    if (reftype $expected_result eq reftype {} ) {
	if (exists($expected_result->{'unix'}) && !$on_windows) {
	    $expected_result = $expected_result->{'unix'};
	} elsif (exists($expected_result->{'win'}) && $on_windows) {
	    $expected_result = $expected_result->{'win'};
	} else {
	    print("$n. ---\n");
	    return;
	}
    }
    # For windows, replace / by \.
    $expected_result =~ tr'/'\\' if $on_windows;
    my @args = @_;
    # For windows, replace / by \, but as the arguments will be surrounded by
    # quotes, interpolation requires us to replace / at the end of each
    # argument by \\.
    @args =  map(tr'/'\\'r =~ s/\\$/\\\\/r, @_) if $on_windows;
    # Surround the arguments by quotes.
    @args = map("'$_'", @args);
    # Compose the function call.
    my $call = "$func(" . join(',', @args) . ')';
    my $result = eval $call;
    print("$n. $call --> '$result'\n");
    die "Expected: '$expected_result'" unless $result eq $expected_result;
}

sub unixtest {
    my $expected_result = pop;
    test(@_, { unix => $expected_result} );
}
sub wintest {
    my $expected_result = pop;
    test(@_, { win => $expected_result} );
}
$" = ',';

sub BEGIN_TEST {
    ($original_texmf_output_directory, $original_texmfoutput, $original_openin_any, $original_openout_any) = ($main::texmf_output_directory, $main::texmfoutput, $main::openin_any, $main::openout_any);
    ($main::texmf_output_directory, $main::texmfoutput, $main::openin_any, $main::openout_any) = @_;
    $main::openin_any = 'a' unless $main::openin_any;
    $main::openout_any = 'p' unless $main::openout_any;
    remove_tree('test');
    mkdir('test');
    mkdir('test/od');
    mkdir('test/tmp');
    chdir('test');
    $batch += 1; $n = 0;
    print("\nTEST $batch: texmf_output_directory=$main::texmf_output_directory, texmfoutput=$main::texmfoutput, openin_any=$main::openin_any, openout_any=$main::openout_any\n");
}

sub END_TEST {
    ($main::texmf_output_directory, $main::texmfoutput, $main::openin_any, $main::openout_any) = ($original_texmf_output_directory, $original_texmfoutput, $original_openin_any, $original_openout_any);
    chdir('..');
}

sub create {
    open(FH, '>', shift);
    print(FH shift, "\n");
    close(FH);
}

use Fcntl qw( :mode );
my %modes = ( r => S_IRUSR, w => S_IWUSR, x => S_IXUSR );
sub mychmod {
    my ($f, $pm_mode) = @_;
    $pm_mode =~ /^([+-])([rwx])$/;
    my $mode = $modes{$2};
    my $fmode = (stat($f))[2];
    if ($1 eq '+') {
	chmod($fmode | $mode, $f);
    } else {
	chmod($fmode & ~ $mode, $f);
    }
}

test('suffix', 'foo.txt', '.txt');
test('suffix', 'foo.txt.gz', '.gz');
test('suffix', '~/temp/foo.txt.gz', '.gz');
test('suffix', '~/temp dir/foo.txt.gz', '.gz');
test('suffix', 'foo', '');
test('suffix', 'foo.', '.');
test('suffix', 'foo.bar.', '.');
test('suffix', '.tex', '.tex');
test('suffix', '~/temp.dir/foo', '');

test('with_suffix', '~/foo.txt', '.log', '~/foo.log');
test('with_suffix', '~/foo', '.log', '~/foo.log');
test('with_suffix', '~/foo.', '.log', '~/foo.log');
test('with_suffix', 'foo.txt.gz', '.log', 'foo.txt.log');
test('with_suffix', 'my foo.txt.gz', '.log', 'my foo.txt.log');
test('with_suffix', '.gz', '.log', '.log');
test('with_suffix', '~/temp.dir/foo', '.log', '~/temp.dir/foo.log');

test('with_name', 'foo.memo.dir/bar.A-A.pdf', 'bar.A.memo', 'foo.memo.dir/bar.A.memo');
test('with_name', 'foo.txt', 'bar.log', 'bar.log');
test('with_name', '~/temp/', 'doc.log', '~/temp/doc.log');
test('with_name', '~/temp', 'doc.log', '~/doc.log');
test('with_name', '~/temp', '', '~/');
test('with_name', '~/temp/', '', '~/temp/');
test('with_name', '/tmp/foo', 'bar', '/tmp/bar');
test('with_name', '/', 'foo', '/foo');

test('join_paths', '~/temp', 'foo.txt', '~/temp/foo.txt');
test('join_paths', '~/temp/', 'foo.txt', '~/temp/foo.txt');
test('join_paths', '~/temp/', './foo.txt', '~/temp/foo.txt');

# on Win, ".." goes up
test('join_paths', '~/temp/', '../foo.txt', {unix => '~/temp/../foo.txt', win => '~/foo.txt'});
unixtest('join_paths', '~/temp/', '/tmp/foo.txt', '/tmp/foo.txt');
unixtest('join_paths', '~/temp/', '/tmp/foo.txt', '/tmp/foo.txt');
wintest('join_paths', '~/temp/', 'C:/tmp/foo.txt', 'C:/tmp/foo.txt');
wintest('join_paths', '~/temp', 'D:/tmp/foo.txt', 'D:/tmp/foo.txt');

test('join_paths', '~/temp/', 'foo.dir/foo.txt', '~/temp/foo.dir/foo.txt');
test('join_paths', '~/temp/', './foo.dir/foo.txt', '~/temp/foo.dir/foo.txt');
test('join_paths', '', 'foo.dir/foo.txt', 'foo.dir/foo.txt');
test('join_paths', '/', 'foo.dir/foo.txt', '/foo.dir/foo.txt');
test('join_paths', '.', 'foo.dir/foo.txt', 'foo.dir/foo.txt');
test('join_paths', './', 'foo.dir/foo.txt', 'foo.dir/foo.txt');
test('join_paths', '', '/foo.dir/foo.txt', '/foo.dir/foo.txt');
test('join_paths', '', './foo.txt', './foo.txt');
test('join_paths', '.', 'foo.txt', './foo.txt');

test('parent', 'foo/bar', 'foo');
test('parent', 'foo/bar/baz', 'foo/bar');
test('parent', 'foo/bar/./baz', 'foo/bar');
test('parent', '/foo/bar', '/foo');
test('parent', '/foo/bar/', '/foo');
test('parent', 'foo/bar/', 'foo');
test('parent', 'foo.txt', '.');
test('parent', '.', '..');
test('parent', '..', '../..');
test('parent', '/', '/');
test('parent', '/foo.txt', '/');
test('parent', './foo.txt', '.');
test('parent', '/../foo.txt', '/');
test('parent', '../foo.txt', '..');
test('parent', '//foo/bar', '/foo');
test('parent', 'foo/bar/..', {unix => 'foo/bar/../..', win => '.'});
test('parent', 'foo/bar/baz/..', {unix => 'foo/bar/baz/../..', win => 'foo'});
wintest('parent', 'C:/foo/bar', 'C:/foo');
wintest('parent', 'C:foo/bar', 'C:foo');
# wintest('parent', 'C:foo/bar/..', 'C:');

test('is_ancestor', '~/TeX/memoize', '~/TeX/memoize/temp', 1);
test('is_ancestor', '~/TeX/memoize', '~/TeX', '');
test('is_ancestor', '~/TeX/memoize/', '~/TeX/memoize/temp', 1);
test('is_ancestor', '/tmp/./foo', '/tmp/foo/bar', 1);
test('is_ancestor', '/', '/tmp/foo/bar', 1);
wintest('is_ancestor', 'C:/', 'C:/tmp/foo/bar', 1);
test('is_ancestor', '/foo/bar', '/foo/barbar', '');
test('is_ancestor', '', '/foo/bar', '');
test('is_ancestor', '/tmp', '', '');
test('is_ancestor', '/foo/bar/..', '/foo/baz', {unix => '', win => 1});


my $none = 'none.txt'; my $od_none = 'od/none.txt'; my $tmp_none = 'tmp/none.txt';
my $cur = 'cur.txt';   my $od_cur = 'od/cur.txt';   my $tmp_cur = 'tmp/cur.txt';
my $od = 'od.txt';     my $od_od = 'od/od.txt';     my $tmp_od = 'tmp/od.txt';
my $tmp = 'tmp.txt';   my $od_tmp = 'od/tmp.txt';   my $tmp_tmp = 'tmp/tmp.txt';
my $curod = 'curod.txt';   my $od_curod = 'od/curod.txt';   my $tmp_curod = 'tmp/curod.txt';
my $curtmp = 'curtmp.txt'; my $od_curtmp = 'od/curtmp.txt'; my $tmp_curtmp = 'tmp/curtmp.txt';
my $odtmp = 'odtmp.txt';   my $od_odtmp = 'od/odtmp.txt';   my $tmp_odtmp = 'tmp/odtmp.txt';
my $curodtmp = 'curodtmp.txt'; my $od_curodtmp = 'od/curodtmp.txt';my $tmp_curodtmp = 'tmp/curodtmp.txt';



BEGIN_TEST;
create($cur);
test('find_in', $cur, $cur);
test('find_in', $none, $none);
test('find_out', $cur, $cur);
test('find_out', $none, $none);

create($od_cur);
create($tmp_cur);
test('find_in', $cur, $cur);
test('find_out', $cur, $cur);
mychmod($cur, '-r');
test('find_in', $cur, $cur);
mychmod($cur, '-w');
test('find_in', $cur, $cur);
mychmod($cur, '+r');
test('find_in', $cur, $cur);
END_TEST;


BEGIN_TEST('', 'tmp');
create($tmp_tmp);

test('find_in', $none, $none);
test('find_in', $tmp, $tmp_tmp);
test('find_out', $none, $none);
test('find_out', $tmp, $tmp);

mychmod('.', '-w');
test('find_in', $none, $none);
test('find_in', $tmp, $tmp_tmp);
unixtest('find_out', $none, $tmp_none); # fail on win (no permissions on dir)
unixtest('find_out', $tmp, $tmp_tmp); # fail on win (no permissions on dir)

mychmod('.', '-r');
test('find_in', $none, $none);
test('find_in', $tmp, $tmp_tmp);
unixtest('find_out', $none, $tmp_none); # fail on win (no permissions on dir)
unixtest('find_out', $tmp, $tmp_tmp); # fail on win (no permissions on dir)

mychmod('.', '+w');
test('find_in', $none, $none);
test('find_in', $tmp, $tmp_tmp);
test('find_out', $none, $none);
test('find_out', $tmp, $tmp);
END_TEST;


BEGIN_TEST('od');
create($cur);
create($od_od);
create($curod);
create($od_curod);

test('find_in', $none, $none);
test('find_out', $none, $od_none);
test('find_in', $cur, $cur);
test('find_out', $cur, $od_cur);
test('find_in', $od, $od_od);
test('find_out', $od, $od_od);
test('find_in', $curod, $od_curod);
test('find_out', $curod, $od_curod);

mychmod('od', '-w');
test('find_in', $none, $none);
test('find_out', $none, $od_none);
mychmod('od', '+w');
mychmod('od', '-x');
unixtest('find_in', $od, $od); # fail on win --> od_od
test('find_out', $od, $od_od);
unixtest('find_in', $curod, $curod); # fail on win --> od_curod
test('find_out', $curod, $od_curod);
mychmod('od', '+x');

mychmod($od_od, '-r');
unixtest('find_in', $od, $od); # fail on win --> od_od
mychmod($od_od, '+r');
mychmod($od_od, '-w');
test('find_out', $od, $od_od);
mychmod($od_od, '+w');
END_TEST;


BEGIN_TEST('od', 'tmp');
create($cur);
create($od_od);
create($tmp_tmp);
create($curod);
create($od_curod);
create($curtmp);
create($tmp_curtmp);
create($od_odtmp);
create($tmp_odtmp);
create($curodtmp);
create($od_curodtmp);
create($tmp_curodtmp);

test('find_in', $none, $none);
test('find_out', $none, $od_none);
test('find_in', $cur, $cur);
test('find_out', $cur, $od_cur);
test('find_in', $od, $od_od);
test('find_out', $od, $od_od);
test('find_in', $tmp, $tmp_tmp);
test('find_out', $tmp, $od_tmp);
test('find_in', $curod, $od_curod);
test('find_out', $curod, $od_curod);
test('find_in', $curtmp, $curtmp);
test('find_out', $curtmp, $od_curtmp);
test('find_in', $odtmp, $od_odtmp);
test('find_out', $odtmp, $od_odtmp);
test('find_in', $curodtmp, $od_curodtmp);
test('find_out', $curodtmp, $od_curodtmp);

mychmod('od', '-w');
unixtest('find_out', $none, $tmp_none); # fail on win (no permissions on dir)
unixtest('find_out', $cur, $tmp_cur); # fail on win (no permissions on dir)
test('find_out', $od, $od_od);
unixtest('find_out', $tmp, $tmp_tmp); # fail on win (no permissions on dir)
test('find_out', $curod, $od_curod);
unixtest('find_out', $curtmp, $tmp_curtmp); # fail on win (no permissions on dir)
test('find_out', $odtmp, $od_odtmp);
test('find_out', $curodtmp, $od_curodtmp);
mychmod('od', '+w');

mychmod($od_od, '-w');
test('find_in', $od, $od_od);
test('find_out', $od, $tmp_od);
mychmod($od_od, '-r');
unixtest('find_in', $od, $od); # fail on win (no -r permission)
test('find_out', $od, $tmp_od);
mychmod($od_od, '+w');
unixtest('find_in', $od, $od); # fail on win (no -r permission)
test('find_out', $od, $od_od);
mychmod($od_od, '+r');
END_TEST;


sub paranoia_out {
    my $f = shift;
    return _paranoia($f, $main::openout_any);
}
my $drive = $on_windows ? 'C:' : '';

# All these tests should also work with $slash='/'.
my $slash = '';


BEGIN_TEST($drive . '/home/user/tex/od' . $slash, $drive . '/tmp' . $slash, 'p', 'p');
test('paranoia_out', $drive . '/foo/bar/baz.txt', '');
test('paranoia_out', 'foo/bar/baz.txt', 1);
test('paranoia_out', '../baz.txt', '');
test('paranoia_out', 'baz.txt', 1);

test('paranoia_out', $drive . '/foo/bar/.baz.txt', '');
test('paranoia_out', 'foo/bar/.baz.txt', {unix => '', win => 1});
test('paranoia_out', '../.baz.txt', '');
test('paranoia_out', '../.baz.txt', '');
test('paranoia_out', '.baz.txt', {unix => '', win => 1});
test('paranoia_out', '.tex', 1);
test('paranoia_out', 'foo/.tex', 1);

test('paranoia_out', $drive . '/home/user/tex/od/foo/bar/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', '');
test('paranoia_out', $drive . '/home/user/tex/baz.txt', '');
test('paranoia_out', $drive . '/home/user/tex/od///./baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od/foo/../baz.txt', '');

test('paranoia_out', $drive . '/tmp/foo/bar/baz.txt', 1);
test('paranoia_out', $drive . '/tmp/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', '');
test('paranoia_out', $drive . '/home/user/tex/baz.txt', '');
test('paranoia_out', $drive . '/tmp///./baz.txt', 1);
test('paranoia_out', $drive . '/tmp/foo/../baz.txt', '');
test('paranoia_out', $drive . '/tmpbaz.txt', '');

test('paranoia_out', join_paths(getcwd(), 'baz.txt'), '');
test('paranoia_out', join_paths(getcwd(), 'foo/baz.txt'), '');
END_TEST;


BEGIN_TEST('od' . $slash, 'tmp' . $slash, 'r', 'r');
test('paranoia_out', $drive . '/foo/bar/baz.txt', 1);
test('paranoia_out', 'foo/bar/baz.txt', 1);
test('paranoia_out', '../baz.txt', 1);
test('paranoia_out', 'baz.txt', 1);

test('paranoia_out', $drive . '/foo/bar/.baz.txt', {unix => '', win => 1});
test('paranoia_out', 'foo/bar/.baz.txt', {unix => '', win => 1});
test('paranoia_out', '../.baz.txt', {unix => '', win => 1});
test('paranoia_out', '.baz.txt', {unix => '', win => 1});
test('paranoia_out', '.tex', 1);
test('paranoia_out', 'foo/.tex', 1);

test('paranoia_out', $drive . '/home/user/tex/od/foo/bar/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od///./baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od/foo/../baz.txt', 1);

test('paranoia_out', $drive . '/tmp/foo/bar/baz.txt', 1);
test('paranoia_out', $drive . '/tmp/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/baz.txt', 1);
test('paranoia_out', $drive . '/tmp///./baz.txt', 1);
test('paranoia_out', $drive . '/tmp/foo/../baz.txt', 1);

test('paranoia_out', join_paths(getcwd(), 'baz.txt'), 1);
test('paranoia_out', join_paths(getcwd(), 'foo/baz.txt'), 1);
END_TEST;


BEGIN_TEST('od' . $slash, 'tmp' . $slash, 'a', 'a');
test('paranoia_out', $drive . '/foo/bar/baz.txt', 1);
test('paranoia_out', 'foo/bar/baz.txt', 1);
test('paranoia_out', '../baz.txt', 1);
test('paranoia_out', '../baz.txt', 1);
test('paranoia_out', 'baz.txt', 1);
test('paranoia_out', $drive . '/foo/bar/.baz.txt', 1);
test('paranoia_out', 'foo/bar/.baz.txt', 1);
test('paranoia_out', '../.baz.txt', 1);
test('paranoia_out', '../.baz.txt', 1);
test('paranoia_out', '.baz.txt', 1);
test('paranoia_out', '.tex', 1);
test('paranoia_out', 'foo/.tex', 1);

test('paranoia_out', $drive . '/home/user/tex/od/foo/bar/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od///./baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/od/foo/../baz.txt', 1);

test('paranoia_out', $drive . '/tmp/foo/bar/baz.txt', 1);
test('paranoia_out', $drive . '/tmp/baz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', 1);
test('paranoia_out', $drive . '/home/user/tex/baz.txt', 1);
test('paranoia_out', $drive . '/tmp///./baz.txt', 1);
test('paranoia_out', $drive . '/tmp/foo/../baz.txt', 1);

test('paranoia_out', join_paths(getcwd(), 'baz.txt'), 1);
test('paranoia_out', join_paths(getcwd(), 'foo/baz.txt'), 1);
END_TEST;


BEGIN_TEST('od' . $slash, '../tmp' . $slash, 'p', 'p');
test('paranoia_out', $drive . '/foo/bar/baz.txt', '');
test('paranoia_out', 'foo/bar/baz.txt', 1);
test('paranoia_out', '../baz.txt', '');
test('paranoia_out', 'baz.txt', 1);

test('paranoia_out', $drive . '/foo/bar/.baz.txt', '');
test('paranoia_out', 'foo/bar/.baz.txt', {unix => '', win => 1});
test('paranoia_out', '../.baz.txt', '');
test('paranoia_out', '../.baz.txt', '');
test('paranoia_out', '.baz.txt', {unix => '', win => 1});
test('paranoia_out', '.tex', 1);
test('paranoia_out', 'foo/.tex', 1);

test('paranoia_out', 'od/foo/bar/baz.txt', 1);
test('paranoia_out', 'od/baz.txt', 1);
test('paranoia_out', 'odbaz.txt', 1); # in current dir
test('paranoia_out', './//./baz.txt', 1);
test('paranoia_out', 'foo/../baz.txt', '');

test('paranoia_out', '../tmp/foo/bar/baz.txt', '');
test('paranoia_out', '../tmp/baz.txt', '');
test('paranoia_out', $drive . '/home/user/tex/odbaz.txt', '');
test('paranoia_out', $drive . '/home/user/tex/baz.txt', '');
test('paranoia_out', '../tmp///./baz.txt', '');
test('paranoia_out', '../tmp/foo/../baz.txt', '');

test('paranoia_out', join_paths(getcwd(), 'baz.txt'), '');
test('paranoia_out', join_paths(getcwd(), 'foo/baz.txt'), '');
test('paranoia_out', join_paths(realpath($main::texmfoutput), 'baz.txt'), '');
test('paranoia_out', join_paths(realpath($main::texmf_output_directory), 'baz.txt'), '');
END_TEST;
