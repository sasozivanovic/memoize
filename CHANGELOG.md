# Memoize changelog

For the development history, see [Memoize's GitHub
repository](https://github.com/sasozivanovic/memoize).

## 2024/04/02 v1.3.0

* New defaults:
  * `memo dir` is now in effect by default.
  * `mkdir command` is now initialized to `memoize-extract.pl --mkdir` even
    when `extract=no` or `extract=tex`.
* Update the manual to reflect the new defaults (plus many minor improvements).
* Bugfixes:
  * The extraction scripts (affecting Windows users): properly escape `\` in
	log messages.
  * Biblatex support: `\volcites` now works as advertised.

## 2024/03/15 v1.2.0

* Biblatex support:
  * Allow for entries containing verbatim material.
  * Support `\volcite` commands.
  * Implement `biblatex ccmemo cite`.
  * Submit all known citation commands to `auto`-keys `(vol)cite(s)`.
	* The support must be explicitly loaded by `\mmzset{biblatex}`.
* Minor changes:
	* Separate generic PGF support out of TikZ support.
	* Support `latexmk`.
	* Drop the obsolete workaround for package `morewrites`.
	* Clear Memoize's `begindocument` hooks after executing them.
* Documentation:
  * Introduce section "Support for specific classes and packages".
  * Improve the documentation of argument specification accepted by CollArgs'
		command `\CollectArguments` and Advice's key `args`, in particular with
		reference to the fact that since 2020, the functionality of package
		`xparse` is mostly integrated into the LaTeX kernel.
	* Add a note about `TEXLIVE_WINDOWS_TRY_EXTERNAL_PERL`.
	* Various minor changes.
	
## 2024/01/21 v1.1.2

* Fix a bug in Biblatex support.

## 2024/01/16 v1.1.1

* Fix a bug where, under `no memo dir`, Memoize was checking whether the extern
  exists in the root folder.

## 2024/01/02 v1.1.0

* Improve the extraction scripts:
  * respect `TEXMF_OUTPUT_DIRECTORY`;
  * respect `openin_any` and `openout_any`;
  * implement `--format`;
  * improve error reporting;
  * drop the `Path::Class` dependency for the Perl script;
  * allow for `PDF::Builder` in the Perl script;
  * implement `--library` in the Perl script;
  * set an appropriate exit code on exit;
  * and several further minor changes.

* Remove key `path` in favour of `prefix`. 

* `mkdir` is now initially `true`, but the directory is only created if `mkdir
  command` is non-empty (and it is empty initially).  The definition of `(no)
  memo dir` is accordingly simpler.

* The directory name is now appended to the value `mkdir command` when
  constructing the system call.

* A workaround for compatibility with package `morewrites`.

* Process package options using the new LaTeX mechanism to avoids the issue of
  spaces in package options.  The remaining issue of `/` is addressed by
  implementing option `options`.

* Add the missing commands to `nomemoize` and `memoizable`, and implement a
  generic variant of the latter (`memoizable.code.tex`).

* Implement auto-key `to context`.

* Write a c-memo even upon abortion.

* Demote warning messages "memoization aborted" & "marked as unmemoizable" to
  info messages.

* Implement biblatex support.

* Support `\DiscardShipoutBox`.

* Advance the counter underlying `\pgfpictureid` when utilizing a tikzpicture
  (`memoize tikz`).

* Remove the `\pgfsys@getposition` hack for `tikzpicture`s.

## 2023/10/10 v1.0.0

* A complete, fully documented reimplementation.

## 2020/07/17 v0.1

* The proof of concept, available only at GitHub.
