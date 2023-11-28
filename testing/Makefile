PYL=pl
TESTS = \
success/unittest-memoize-extract.$(PYL)\
success/extract-nomemodir.$(PYL)\
success/extract-memodir.$(PYL)\
success/extract-from-subdir.$(PYL)\
success/extract-from-subdir-no-memos.$(PYL)\
success/extract-from-parallel-dir.$(PYL)\
success/extract-from-subdir-memos.$(PYL)\
success/extract-from-subdir-prune.$(PYL)\
success/extract-to-tmp.$(PYL)\
success/mkdir.$(PYL)\
success/compile-and-extract-to-tmp.$(PYL)\
success/compile-and-extract-to-od.$(PYL)\
success/extract-to-notmp.$(PYL)\
success/extract-to-bad-relative-tmp.$(PYL)\
success/mmz-log.$(PYL)\
success/prune-size-mismatch.$(PYL)\


.PHONY: all

all: $(TESTS)
SRCDIR=..

define CLEAN
chmod -R +rwx test tmp
rm -rf test tmp
mkdir test tmp
endef

CWD = $(shell pwd)
DIFF=GIT_PAGER=cat git diff --no-index --word-diff=color --word-diff-regex=.

define title
@echo
@echo "===========================  $(1)  ==========================="
@echo $(2)
endef

success/unittest-memoize-extract.$(PYL): unittest-memoize-extract.$(PYL) $(SRCDIR)/memoize-extract.$(PYL)
	./$<
	touch $@

build/nomemodir/doc.pdf: src/nomemodir/doc.tex
	$(call title,"Compiling $@")
	rm -rf build/nomemodir/
	mkdir build/nomemodir/
	cp src/nomemodir/doc.tex build/nomemodir/
	cd build/nomemodir/ && pdflatex doc
	$(DIFF) {expected/nomemodir,build/nomemodir}/doc.mmz
	$(DIFF) {expected/nomemodir,build/nomemodir}/doc.799CD96D5634EBEB7E30191285AF4082.memo
	$(DIFF) {expected/nomemodir,build/nomemodir}/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	$(DIFF) {expected/nomemodir,build/nomemodir}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80.memo
	$(DIFF) {expected/nomemodir,build/nomemodir}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo

build/memodir/doc.pdf: src/memodir/doc.tex
	$(call title,"Compiling $@")
	rm -rf build/memodir
	mkdir -p build/memodir/doc.memo.dir
	cp src/memodir/doc.tex build/memodir
	cd build/memodir && pdflatex doc
	$(DIFF) {expected/memodir,build/memodir}/doc.mmz
	$(DIFF) {expected/memodir,build/memodir}/doc.memo.dir/799CD96D5634EBEB7E30191285AF4082.memo
	$(DIFF) {expected/memodir,build/memodir}/doc.memo.dir/799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	$(DIFF) {expected/memodir,build/memodir}/doc.memo.dir/7DBC7B29C0C49BCFD5C4A18740E06E80.memo
	$(DIFF) {expected/memodir,build/memodir}/doc.memo.dir/7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo

