#!/usr/bin/env texlua

function inspect(x, levels, indent)
   indent = indent or ''
   levels = levels or -1
   local pdfw_object_status = ''
   if pdfw.is_pdfw_object(x) then pdfw_object_status = ' (pdfw object)' end
   print(indent .. tostring(x) .. pdfw_object_status)
   if type(x) == 'table' then
      _inspect_table(x, levels, indent .. '| ', {})
   elseif pdfe.type(x) == 'pdfe.dictionary' then
      _inspect_table(pdfe.dictionarytotable(x), levels, indent .. '| ', {})
   elseif pdfe.type(x) == 'pdfe.array' then
      _inspect_table(pdfe.arraytotable(x), levels, indent .. '| ', {})
   --elseif pdfe.type(x) == 'pdfe.stream' then
   --   _inspect_table(pdfe.arraytotable(x), levels, indent .. '| ')
   end
end

function _inspect_table(x, levels, indent, received_done)
   -- done prevents infinite regress
   local done = {} for k,v in pairs(received_done) do done[k]=v end
   if levels ~= 0 and (not done or not done[x]) then
      done[x] = true
      for k,v in pairs(x) do
	 local pdfw_object_status = ''
	 if pdfw.is_pdfw_object(v) then pdfw_object_status = ' (pdfw object)' end
	 print(indent .. tostring(k), tostring(v) .. pdfw_object_status)
	 if type(v) == 'table' then
	    _inspect_table(v, levels-1, indent .. '  ', done)
	 end
      end
   end
end

pdfw = {}

--pdfw objects are tables in the same format as returned by
--pdfe.dictionarytotable and pdfe.arraytotable.
function pdfw.object(obj_type, value, detail)
   assert(math.type(obj_type) == 'integer' and obj_type >= 0 and obj_type <= 10)
   obj = { obj_type, value, detail }
   setmetatable(obj, pdfw._object_metatable)
   return obj
end
function pdfw.null()                      return pdfw.object(1)                      end
function pdfw.boolean(value)              return pdfw.object(2, value)               end
function pdfw.integer(value)              return pdfw.object(3, value)               end
function pdfw.float(value)                return pdfw.object(4, value)               end
function pdfw.name(value)                 return pdfw.object(5, value)               end
function pdfw.string(value, hex)          return pdfw.object(6, value, hex)          end
function pdfw.array(a)       a = a or {}  return pdfw.object(7, a)                   end
function pdfw.dictionary(d)  d = d or {}  return pdfw.object(8, d)                   end
function pdfw.stream(stream, stream_dict) return pdfw.object(9, stream, stream_dict) end
function pdfw.reference(referenced_obj)   return pdfw.object(10, referenced_obj)     end
--pdfw.array/dictionary: a/d argument is a table or a pdfe object; we don't
--set size of array/dict as the detail, because then we would have to update
--it when adding or removing to the array/dictionary.

function pdfw.is_pdfw_object(obj)
   return getmetatable(obj) == pdfw._object_metatable
end

