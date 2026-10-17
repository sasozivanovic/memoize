# Prepare the CTAN submission for all three packages.

PACKAGES = memoize advice collargs

.PHONY: all force clean versions-show \
	all-runtimes link-all-runtimes install-all-runtimes unlink-all-runtimes \
	test examples

all: ctan/memoize.zip
	$(MAKE) -f Makefile.advice ctan/advice.zip
	$(MAKE) -f Makefile.collargs ctan/collargs.zip
	@echo "Don't forget to run the tests!"

# Prepare the CTAN submission.

PACKAGE = memoize
VERSION = 1.5.0-rc1
YEAR = 2026
MONTH = 10
DAY = 17

FORMAT = generic

COMMON = memoize nomemoize memoizable
PLAIN = memoize-extract-one.tex
GENERIC = memoizable.code.tex
LATEX = memoize-biblatex.code.tex memoize-beamer.code.tex
SOURCE = memoize.edtx memoize.ins

LUA_SCRIPTS := memoize-extract.lua memoize-utils.lua
OTHER_SCRIPTS := memoize-extract.py memoize-clean.py memoize-extract.pl memoize-clean.pl
SCRIPTS := $(LUA_SCRIPTS) $(OTHER_SCRIPTS)

MAN := memoize-extract memoize-utils memoize-utils-clean memoize-utils-info \
	memoize-extract.pl memoize-clean.pl
man-src := $(MAN:%=doc/%.1.md)
MAN := $(MAN:%=doc/%.1) doc/memoize-extract.py.1 doc/memoize-clean.py.1

%.py.1: %.pl.1
	echo .so man1/$*.1 > $@     # link to .pl.1 man page

README = doc/README.memoize.md
INSTALL = INSTALL.md
CHANGELOG = CHANGELOG.md
MAKEFILE = Makefile Makefile.package Makefile.runtimes Makefile.advice Makefile.collargs
LICENCE = LICENCE

PACKAGES.edtx = $(PACKAGES:%=%.edtx)
PACKAGES.dtx = $(PACKAGES:%=%.dtx)
PACKAGES.ins = $(PACKAGES:%=%.ins)

codedoc-source = memoize-code.tex \
                 memoize-code.sty memoize-doc-common.sty \
		 memoize-code.latexmkrc

manual-source = memoize-doc.tex \
                memoize-doc.sty memoize-doc-common.sty yadoc.sty \
		memoize-doc.mst memoize-doc.latexmkrc

PDF = memoize-doc.pdf memoize-code.pdf

codedoc-source := $(codedoc-source:%=doc/%)
manual-source := $(manual-source:%=doc/%)
pdf := $(PDF:%=doc/%)
DOC = $(codedoc-source) $(manual-source) $(pdf) $(man-src) \
      doc/examples-src.zip doc/examples.zip

# For local binaries (install/link-runtimes):
BIN-DIR = ~/texmf/bin
BIN = $(basename $(LUA_SCRIPTS)) $(OTHER_SCRIPTS)
BIN.memoize-extract = $(TDS-SCRIPTS-DIR)/memoize-extract.lua
BIN.memoize-utils = $(TDS-SCRIPTS-DIR)/memoize-utils.lua
BIN.memoize-extract.py = $(TDS-SCRIPTS-DIR)/memoize-extract.py
BIN.memoize-extract.pl = $(TDS-SCRIPTS-DIR)/memoize-extract.pl
BIN.memoize-clean.py = $(TDS-SCRIPTS-DIR)/memoize-clean.py
BIN.memoize-clean.pl = $(TDS-SCRIPTS-DIR)/memoize-clean.pl

# For Lua tests
LUA_VERSION := 5.3
LUA_PREFIXES := /usr $(HOME)/.luarocks
LUA_EXTRA_DIRS = \
	$(LUA_PREFIXES:%=%/share/lua/$(LUA_VERSION)/?.lua) \
	$(LUA_PREFIXES:%=%/share/lua/$(LUA_VERSION)/?/init.lua) \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/?.lua) \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/?/init.lua)
LUA_EXTRA_CDIRS = \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/?.so) \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/loadall.so)
# both .so and .dll, to simplify matters
LUA_EXTRA_CDIRS = \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/?.so) \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/loadall.so) \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/?.dll) \
	$(LUA_PREFIXES:%=%/lib/lua/$(LUA_VERSION)/loadall.dll)
noop =
space = $(noop) $(noop)
LUA_PATH = ;;$(subst $(space),;,$(LUA_EXTRA_DIRS))
LUA_CPATH = ;;$(subst $(space),;,$(LUA_EXTRA_CDIRS))

doc/examples-src.zip: $(examples-src)
	$(MAKE) -C doc/examples ../examples-src.zip

doc/examples.zip: $(examples-src)
	$(MAKE) -C doc/examples ../examples.zip