success/extract-nomemodir.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,"Extract from a [nomemodir] document")
	$(CLEAN)
	cp -r build/nomemodir/* test
	cd test && memoize-extract.$(PYL) doc.mmz
	$(DIFF) expected/extract-nomemodir/doc.mmz test/doc.mmz
	[[ -a test/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	[[ -a test/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	touch $@

success/extract-memodir.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/memodir/doc.pdf
	$(call title,"Extract from a [memodir] document","Also test that memoize-extract can be called without .mmz suffix")
	$(CLEAN)
	cp -r build/memodir/* test
	cd test && memoize-extract.$(PYL) doc
	$(DIFF) expected/extract-memodir/doc.mmz test/doc.mmz
	[[ -a test/doc.memo.dir/799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	[[ -a test/doc.memo.dir/7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	touch $@

# "! memoize-extract" ... makes this test (and others) succeed upon failure
success/extract-from-subdir.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,".mmz in a parent directory without -k","")
	$(CLEAN)
	cp -r build/nomemodir/* test
	mkdir test/foo
	cd test/foo && ! memoize-extract.$(PYL) ../doc.mmz
	touch $@

success/extract-from-subdir-no-memos.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,".mmz in a parent directory with -k","This fails because the associated .memo files don't exist")
	$(CLEAN)
	cp -r build/nomemodir/* test
	mkdir test/foo
	cd test/foo && ! memoize-extract.$(PYL) -k ../doc.mmz
	touch $@

success/extract-from-subdir-memos.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,".mmz in a parent directory with -k","Successful because first copy the associated .memo files into /tmp")
	$(CLEAN)
	cp -r build/nomemodir/* test
	mkdir test/foo
	mv test/doc.*.memo test/foo
	cd test/foo && memoize-extract.$(PYL) -k ../doc.mmz
	touch $@

success/extract-from-parallel-dir.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,".mmz in a parallel directory","Fails without --keep")
	$(CLEAN)
	cp -r build/nomemodir/* test
	cd tmp && ! memoize-extract.$(PYL) ../test/doc.mmz
	touch $@

success/extract-from-subdir-prune.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,".mmz in a parallel directory","Fails due to --prune")
	$(CLEAN)
	cp -r build/nomemodir/* test
	mkdir test/foo
	cd test/foo && ! memoize-extract.$(PYL) -kp ../doc.mmz
	touch $@

success/extract-to-tmp.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,"Output to a temporary directory","The current directory is non-writable")
	$(CLEAN)
	cp -r build/nomemodir/* test
	chmod -w test
	cd test && TEXMFOUTPUT=$(CWD)/tmp memoize-extract.$(PYL) doc.mmz
	touch $@

success/mkdir.$(PYL):  $(SRCDIR)/memoize-extract.$(PYL)
	$(call title,"--mkdir","(a) Create a subdir .. OK; (b) create a parallel dir .. FAIL; (c) create a subsubdir .. OK; (d) create a subdir referred to using \"..\" .. FAIL")
	$(CLEAN)
	cd test && memoize-extract.$(PYL) --mkdir foo
	cd test/foo && ! memoize-extract.$(PYL) --mkdir ../bar ; echo $$?
	memoize-extract.$(PYL) --mkdir tmp/foo
	! memoize-extract.$(PYL) --mkdir tmp/foo/../bar
	touch $@

success/compile-and-extract-to-tmp.$(PYL): src/nomemodir/doc.tex
	$(call title,"Compile and extract to a temporary directory","Current directory is not writable; also test that memoize-extract can be called with .tex suffix")
	$(CLEAN)
	cp src/nomemodir/doc.tex test
	chmod -w test
	cd test && TEXMFOUTPUT=$(CWD)/tmp pdflatex doc
	$(DIFF) {expected/nomemodir,$(CWD)/tmp}/doc.mmz
	$(DIFF) {expected/nomemodir,$(CWD)/tmp}/doc.799CD96D5634EBEB7E30191285AF4082.memo
	$(DIFF) {expected/nomemodir,$(CWD)/tmp}/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	$(DIFF) {expected/nomemodir,$(CWD)/tmp}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80.memo
	$(DIFF) {expected/nomemodir,$(CWD)/tmp}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	cd test && TEXMFOUTPUT=$(CWD)/tmp memoize-extract.$(PYL) doc.tex
	[[ -a $(CWD)/tmp/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	[[ -a $(CWD)/tmp/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	touch $@

success/compile-and-extract-to-od.$(PYL): src/nomemodir/doc.tex
	$(call title,"Compile and extract to output directory","")
	$(CLEAN)
	cp src/nomemodir/doc.tex test
	mkdir test/od
	cd test && pdflatex -output-directory=od doc
	$(DIFF) {expected/nomemodir,test/od}/doc.mmz
	$(DIFF) {expected/nomemodir,test/od}/doc.799CD96D5634EBEB7E30191285AF4082.memo
	$(DIFF) {expected/nomemodir,test/od}/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	$(DIFF) {expected/nomemodir,test/od}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80.memo
	$(DIFF) {expected/nomemodir,test/od}/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	cd test && TEXMF_OUTPUT_DIRECTORY=od memoize-extract.$(PYL) doc.tex
	[[ -a test/od/doc.799CD96D5634EBEB7E30191285AF4082-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	[[ -a test/od/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf ]]
	touch $@

success/extract-to-notmp.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,"Output to a non-existing temporary directory","We end up attempting to write to a readonly current directory and get a permission error")
	$(CLEAN)
	cp -r build/nomemodir/* test
	chmod -w test
	cd test && ! TEXMFOUTPUT=$(CWD)/tmp/does/not/exist memoize-extract.$(PYL) doc.mmz
	touch $@

success/extract-to-bad-relative-tmp.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,"Output to a temporary directory involving \"..\"","Paranoia kicks in")
	$(CLEAN)
	cp -r build/nomemodir/* test
	chmod -w test
	cd test && ! TEXMFOUTPUT=../tmp memoize-extract.$(PYL) doc.mmz
	touch $@

success/mmz-log.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,"Create .mmz.log for LaTeX")
	$(CLEAN)
	cp -r build/nomemodir/* test
	cd test && memoize-extract.$(PYL) -F latex doc.mmz
	[[ -a test/doc.mmz.log ]]
	[[ `grep '^\\\\PackageInfo' test/doc.mmz.log | wc -l` == 4 ]]
	[[ `grep '^\\\\endinput$$' test/doc.mmz.log | wc -l` == 1 ]]
	touch $@

success/prune-size-mismatch.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,Problems due to a previous --prune,The original document contains two extern pages. Pruning removes both.  The second extraction throws a size-mismatch warning trying to extract a document page 1, an error trying to extract a non-existing page 2.)
	$(CLEAN)
	cp -r build/nomemodir/* test
	cd test && memoize-extract.$(PYL) --keep --prune doc.mmz
	cd test && ! memoize-extract.$(PYL) -F latex doc.mmz
	[[ -a test/doc.mmz.log ]]
	[[ `grep '^\\\\PackageWarning' test/doc.mmz.log | wc -l` == 1 ]]
	[[ `grep '^\\\\PackageError' test/doc.mmz.log | wc -l` == 1 ]]
	touch $@

success/extract-no-memos.$(PYL): $(SRCDIR)/memoize-extract.$(PYL) build/nomemodir/doc.pdf
	$(call title,"Removed memo files","")
	$(CLEAN)
	cp -r build/nomemodir/* test
	rm test/doc.799CD96D5634EBEB7E30191285AF4082.memo test/doc.7DBC7B29C0C49BCFD5C4A18740E06E80-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.memo
	cd test && ! memoize-extract.$(PYL) doc
	touch $@