pdfw._object_metatable = {
   __index = function(table, key)
      local f = getmetatable(table)['__indices'][key]
      if not f then
	 local indices_for_type = getmetatable(table)['__indices'][table.type]
	 if indices_for_type then f = indices_for_type[key] end
      end
      if f then return f(table) else return rawget(table, key) end
   end,
   __indices = {
      type   = function(table) return rawget(table,1) end,
      value  = function(table) return rawget(table,2) end,
      detail = function(table) return rawget(table,3) end,
      [6] = { --string
	 hex = function(table) return rawget(table,3) end,
      },
      [7] = { --array
	 items = function(table)
	    array = table.value
	    if type(array) == 'table' then
	       return array
	    elseif pdfe.type(array)  == 'pdfe.array' then
	       local t = pdfe.arraytotable(array)
	       for i,v in ipairs(t) do
		  setmetatable(v, pdfw._object_metatable)
	       end
	       return t
	    else
	       error("Illicit pdfw.array object value", 2)
	    end
	 end,
      },
      [8] = { --dictionary
	 items = function(table)
	    dict = table.value
	    if type(dict) == 'table' then
	       return dict
	    elseif pdfe.type(dict)  == 'pdfe.dictionary' then
	       t = pdfe.dictionarytotable(dict)
	       for k,v in pairs(t) do
		  setmetatable(v, pdfw._object_metatable)
	       end
	       return t
	    else
	       error("Illicit pdfw.dictionary object value", 2)
	    end
	 end,
      },
      [9] = { --stream (todo: editable streams)
	 stream = function(table)
	    s = rawget(table,2)
	    assert(pdfe.type(s) == 'pdfe.stream')
	    return s
	 end,
	 dictionary = function(table)
	    d = rawget(table,3)
	    if pdfe.type(d) == 'pdfe.dictionary' then
	       return pdfw.dictionary(d)
	    elseif pdfw.is_pdfw_object(d) and d.type == 8 then
	       return d
	    else
	       error("Illicit stream dictionary", 2)
	    end
	 end
      },
      [10] = { --reference
	 resolve = function(table)
	    return function(pdf)
	       local reference_value = table.value
	       if pdfw.is_pdfw_object(reference_value) then
		  return reference_value
	       elseif pdfe.type(reference_value) == 'pdfe.reference' then
		  local pointer = tostring(reference_value)
		  local referenced_object = pdf.reference_resolutions[pointer]
		  if not referenced_object then
		     referenced_object = pdfw.object(pdfe.getfromreference(reference_value))
		     pdf.reference_resolutions[pointer] = referenced_object
		  end
		  return referenced_object
	       else
		  error("Illicit pointer in pdfw.reference", 2)
	       end
	    end
	 end,
      },
   },
   __newindex = function(table, key, value)
      local f = getmetatable(table)['__newindices'][key]
      if not f then
	 local newindices_for_type = getmetatable(table)['__newindices'][table.type]
	 if newindices_for_type then f = newindices_for_type[key] end
      end
      if f then return f(table, value) else return rawset(table, key, value) end
   end,
   __newindices = {
      type   = function(table,value) return rawset(table,1,value) end,
      value  = function(table,value) return rawset(table,2,value) end,
      detail = function(table,value) return rawset(table,3,value) end,
   },
}

function pdfw.new()
   local Pages = pdfw.dictionary({
	 Type = pdfw.name('Pages'),
	 Count = pdfw.integer(0),
	 Kids = pdfw.array(),
   })
   local Catalog = pdfw.dictionary({
	 Type = pdfw.name('Catalog'),
	 Pages = pdfw.reference(Pages),
   })
   local Info = pdfw.dictionary({
	 Producer = pdfw.string('pdfw'),
   })
   local pdf = {
      objects = {}, --holds *indirect* objects
      max_id = 0,
      reference_resolutions = {},
      Catalog = Catalog,
      Pages = Pages,
      Info = Info,
      major = 1,
      minor = 4,
   }
   pdfw._add_indirect_object(pdf, Catalog)
   pdfw._add_indirect_object(pdf, Pages)
   pdfw._add_indirect_object(pdf, Info)
   return pdf
end

function pdfw._add_indirect_object(pdf, obj)
   assert(pdfw.is_pdfw_object(obj))
   pointer = tostring(obj)
   if not pdf.objects[pointer] then
      pdf.max_id = pdf.max_id + 1
      obj.id = pdf.max_id
      pdf.objects[pointer] = obj
   end
end

function pdfw._distribute(obj, distributor)
   local f = distributor[obj.type]
   assert (f, "assertion failed " .. tostring(obj))
   return f
end

function pdfw._noop(...) end

function pdfw.collect_indirect_objects(pdf, obj, add_this_object)
   assert(pdfw.is_pdfw_object(obj))
   if not pdf.objects[tostring(obj)] then
      if add_this_object then
	 pdfw._add_indirect_object(pdf, obj)
      end
      pdfw._distribute(obj, pdfw._collect_indirect_objects_distributor)(pdf, obj)
   end
end

-- trace collection indent: nil = don't trace, '' = trace
tc_indent = nil

pdfw._collect_indirect_objects_distributor = {
   pdfw._noop,
   pdfw._noop,
   pdfw._noop,
   pdfw._noop,
   pdfw._noop,
   pdfw._noop,
   function(pdf, obj) --array
      for i,o in ipairs(obj.items) do
	 if tc_indent then
	    print(tc_indent, i, o)
	    tc_indent = tc_indent .. '\t'
	 end
	 pdfw.collect_indirect_objects(pdf, o)
	 if tc_indent then tc_indent = string.sub(tc_indent, 1, -2) end
      end
   end,
   function(pdf, obj) --dict
      for k,o in pairs(obj.items) do
	 if tc_indent then
	    print(tc_indent, k, o)
	    tc_indent = tc_indent .. '\t'
	 end
	 pdfw.collect_indirect_objects(pdf, o)
	 if tc_indent then tc_indent = string.sub(tc_indent, 1, -2) end
      end
   end,
   function(pdf, obj) --stream
      for k,o in pairs(obj.dictionary.items) do
	 pdfw.collect_indirect_objects(pdf, o)
      end
   end,
   function(pdf, obj) --ref
      referenced_pdfw_object = obj.resolve(pdf)
      if tc_indent then
	 print(tc_indent, obj, referenced_pdfw_object)
	 tc_indent = tc_indent .. '\t'
      end
      pdfw.collect_indirect_objects(pdf, referenced_pdfw_object, true)
      if tc_indent then tc_indent = string.sub(tc_indent, 1, -2) end
   end,
}

