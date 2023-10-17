# Installation from the TDS archive

If Advice is not (yet) offered by your TeX distribution, the easiest way to
install it is by downloading the TDS archive `advice.tds.zip` from [Advice's
CTAN page](https://ctan.org/pkg/advice), and unpacking it into your `texmf`
directory. You will most likely also have to do the same for an auxiliary
package Advice depends on: [CollArgs](https://ctan.org/pkg/collargs).

Read on only if you have an unstoppable urge to install from source and/or
compile the manual or the documented source code.

# Installation from the source

## Getting the sources

There are several options:

* Download and unpack the zip archive of the package from [Advice's CTAN
  page](https://ctan.org/pkg/advice).
  
* Download and unpack the TDS archive, or copy the files from your local
  distribution. The sources reside in `<texmf>/source/generic/advice`.
  
* Clone the [GitHub repository of
  Memoize](https://github.com/sasozivanovic/memoize).

## Generating the runtime files

The easiest way to generate the runtime files is by running `make`. The
following command will generate runtime files for all supported formats
(currently: LaTeX, plain TeX and ConTeXt).

```
make advice.sty
```

Alternatively, you can generate these files manually.  The source of this
package was written using [EasyDTX](https://ctan.org/pkg/easydtx).  Therefore,
you first have to convert the `.edtx` file into a regular `.dtx`:

```
edtx2dtx advice.edtx > advice.dtx
```

The next step is standard.  Produce the runtime files by compiling the
installation file:

```
tex advice.ins
```

Finally, if you require the ConTeXt runtime, replace all instances of
`\expanded` and `\unexpanded` in `t-advice.tex` by `\normalexpanded` and
`\normalunexpanded`, respectively.  One way to do this is:

```
sed -i -s -e 's/\\\(un\)\?expanded/\\normal\1expanded/g;' t-advice.tex
```

## Installation

It is recommended to install the files into a TDS-compliant `texmf` directory,
as usual.  Inspect file `FILES` or the TDS archive `advice.tds.zip` to see what
goes where.

# Compiling the documentation

The documentation of this package is integrated into the documentation of
[Memoize](https://ctan.org/pkg/memoize), please continue there.
