#!/usr/bin/env texlua

-- Usage: pdfextractseveral.lua [-p] infile outfile_prefix page_number [page_number ...]

pdf = require('luapdfrw')

if arg[1] == '-p' then
   prune = true
   table.remove(arg,1)
end

infile = table.remove(arg,1)
outfile_prefix = table.remove(arg,1)
--arg now contains only the page numbers (as strings)

indoc = pdf.open(infile)
pages = indoc:get_pages()

for i, page_n in ipairs(arg) do
   outdoc = pdf.new()
   outdoc:insert_page(pages[tonumber(page_n)])
   outdoc:update_version(indoc)
   outdoc:save(outfile_prefix .. page_n .. '.pdf')
end

--Pruning is virtually instantaneous, as the PDF is incrementally updated.
if prune then
   for i, page_n in ipairs(arg) do
      indoc:remove_page(pages[tonumber(page_n)])
   end
   indoc:update()
end
