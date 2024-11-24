SHELL := /bin/bash
.PHONY: clean all
.SECONDARY:
.DEFAULT_GOAL := all

# todo: compare to the list of used .dtxs
clean:
	find . \( \( -type f -not \( \
		-name '*.dtx' -or -name 'ins.*' -or -name .gitignore -or               \
		-name Makefile -or -name memoize.cfg -or -name extract-excerpts.pl -or \
		-name get-filename-from-mmz.tex                                        \
	\) \) -or \( -type d -name '*.memo.dir' \) \) -print -delete

# expand_n
#
# $(eval $(call expand_n,n,text))
#
# $(1) = <n>
# $(2) = <text>
#
# Returns <n> copies of <text>, with "$$n" in text replaced by i = 1 .. n
# Copies of text are separated by a space, and there's a space at the end, too.
#
# Uses the shell to do this.
#
# Example:
# $(call expand_n,3,file$$n.txt) --> 'file1.txt file2.txt file3.txt '

define expand_n
$(shell for ((n=1;$$n<=$(or $(1),0);n++)) ; do echo -n "$(2) " ; done)
endef


# DTX
#
# $(eval $(call DTX,filename,n))
#
# $(1) = <filename> (may contain suffixes)
# $(2) = <n>, optional
# 
# If <n> is not given, define a rule which processes <filename>.dtx to
# produce <filename>, <filename>.listing and <filename>.attachment.
#
# If <n> is given, it produces <filename>.c<i>, <filename>.c<i>.listing and
# <filename>.c<i>.attachment, for i = 1 .. n
#
# <filename>.ins is produced as an intermediary file.

define DTX
ifeq ($(2),)
TARGETS += $(1)
DTXS += $(1).dtx
$(1) $(1).listing $(1).attachment &: $(1).dtx
else
TARGETS += $(1).c$(2)
$(call expand_n,$(2),$(1).c$$n $(1).c$$n.listing $(1).c$$n.attachment) &: $(1).dtx
endif
	sed 's|example|$(1)|g;' ins.begin > $(1).ins
ifneq ($(2),)
	for ((n=1;$$$$n<=$(or $(2),0);n++)) ;                                   \
		do sed "s|example|$(1)|g; s/c1/c$$$$n/g;" ins.mid >> $(1).ins ; \
	done
endif
	cat ins.end >> $(1).ins
	tex -interaction batchmode $(1).ins
	shopt -s nullglob ; \
		sed -i 's/~//g;' $(1) $(1).attachment $(1).c? $(1).c?.attachment
endef

# PDF
#
# $(eval $(call PDF,basename,n,extra_prereqs,before_each_compilation))
#
# $(1) = <basename>
# $(2) = <n>, optional
# $(3) = extra_prerequisites, optional
# $(4) = before_each_compilation, optional
# 
# If <n> is not given, define a rule which compiles <filename>.tex (the
# prerequisite) to produce <filename>.pdf (the target).
#
# If <n> is given, then for each i = 1 ... n:
#   <filename>.tex.c<i> is copied to <filename>.tex,
#   which is compiled into <filename>.pdf,
#   which is copied to <filename>.c<i>.pdf
# All <filename>.tex.c<i> are prerequisites.
# <filename>.c<i>.pdf are grouped targets.
#
# There is cleaning before compilation.
#
# If extra_prerequisites are given, they are added to prerequisites.
#
# If before_each_compilation is given, it is executed (in bash) just before
# each compilation; the value should end in ";". Use "$$$$n" in the value to
# refer to the compilation cycle number.

define PDF
ifeq ($(2),)
TARGETS += $(1).pdf
$(1).pdf $(1).mmz &: $(1).tex $(3)
else
TARGETS += $(1).c$(2).pdf
$(call expand_n,$(or $(2),0),$(1).c$$n.pdf $(1).mmz.c$$n) &: $(call expand_n,$(or $(2),0),$(1).tex.c$$n) $(3)
endif
	rm -rf $(1).mmz $(1).memo.dir
	latexmk -C $(1) || true
ifeq ($(2),)
	pdflatex -interaction batchmode $(1)
else
	for ((n=1;$$$$n<=$(or $(2),0);n++)) ; do                                 \
		cp $(1).tex.c$$$$n $(1).tex ; $(4)                         \
		pdflatex -interaction batchmode $(1) ;                   \
		cp $(1).pdf $(1).c$$$$n.pdf ;                                \
		if [[ -a $(1).mmz ]] ; then cp $(1).mmz $(1).mmz.c$$$$n ; fi ; \
	done
	rm -f $(1).{tex,pdf,mmz}
endif
endef


# ATT
#
# $(eval $(call ATT,filename,n,attachment_filename))
#
# $(1) = <filename>
# $(2) = <n>, optional
# $(3) = <attachment_filename> optional
#
# Copy <filename> (<filename>.c<n>, if <n> is given) to "attachments" folder.
# The destination is named <attachment_filename>, if given, otherwise <filename>.

