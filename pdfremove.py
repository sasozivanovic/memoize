#!/usr/bin/env texlua

-- Usage: pdfprune.lua [-n] infile page_number [page_number ...]

pdf = require('luapdfrw')

if arg[1] == '-n' then
   by_numbers = true
   table.remove(arg,1)
end

filename = table.remove(arg,1) --arg now contains only the page numbers

doc = pdf.open(filename)

if by_numbers then
   --pass page numbers to remove_page
   --they need to be passed in reverse (numeric!) order
   for i,v in ipairs(arg) do arg[i] = tonumber(v) end
   table.sort(arg, function(a,b) return a>b end)
   for _,page_n in ipairs(arg) do
      doc:remove_page(page_n)
   end
else
   --pass page objects to remove_page
   pages = doc:get_pages()
   for i, page_n in ipairs(arg) do
      doc:remove_page(pages[tonumber(page_n)])
   end
end

doc:update()
