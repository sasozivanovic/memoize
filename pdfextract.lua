#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile page_number outfile

local pdf = require('luapdfrw')

infile, page_n, outfile = table.unpack(arg)

indoc = pdf.open(infile)
outdoc = pdf.new()
outdoc.major, outdoc.minor = indoc.major, indoc.minor

page = indoc:get_page(tonumber(page_n))
outdoc:insert_page(page)
outdoc:save(outfile)
