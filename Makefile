# Prepare the CTAN submission for all three packages.

PACKAGES = memoize advice collargs

all: ctan/memoize.zip
	$(MAKE) -f Makefile.advice ctan/advice.zip
	$(MAKE) -f Makefile.collargs ctan/collargs.zip
	@echo "Don't forget to run the tests!"

# Prepare the CTAN submission.

PACKAGE = memoize
VERSION = 1.4.0
YEAR = 2024
MONTH = 10
DAY = 25

FORMAT = generic

COMMON = memoize nomemoize memoizable
PLAIN = memoize-extract-one.tex
GENERIC = memoizable.code.tex
LATEX = memoize-biblatex.code.tex memoize-beamer.code.tex
SOURCE = memoize.edtx memoize.ins

SCRIPTS := memoize-extract memoize-clean
man-src := $(SCRIPTS:%=doc/%.1.md)
MAN := $(SCRIPTS:%=%.1) $(SCRIPTS:%=%.pl.1) $(SCRIPTS:%=%.py.1)
MAN := $(MAN:%=doc/%)
SCRIPTS := $(SCRIPTS:%=%.pl) $(SCRIPTS:%=%.py)

%.pl.1: %.1
	echo .so man1/$*.1 > $@     # link to .1 man page
%.py.1: %.1
	echo .so man1/$*.1 > $@     # link to .1 man page

README = doc/README.memoize.md
INSTALL = INSTALL.md
CHANGELOG = CHANGELOG.md
MAKEFILE = Makefile Makefile.package Makefile.runtimes Makefile.advice Makefile.collargs
LICENCE = LICENCE

PACKAGES.edtx = $(PACKAGES:%=%.edtx)
PACKAGES.dtx = $(PACKAGES:%=%.dtx)
PACKAGES.ins = $(PACKAGES:%=%.ins)

codedoc-source = memoize-code.tex \
                 memoize-code.sty memoize-doc-common.sty

manual-source = memoize-doc.tex \
                memoize-doc.sty memoize-doc-common.sty yadoc.sty \
		memoize-doc.mst

PDF = memoize-doc.pdf memoize-code.pdf

codedoc-source := $(codedoc-source:%=doc/%)
manual-source := $(manual-source:%=doc/%)
pdf := $(PDF:%=doc/%)
DOC = $(sort $(codedoc-source) $(manual-source)) $(pdf) $(man-src)

examples-src := Makefile ins.begin ins.mid ins.end
examples-src := $(examples-src:%=doc/examples/%)
#examples-src += $(shell git ls-files | grep ^doc/examples/.*dtx$)
examples-src += $(shell find doc/examples -name '*.dtx')

ctan/$(PACKAGE).zip:
	$(TDS-BEGIN)
	cd doc && zip ../$(TDS-DOC-DIR)/examples-src.zip $(examples-src:doc/%=%)
	cd doc && zip -r ../$(TDS-DOC-DIR)/examples.zip doc/examples/attachments/*
	$(TDS-END)
	$(CTAN-BEGIN)
	ln -sr $(TDS-DOC-DIR)/examples-src.zip $(CTAN-DIR)/doc
	ln -sr $(TDS-DOC-DIR)/examples.zip $(CTAN-DIR)/doc
	$(CTAN-END)

%.py.dtx: %.py
	edtx2dtx -s -c '#' -B '^__version__' -E '^# Local Variables:' $< \
		| sed -e '/^% Local Variables:/Q' > $@

%.pl.dtx: %.pl
	edtx2dtx -s -c '#' -B '^my \$$PROG' -E '^# Local Variables:' $< \
		| sed -e '/^% Local Variables:/Q' > $@

doc/memoize-code.pdf: $(codedoc-source) \
                      $(PACKAGES.dtx) $(PACKAGES.ins) $(SCRIPTS:%=%.dtx)

doc/memoize.pdf: $(manual-source) $(examples-src) $(PACKAGES.edtx) examples

%.pdf: %.tex
	latexmk -cd -lualatex -shell-escape -bibtex- $(LATEXMK) $<



# Maintenance

test.tex = $(wildcard test*.tex)

.PHONY: all runtime force clean versions-show

.PRECIOUS: %.1

clean: # clean this directory
	memoize-clean.py -a $(test.tex:%.tex=-p %.) $(test.tex:%.tex=-p %.memo.dir/)
	latexmk -C -f $(test.tex) _region_

version:
	$(MAKE) -f Makefile.collargs version
	$(MAKE) -f Makefile.advice version
	$(call EDIT-VERSION-LATEX,memoize.edtx,memoize)
	$(call EDIT-VERSION-LATEX,memoize.edtx,nomemoize)
	$(call EDIT-VERSION-LATEX,memoize.edtx,memoizable)
	$(call EDIT-VERSION-CONTEXT,memoize.edtx)
	$(call EDIT-VERSION-PLAIN,memoize.edtx,memoize)
	$(call EDIT-VERSION-PLAIN,memoize.edtx,nomemoize)
	$(call EDIT-VERSION-PLAIN,memoize.edtx,memoizable)
	$(call EDIT-VERSION-PERL,memoize-extract.pl)
	$(call EDIT-VERSION-PERL,memoize-clean.pl)
	$(call EDIT-VERSION-PYTHON,memoize-extract.py)
	$(call EDIT-VERSION-PYTHON,memoize-clean.py)
	$(call EDIT-VERSION-MAN,doc/memoize-extract.1.md)
	$(call EDIT-VERSION-MAN,doc/memoize-clean.1.md)
	$(call EDIT-DATE-CHANGELOG,CHANGELOG.md)
	$(call EDIT-VERSION-LATEX,doc/memoize-doc.tex,memoize)
	$(call EDIT-VERSION-LATEX,doc/memoize-code.tex,memoize)
define COLOR_VERSION
grep -E --color '[0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}|v?[0-9]\.[0-9]\.[0-9]([-a-z]*)|(January|February|March|April|May|June|July|August|September|October|November|December) [0-9]+, [0-9]{4}'
endef

versions-show:
	@grep -E '\\ProvidesPackage|^%<context>%D\s*(version|date)=' $(PACKAGES.edtx) $(pdf:%.pdf=%.tex) | ${COLOR_VERSION}
	@grep __version__ *.py | ${COLOR_VERSION}
	@grep VERSION *.pl | ${COLOR_VERSION}
	@grep -E '^(footer|date):' doc/memoize-*.md | ${COLOR_VERSION}
	@${COLOR_VERSION} CHANGELOG.md doc/CHANGELOG.advice.md doc/CHANGELOG.collargs.md

include Makefile.package
include Makefile.runtimes

VERSION-MAN = of Memoize v$(VERSION)

.PHONY: all-runtimes link-all-runtimes unlink-all-runtimes test examples

all-runtimes: runtimes
	$(MAKE) -f Makefile.advice runtimes
	$(MAKE) -f Makefile.collargs runtimes

link-all-runtimes: link-runtimes
	$(MAKE) -f Makefile.advice link-runtimes
	$(MAKE) -f Makefile.collargs link-runtimes

unlink-all-runtimes: unlink-runtimes
	$(MAKE) -f Makefile.advice unlink-runtimes
	$(MAKE) -f Makefile.collargs unlink-runtimes

test:
	cd testing && ./MakeTests.py

examples:
	$(MAKE) -C doc/examples