define ATT
ATTACHMENTS += attachments/$$(or $(3),$(1))
attachments/$$(or $(3),$(1)): $(1)$(if $(2),.c$(2),).attachment
	mkdir -p $$(dir $$@)
	cp $$< $$@
endef


# DTX+PDF: a shorthand for DTX(<basename.tex>,<n>) followed by PDF(<basename>,<n>).
define DTX+PDF
$(eval $(call DTX,$(1).tex,$(2)))
$(eval $(call PDF,$(1),$(2)))
endef

# DTX+ATT: a shorthand for DTX(<filename>,<n>) followed by ATT(<filename>,<n>).
define DTX+ATT
$(eval $(call DTX,$(1),$(2)))
$(eval $(call ATT,$(1),$(2)))
endef

# DTX+PDF+ATT: a shorthand for DTX(<basename.tex>,<n>) followed by
# PDF(<basename>,<n>) and ATT(<basename>.tex,<n>)
define DTX+PDF+ATT
$(eval $(call DTX,$(1).tex,$(2)))
$(eval $(call PDF,$(1),$(2)))
$(eval $(call ATT,$(1).tex,$(2)))
endef


# Utilities

EMPTY :::=
SPACE :::= $(EMPTY) $(EMPTY)
COMMA = ,
COLON_SPACE = :$(SPACE)
TAB = $(EMPTY)	$(EMPTY)
define NEWLINE


endef

SED_CMD :::= \\\\\([a-zA-Z]\\+\)
SED_CMD_ :::= \\\\[a-zA-Z]\\+
SED_MARG :::= {\([^}]*\)}
SED_MARG_ :::= {[^}]*}

GET_FILENAME_FROM_MMZ = etex \
'\input{get-filename-from-mmz}\get{$(1)}{$(2)}{$(3)}{$(4)}{$(5)}'

# Various

%.listing.attachment: %.listing
	sed 's/~//g;' $< > $@

%.excerpts: ../../%.edtx
	perl extract-excerpts.pl $< > $@
	grep -v '^_' $@ | xargs -r cp -t attachments

TARGETS :=


################################################################################

$(eval $(call DTX+ATT,ConTeXt.tex))

$(eval $(call DTX,auto-ref.tex))

$(eval $(call DTX,collargs-ignore-other-tags.tex,2))

$(eval $(call DTX,collargs-ignore-nesting-true.tex))

$(eval $(call DTX+PDF,automemoize-command))
$(eval $(call ATT,automemoize-command.tex))

$(eval $(call DTX+PDF,automemoize-environment))
$(eval $(call ATT,automemoize-environment.tex))

$(eval $(call DTX+PDF,beamer))
$(eval $(call ATT,beamer.tex))
TARGETS += beamer.cmemo.listing beamer.ccmemo.listing
beamer.cmemo: beamer.mmz
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCMemo,$<,mymemo,$@)
beamer.cmemo.listing: beamer.cmemo
	sed 's/\\mmzSetBeamerOverlays $(SED_MARG)$(SED_MARG)/~\0~/'  `tail -1 $<` > $@
beamer.ccmemo: beamer.mmz
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$<,mymemo,$@)
beamer.ccmemo.listing: beamer.ccmemo
	sed 's/overlay=[0-9]*/~\0~/;   s/pauses=[0-9]*/~\0~/;   s/}\\mmzIncludeExtern/}\n\\mmzIncludeExtern/;   s/\\\mmzStepPgfPictureId/\n\0/;   '  `tail -1 $<` > $@

$(eval $(call DTX+ATT,book.tex))
$(eval $(call DTX+ATT,chapters/chapter1.tex))

$(eval $(call DTX+PDF,capture))
$(eval $(call ATT,capture.tex))

$(eval $(call DTX,chained-advice.tex))
$(eval $(call ATT,chained-advice.tex))

$(eval $(call DTX+PDF,clean-house))
$(eval $(call ATT,clean-house.tex))

$(eval $(call DTX+ATT,collargs-expandable-processor.tex))

$(eval $(call DTX+ATT,collargs-makebox.tex))

$(eval $(call DTX+ATT,collargs-minipage.tex))

$(eval $(call DTX+ATT,collargs-nodelimiters.tex))

$(eval $(call DTX+ATT,collargs-processor.tex))

$(eval $(call DTX+ATT,collargs-return-no.tex))

$(eval $(call DTX+ATT,collargs-return-plain.tex))

$(eval $(call DTX+ATT,collargs-transition-comment.tex))

$(eval $(call DTX+ATT,collargs-transition-cs.tex))

$(eval $(call DTX+ATT,collargs-transition-ok.tex))

