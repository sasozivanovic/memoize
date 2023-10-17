---
title: memoize-extract
section: 1
header: User Manual
footer: memoize-extract of Memoize v1.0.0
date: October 10, 2023
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

*document.mmz* also records the expected width and height of each extern. In
case of a mismatch, **memoize-extract** refuses to extract the page and removes
the extern file if it already exist, and prints a warning message to the
standard error.  The script furthermore refuses to extract the page if a
(c)c-memo associated to the extern does not exist, and to write to any file
whose absolute path does not occur under the current directory or the directory
set by TEXMFOUTPUT (in *texmf.cnf* or as an environment variable); TEXMFOUTPUT
is also not allowed to point to the root directory, except on Windows, where it
can only point to a drive root.

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

**-f, \--force**
: Extract the extern even if the size-check fails.

**-l, \--log** *filename*
: Log size mismatches to *filename* rather than to the standard error.

**-w, \--warning-template** *string*
: Wrap the size mismatch warning text into the given template: \\warningtext in
  the template will be replaced by the warning text.

**-q, \--quiet**
: Don't describe what's happening.

**-e, \--embedded**
: Prefix all messages to the standard output with the script name.

**-m, \--mkdir**
: A paranoid *mkdir -p*. (No extraction occurs, *document.mmz* is interpreted as a directory name.)

**-h, \--help**
: Show help and exit.

**-V, \--version**
: Show the Memoize version number and exit.

# SEE ALSO

[Memoize manual](https://ctan.org/pkg/memoize), section 6.6.1.
