---
title: memoize-extract
section: 1
header: User Manual
footer: memoize-extract of Memoize v1.1.2
date: January 21, 2024
hyphenate: false
---

# NAME
memoize-extract.pl, memoize-extract.py - Extract extern pages out of the PDF


# SYNOPSIS
**memoize-extract.pl** [*OPTIONS*] *document.mmz*

**memoize-extract.py** [*OPTIONS*] *document.mmz*


# DESCRIPTION

**memoize-extract** is a script accompanying Memoize, a TeX package which
allows the author to reuse the results of compilation-intensive code such as
TikZ pictures.

Memoize dumps the created externs (boxes containing the typeset material to be
reused) onto their own pages in the produced PDF file.  It is the job of
**memoize-extract** to extract these extern pages into separate PDF files. At
subsequent compilations, Memoize will include those extern files into the
document, without compiling their source again.

Memoize communicates with **memoize-extract** through file *document.mmz*. When
*document.tex* is compiled to produce *document.pdf*, Memoize produces
*document.mmz*, which records which pages in the produced document are extern
pages and to which extern files they should be extracted. Therefore, after
compiling *document.tex*, the externs should be extracted by
**memoize-extract** *document.mmz*.  

*document.mmz* may also be given as document* or *document.tex*.  When
environment variable *TEXMF_OUTPUT_DIRECTORY* is set, this filename is relative
to the output directory specified by this variable.

*document.mmz* also records the expected width and height of each extern. In
case of a mismatch, **memoize-extract** refuses to extract the page and removes
the extern file if it already exist, and prints a warning message to the
standard error.  The script also refuses to extract the page if a (c)c-memo
associated to the extern does not exist.  See also section SECURITY.

The Perl (.pl) and the Python (.py) version of the script are functionally
equivalent.  The Perl script requires library
[PDF::API2](https://metacpan.org/pod/PDF::API2), and the Python script requires
library [pdfrw2](https://pypi.org/project/pdfrw2).

# OPTIONS

**-P, \--pdf** *filename.pdf*
: The externs will be extracted from *filename.pdf*.  By default,
  they are extracted from *document.pdf*.

**-p, \--prune**
: Remove the extern pages from the PDF after extraction.

**-k, \--keep**
: Do not modify the *document.mmz* to mark the externs as extracted.  By
  default, they are commented out to prevent double extraction.

**-F, \--format** *latex*|*plain*|*context*
: When this option is given, the script assumes that it was called from within
  a TeX compilation of a document in the given format: it prefixes all output
  by the script name, and creates a log file *document.mmz.log*, which receives
  any extraction-related warnings and errors.

**-f, \--force**
: Extract the extern even if the size-check fails.

**-q, \--quiet**
: Don't describe what's happening.

**-m, \--mkdir**
: A paranoid *mkdir -p*. (No extraction occurs, *document.mmz* is interpreted as a directory name, which may end in any suffix; no suffix mangling is performed.)

**-V, \--version**
: Show the Memoize version number and exit.

**-h, \--help**
: Show help and exit.

# SECURITY

This script respects the restrictions on file input and output imposed by the
TeX configuration, more precisely, the variables *openin_any* and *openout_any*
of the **kpathsea** library (https://tug.org/kpathsea). You can inspect the
values of these variables by executing '**kpsewhich** -var-value=openin_any' and
'**kpsewhich** -var-value=openout_any'.  The interpretation is as follows:

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

# EXIT STATUS

**0**
: The externs were successfully extracted.  This exit code is returned even if
  no externs need to be extracted, or if *document.mmz* does not exist.
  
**10**
: A warning also reported back to the compilation when given option
  **\--format**.  Currently, either: (i) size-mismatch; (ii) a non-existing
  associated (c)c-memo file; or (iii) unavailable *kpsewhich*.

**11**
: An error also reported back to the compilation when given option
  **\--format**. Currently, either: (i) a currupted document PDF, or (ii)
  a kpathsea permission error.

Other exit codes are as produced by the underlying scripting language (Perl of
Python).

# SEE ALSO

[Memoize manual](https://ctan.org/pkg/memoize), section 6.6.1.
