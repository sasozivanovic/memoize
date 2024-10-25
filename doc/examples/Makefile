SHELL := /bin/bash
.PHONY: clean all excerpts
.SECONDARY:
.DEFAULT_GOAL := all

clean:
	find . \( \( -type f -not \( \
		-name '*.dtx' -or -name 'ins.*' -or -name .gitignore -or               \
		-name Makefile -or -name memoize.cfg -or -name extract-excerpts.pl -or \
		-name get-filename-from-mmz.tex                                        \
	\) \) -or \( -type d -name '*.memo.dir' \) \) -print -delete

N = 0

%.pdf: %.tex
	touch $*.mmz ; memoize-clean.py --all --yes $*.mmz
	rm -f $*.mmz
	latexmk -C $*
	if [[ $(N) > 0 ]] ; then                                               \
		for ((n=1;$$n<=$(N);n++)) ; do                                 \
			cp $*.tex.c$$n $*.tex ; $(BEFORE_EACH_COMPILATION)     \
			pdflatex -interaction batchmode $* ;                   \
			cp $*.pdf $*.c$$n.pdf ;                                \
			if [[ -a $*.mmz ]] ; then cp $*.mmz $*.mmz.c$$n ; fi ; \
		done ;                                                         \
	else                                                                   \
		pdflatex -interaction batchmode $* ;                           \
	fi

%:: %.dtx
	sed 's|example|$*|g;' ins.begin > $*.ins
	for ((n=1;$$n<=$(N);n++)) ;                                       \
		do sed "s|example|$*|g; s/c1/c$$n/g;" ins.mid >> $*.ins ; \
	done
	cat ins.end >> $*.ins
	tex -interaction batchmode $*.ins
	shopt -s nullglob ; sed -i 's/~//g;' $* $*.attachment $*.c? $*.c?.attachment

%.listing.attachment: %.listing
	sed 's/~//g;' $< > $@

EMPTY :::=
SPACE :::= $(EMPTY) $(EMPTY)
SED_CMD :::= \\\\\([a-zA-Z]\\+\)
SED_CMD_ :::= \\\\[a-zA-Z]\\+
SED_MARG :::= {\([^}]*\)}
SED_MARG_ :::= {[^}]*}
GET_FILENAME_FROM_MMZ = etex '\input{get-filename-from-mmz}\get{$(1)}{$(2)}{$(3)}{$(4)}{$(5)}'

excerpts: memoize.excerpts advice.excerpts collargs.excerpts

%.excerpts: ../../%.edtx
	perl extract-excerpts.pl $< && touch $@

TARGETS = memoize-example.cfg disable-bad.tex disable-good.tex disable-nomemoize.tex disable-nommz.tex disable-auto-cmd.tex disable-auto-env.tex book.tex chapters/chapter1.tex memoize-region.cfg titlepage.pdf test.pdf manual.pdf mmztikz.pdf automemoize-environment.pdf automemoize-command.pdf recompile.pdf disable.pdf readonly.pdf meaning-to-context.pdf clean-house.pdf dirty-house.pdf beamer.pdf overlay.pdf verbatim-manual.pdf verbatim-auto.pdf capture.pdf no-linebreaking.pdf sectionbox.tex ref.pdf vref.tex fontsize.pdf skak.pdf redefinitions.pdf progressbar.pdf poormansbox.sty poormansbox.pdf poormansbox-memoizable.sty poormansbox-memoizable.pdf memoize-internal.pdf label.pdf label+.pdf per-overlay-v1.sty salt.pdf record-files.tex record-extern-pages.tex pgfmathparse.pdf pgfmathparse-embellished.pdf countdown.pdf countdown.sty poormansbox-driver.pdf poormansbox-driver.sty _auto-ref.tex chained-advice.tex om-collector-NewDocumentCommand.tex om-collector-newcommand.tex collargs-makebox.tex collargs-minipage.tex collargs-verbatim.tex plainTeX.tex ConTeXt.tex _collargs-verbatim.tex _collargs-ignore-other-tags.tex collargs-processor.tex collargs-expandable-processor.tex collargs-nodelimiters.tex collargs-return-plain.tex collargs-return-no.tex collargs-transition-ok.tex collargs-transition-cs.tex collargs-transition-comment.tex \
titlepage.mmz.c1 titlepage.mmz.c2 titlepage.cmemo titlepage.ccmemo poormansbox-memoizable.cmemo label.ccmemo label+.ccmemo ref.cmemo beamer.cmemo beamer.ccmemo poormansbox-driver.ccmemo pgfmathparse.ccmemo

