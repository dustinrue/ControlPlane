TARGETS = help.pdf

all:	$(TARGETS)

%-full.pdf : %.tex
	pdflatex "$^"
	mv "$*.pdf" "$@"
	rm "$*.aux" "$*.log"

%.pdf : %-full.pdf
	pdfcrop --margins 5 "$<" "$@"
