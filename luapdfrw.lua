#!/usr/bin/env texlua

--luacheck: read_globals pdfe (loaded by texlua)

--\section{Utilities}

do
   local function _inspect_table(x, levels, indent, received_done)
      -- done prevents infinite regress
      local done = {} for k,v in pairs(received_done) do done[k]=v end
      if levels ~= 0 and (not done or not done[x]) then
	 done[x] = true
	 for k,v in pairs(x) do
	    print(indent .. tostring(k), tostring(v))
	    if type(v) == 'table' then
	       _inspect_table(v, levels-1, indent .. '  ', done)
	    end
	 end
      end
   end
   --luacheck: globals inspect (intentionally exported)
   function inspect(x, levels, indent)
      indent = indent or ''
      levels = levels or -1
      print(indent .. tostring(x))
      if type(x) == 'table' then
	 _inspect_table(x, levels, indent .. '| ', {})
      elseif pdfe.type(x) == 'pdfe.dictionary' then
	 _inspect_table(pdfe.dictionarytotable(x), levels, indent .. '| ', {})
      elseif pdfe.type(x) == 'pdfe.array' then
	 _inspect_table(pdfe.arraytotable(x), levels, indent .. '| ', {})
      end
   end
end

local function index_error() error("Invalid index", 2) end
local function identity(obj) return obj end
local function copy_table(t)
   local c = {}
   for k,v in pairs(t) do c[k]=v end
   return c
end

--\section{Types}

--Table |pdfw| holds the public functions, except the functions of the document
--``class'' |mt_pdfw_doc|, which are held by |pdfw_doc|.
local pdfw = {}
local pdfw_doc = {}
local mt_pdfw_doc = { __index = pdfw_doc }

--Assigning nil to a table removes the entry, so we need an explicit null type
--to put a null value into a dict or array, don't we?

do --null
   local metatable_null = {
      pdfw_type = 'null',
      __index = index_error, __newindex = index_error,
      __tostring = function() return 'null' end,
      __call = identity,
   }
   function pdfw.null() return setmetatable({}, metatable_null) end
end

--Simple PDF types are mapped directly to primitive Lua types: booleans to
--booleans, integers \& floats to numbers, and names and non-hex strings to
--strings.

do --hex string
   local metatable_string = {
      pdfw_type = 'hex_string',
      __index = index_error, __newindex = index_error,
      __call = identity,
   }
   function pdfw.hex_string(value)
      return setmetatable({value = value}, metatable_string)
   end
end

--Set by arrays and dictionaries, used in |linearize| and |update|.
local updated_objects =     setmetatable({}, { __mode = 'k' } )

