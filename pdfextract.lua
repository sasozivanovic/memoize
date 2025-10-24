#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile page_number outfile

local pdf = require('luapdfrw')

infile, page_n, outfile = table.unpack(arg)

indoc = pdf.open(infile)
outdoc = pdf.new()

page = indoc:get_page(page_n)
outdoc:insert_page(page)
outdoc:update_version(indoc)
outdoc:save(outfile)
