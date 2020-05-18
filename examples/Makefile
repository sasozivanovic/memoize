all: 1-basic.pdf 2-memodir.pdf 3-enable-disable-prevent.pdf 4-main.pdf 5-overlay.pdf

%.pdf: %.tex
	pdflatex -interaction batchmode $<
	pdflatex -interaction batchmode -shell-escape $<

4-main.tex: chapters/4-chapter.tex

cleantmp: 
	find . -regex '^.*\.\(log\|aux\|synctex.gz\|el\)$$' -exec rm {} \;

cleanmemo:
	find . -regex '^.*\.\(mmz\|memo\|memo.pdf\)$$' -exec rm {} \;

cleanbak: 
	find . -name '*~' -exec rm {} \;

cleanpdf:
	find . -name '*.pdf' -exec rm {} \;

clean: cleantmp cleanbak cleanmemo
