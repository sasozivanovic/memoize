# What and why? #

Memoize is yet another package for *externalization*.  The idea is that if your
document contains code that doesn't change but takes a long time to compile,
you compile it once and reuse it in subsequent compilations.  It is common to
externalize complex TikZ pictures or Forest trees.  (Yes, I'm also the author
of Forest.)

Memoize is called as it is because the plan is to make it do more than
externalize
graphics. [Occasionally](https://tex.stackexchange.com/q/16016/16819), one also
wants to "externalize" a non-graphical result of some lengthy computation, and
that's sometimes called *memoization*.  General memoization does not work in
this alpha version --- the goal here was to implement a proof of concept for
the idea described below --- but it's near the top of the todo list.

But why yet another externalization package?  PGF/TikZ contains an
externalization library, after all. (This library is documented in section 53
of the PGF/TikZ manual.)

In a single compilation, TeX can produce only a single output file, but we want
each externalized picture to reside in its own file. Externalization in TikZ
therefore requires a separate compilation for externalizing each and every
picture.  While this is not a problem if you externalize as you write, but what
happens if you're editing a 1000+ pages book and you want to externalize 200+
TikZ pictures and Forest trees? You wait for hours, that's what happens.[^1]

Enter Memoize. The basic idea is very simple. A PDF can contain multiple pages,
right?  So *why not externalize all the pictures in one go, and use them by
including a specific page from the resulting PDF?* Pure magic: the
computational complexity drops from quadratic to linear. Or in plain English,
those 5 hours turn into (less than) 5 minutes.

In more detail, memoization/externalization in Memoize works in two stages:

1. Everything that needs to be externalized is plopped right in the middle of a
   document --- during the normal compilation of the document.
   
2. When you compile the document again, all the externalized stuff is split off
   the main document into separate files, called *memos*.

A memo is identified by the md5 sum of the code that produced it, so if you
change the code, the memo will be recompiled (in fact, a new memo will be
produced).

# Basic usage #

If you want to externalize TikZ pictures and Forest trees, say
`\usepackage{memoize}`. That's it. If your situation is more complicated, read
on.

What can be memoized and how do we specify what should be memoized?
While PGF, TikZ and Forest can only externalize their respective products,
Memoize can externalize anything: `\memoize{<arbitrary code>}` will externalize
whatever is typeset by `<arbitrary code>`. 

Of course, we often want to memoize results of every invocation of certain
environment or command, like all the TikZ pictures and/or all Forest trees.
Memoize makes this easy: if you say `\memoizeset{enable=<environment name>}`,
all instances of this environment will be externalized --- in fact,
auto-memoization of environments `tikzpicture` and `forest` is enabled by
default, so nothing needs to be done for those but loading Memoize.

Auto-memoization of commands is a bit more complicated than auto-memoization of
environments. It is (reasonably) clear where the end of an environment is, but
a command can take any number of arguments, it can take various kinds of
optional arguments and such.  We need to teach Memoize about the argument
structure of a command we want to auto-memoize. This can be achieved by
`\memoizeset{register=\command{<argument structure>}`, which defines a *command
handler* we then enable by `\memoizeset{enable=\command}`.  The `<argument
structure>` should be given in `xparse` syntax.  And don't worry about the
`\tikz` command, it is registered and enabled by default.

However, there might be exceptions. For example, maybe you want to externalize
all TikZ pictures but not `\todo` notes of package Todonotes, which uses TikZ
internally. (Those notes are usually short, plus they use the as-of-yet
unsupported `remember picture` key.)  Solution: register the command and then
prevent memoization within it: `\memoizeset{register=\todo{O{}+m},
prevent=\todo}`. (The `prevent` key is hopefully transparent, but the xparse
argument specification might not be: `O{}` means the optional argument with an
empty default; `+m` means a long mandatory argument.)

# What works? #

You might like the fact that TikZ `overlay`s are allowed, even though an
overlay which sticks out of the bounding box more than an inch requires (a
one-time) manual intervention by setting one or more of the `padding ...`
options.

What about `\label`--`\ref` support, you ask? Bad news first: it is not yet
implemented, because it falls under the more general issue of context
dependency (see the TODO list below), which is not yet implemented.  And the
good news: preliminary experiments show that `\label`--`\ref` more or less just
works, and this includes `\pageref`s.  This is so because the pictures are
externalized during a normal compilation.

# Different ways of doing it #

The two stages of operation outlined above are not set in stone.

1. You can externalize the pictures in `document.tex` into a PDF other than
   `document.pdf`, by invoking LaTeX with the `-jobname` option. But sensible
   support for this is still lacking.
   
2. Out of the box, splitting is done by LaTeX, specifically by the `pdfpages`
   package.  When you compile your document for the second time, Memoize
   notices there is stuff to split off the existing PDF, and invokes an
   embedded instance of LaTeX to do that. This means that the out-of-box
   approach only works if your TeX has sufficient `-shell-escape` permissions.
   
   But we already know that TeX can only produce one PDF at a time. So our
   outer compilation needs to execute a separate embedded compilation for every
   externalized picture. While this is ok if we have only a few pictures, it
   takes a while if you have many. (But it is still *much* faster than TikZ
   externalization!) The solution offered by Memoize is an external splitting
   tool. While TeX-based splitting needs to run TeX and the big PDF as many
   times as there are externalized pictures, the included Python script
   `memomanager` is executed once and spits out the memos in no time.

Some other stuff is configurable as well, in particular the file structure. By
allowing you to keep the memos where you need them, Memoize can be
transparently used in complicated setups --- for example, you can (easily!) set
it up so that a compilation of an individual chapter of a book will use the
same memos as the compilation of the entire book (and vice versa).  To
customize the landing site of your memos, use memoize keys `memo filename
prefix` and `memo filename suffix`.  But if you only want to put the memos out
of the way in a special directory, key `memo dir` will probably suffice --- if
you are compiling `document.tex`, you fill find your memos in directory
`document.memo.dir`, but note that *you have to create the directory yourself*.

# The future #

All this said, there's still lots of stuff to be done yet before this package
is ripe for CTAN:

* Proper documentation.  For now, there is only the comments in `memoize.sty`
  --- but for once, they are plentiful --- and some examples (in the `examples`
  directory).

* Context dependency, including support for `\label`--`\ref` and beamer
  overlays.  Context dependency will be implemented like in Forest (which
  features TikZ-based externalization) but with a friendlier UI.  The idea is
  to define a context, which can contain values of counters, definitions of
  macros etc., and reexternalize if that context changes.

* (Some kind of) support for TikZ pictures using `remember picture`.

* Named memos (as in TikZ, see manual section 53.4.2).

* Support for further TeX engines, in particular LuaTeX.  At the moment, the
  package supports PdfTeX and XeTeX.

* General memoization. At the moment, only externalization works, and even that
  is limited to externalizing a single picture per a piece of memoized code.

* More flexibility in the workflow.

* Customizable verbosity level.

* Testing. If you use the package, please report (github, email) any problems
  you encounter!

    * How robust is the package?  Do we ever lose any data due to a
      compilation error?  (We should not, even if the error occurs elsewhere!)
	  
	* Compatibility with other packages.

Some long-term ideas:

* Externalize into formats other than PDF.

* Support for TeX formats other than LaTeX --- in particular, Plain TeX and
  ConTeXt.
  

[^1]: This is what happened to Stefan Müller when he was working on the [HPSG
    Handbook](https://github.com/langsci/hpsg-handbook/).  We have a nice
    symbiotic relatioship here: I save him some time (at least in the long run,
    I hope), and he finds my bugs.  Thanks, Stefan!