$(eval $(call DTX+ATT,collargs-verbatim.tex))

$(eval $(call DTX,countdown.sty,2))
$(eval $(call DTX,countdown.tex,2))
$(eval $(call PDF,countdown,2,countdown.sty.c2,cp countdown.sty.c1 countdown.sty;))
$(eval $(call ATT,countdown.tex,1))
$(eval $(call ATT,countdown.sty,1))
$(eval $(call ATT,countdown.sty,2,countdown-integrated-driver.sty))

$(eval $(call DTX+PDF,dirty-house))
$(eval $(call ATT,dirty-house.tex))

$(eval $(call DTX+ATT,disable-auto-cmd.tex))

$(eval $(call DTX+ATT,disable-auto-env.tex))

$(eval $(call DTX+ATT,disable-bad.tex))

$(eval $(call DTX+ATT,disable-good.tex))

$(eval $(call DTX+ATT,disable-nomemoize.tex))

$(eval $(call DTX+ATT,disable-nommz.tex))

$(eval $(call DTX+PDF+ATT,disable))

$(eval $(call DTX+PDF,fontsize,2))
$(eval $(call ATT,fontsize.tex,1))

$(eval $(call DTX+PDF+ATT,label,3))
TARGETS += label.ccmemo.listing
label.ccmemo: label.mmz.c1
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$<,mymemo,$@)
label.ccmemo.listing: label.ccmemo
	sed 's/\\quitvmode \\mmzIncludeExtern/\\quitvmode\n\\mmzIncludeExtern/;   s/$(SED_MARG)\\mmzIncludeExtern/{\1}\n\\mmzIncludeExtern/;   s/\\mmzLabel *$(SED_MARG)$(SED_MARG)/~\\mmzLabel{\1}{\2}~ /g;   s/\\\mmzStepPgfPictureId/\n\0/;   ' `tail -1 $<` > $@

$(eval $(call DTX,label+.tex,6))
$(eval $(call PDF,label+,2))
TARGETS += label+.ccmemo.listing
label+.ccmemo: label+.mmz.c1
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$<,mymemo,$@)
label+.ccmemo.listing: label+.ccmemo
	sed 's/\\mmzLabel *$(SED_MARG)$(SED_MARG)/~\0~/;   s/$(SED_MARG)\\mmzIncludeExtern/\1 \\mmzIncludeExtern/;   s/\($(SED_MARG_)$(SED_MARG_)$(SED_MARG_)\)\($(SED_MARG_)$(SED_MARG_)$(SED_MARG_)$(SED_MARG_)\)/\1 \2/;'  `tail -1 $<` > $@
$(eval $(call ATT,label+.tex,1))
$(eval $(call ATT,label+.tex,3,label+mmzNoRef.tex))
$(eval $(call ATT,label+.tex,4,label+context.tex))
$(eval $(call ATT,label+.tex,5,label+listii.tex))
$(eval $(call ATT,label+.tex,6,label+auto.tex))

$(eval $(call DTX+PDF+ATT,manual))

$(eval $(call DTX+PDF,meaning-to-context,2))
$(eval $(call ATT,meaning-to-context.tex,1))

$(eval $(call DTX+ATT,memoize-example.cfg))

$(eval $(call DTX+PDF,memoize-internal,2))
$(eval $(call ATT,memoize-internal.tex,1))

$(eval $(call DTX+ATT,memoize-region.cfg))

$(eval $(call DTX+PDF+ATT,mmztikz))

$(eval $(call DTX+PDF,no-linebreaking,2))
$(eval $(call ATT,no-linebreaking.tex,1))

$(eval $(call DTX+PDF+ATT,om-collector-NewDocumentCommand))

$(eval $(call DTX+PDF+ATT,om-collector-newcommand))

$(eval $(call DTX+PDF,overlay,4))
$(eval $(call ATT,overlay.tex,1))
$(eval $(call ATT,overlay.tex,2,overlay-no-padding.tex))
$(eval $(call ATT,overlay.tex,3,overlay-default-padding.tex))
$(eval $(call ATT,overlay.tex,4,overlay-extra-padding.tex))

$(eval $(call DTX+ATT,per-overlay-v1.sty))

$(eval $(call DTX+PDF+ATT,pgfmathparse-embellished))

$(eval $(call DTX+PDF+ATT,pgfmathparse))
TARGETS += pgfmathparse.ccmemo
pgfmathparse.ccmemo: pgfmathparse.mmz
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$<,mymemo,$@)

$(eval $(call DTX+ATT,plainTeX.tex))

poormansbox.pdf: poormansbox.sty
$(eval $(call DTX+ATT,poormansbox.sty))
$(eval $(call DTX+PDF+ATT,poormansbox))