all: excerpts $(TARGETS)

chained-advice.tex _collargs-ignore-other-tags.tex countdown.sty poormansbox-driver.pdf fontsize.pdf label+.pdf meaning-to-context.pdf memoize-internal.pdf no-linebreaking.pdf progressbar.pdf readonly.pdf titlepage.pdf : N = 2
label.pdf recompile.pdf : N = 3
overlay.pdf : N = 4
label+.tex redefinitions.pdf : N = 6
ref.pdf : N = 7

poormansbox.pdf: poormansbox.sty
poormansbox-memoizable.pdf: poormansbox-memoizable.sty
countdown.pdf: countdown.sty
countdown.pdf: N = 2 
countdown.pdf: BEFORE_EACH_COMPILATION = cp $*.sty.c1 $*.sty ;
poormansbox-driver.pdf: poormansbox-driver.sty

titlepage.mmz.c1: titlepage.pdf
	sed -i 's/\\mmzNewExtern/~\0~/' $@

titlepage.mmz.c2: titlepage.pdf
	sed -i 's/\\mmzUsedExtern/~\0~/' $@

titlepage.cmemo: titlepage.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCMemo,$(basename $<).mmz.c1,mymemo,$@)

titlepage.ccmemo: titlepage.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$(basename $<).mmz.c1,mymemo,$@)
	sed 's/\\quitvmode \\mmzIncludeExtern/\\quitvmode\n\\mmzIncludeExtern/; s/\\\mmzStepPgfPictureId/\n\0/' `tail -1 titlepage.ccmemo` > $@.listing

poormansbox-memoizable.cmemo: poormansbox-memoizable.pdf
	$(call GET_FILENAME_FROM_MMZ,GetLast,mmzNewCMemo,$(basename $<).mmz,mymemo,$@)
	sed 's/]{/]\n              {/;' `tail -1 $@` > $@.listing

label.ccmemo: label.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$(basename $<).mmz.c1,mymemo,$@)
	sed 's/\\quitvmode \\mmzIncludeExtern/\\quitvmode\n\\mmzIncludeExtern/;   s/$(SED_MARG)\\mmzIncludeExtern/{\1}\n\\mmzIncludeExtern/;   s/\\mmzLabel *$(SED_MARG)$(SED_MARG)/~\\mmzLabel{\1}{\2}~ /g;   s/\\\mmzStepPgfPictureId/\n\0/;   ' `tail -1 $@` > $@.listing

label+.ccmemo: label+.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$(basename $<).mmz.c1,mymemo,$@)
	sed 's/\\mmzLabel *$(SED_MARG)$(SED_MARG)/~\0~/;   s/$(SED_MARG)\\mmzIncludeExtern/\1 \\mmzIncludeExtern/;   s/\($(SED_MARG_)$(SED_MARG_)$(SED_MARG_)\)\($(SED_MARG_)$(SED_MARG_)$(SED_MARG_)$(SED_MARG_)\)/\1 \2/;'  `tail -1 $@` > $@.listing

ref.cmemo: ref.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCMemo,$(basename $<).mmz.c1,mymemo,$@)
	sed 's/\\global.*/~\0~/'  `tail -1 $@` > $@.listing

beamer.cmemo: beamer.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCMemo,$(basename $<).mmz,mymemo,$@)
	sed 's/\\mmzSetBeamerOverlays $(SED_MARG)$(SED_MARG)/~\0~/'  `tail -1 $@` > $@.listing

beamer.ccmemo: beamer.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$(basename $<).mmz,mymemo,$@)
	sed 's/overlay=[0-9]*/~\0~/;   s/pauses=[0-9]*/~\0~/;   s/}\\mmzIncludeExtern/}\n\\mmzIncludeExtern/;   s/\\\mmzStepPgfPictureId/\n\0/;   '  `tail -1 $@` > $@.listing

poormansbox-driver.ccmemo: poormansbox-driver.pdf
	$(call GET_FILENAME_FROM_MMZ,GetSecond,mmzNewCCMemo,$(basename $<).mmz.c1,mymemo,$@)
	sed 's/\\csuse *{poormansbox@outer}/~\0~/;   s/{\\mmzIncludeExtern.*}}/~\0~/'  `tail -1 $@` > $@.listing

pgfmathparse.ccmemo: pgfmathparse.pdf
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$(basename $<).mmz,mymemo,$@)

