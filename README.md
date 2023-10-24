Memoize is a package for externalization of graphics and memoization of
compilation results in general, allowing the author to reuse the results of
compilation-intensive code. 

Memoize (i) induces very little overhead, as all externalized graphics is
produced in a single compilation. It features (ii) automatic recompilation upon
the change of code or user-adjustable context, and (iii) automatic
externalization of TikZ pictures and Forest trees, easily extensible to other
commands and environments. Furthermore, Memoize (iv) supports
cross-referencing, TikZ overlays and Beamer, (v) works with all major engines
and formats, and (vi) is adaptable to any workflow.

This repository also contains the code of two generic auxiliary packages
developed and documented alongside Memoize. Package Advice implements a generic
framework for extending the functionality of selected commands and
environments, and package CollArgs provides a command which can determine the
argument scope of any command whose argument structure conforms to
[xparse](https://ctan.org/pkg/xparse)'s argument specification.

See [INSTALL.md](INSTALL.md) for instructions on how to generate runtime files
and compile the documentation.

# LICENCE

This work may be distributed and/or modified under the conditions of the LaTeX
Project Public License, either version 1.3c of this license or (at your option)
any later version.  The latest version of this license is in
https://www.latex-project.org/lppl.txt and version 1.3c or later is part of all
distributions of LaTeX version 2008 or later.

This work has the LPPL maintenance status `maintained'.  The Current Maintainer
of this work is Sašo Živanović (saso.zivanovic@guest.arnes.si).
