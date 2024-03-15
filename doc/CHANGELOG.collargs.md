# CollArgs changelog

This package was developed as an auxiliary package of
[Memoize](https://ctan.org/pkg/memoize), and is documented alongside that
package.  Note, however, that the Memoize manual, `memoize-doc.pdf`, is not
reissued for patch-level releases of CollArgs; the version of the Memoize manual
fully applicable to the particular version of CollArgs is indicated at each
version.

Whenever the date of the Memoize manual is older than the release date of a
particular version of CollArgs, the documented source of CollArgs shown in that
version of `memoize-code.pdf` of course does not reflect the latest changes; in
those cases, please see [Memoize's GitHub
repository](https://github.com/sasozivanovic/memoize) for the recent
development history.

## 2024/03/15 v1.2.0
* Argument processors:
  * They now work without a formal argument, taking token register
    `\collargsArg` as input. The processors taking a formal argument were
    impossible (or at least too hard for me) to define.
	* Remove `append/prepend pre/postwrap`, as they become useless with the above
    change.
* Implement keys `clear args` and `return`, and expose `\collargsArgs`.
* Implement key `alias`.

## 2024/01/02 v1.1.0
* Implement `brace collected`.

Manual: Memoize 2024/01/02 v1.1.0

## 2023/10/10 v1.0.0
* The initial release.

Manual: Memoize 2023/10/10 v1.0.0
