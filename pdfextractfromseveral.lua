#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile1 page_number infile2 page_number outfile

pdf = require('luapdfrw')

infile1, pagen1, infile2, pagen2, outfile = table.unpack(arg)

indoc1 = pdf.open(infile1)
indoc2 = pdf.open(infile2)

outdoc = pdf.new()
outdoc:insert_page(indoc1:get_page(pagen1))
outdoc:insert_page(indoc1:get_page(pagen2))
outdoc:save(outfile)
