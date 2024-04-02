---
title: memoize-clean
section: 1
header: User Manual
footer: memoize-clean of Memoize v1.3.0
date: April 02, 2024
hyphenate: false
---

# NAME
memoize-clean.pl, memoize-clean.py - Remove (stale) memo and extern files


# SYNOPSIS
**memoize-clean.pl** [*OPTIONS*] [*document1.mmz* ...]

**memoize-clean.py** [*OPTIONS*] [*document1.mmz* ...]


# DESCRIPTION

**memoize-clean** is a script accompanying Memoize, a TeX package which allows
the author to reuse the results of compilation-intensive code such as TikZ
pictures.

By default, this script removes stale memo and extern files.  A stale memo or
extern is an extern produced during a compilation of a previous version of the
document which was neither used nor produced during the last compilation of the
document.  Typically, stale files arise when we change the memoized code (or
its context).

**memoize-clean.pl** removes all memo and extern files with prefixes mentioned
in the listed **.mmz** files and by options **\--prefix** which are not
explicitly mentioned in the **.mmz** files.

Before deleting anything, **memoize-clean.pl** lists all the files it would
delete and asks for confirmation.

# OPTIONS

**-p, \--prefix**
: Add a memo/extern prefix for cleaning. This option may be given multiple
    times.

**-a, \--all**
: Remove all memos and externs, rather than only the stale ones.

**-y, \--yes**
: Do not ask for confirmation.

**-q, \--quiet**
: Don't describe what's happening.

**-h, \--help**
: Show help.

**-V, \--version**
: Show the Memoize version number and exit.

# SEE ALSO

[Memoize manual](https://ctan.org/pkg/memoize), section 6.6.3.