$(eval $(call DTX+ATT,poormansbox-memoizable.sty))
# We compile only to test.
$(eval $(call PDF,poormansbox-memoizable))
poormansbox-memoizable.tex: poormansbox.tex
	sed 's/\\usepackage{poormansbox}/\\usepackage{poormansbox-memoizable}/' $< > $@
poormansbox-memoizable.pdf: poormansbox-memoizable.sty
TARGETS += poormansbox-memoizable.cmemo.listing
poormansbox-memoizable.cmemo: poormansbox-memoizable.mmz
	$(call GET_FILENAME_FROM_MMZ,GetLast,mmzNewCMemo,$<,mymemo,$@)
poormansbox-memoizable.cmemo.listing: poormansbox-memoizable.cmemo
	sed 's/]{/]\n              {/;' `tail -1 $<` > $@

$(eval $(call DTX+ATT,poormansbox-driver.sty))
poormansbox-driver.tex.c1 poormansbox-driver.tex.c2: poormansbox.tex
	sed 's/\\usepackage{poormansbox}/\\usepackage{poormansbox-driver}/' $< > $@
$(eval $(call PDF,poormansbox-driver,2,poormansbox-driver.sty))
TARGETS += poormansbox-driver.ccmemo.listing
poormansbox-driver.ccmemo: poormansbox-driver.mmz.c1
	$(call GET_FILENAME_FROM_MMZ,GetSecond,mmzNewCCMemo,$<,mymemo,$@)
poormansbox-driver.ccmemo.listing: poormansbox-driver.ccmemo
	sed 's/\\csuse *{poormansbox@outer}/~\0~/;   s/{\\mmzIncludeExtern.*}}/~\0~/'  `tail -1 $<` > $@

$(eval $(call DTX+PDF,progressbar,2))
$(eval $(call ATT,progressbar.tex,1))

$(eval $(call DTX+PDF,readonly,2))
$(eval $(call ATT,readonly.tex,1))

$(eval $(call DTX+PDF,recompile,3))
$(eval $(call ATT,recompile.tex,1))

$(eval $(call DTX+ATT,record-extern-pages.tex))

$(eval $(call DTX+ATT,record-files.tex))

$(eval $(call DTX+PDF,redefinitions,7))
$(eval $(call ATT,redefinitions.tex,1))

$(eval $(call DTX+PDF,ref,7))
$(eval $(call ATT,ref.tex,3))
$(eval $(call ATT,ref.tex,7,ref-force.tex))
TARGETS += ref.cmemo.listing
ref.cmemo: ref.mmz.c1
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCMemo,$<,mymemo,$@)
ref.cmemo.listing: ref.cmemo
	sed 's/\\global.*/~\0~/'  `tail -1 $<` > $@

$(eval $(call DTX+PDF+ATT,salt))

$(eval $(call DTX+ATT,sectionbox.tex))

$(eval $(call DTX+PDF+ATT,skak))

$(eval $(call DTX+PDF+ATT,test))

$(eval $(call DTX+PDF+ATT,titlepage,2))
TARGETS += titlepage.mmz-pre titlepage.mmz-post \
	   titlepage.cmemo titlepage.ccmemo.listing
titlepage.mmz-pre: titlepage.mmz.c1
	sed 's/\\mmzNewExtern/~\0~/' $< > $@
titlepage.mmz-post: titlepage.mmz.c2
	sed 's/\\mmzUsedExtern/~\0~/' $< > $@
titlepage.cmemo: titlepage.mmz.c1
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCMemo,$<,mymemo,$@)
titlepage.ccmemo: titlepage.mmz.c1
	$(call GET_FILENAME_FROM_MMZ,GetFirst,mmzNewCCMemo,$<,mymemo,$@)
titlepage.ccmemo.listing: titlepage.ccmemo
	sed 's/\\quitvmode \\mmzIncludeExtern/\\quitvmode\n\\mmzIncludeExtern/; s/\\\mmzStepPgfPictureId/\n\0/' `tail -1 $<` > $@

$(eval $(call DTX+PDF+ATT,verbatim-auto))

$(eval $(call DTX+PDF+ATT,verbatim-manual))

$(eval $(call DTX+ATT,vref.tex))

################################################################################

TARGETS += $(ATTACHMENTS)

../examples.zip: $(ATTACHMENTS) memoize.excerpts advice.excerpts collargs.excerpts
	rm -f $@
	cd attachments && grep -hv '^_' ../memoize.excerpts ../advice.excerpts ../collargs.excerpts | xargs -r zip -r ../$@ $(ATTACHMENTS:attachments/%=%)

../examples-src.zip: Makefile ins.begin ins.mid ins.end memoize.cfg \
		extract-excerpts.pl get-filename-from-mmz.tex $(DTXS) 
	rm -f $@
	zip -r $@ $^

all: $(TARGETS) ../examples.zip ../examples-src.zip