do --array & dictionary

   local metatable_pdfe_triplet = {}
   local function is_pdfe_triplet(obj)
      return getmetatable(obj) == metatable_pdfe_triplet
   end

   --The situations for array and dictionary are very similar, so we define
   --parametrized metamethods.

   local mt_index = function(tbl, key, pdfe_doc, legal_index_f)
      assert(legal_index_f(key))
      local value = tbl[key]
      if is_pdfe_triplet(value) then
	 value = pdfw.from_pdfe_triplet(pdfe_doc, table.unpack(value))
	 tbl[key] = value
      end
      return value
   end

   local mt_newindex = function(obj, tbl, key, value, pdfe_doc, legal_index_f)
      assert(legal_index_f(key))
      tbl[key] = value
      updated_objects[pdfe_doc] = updated_objects[pdfe_doc] or {}
      updated_objects[pdfe_doc][obj] = true
   end

   local mt_pairs = function(tbl, pdfe_doc, pairs_f)
      for key, value in pairs_f(tbl) do
	 if is_pdfe_triplet(value) then
	    tbl[key] = pdfw.from_pdfe_triplet(pdfe_doc, table.unpack(value))
	 end
      end
      return pairs_f(tbl)
   end

   local function is_legal_array_key(key)
      return math.type(key) == "integer" and key > 0
   end
   local function is_legal_dictionary_key(key)
      return type(key) == "string"
   end

   function pdfw.from_pdfe_array(pdfe_doc, pdfe_obj)
      assert(pdfe.type(pdfe_doc) == 'pdfe' and pdfe.type(pdfe_obj) == 'pdfe.array')
      --A complication for |pdfw.copy|: a copy needs the local pdfe_doc, but
      --has to rely on a copy of |tbl|.  So it will get a new metatable with a
      --copy of the original |tbl| in variable |tbl|.
      --
      --|pdfe_doc| is bound by the argument of |from_pdfe_array|.
      local function mtf(tbl)
	 return {
	    pdfw_type = "array",
	    __index = function(_t,k)
	       return mt_index(tbl,k,pdfe_doc,is_legal_array_key) end,
	    __newindex = function(t,k,v)
	       return mt_newindex(t,tbl,k,v,pdfe_doc,is_legal_array_key) end,
	    __pairs = function()
	       return mt_pairs(tbl,pdfe_doc,ipairs) end,
	    __len = function() return #tbl end,
	    __call = function(obj, copy)
	       if copy then return setmetatable({}, mtf(copy_table(tbl)))
	       else return obj end
	    end,
	 }
      end
      local tbl = pdfe.arraytotable(pdfe_obj)
      for _, pdfe_triplet in ipairs(tbl) do
	 setmetatable(pdfe_triplet, metatable_pdfe_triplet)
      end
      return setmetatable({}, mtf(tbl))
   end

   function pdfw.from_pdfe_dictionary(pdfe_doc, pdfe_obj)
      assert(pdfe.type(pdfe_doc) == 'pdfe' and pdfe.type(pdfe_obj) == 'pdfe.dictionary')
      --The same complication for |pdfw.copy| as for arrays.
      local function mtf(tbl)
	 return {
	    pdfw_type = "dictionary",
	   __index = function(_t,k) return
		 mt_index(tbl,k,pdfe_doc,is_legal_dictionary_key) end,
	   __newindex = function(t,k,v) return
		 mt_newindex(t,tbl,k,v,pdfe_doc,is_legal_dictionary_key) end,
	   __pairs = function()
	      return mt_pairs(tbl,pdfe_doc,pairs) end,
	    __call = function(obj, copy)
	       if copy then return setmetatable({}, mtf(copy_table(tbl)))
	       else return obj end
	    end,
	 }
      end
      local tbl = pdfe.dictionarytotable(pdfe_obj)
      for _, pdfe_triplet in pairs(tbl) do
	 setmetatable(pdfe_triplet, metatable_pdfe_triplet)
      end
      return setmetatable({}, mtf(tbl))
   end

end --array & dictionary

do --stream

   local metatable_stream = {
      pdfw_type = 'stream',
      __index = index_error, __newindex = index_error,
   }

   function pdfw.from_pdfe_stream(pdfe_doc, stream, dictionary)
      return setmetatable(
	 { pdfe_doc = pdfe_doc, stream = stream, dictionary = dictionary },
	 metatable_stream
      )
   end

   --parameter |stream| must be a function (without arguments) which returns
   --the stream contents
   function pdfw.stream(stream, dictionary)
      return setmetatable(
	 { stream = stream, dictionary = dictionary },
	 metatable_stream
      )
   end

end

--Set and used when resolving references.
local referenced_objects =  setmetatable({}, { __mode = 'k' } )

--Set when resolving references, used in |linearize| and |update|.
local original_object_ids = setmetatable({}, { __mode = 'k' } )
local function get_original_object_id(obj)
   local t = original_object_ids[obj]
   if t then
      return table.unpack(t)
   else
      return nil, nil
   end
end

