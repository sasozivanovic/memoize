#!/usr/bin/env texlua

-- Usage: pdfextract.lua file1 page_number file2

local pdf = require('luapdfrw')

file1, page_n, file2 = table.unpack(arg)

doc1 = pdf.open(file1)
doc2 = pdf.open(file2)

pages = doc2:get_pages()
for i=#pages,1,-1 do
   doc1:insert_page(tonumber(page_n), pages[i])
end
doc1:update(file1)
