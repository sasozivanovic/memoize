---
title: memoize-utils
section: 1
header: User Manual
footer: memoize-utils of Memoize v1.5.0-rc1
date: October 11, 2026
hyphenate: false
---

# NAME
memoize-utils - Utilities for TeX package Memoize


# SYNOPSIS
**memoize-utils** [*OPTIONS*] info|clean ...


# DESCRIPTION

**memoize-clean** is a script accompanying Memoize, a TeX package which allows
the author to reuse the results of compilation-intensive code such as TikZ
pictures.  

See the manual pages of the individual commands further information.

# OPTIONS

**-h, \--help**
: Show help.

**-V, \--version**
: Show the Memoize version number and exit.


Remove (stale) memo and extern files


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

# SEE ALSO

[Memoize manual](https://ctan.org/pkg/memoize), section 5.5.6.
