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
   outdoc:insert_page(
      --We need to insert the copy for the pruning to work. Inserting a page
      --into another document changes its parent, so it is (in a way) not a
      --part of the source document any more.
      pdf.copy(pages[tonumber(page_n)])
   )
   outdoc:save(outfile_prefix .. page_n .. '.pdf')
end

--Pruning is virtually instantaneous, as the PDF is incrementally updated.
if prune then
   for i, page_n in ipairs(arg) do
      indoc:remove_page(pages[tonumber(page_n)])
   end
   indoc:update()
end
