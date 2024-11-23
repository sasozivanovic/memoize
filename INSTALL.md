# Installation from the TDS archive

Memoize is most probably already included in your TeX distribution, but if it
is not, the easiest way to install it is by downloading the TDS archive
`memoize.tds.zip` from [Memoize's CTAN page](https://ctan.org/pkg/memoize), and
unpacking it into your `texmf` directory.  You will most likely also have to do
the same for two auxiliary packages Memoize depends on
[Advice](https://ctan.org/pkg/advice) and
[CollArgs](https://ctan.org/pkg/collargs).

The TDS archives are also available through [Memoize's GitHub
releases](https://github.com/sasozivanovic/memoize/releases).  This is where
you can find both the older versions of the package, and the work-in-progress
(wip) version (if any).  Note that even though Memoize, Advice and CollArgs
share the GitHub repository, you have to download the TDS archive for each
package separately. Each release offers both the source code and the TDS
archive; download the latter, it follows the naming scheme
`memoize/advice/collargs-<date>-<version>-zip`,
e.g. `memoize-2024-04-02-v1.3.0.zip`.


# Installation from the sources

Read this if you want to install from source (for example, to test a
development version of the package) and/or compile the manual or the documented
source code.

Note that installation from the sources and compilation of the documentation
require a UNIX-like operating system (Windows Subsystem for Linux suffices)
with `make` and several other programs installed.  In detail, Memoize's build
system utilizes standard utilities `make`, `bash`, `sed`, `grep`, `perl`,
`pandoc` and `zip`, plus the TeX-specific `latexmk` and `edtx2dtx`, which
should be included in your TeX distribution.

## For the impatient

To download and install the files needed to use the most recent, possibly
development version of Memoize:

1. Clone the [Memoize's GitHub repository](https://github.com/sasozivanovic/memoize)

		git clone git@github.com:sasozivanovic/memoize.git

2. Switch to the newly created `memoize` directory:

		cd memoize

3. Generate and install the runtime files:

		make install-all-runtimes


## Getting the sources
	
You can get the sources in several ways:

* Clone the [Memoize's GitHub repository](https://github.com/sasozivanovic/memoize).
  
		git clone git@github.com:sasozivanovic/memoize.git

  Branch `main`, which is checked out by default, might contain work in
  progress.  To check out an older version, execute `git checkout <tag>`, for
  example:

		git checkout memoize-1.4.0
	
  For the list of tags, execute `git tag`, or visit [the list on
  GitHub](https://github.com/sasozivanovic/memoize/tags).  Note that the
  installation instructions below only work for Memoize versions >= 1.4.0.

* Download a *source code* archive of a
  [release](https://github.com/sasozivanovic/memoize/releases) on GitHub.

* Download the zip archive of the package from [Memoize's CTAN
  page](https://ctan.org/pkg/memoize).  Depending on what you want to produce,
  you might also have to download the zip archives of packages
  [Advice](https://ctan.org/pkg/advice) and
  [CollArgs](https://ctan.org/pkg/collargs).  Note that the contents of
  directories `memoize`, `advice` and `collargs` within the respective zip
  archives have to be merged into one and the same directory.

In principle, you could also get the sources from TDS archive(s), but this is
not recommended, as you would need to move the files around after unpacking, to
arrive at the directory structure from GitHub / CTAN zip archive.

## Generating and installing the runtime files

The runtimes can be generated and installed using `make`. To generate and
install runtimes for Memoize, Advice and CollArgs in one go, execute

	make install-all-runtimes

In more detail, the following targets are available. 

* `runtimes` and `all-runtimes`: generate the runtime files

* `install-runtimes` and `install-all-runtimes`: (generate and) install the
  runtime files

* `uninstall-runtimes` and `uninstall-all-runtimes`: uninstall the runtime files

* `link-runtimes` and `link-all-runtimes`: (generate and) install the runtime
  files by soft-linking rather than copying

The `all` variants perform the action for all three packages (Memoize, Advice
and CollArgs), while the plain variants (without `all`) are limited to Memoize.
To perform an action only for Advice or Collargs, use the plain target but
specify the relevant Makefile (`Makefile.advice` or `Makefile.collargs`), e.g.

	make -f Makefile.advice install-runtimes

By default, the runtime files are installed to (or uninstalled from) the user
`texmf` directory, as returned by `kpsewhich -var-value TEXMFHOME`.  To
(un)install into another directory, append `TEXMFHOME=<dir>` to the invocation
of `make`, e.g.

	make install-runtimes TEXMFHOME=/home/user/my-texmf-directory


## Compiling the documentation

The documentation of Advice and CollArgs, both their manuals and documented
code listings, is included within Memoize's documentation.  The documentation
is compiled with LuaLaTeX.

To compile the documented code listing:

	make doc/memoize-code.pdf
	
To compile the manual:

	make doc/memoize-doc.pdf

Note that the compilation of the manual takes a while, and is preceded by the
compilation of the examples, which can be triggered separately by 

	make -C doc/examples

By default, the manual is compiled with memoization disabled.  To enable it,
change `\usepackage{nomemoize}` in `doc/memoize-doc.tex` to
`\usepackage{memoize}`.


## Building the releases

How do I build the CTAN release files?  First, I change the values of variables
`VERSION`, `YEAR`, `MONTH` and `DAY` in `Makefile` (for Memoize),
`Makefile.advice` and `Makefile.collargs`.  Then, I execute

	make version

which updates the version information in the source code, the scripts, the
documentation, the changelog and the manual pages.  I next perform a sanity
check:

	make versions-show

Finally, I build the CTAN release archives for all three packages, complete
with the TDS archives, by executing:

	make

This command creates: 

* TDS directories `memoize.tds`, `advice.tds` and `collargs.tds`,

* CTAN directories `ctan/memoize`, `ctan/advice` and `ctan/memoize`,

* TDS archives `memoize.tds.zip`, `advice.tds.zip` and `collargs.tds.zip`
  inside the CTAN directories, and 
  
* CTAN archives `memoize.zip`, `advice.zip` and `collargs.zip` inside directory
  `ctan`.

Invoking the plain `make` also compiles the documentation. This can
be avoided by executing 

	make PDF=