ctan/$(PACKAGE).zip:
	$(TDS-BEGIN)
	$(TDS-END)
	$(CTAN-BEGIN)
	$(CTAN-END)

%.py.dtx: %.py
	edtx2dtx -s -c '#' -B '^__version__' -E '^# Local Variables:' $< > $@

%.pl.dtx: %.pl
	edtx2dtx -s -c '#' -B '^my \$$PROG' -E '^# Local Variables:' $< > $@

%.lua.dtx: %.lua
	edtx2dtx -s -c '---' -B '^local VERSION' -E '^--- Local Variables:' $< > $@

doc/memoize-code.pdf: $(codedoc-source) \
                      $(PACKAGES.dtx) $(PACKAGES.ins) $(SCRIPTS:%=%.dtx)

doc/memoize-doc.pdf: $(manual-source) $(PACKAGES.edtx) doc/examples.zip

%.pdf: %.tex
	latexmk -r $*.latexmkrc $(LATEXMK) $<



# Maintenance

test.tex = $(wildcard test*.tex)

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
	$(call EDIT-VERSION-LUA,memoize-extract.lua)
	$(call EDIT-VERSION-LUA,memoize-utils.lua)
	$(call EDIT-VERSION-MAN,doc/memoize-extract.pl.1.md)
	$(call EDIT-VERSION-MAN,doc/memoize-clean.pl.1.md)
	$(call EDIT-VERSION-MAN,doc/memoize-extract.1.md)
	$(call EDIT-VERSION-MAN,doc/memoize-utils.1.md)
	$(call EDIT-VERSION-MAN,doc/memoize-utils-clean.1.md)
	$(call EDIT-VERSION-MAN,doc/memoize-utils-info.1.md)
	$(call EDIT-DATE-CHANGELOG,CHANGELOG.md)
	$(call EDIT-VERSION-LATEX,doc/memoize-doc.tex,memoize)
	$(call EDIT-VERSION-LATEX,doc/memoize-code.tex,memoize)
define COLOR_VERSION
grep -E --color '[0-9]{4}[/-][0-9]{1,2}[/-][0-9]{1,2}|v?[0-9]\.[0-9]\.[0-9]([-a-z]*)|(January|February|March|April|May|June|July|August|September|October|November|December) [0-9]+, [0-9]{4}'
endef

versions-show:
	@grep -E '\\ProvidesPackage|^%<context>%D\s*(version|date)=' $(PACKAGES.edtx) $(pdf:%.pdf=%.tex) | ${COLOR_VERSION}
	@grep __version__ *.py | ${COLOR_VERSION}
	@grep VERSION *.lua *.pl | ${COLOR_VERSION}
	@grep -E '^(footer|date):' doc/memoize-*.md | ${COLOR_VERSION}
	@${COLOR_VERSION} CHANGELOG.md doc/CHANGELOG.advice.md doc/CHANGELOG.collargs.md

include Makefile.package
include Makefile.runtimes # comment this out for luatestwin if using GnuWin32 make

VERSION-MAN = of Memoize v$(VERSION)

all-runtimes: runtimes
	$(MAKE) -f Makefile.advice runtimes
	$(MAKE) -f Makefile.collargs runtimes

link-all-runtimes: link-runtimes
	$(MAKE) -f Makefile.advice link-runtimes
	$(MAKE) -f Makefile.collargs link-runtimes

install-all-runtimes: install-runtimes
	$(MAKE) -f Makefile.advice install-runtimes
	$(MAKE) -f Makefile.collargs install-runtimes

uninstall-all-runtimes: uninstall-runtimes
	$(MAKE) -f Makefile.advice uninstall-runtimes
	$(MAKE) -f Makefile.collargs uninstall-runtimes

test-venv:
	rm -rf testing/venv
	cd testing && python -m venv venv
	testing/venv/bin/pip install --upgrade pip
	testing/venv/bin/pip install -r testing/requirements.txt

test: luatest
	mkdir -p testing/{build,success}
	cd testing && source venv/bin/activate && ./MakeTests.py

TEXLUA := texlua
BUSTED := busted

luatest:
	cd testing && LUA_PATH="$(LUA_PATH)" LUA_CPATH="$(LUA_CPATH)" \
		$(BUSTED) --lua $(TEXLUA) test-memoize-extract.lua $(LUATESTFLAGS)

# make luatestwin BUSTED=Z:\win\luarocks\bin\busted.bat LUA_PREFIXES="Z:\win\luarocks"

luatestwin: 
	set LUA_PATH="$(LUA_PATH)" && set LUA_CPATH="$(LUA_CPATH)" && cd testing && $(BUSTED) --lua $(TEXLUA) -o plainTerminal test-memoize-extract.lua $(LUATESTFLAGS)

test-clean:
	rm -rf testing/build
