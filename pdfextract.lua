#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile page_number outfile

require('pdfw')

infile = arg[1]
page_n = tonumber(arg[2])
outfile = arg[3]

doc = pdfe.open(infile)
pdf = pdfw.new()
pdfw.append_page(pdf, doc, page_n)
pdfw.save(pdf, outfile)
