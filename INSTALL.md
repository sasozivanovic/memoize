# Installation from the TDS archive

If Memoize is not (yet) offered by your TeX distribution, the easiest way to
install it is by downloading the TDS archive `memoize.tds.zip` from [Memoize's
CTAN page](https://ctan.org/pkg/memoize), and unpacking it into your `texmf`
directory.  You will most likely also have to do the same for two auxiliary
packages Memoize depends on: [Advice](https://ctan.org/pkg/advice) and
[CollArgs](https://ctan.org/pkg/collargs).

Read on only if you have an unstoppable urge to install from source and/or
compile the manual or the documented source code.

# Installation from the source

# Getting the sources

There are several options:

* Download and unpack the zip archive of the package from [Memoize's CTAN
  page](https://ctan.org/pkg/memoize).
   
* Download and unpack the TDS archive, or copy the files from your local
  distribution. The sources reside in `<texmf>/source/generic/memoize`.

* Clone the [GitHub repository](https://github.com/sasozivanovic/memoize).

## Generating runtime files

The easiest way to generate the runtime files is by running `make`. The
following command will generate (i) runtime TeX files for all supported formats
(currently: LaTeX, plain TeX and ConTeXt), and (ii) the man pages for the
accompanying scripts:

```
make runtime
```

To only generate the runtime TeX files, execute

```
make memoize.sty
```

Alternatively, you can generate the runtime files manually.  The source of this
package was written using [EasyDTX](https://ctan.org/pkg/easydtx).  Therefore,
you first have to convert the `.edtx` file into a regular `.dtx`:

```
edtx2dtx memoize.edtx > memoize.dtx
```

The next step is standard.  Produce the runtime files by compiling the
installation file:

```
tex memoize.ins
```

If you require the ConTeXt runtime, replace all instances of `\expanded` and
`\unexpanded` in `t-memoize.tex` by `\normalexpanded` and `\normalunexpanded`,
respectively.  One way to do this is:

```
sed -i -s -e 's/\\\(un\)\?expanded/\\normal\1expanded/g;' t-memoize.tex
```

The man pages are produced by converting their MarkDown sources by `pandoc`
(execute this in the `doc` subdirectory):

```
pandoc memoize-extract.1.md -s -t man -o memoize-extract.1
pandoc memoize-clean.1.md -s -t man -o memoize-clean.1
```

Additionally, links from `memoize-x.pl.1` and `memoize-x.py.1` to `memoize-x.1`
can be created by:

```
echo .so man1/memoize-extract.1 > memoize-extract.pl.1
echo .so man1/memoize-extract.1 > memoize-extract.py.1
echo .so man1/memoize-clean.1 > memoize-clean.pl.1
echo .so man1/memoize-clean.1 > memoize-clean.py.1
```

## Installation

It is recommended to install the files into a TDS-compliant `texmf` directory,
as usual.  Inspect file `FILES` or the TDS archive `memoize.tds.zip` to see
what goes where.

Next, the scripts residing in `<texmf>/scripts/memoize` should be linked into
some directory listed in the executable search `PATH`.  The scripts are the
following:

* `memoize-extract.pl`
* `memoize-extract.py`
* `memoize-clean.pl`
* `memoize-clean.py`

If you have downloaded the sources from GitHub, you can build the TDS
directories/archives of both Memoize and its auxiliary packages Advice and
CollArgs by issuing

```
make
```

This command creates: 

* TDS directories `memoize.tds`, `advice.tds` and `collargs.tds`,

* CTAN directories `ctan/memoize`, `ctan/advice` and `ctan/memoize`,

* TDS archives `memoize.tds.zip`, `advice.tds.zip` and `collargs.tds.zip`
  inside the CTAN directories, and 
  
* CTAN archives `memoize.zip`, `advice.zip` and `collargs.zip` inside directory
  `ctan`.
  
The plain `make` shown above will also attempt to compile the documentation.
If you're not ready for that (yet), you can avoid that by executing this
instead:

```
make PDF=
```

# Compiling the documentation

Compiling both the documented code listing and the manual requires a Unix-like
operating system.  I have developed Memoize on Linux, but the documentation
should also be compilable under Cygwin on Windows (not tested).

The documentation of Advice and CollArgs, both their manuals and documented
code listings, is included within Memoize's documentation.

## Getting the source

In principle, the options are the same as for the installation from the source,
but the GitHub option is strongly preferred here, as the other two options
require manually copying the sources of Advice and CollArgs into the Memoize
directory.  That said:

* Clone the [GitHub repository](https://github.com/sasozivanovic/memoize).
  You're done.

* Download and unpack the zip archives of all three packages from their CTAN
  pages: https://ctan.org/pkg/memoize, https://ctan.org/pkg/advice and
  https://ctan.org/pkg/collargs.
   
  Copy `advice.edtx` and `collargs.edtx` into the Memoize directory, alongside
  `memoize.edtx`.
   
* From TDS archives (of all three packages), or your local distribution's
  `<texmf>` folder.  This is not straightforward:
  
  1. Make a local copy of directory `<texmf>/source/generic/memoize`; we'll
     call it "the Memoize directory".
	 
  2. Copy directory `<texmf>/doc/generic/memoize` into the the Memoize
     directory as `doc`.
	 
  3. Copy `memoize-extract.pl`, `memoize-extract.py`, `memoize-clean.pl` and
     `memoize-clean.py` from directory `<texmf>/scripts` into the Memoize
     directory.
  
  4. Copy `advice.edtx` from `<texmf>/source/generic/advice` and
     `collargs.edtx` from `<texmf>/source/generic/collargs` into the the
     Memoize directory.

## Compiling the documented code listing

I have compiled the code docs with LuaLaTeX on a Linux system with
TeXLive 2023.  If you have `make`, the easiest way to compile them is by
issuing

```
make doc/memoize-code.pdf
```

Alternatively, you can use `latexmk`, but you first have to convert the `.edtx`
sources of all three packages into `.dtx`, if you haven't done so yet:

```
edtx2dtx memoize.edtx > memoize.dtx
edtx2dtx advice.edtx > advice.dtx
edtx2dtx collargs.edtx > collargs.dtx
```

Then, you can execute `latexmk` from the `doc` subdirectory:

```
latexmk -lualatex -bibtex memoize-code
```

To compile the code docs manually, three iterations of `lualatex memoize-code`
with `makeindex -s gind.ist memoize-code.idx` between them should suffice.

## Compiling the manual

I have compiled the manual with LuaLaTeX on a Linux system with TeXLive 2023,
`make`, `latexmk`, `perl` and `sed` installed.  Furthermore, you absolutely
have to run the compilation with some form of `--shell-escape`, as it executes
`make` and `sed` to build the examples.  (There is no way to compile these from
the command line, as the instructions are baked into the manual source.)

Given all this, either of the following should do the trick:

* `make doc/memoize.pdf` from the Memoize directory;

* `latexmk -lualatex -bibtex memoize` for the `doc` subdirectory; or

* quite a few runs of `lualatex memoize` interspersed by `makeindex memoize.idx`.
	
If all worked well, you can change `\usepackage{nomemoize}` in
`doc/memoize.tex` to `\usepackage{memoize}` and observe Memoize at work.
