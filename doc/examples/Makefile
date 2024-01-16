SHELL := /bin/bash
N = 1

.PRECIOUS: %.c1

%.ins: ins.begin ins.mid ins.end
	sed 's|example|$*|g;' $< > $@
	cat ins.begin > $@
	for n in {1..$N} ; do sed "s|example|$*|g; s/c1/c$$n/g;" ins.mid >> $@ ; done
	cat ins.end >> $@

%.c1: %.dtx %.ins
	tex -interaction batchmode $*.ins
	sed -i 's/~//g;' $*.c? $*.c?.attachment
	echo $@

%.pdf: %.tex.c1
	cp $*.tex.c1 $*.tex
	touch $*.mmz ; memoize-clean.py --all --yes $*.mmz
	rm -f $*.mmz
	latexmk -C $*
	for n in {1..$N}; do cp $*.tex.c$$n $*.tex ; pdflatex -interaction batchmode $* ; cp $*.pdf $*.c$$n.pdf ; if [[ -a $*.mmz ]] ; then cp $*.mmz $*.mmz.c$$n ; fi ; done

%.sty: %.sty.c1
	cp $*.sty.c$N $@

%.excerpt: $(SOURCE)
	if [[ -z '$(SOURCE)' ]] ; then echo Empty SOURCE! ; false ; fi
	perl -e '$$f=q{$*}; while(<>) {$$r &&= !/^ *% *\\\Qend{listingregion}/; print if $$r; $$r ||= /^ *% *\\\Qbegin{listingregion}{$$f}/; }' ${SOURCE} > $@

%.listing.attachment: %.listing
	sed 's/~//g;' $< > $@

.PHONY: clean
clean:
	find . -type f -not \( -name '*.dtx' -or -name 'ins.*' -or -name .gitignore -or -name Makefile \) -delete
