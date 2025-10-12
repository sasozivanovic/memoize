#!/usr/bin/env texlua

-- Usage: pdfprune.lua infile page_number [page_number ...]

pdf = require('luapdfrw')

filename = table.remove(arg,1) --arg now contains only the page numbers

doc = pdf.open(filename)

pages = doc:get_pages()
for i, page_n in ipairs(arg) do
   doc:remove_page(pages[tonumber(page_n)])
end

doc:update()