function pdfw.to_pdf_representation(pdf, obj)
   assert(pdfw.is_pdfw_object(obj))
   return pdfw._distribute(obj, pdfw._to_pdf_representation_distributor)(obj, pdf)
end

pdfw._to_pdf_representation_distributor = {
   --Note the reversed order of pdf and obj in the functions below.
   function() return 'null' end,                        --null
   function(obj) return tostring(obj.value) end,        --boolean
   function(obj) return tostring(obj.value) end,        --integer
   function(obj) return tostring(obj.value) end,        --float
   function(obj) return '/' .. tostring(obj.value) end, --name
   function(obj)                                        --string
      if obj.hex then
	 hex_chars = { [0] = '<' }
	 value = obj.value
	 for i = 1, string.len(value) do
	    hex_chars[i] = string.format("%X", string.byte(value, i))
	 end
	 table.insert(hex_chars, '>')
	 return table.concat(hex_chars, '', 0)
      else
	 return table.concat( { '(', obj.value, ')' } )
      end
   end,
   function(obj, pdf)                                   --array
      local child_reprs = { [0] = '[' }
      for i, child_obj in ipairs(obj.items) do
	 child_reprs[i] = pdfw.to_pdf_representation(pdf, child_obj)
      end
      table.insert(child_reprs, ']')
      return table.concat(child_reprs, ' ', 0)
   end,
   function(obj, pdf)                                   --dictionary
      local child_reprs = { [0] = '<<' }
      local i = 1
      for key, child_obj in pairs(obj.items) do
	 child_reprs[i] = '/' .. key .. ' ' .. pdfw.to_pdf_representation(pdf, child_obj)
	 i = i + 1
      end
      child_reprs[i] = '>>'
      return table.concat(child_reprs, ' ', 0)
   end,
   function(obj, pdf)                                   --stream
      local chunks = {
	 pdfw.to_pdf_representation(pdf, obj.dictionary),
	 'stream',
	 obj.stream(),
	 'endstream'
      }
      return table.concat(chunks, "\n")
   end,
   function(obj, pdf)                                   --reference
      return obj.resolve(pdf).id .. ' 0 R'
   end
}

function pdfw.append_page(pdf, source_pdfe_doc, page_n)
   local pdfe_source_page = pdfw.dictionary(pdfe.getpage(source_pdfe_doc, page_n))
   local new_page = pdfw.dictionary(pdfe_source_page.items)
   table.insert(pdf.Pages.value.Kids.value, pdfw.reference(new_page))
   pdf.Pages.value.Count.value = pdf.Pages.value.Count.value + 1
   new_page.value.Parent = pdfw.reference(pdf.Pages)
   pdfw.collect_indirect_objects(pdf, new_page, true)
   major, minor = pdfe.getversion(source_pdfe_doc)
   assert(major == 1)
   pdf.minor = math.max(pdf.minor, minor)
end

function pdfw.save(pdf, filename)
   fh = io.open(filename, 'wb')
   fh:write(string.format("%%PDF-%d.%d\n", pdf.major, pdf.minor))
   xref = {}
   for k,obj in pairs(pdf.objects) do
      xref[obj.id] = fh:seek()
      fh:write(
	 obj.id .. ' 0 obj\n',
	 pdfw.to_pdf_representation(pdf, obj),
	 '\nendobj\n'
      )
   end
   startxref = fh:seek()
   fh:write(
      'xref\n',
      '0 ', #xref + 1, "\n",
      '0000000000 65535 f \n'
   )
   for id,pos in ipairs(xref) do
      fh:write(string.format("%010d", pos), ' 00000 n \n')
   end
   local trailer = pdfw.dictionary({
	 Root = pdfw.reference(pdf.Catalog),
	 Info = pdfw.reference(pdf.Info),
	 Size = pdfw.integer(#xref + 1),
   })
   fh:write("trailer\n", pdfw.to_pdf_representation(pdf, trailer), "\n")
   fh:write("startxref\n", startxref, "\n")
   fh:write("%%EOF\n")
   fh:close()
end