do --reference

   local function ref_index_error()
      error("Cannot index a reference! \z
             Did you forget to call the reference to resolve it?", 2)
   end

   do

      local function mt_call(_obj, pdfe_doc, pdfe_reference, referenced_pdfe_obj_id)
	 referenced_objects[pdfe_doc] = referenced_objects[pdfe_doc] or {}
	 local referenced_objects_for_doc = referenced_objects[pdfe_doc]
	 local referenced_object = referenced_objects_for_doc[referenced_pdfe_obj_id]
	 if not referenced_object then
	    referenced_object = pdfw.from_pdfe_triplet(
	       pdfe_doc, pdfe.getfromreference(pdfe_reference))
	    referenced_objects_for_doc[referenced_pdfe_obj_id] = referenced_object
	    original_object_ids[referenced_object] = { pdfe_doc, referenced_pdfe_obj_id }
	 end
	 return referenced_object
      end

      function pdfw.from_pdfe_reference(pdfe_doc, pdfe_reference, referenced_pdfe_obj_id)
	 return setmetatable({}, {
	       pdfw_type = "reference",
	       __index = ref_index_error, __newindex = ref_index_error,
	       __call = function(obj) return mt_call(
		     obj, pdfe_doc, pdfe_reference, referenced_pdfe_obj_id) end,
	 })
      end

   end

   function pdfw.reference(referenced_pdfw_obj)
      if not pdfw.type(referenced_pdfw_obj) then
	 referenced_pdfw_obj = pdfw.indirect(referenced_pdfw_obj)
      end
      return setmetatable({}, {
	    pdfw_type = "reference",
	    __index = ref_index_error, __newindex = ref_index_error,
	    __call = function() return referenced_pdfw_obj end,
      })
   end

end --reference

--This type does not exist in pdfe. We define it to support indirect strings,
--numbers and booleans.

do --indirect
   local metatable_indirect = {
      pdfw_type = 'indirect',
      __index = index_error, __newindex = index_error,
      __call = identity,
   }
   function pdfw.indirect(value)
      assert(not pdfw.type(value))
      return setmetatable({value = value}, metatable_indirect)
   end
end

--Function |pdfw.from_pdfe_triplet| is the bridge between pdfe (the reader
--library) and this module.  It wraps |type, value, detail| triplets returned
--by |pdfe.gefrom[dictionary/array/reference]| to |pdfw| objects defined
--above. (Ok, it does not wrap the simple types like integers and strings.
--Those become Lua numbers and strings, etc.)

do --pdfw.from_pdfe_triplet
   local val = function(_pdfe_doc, value) return value end
   local distributor = {
      function() return pdfw.null() end, --null
      val, --boolean
      val, --integer
      val, --float
      function(_pdfe_doc, value) return '/' .. value:gsub('/', '#2F') end,
      function(_pdfe_doc, value, hex)
	 if hex then return pdfw.hex_string(value)
	 elseif value:sub(1,1) == '/' then return '\\057' .. value:sub(2)
	 else return value end
      end,
      pdfw.from_pdfe_array, ['pdfe.array'] = pdfw.from_pdfe_array,
      pdfw.from_pdfe_dictionary, ['pdfe.dictionary'] = pdfw.from_pdfe_dictionary,
      pdfw.from_pdfe_stream, ['pdfe.stream'] = pdfw.from_pdfe_stream,
      pdfw.from_pdfe_reference, ['pdfe.reference'] = pdfw.from_pdfe_reference,
   }
   function pdfw.from_pdfe_triplet(pdfe_doc, type, value, detail)
      if pdfe.type(pdfe_doc) ~= 'pdfe' then
	 error("The first argument should be a pdf document object", 2)
      end
      local f = distributor[type]
      if not f then
	 error("object type not found in distributor", 2)
      end
      return f(pdfe_doc, value, detail)
   end
end

--Returns the pdfw type of the object, as a string, or |nil|, if the given
--argument is not a pdfw object.
function pdfw.type(obj)
   local mt = getmetatable(obj)
   return (mt and mt.pdfw_type) or type(obj)
end

---Function |pdfw.copy| makes a \emph{shallow} copy of the given object.  For
---example, if we're copying a dictionary (say, Pages) containing an array
---(Kids), the copy will contain the same array.
do --copy
   local distributor = {
      hex_string = function(obj) return pdfw.hex_string(obj.value) end,
      --Arrays and dictionaries are copied by passing |true| to their |__call|.
      array = function(obj) return obj(true) end,
      dictionary = function(obj) return obj(true) end,
      stream = function(obj)
	 local s = obj.stream()
	 return pdfw.stream(function() return s end, pdfw.copy(obj.dictionary))
      end,
      table = copy_table,
      --reference is immutable
   }
   function pdfw.copy(obj)
      local f = distributor[pdfw.type(obj)] or distributor[type(obj)] or identity
      return f(obj)
   end
end

--\section{Linearization}

--Function |pdfw.linearize| recurses into the object tree, starting with the
--given object, writing all indirect objects it finds (for the first time) into
--the output file (specified by file handle |doc.fh|). Argument |indirect| may
--be specified to determine whether the given object should be written as well
--(if not, its linearization is returned).
--
--Several fields in the document table |doc| must be initialized before calling
--|linearize|: |.object_ids| (will hold the object ids assigned during
--linearization), |.max_id| (the current maximum object id), |.xref| (a table
--mapping indirect object ids to the object position in the output file), and
--|.fh| (the file handle of an opened, writeable file).
--
--Perpahs this function should not be public \dots

do --linearize

   local linearize, distributor

   linearize = function(doc, obj, indirect)
      if indirect then
	 if not doc.object_ids[obj] then
	    local original_pdfe_doc, original_id = get_original_object_id(obj)
	    if doc.updating then
	       if original_pdfe_doc == doc.pdfe_doc then
		  doc.object_ids[obj] = original_id
	       else
		  doc.max_id = doc.max_id + 1
		  doc.object_ids[obj] = doc.max_id
	       end
	    else
	       doc.max_id = doc.max_id + 1
	       doc.object_ids[obj] = doc.max_id
	    end
	    --An object encountered during linearization gets written out: (a)
	    --always if we're saving rather than updating; (b) if it comes from
	    --another document, or (c) if it was modified.
	    if not doc.updating or original_pdfe_doc ~= doc.pdfe_doc
	       or updated_objects[doc.pdfe_doc][obj] then
	       local pdf_repr = distributor[pdfw.type(obj)](obj, doc)
	       local id = doc.object_ids[obj]
	       doc.xref[id] = doc.fh:seek()
	       doc.fh:write(id .. ' 0 obj\n', pdf_repr, '\nendobj\n')
	       return pdf_repr
	    end
	 end
      else
	 return distributor[pdfw.type(obj)](obj, doc)
      end
   end

   pdfw.linearize = linearize
   --todo: either implement a sensible API, or make it a private function

   distributor = {
      --Note the reversed order of doc and obj in the functions below. This is so
      --that the first couple of functions below can easily receive merely obj.
      ["nil"] = function() return 'null' end, --primitive nil --> pdf null
      null = tostring, --pdfw.null
      --The following four are both for primitive and pdfw objects.
      boolean = tostring,
      number = tostring,
      --Note that '/foo' will end up as a name.  This is intentional, so that
      --names can be given simply as strings.  If you need a string that starts
      --with a slash, start it with either octal \057 or use pdfw.string.  And
      --if you need a name that contains a slash (as a non-first character),
      --replace the slash with '#2F'.
      string = function(s)
	 if s:sub(1,1) == '/' then return s
	 else return table.concat{ '(', s, ')' } end
      end,
      hex_string = function(obj) return table.concat{ '<', obj.value, '>' } end,
      array = function(obj, doc)
	 local child_reprs = { [0] = '[' }
	 for i, child_obj in ipairs(obj) do
	    child_reprs[i] = pdfw.linearize(doc, child_obj)
	 end
	 table.insert(child_reprs, ']')
	 return table.concat(child_reprs, ' ', 0)
      end,
      dictionary = function(obj, doc)
	 local child_reprs = { [0] = '<<' }
	 local i = 1
	 for key, child_obj in pairs(obj) do
	    child_reprs[i] = '/' .. key .. ' ' .. pdfw.linearize(doc, child_obj)
	    i = i + 1
	 end
	 child_reprs[i] = '>>'
	 return table.concat(child_reprs, ' ', 0)
      end,
      --A table is cast into either an array or a dictionary.  Basically, it is
      --an array if numeric index 1 is present.  However, an empty table could
      --be either an array or a dictionary.  We get around this by the
      --convention that setting numeric index 0 implies that it is an array.
      table = function(obj, doc)
	 local r
	 if obj[1] or obj[0] then
	    r = distributor["array"](obj, doc)
	 else
	    r = distributor["dictionary"](obj, doc)
	 end
	 return r
      end,
      stream = function(obj, doc)
	 local chunks = {
	    distributor["dictionary"](
	       pdfw.from_pdfe_dictionary(obj.pdfe_doc, obj.dictionary), doc),
	    'stream',
	    obj.stream(),
	    'endstream'
	 }
	 return table.concat(chunks, "\n")
      end,
      reference = function(obj, doc)
	 local referenced_pdfw_object = obj()
	 pdfw.linearize(doc, referenced_pdfw_object, true)
	 return doc.object_ids[referenced_pdfw_object] .. ' 0 R'
      end,
      indirect = function(obj, doc)
	 return pdfw.linearize(doc, obj.value)
      end,
   }

end --linearize

--\section{Creating, opening, saving and updating PDF files}

--Create a document given a trailer dictionary. If no trailer is given, create
--an empty document with a rudimentary trailer, Catalog and root Pages object.

function pdfw.new(trailer)
   trailer = trailer or
      {
	 Root = pdfw.reference{
	    Type = '/Catalog',
	    Pages = pdfw.reference{
	       Type = '/Pages',
	       Count = 0,
	       Kids = {},
	    },
	 },
	 Info = {
	    Producer = 'pdfw',
	 },
      }
   local doc = {
      trailer = trailer,
      major = 1,
      minor = 4,
      max_kids = 10,
   }
   return setmetatable(doc, mt_pdfw_doc)
end

--Open (via pdfe) an existing PDF document.

function pdfw.open(filename)
   local pdfe_doc = pdfe.open(filename)
   local trailer = pdfw.from_pdfe_dictionary(pdfe_doc, pdfe.gettrailer(pdfe_doc))
   local major, minor = pdfe.getversion(pdfe_doc)
   local doc = {
      filename = filename,
      pdfe_doc = pdfe_doc,
      trailer = trailer,
      major = major,
      minor = minor,
      max_kids = 10, --todo: autodetect
   }
   return setmetatable(doc, mt_pdfw_doc)
end

--Close the document. Calling this function only makes sense for |open|ed (not
--|new|) documents, and even then it is usually probably unnecessary.

function pdfw_doc.close(doc)
   if doc.pdfe_doc then doc.pdfe_doc.close() end
end

--Save the document from scratch.

function pdfw_doc.save(doc, filename)

   doc.object_ids = {}
   doc.max_id = 0
   doc.xref = {}
   doc.fh = io.open(filename, 'wb')

   doc.fh:write(string.format("%%PDF-%d.%d\n", doc.major, doc.minor))

   local magic_bin = 'LuaPDFrw'
   magic_bin = {magic_bin:byte(1,-1)}
   doc.fh:write("%")
   for _,v in ipairs(magic_bin) do
      doc.fh:write(string.char(v+128))
   end
   doc.fh:write("\n")

   --Note that this does not write out the trailer itself, because argument
   --|indirect| is not given.  Writing out the |Catalog| here would not work,
   --because |Info| is only referred to by the trailer, so it would get written
   --out (alongside the trailer) behind |xref|.
   pdfw.linearize(doc, doc.trailer)

   local startxref = doc.fh:seek()
   doc.fh:write(
      'xref\n',
      '0 ', #doc.xref + 1, "\n",
      '0000000000 65535 f \n'
   )
   for _,pos in ipairs(doc.xref) do -- _id,pos
      doc.fh:write(string.format("%010d", pos), ' 00000 n \n')
   end

   doc.trailer.Size = #doc.xref + 1
   doc.fh:write("trailer\n", pdfw.linearize(doc, doc.trailer), "\n")

   doc.fh:write("startxref\n", startxref, "\n")
   doc.fh:write("%%EOF\n")
   doc.fh:close()

   doc.object_ids, doc.max_id, doc.xref, doc.fh, doc.trailer.Size = nil, nil, nil, nil, nil
end

--Perform an incremental update of the PDF file.

function pdfw_doc.update(doc, prune)

   assert(doc.filename)

   --todo: prune, i.e. mark all unused objects as deleted

   --Get the location of the previous xref table.
   local fh = io.open(doc.filename, 'rb')
   fh:seek("end", -40)
   local prev = fh:read("a")
   fh:close()
   local _
   _,_,prev = prev:find('startxref%s+(%d+)%s+%%%%EOF')

   doc.updating = true --a parameter for linearize
   doc.object_ids = {}
   doc.max_id = doc.trailer.Size
   doc.xref = {}
   doc.fh = io.open(doc.filename, 'a+b')
   doc.fh:seek("end")

   pdfw.linearize(doc, doc.trailer)
   for obj,_ in pairs(updated_objects[doc.pdfe_doc]) do
      if get_original_object_id(obj) then
	 pdfw.linearize(doc, obj, true)
      end
   end

   local startxref = doc.fh:seek()
   doc.fh:write('xref\n',
		'0 1\n0000000000 65535 f \n')

   local function write_xref_section(start_id)
      while not doc.xref[start_id] and start_id <= doc.max_id do
	 start_id = start_id + 1
      end
      if start_id > doc.max_id then return start_id end

      local next_id = start_id + 1
      while doc.xref[next_id] do next_id = next_id + 1 end

      doc.fh:write(start_id, ' ', next_id - start_id, "\n")
      for id = start_id, next_id - 1  do
	 doc.fh:write(string.format("%010d", doc.xref[id]), ' 00000 n \n')
      end

      return next_id
   end

   local id = 1
   while id <= doc.max_id do id = write_xref_section(id) end
   assert(id == doc.max_id + 1)

   doc.trailer.Size = id
   doc.trailer.Prev = tonumber(prev)
   doc.fh:write("trailer\n", pdfw.linearize(doc, doc.trailer, false, true), "\n")

   doc.fh:write("startxref\n", startxref, "\n")

   doc.fh:write("%%EOF\n")
   doc.fh:close()
   doc.updating = nil
end

--\section{Pages}

--This module knows almost nothing about the high-level content of a PDF file,
--the exception being the page structure functions defined in this section.

--Enumerate pages, i.e. produce an array of Page objects from the Page tree.
do
   local function get_pages_from_Pages(p, result)
      if p.Type == '/Page' then
	 table.insert(result, p)
      else
	 for _,kid in ipairs(p.Kids) do
	    get_pages_from_Pages(kid(), result)
	 end
      end
   end
   function pdfw_doc.get_pages(doc)
      local result = {}
      local root_Pages = doc.trailer.Root().Pages()
      get_pages_from_Pages(root_Pages, result)
      return result
   end
end

--Get a specific page by number.
do
   local function get_page(Pages, page_n)
      for i, kid_ref in ipairs(Pages.Kids) do
	 local kid_obj = kid_ref()
	 local kid_is_page = kid_obj.Type == '/Page'
	 page_n = page_n - (kid_is_page and 1 or kid_obj.Count)
	 if page_n <= 0 then
	    if kid_is_page then
	       return kid_obj, Pages, {i}
	    else
	       local kid, parent, path = get_page(kid_obj, page_n + kid_obj.Count)
	       table.insert(path, 1, i)
	       return kid, parent, path
	    end
	 end
      end
   end

   function pdfw_doc.get_page(doc, page_n)
      local root_Pages = doc.trailer.Root().Pages()
      assert(math.type(page_n) == 'integer'
	     and page_n > 0 and page_n <= root_Pages.Count,
	     ("Page number %d does not exist, the document has %d page(s)")
	     :format(page_n, root_Pages.Count)
      )
      return get_page(root_Pages, page_n)
   end
end

--Function |insert_page| inserts the given |page| object into the Page tree so
--that it becomes page number |page_n|.  The argument signature of this
--function is as for |table.insert|, and it also shifts the following pages in
--the same manner.  The maximum number of member of the Kids array in a Pages
--object is determined by |doc.max_kids|.
--
--A note on inherited Page attributes. This function is safe to use if the
--target document relies on inheritance, but it does not check whether the
--inserted page inherited some attributes in the source document, so the
--inserted page might wrongly inherit some attributes from the target
--document. The workaround is to explicitly assign all the attributes to the
--inserted page.
--
--This module was written to support extern extraction in TeX package Memoize.
--This is the only function which is not strictly used by that package, which
--only creates single-page PDFs. But having a |remove_page| supporting nested
--Pages, it seemed a shame not to support them in |insert_page| as well.

do
   local function prune_ancestors(Pages, Catalog, path, max_kids)
      local Kids = Pages.Kids
      local n_kids = #Kids
      if n_kids <= max_kids then return end

      local right_Pages = pdfw.copy(Pages)
      right_Pages.Kids = {}

      local half = n_kids // 2
      right_Pages.Count = n_kids - half
      Pages.Count = half

      local left_Kids = Pages.Kids
      local right_Kids = right_Pages.Kids
      for i = half+1, n_kids do
	 table.insert(right_Kids, left_Kids[i])
	 left_Kids[i] = nil
      end

      local next_f = function() end
      if Pages.Parent then
	 local parent = Pages.Parent()
	 local i = table.remove(path)
	 table.insert(parent.Kids, i+1, pdfw.reference(right_Pages))
	 next_f = function() prune_ancestors(parent, Catalog, path, max_kids) end
      else
	 local new_root_Pages = {
	    Type = '/Pages',
	    Count = Pages.Count + right_Pages.Count,
	    Kids = { pdfw.reference(Pages), pdfw.reference(right_Pages) }
	 }
	 Catalog.Pages = pdfw.reference(new_root_Pages)
      end
      return next_f()
   end

   function pdfw_doc.insert_page(doc, page_n, page)
      local Catalog = doc.trailer.Root()
      local root_Pages = Catalog.Pages()
      if type(page_n) ~= 'number' and pdfw.type(page_n) then
	 page = page_n
	 page_n = root_Pages.Count + 1
      end
      assert(math.type(page_n) == 'integer'
	     and page_n > 0 and page_n <= root_Pages.Count + 1,
	     ("The insertion position (given: %d) must be between \z
               1 and %d (the number of pages + 1)")
	     :format(page_n, root_Pages.Count + 1))
      if root_Pages.Count == 0 then
	 --This is the only part of the function used by Memoize.
	 table.insert(root_Pages.Kids, pdfw.reference(page))
	 page.Parent = pdfw.reference(root_Pages)
	 root_Pages.Count = 1
      else
	 --Insert to the right (offset=1) or to the left (offset=0)?
	 local offset = (page_n == root_Pages.Count + 1) and 1 or 0
	 local _, parent, path = doc:get_page(page_n - offset) -- _kid,parent,path
	 local i = table.remove(path)
	 table.insert(parent.Kids, i + offset, pdfw.reference(page))
	 local p = parent
	 while p do
	    if pdfw.type(p) == 'reference' then p = p() end
	    p.Count = p.Count + 1
	    p = p.Parent
	 end
	 prune_ancestors(parent, Catalog, path, doc.max_kids)
      end
   end
end

--Remove the given page object from the Page tree.

do
   local function remove_from_pages(obj, root)
      if obj == root then return end
      local function next_remove() end
      local parent = obj.Parent()
      local kids = parent.Kids
      for i, kid in ipairs(kids) do
	 if kid() == obj then
	    table.remove(kids, i)
	    parent.Count = parent.Count - 1
	    if parent.Count == 0 then
	       next_remove = function()
		  remove_from_pages(parent, root)
	       end
	    else
	       while parent.Parent do
		  parent = parent.Parent()
		  parent.Count = parent.Count - 1
	       end
	    end
	    break
	 end
      end
      next_remove()
   end

   function pdfw_doc.remove_page(doc, page)
      assert(page.Type == '/Page')

      --Check that the |page| object indeed belongs to the document.
      local root_Pages = page.Parent()
      while root_Pages.Parent do root_Pages = root_Pages.Parent() end
      assert(root_Pages == doc.trailer.Root().Pages())

      --Remove the page from its parent Pages object.  If the modified Pages
      --are empty, remove them from their parent Pages, and so on until the
      --root Pages object.
      remove_from_pages(page, root_Pages)
   end
end

return pdfw
