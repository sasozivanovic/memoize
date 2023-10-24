# Advice changelog

This package was developed as an auxiliary package of
[Memoize](https://ctan.org/pkg/memoize), and is documented alongside that
package.  Note, however, that the Memoize manual, `memoize-doc.pdf`, is not
reissued for patch-level releases of Advice; the version of the Memoize manual
fully applicable to the particular version of Advice is indicated at each
version.

Whenever the date of the Memoize manual is older than the release date of a
particular version of Advice, the documented source of Advice shown in that
version of `memoize-code.pdf` of course does not reflect the latest changes; in
those cases, please see [Memoize's GitHub
repository](https://github.com/sasozivanovic/memoize) for the recent
development history.

## 2023/10/25 v1.0.1
* Require package `xparse`, as `\GetDocumentCommandArgSpec` is being dropped
  from the LaTeX kernel.
* Reimplement the tracing typeout routine (don't use `\write16`).

Manual: Memoize 2023/10/10 v1.0.0

## 2023/10/10 v1.0.0
* The initial release.

Manual: Memoize 2023/10/10 v1.0.0
