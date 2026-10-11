---
title: memoize-extract
section: 1
header: User Manual
footer: memoize-extract of Memoize v1.5.0-rc1
date: October 11, 2026
hyphenate: false
---

# NAME
memoize-extract - Extract extern pages out of the PDF


# SYNOPSIS
**memoize-extract** [*OPTIONS*] *document.pdf*


# DESCRIPTION

**memoize-extract** is a script accompanying Memoize, a TeX package which
allows the author to reuse the results of compilation-intensive code such as
TikZ pictures.

Memoize dumps the created externs (boxes containing the typeset material to be
reused) onto their own pages in the produced PDF file.  It is the job of
**memoize-extract** to extract these extern pages into separate PDF files. At
subsequent compilations, Memoize will include those extern files into the
document, without compiling their source again.

When environment variable *TEXMF_OUTPUT_DIRECTORY* is set, *document.pdf* is
relative to the output directory specified by this variable; otherwise, this
filename is relative to the current directory.  If *document.pdf* cannot be
found *TEXMF_OUTPUT_DIRECTORY* or the current directory, the script tries to
find it in *TEXMFOUTPUT* directory, if this directory is set in *texmf.cnf* or
as an environment variable.

Memoize communicates with **memoize-extract** through the */MMIZ_Record* entry
in the PDF catalog, produced with package option *record=pdf*.  This entry
records which pages in the produced document are extern pages and to which
extern files they should be extracted.

At the moment, this script is considered experimental.  If you encounter
problems, please file a bug report at https://github.com/sasozivanovic/memoize.
As a workaround, you may use the Perl (memoize-extract.pl) or the Python
(memoize-extract.py) version of the script, but note that these will eventually
become deprecated and then removed from the package.

# OPTIONS

**-p, \--prune**
: Remove the extern pages from the PDF after extraction.

**-F, \--format** *latex*|*plain*|*context*
: When this option is given, the script assumes that it was called from within
  a TeX compilation of a document in the given format: it prefixes all output
  by the script name, and creates a log file *document.mmz.log*, which receives
  any extraction-related warnings and errors.

**-f, \--force**
: Normally, the script refuses to extract an extern page if the c-memo or the
  cc-memo associated to the extern does not exist.  This option forces the
  extraction even if the memos do not exist.  See also section SECURITY.

**-q, \--quiet**
: Don't describe what's happening.

**-m, \--mkdir**
: A paranoid *mkdir -p*. (No extraction occurs, *document.pdf* is interpreted as a directory name, which may end in any suffix; no suffix mangling is performed.)

**-V, \--version**
: Show the Memoize version number and exit.

**-h, \--help**
: Show help and exit.

# SECURITY

This script respects the restrictions on file input and output imposed by the
TeX configuration, more precisely, the variables *openin_any* and *openout_any*
of the **kpathsea** library (https://tug.org/kpathsea). You can inspect the
values of these variables by executing `kpsewhich -var-value=openin_any` and
`kpsewhich -var-value=openout_any`.  The interpretation is as follows:

**a** (or **y** or **1**) any
: Allows any file to be opened.

**r** (or **n** or **0**) restricted
: Means disallowing special file names.

**p** (or any other value) paranoid
: Means being really paranoid: disallowing special file names and restricting
  input/output files to be in or below the working directory or the directory
  specified by *TEXMFOUTPUT* or *TEXMF_OUTPUT_DIRECTORY*.  *TEXMFOUTPUT* may be
  set either in *texmf.cnf* (e.g. by **tlmgr**) or as an environment
  variable. *TEXMF_OUTPUT_DIRECTORY* may only be set as an environment
  variables; it is automatically set by TeX when called by *-output-directory*
  option (starting in TeXLive 2024).
  
Note that as of TeX Live 2026, *openin_any* is obsolete.  The system behaves as
if it was set to *a*.

# EXIT STATUS

**0**
: The externs were successfully extracted.  This exit code is returned even if
  no externs need to be extracted, if *document.pdf* does not exist, or if it
  contains no */MMIZ_Record*.
  
**10**
: Signals that some extern page(s) could not be extracted. (This is also
  reported, as a package warning, back to the compilation when given option
  **\--format**).

**11**
: Signals that a fatal error has occurred. (This error is also reported back to
  the compilation when given option **\--format**).

Other exit codes are as produced by Lua, the underlying scripting language.

# SEE ALSO

[Memoize manual](https://ctan.org/pkg/memoize), section 5.5.2.
