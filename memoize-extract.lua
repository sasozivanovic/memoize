#!/usr/bin/env texlua

-- This file is a part of Memoize, a TeX package for externalization of
-- graphics and memoization of compilation results in general, available at
-- https://ctan.org/pkg/memoize and https://github.com/sasozivanovic/memoize.
--
-- Copyright (c) 2025  Lukas ?? (atticus-sullivan @ github.com)
--               2025- Saso Zivanovic <saso.zivanovic@guest.arnes.si>
--
-- This work may be distributed and/or modified under the conditions of the
-- LaTeX Project Public License, either version 1.3c of this license or (at
-- your option) any later version.  The latest version of this license is in
-- https://www.latex-project.org/lppl.txt and version 1.3c or later is part of
-- all distributions of LaTeX version 2008 or later.
--
-- This work has the LPPL maintenance status `maintained'.
-- The Current Maintainer of this work is . TODO(all)
--
-- The files belonging to this work and covered by LPPL are listed in
-- <texmf>/doc/generic/memoize/FILES.

local VERSION = '2025/01/17 v1.4.1' -- TODO(release)

-- The following libraries are already available due to the use of LuaTeX: kpse
-- (Kpathsea), lfs (LuaFileSystem).  Furthermore, the following libraries are
-- extended in LuaTeX: lfs, os.  Finally, we also require several further
-- LuaTeX modules:

require 'lualibs-basic-merged' --only for debugging
require 'lualibs-lpeg' --required by lualibs-file
require 'lualibs-file'
require 'lualibs-dir'

-- I don't know how to properly set up Lua Language Server (luals) to load the
-- meta files from GitHub repo TeXLuaCATS/LuaTeX.  A workaround:

---@class os
---@field type string
os = os

---@class file
---@field splitname function
---@field suffix function
---@field replacesuffix function
---@field addsuffix function
---@field dirname function
---@field join function
---@field basename function
---@field is_rootbased_path function
file = file

---@class dir
---@field makedirs function
dir = dir

---@class lfs
---@field isfile function
---@field attributes function
lfs = lfs

---@class io
---@field exists function
io = io

-- Load "our own" PDF writer, LuaPDFrw.

local pdf = require 'luapdfrw'

-- Setup kpse.

kpse.set_program_name("texlua", "memoize-extract.lua")

--\paragraph{Messages}

--The messages are written both to the extraction log and the terminal (we
--output to stdout rather than stderr so that messalges on the TeX terminal and
--document |.log| appear in chronological order).  Messages are automatically
--adapted to the TeX |--format|.

--The format of the messages.  It depends on the given |--format|; the last
--entry is for t the terminal output.

local exit, logging
do
    local os_exit = os.exit
    exit = {
        error = function() logging:close() os_exit(11) end,
        warn  = function() logging:close() os_exit(10) end,
        succ  = function() logging:close() os_exit(0) end,
    }
end

logging = {
    file      = nil,
    header    = "",
    indent    = "",
    texindent = "",
    quiet = false,
    format = "None",
    header = '',
    package_name = 'memoize (lua-based extraction)',
}
do
    local package_name = "memoize (texlua-based extraction)"
    local ERROR = {
        latex = function(self, short, long) return
		("\\PackageError{%s}{%s}{%s}")
		:format(self.package_name, short, long) end,
        plain = function(self, short, long) return
		("\\errhelp{%s}\\errmessage{%s: %s}")
		:format(long, self.package_name, short) end,
        context = function(self, short, long) return
		("\\errhelp{%s}\\errmessage{%s: %s}")
		:format(long, self.package_name, short) end,
        None = function(self, short, long) return
		("%s%s.\n%s")
		:format(self.header, short, long)       end,
    }
    local WARNING = {
        latex = function(self, text) return
		("\\PackageWarning{%s}{%s%s}")
		:format(self.package_name, self.texindent, text) end,
        plain = function(self, text) return
		("\\message{%s: %s%s}")
		:format(self.package_name, self.texindent, text) end,
        context = function(self, text) return
		("\\message{%s: %s%s}")
		:format(self.package_name, self.texindent, text) end,
        None = function(self, text) return
		("%s%s%s.")
		:format(self.header, self.indent, text)          end,
    }
    local INFO = {
        latex = function(self, text) return
		("\\PackageInfo{%s}{%s%s}")
		:format(self.package_name, self.texindent, text) end,
        plain = function(self, text) return
		("\\message{%s: %s%s}")
		:format(self.package_name, self.texindent, text) end,
        context = function(self, text) return
		("\\message{%s: %s%s}")
		:format(self.package_name, self.texindent, text) end,
        None = function(self, text) return
		("%s%s%s.")
		:format(self.header, self.indent, text)          end,
    }

    ---@param fh file*
    function logging:open(fn)
	self.fh = io.open(fn, "w")
    end

    ---Closes the file after marking the log as complete.
    function logging:close()
        if self.fh then
            self.fh:write("\\endinput\n")
            self.fh:close()
            self.fh = nil
        end
    end

    ---@param short string
    ---@param long string
    function logging:error(short, long)
        short = short or ''
        long = long or ''
        if not self.quiet then
            print(ERROR.None(self, short, long))
        end
        if self.fh then
            self.fh:write(
		ERROR[self.format](
		    self,
		    short:gsub("\\", "\\string\\"),
		    long:gsub("\\", "\\string\\"),
		    "\n"
	    ))
	end
	--Exit immediately.
        exit.error()
    end

    ---@param text string
    function logging:warn(text)
	text = text or ''
        if not self.quiet then
            print(WARNING.None(self, text))
        end
        if self.fh then
            self.fh:write(WARNING[self.format](self, text:gsub("\\", "\\string\\"), "\n"))
        end
        -- Set the exit code.
        exit.succ = exit.warn
    end

    ---@param text string
    function logging:info(text)
	text = text or ''
        if not self.quiet then
            print(INFO.None(self, text))
        end
        if self.fh then
            self.fh:write(INFO[self.format](self, text:gsub("\\", "\\string\\")), "\n")
        end
    end

end

local function reraise(msg, f, ...)
    local function g(success, ...)
	if success then return ... end
	error(msg:format(tostring(...)), 0)
    end
    return g(pcall(f,...))
end

local function try_error(short, long, f, ...)
    local function g(success, ...)
	if success then return ... end
	logging:error(short:format(tostring(...)), long:format(tostring(...)))
    end
    return g(pcall(f,...))
end

local function try_warn(msg, f, ...)
    assert(type(msg) == 'string')
    msg = msg ~= '' and msg
    local function g(success, ...)
	if not success then 
	    logging:warn(msg:format(tostring(...)))
	end
	return ...
    end
    return g(pcall(f,...))
end

-- \paragraph{Additions to lualibs-file and lualibs-dir}

local pathlib = {}

---@param char string
---@return boolean
function pathlib.is_sep(char)
    return char == '/' or (os.type == 'windows' and char == '\\')
end

-- Like file.join, but also compress multiple separators into one.

---@vararg string
---@return string
function pathlib.join(...)
    return (file.join(...):gsub('[/\\]+', '/'))
end

---@param path string
---@return boolean
function pathlib.is_dir(path)
    return lfs.attributes(path, 'mode') == 'directory'
end

-- On Windows, we disallow ``semi-absolute'' paths, i.e.\ paths starting with
-- the |\| but lacking the drive, or the reverse.

---@param path string
---@return boolean
function pathlib.is_absolute(path)
    local drive, dir_path = file.splitname(path)
    local is_rootbased = file.is_rootbased_path(dir_path)
    assert(os.type ~= 'windows' or (drive ~= '' == is_rootbased),
	   ("\"Semi-absolute\" paths are disallowed: '%s'"):format(path),
	   ("The path must either contain both the drive letter and start with '\\', \z
             or none of these; paths like 'C:foo' and '\\foo' are disallowed"))
    return is_rootbased
end

-- \paragraph{Permission-related functions}

---@param fn string
local function paranoia_in(fn)
    if type(fn) ~= 'string' then
        error(("A value of type '%s' was passed to paranoia_in"):format(type(fn)), 2)
    end
    if not kpse.in_name_ok_silent_extended(fn) then
	error(("I'm not allowed to read from '%s' (openin_any = {%s})")
	    :format(fn, kpse.expand_var('openin_any'), 2))
    end
end

---@param fn string
local function paranoia_out(fn)
    if type(fn) ~= 'string' then
        error(("A value of type '%s' was passed to paranoia_out"):format(type(fn)), 2)
    end
    if not kpse.out_name_ok_silent_extended(fn) then
	error(("I'm not allowed to write to '%s' (openout_any = {%s})")
	    :format(fn, kpse.expand_var('openout_any'), 2))
    end
end

local os_access
do
    local rwx_offsets = { r=0, w=1, x=2 }

    if os.type == 'windows' then  --todo: test rwx_offsets

        ---@param fn string
        ---@param mode string
        ---|"'r'" # readable?
        ---|"'w'" # writable?
        ---|"'x'" # executable?
        ---@return boolean
        function os_access(fn, mode)
    	local permissions = lfs.attributes(fn, "permissions")
    	local offset = rwx_offsets[mode]
    	return permissions:sub(offset, 1) == mode
        end

    else

        local my_euid, my_egid
        local status, err = io.open("/proc/self/status")
        assert(status, err)
        local lines = status:lines()
        for line in lines do
	    my_euid = line:match("^Uid:\t%d+\t(%d+)\t%d+\t%d+$")
	    if my_euid then
		my_euid = tonumber(my_euid)
		my_egid = tonumber(lines():match("^Gid:\t%d+\t(%d+)\t%d+\t%d+$"))
		assert(my_egid)
		break
	    end
        end
        status:close()

        ---@param fn string
        ---@param mode string
        ---|"'r'" # readable?
        ---|"'w'" # writable?
        ---|"'x'" # executable?
        ---@return boolean
        function os_access(fn, mode)
	    local attrs = lfs.attributes(fn)
	    if not attrs then return false end
	    local ugo_offset = my_euid == attrs.uid and 1
		or (my_egid == attrs.gid and 4 or 7)
	    local rwx_offset = rwx_offsets[mode]
	    return attrs.permissions:sub(ugo_offset + rwx_offset, 1) == mode
        end
    end
end

---@param fn string
---@return boolean
local function access_in(fn)
    return os_access(fn, 'r')
end

--This function can fail on Windows, reporting a non-writable file or dir as
--writable, because |os.access| does not work with Windows' |icacls|
--permissions.  Consequence: we might try to write to a read-only current or
--output directory instead of switching to the temporary directory.

---@param fn string
---@return boolean
local function access_out(fn)
	local success, exists = pcall(io.exists, fn)
	-- Presumably, we do not succeed when the parent directory is not executable.
	if success then
		if exists then
			--An existing file should be writable, and if it's a directory, it
			--should also be executable.
			return os_access(fn, 'w') and (not pathlib.is_dir(fn) or os_access(fn, 'x'))
		else
			--For a non-existing file, the parent directory should be writable.
			--(This is the only place where function |pathlib.parent| is used,
			--so it's ok that it returns the logical parent.)
			return os_access(fn, 'w')
		end
	else
		return false
	end
end

local find_in, find_out
do

    --First, get the values of |TEXMFOUTPUT| and |TEXMF_OUTPUT_DIRECTORY|.    
    --An output directory should exist, and may not point to the root on Linux
    --(Karl Berry, p.c.). On Windows, it may point to the root (of a drive),
    --because we only allow absolute filenames containing the drive, e.g.\
    --|F:\|; see |is_absolute|.

    ---@param f function
    ---@param var string
    ---@return string?
    local function get_outdir(f, var)
        local path = f(var)
	if path then
            if not pathlib.is_dir(path) then
                logging:warn(("I refuse to set %s to '%s', which is not a directory.")
		    :format(var, path))
                return
            end
	    if os.type ~= 'windows' and pathlib.join(path) ~= pathlib.sep then
		logging:warn(("I refuse to set %s to the root directory"):format(var))
	    end
	end
	return path
    end

    local texmf_output_directory = get_outdir(os.getenv, "TEXMF_OUTPUT_DIRECTORY")
    local texmfoutput = get_outdir(kpse.var_value, "TEXMFOUTPUT")

    --This function finds the location for an input file, respecting
    --|TEXMF_OUTPUT_DIRECTORY| and |TEXMFOUTPUT|, and the permissions in the
    --filesystem.  It returns an absolute file as-is.  For a relative file, it
    --tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current directory
    --(always), and |TEXMFOUTPUT| directory (if defined), in this order.  The
    --first readable file found is returned; if no readable file is found, the
    --file in the current directory is returned.

    ---@param fn string
    ---@return string
    function find_in(fn)
        if pathlib.is_absolute(fn) then return fn end
        for _, df in ipairs(
	    {
		texmf_output_directory and pathlib.join(texmf_output_directory, fn),
		fn,
		texmfoutput and pathlib.join(texmfoutput, fn),
            }
        ) do
            if df and access_in(df) then return df end
        end
	return fn
    end

    --This function finds the location for an output file, respecting
    --|TEXMF_OUTPUT_DIRECTORY| and |TEXMFOUTPUT|, and the permissions in the
    --filesystem.  It returns an absolute file as-is.  For a relative file, it
    --tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current directory
    --(unless |TEXMF_OUTPUT_DIRECTORY| is defined), and |TEXMFOUTPUT| directory
    --(if defined), in this order.  The first writable file found is returned;
    --if no writable file is found, the file in either the current or the
    --output directory is returned.

    ---@param fn string
    ---@return string
    function find_out(fn)
        if pathlib.is_absolute(fn) then return fn end
        for _, df in ipairs(
	    {
		texmf_output_directory and pathlib.join(texmf_output_directory, fn),
		not texmf_output_directory and fn,
		texmfoutput and pathlib.join(texmfoutput, fn),
            }
        ) do
            if df and access_out(df) then return df end
        end
	return texmf_output_directory and pathlib.join(texmf_output_directory, fn) or fn
    end
end

--A paranoid |dir.makedirs|.  The given folder is preprocessed by |find_out|.

---@param folder string
local function mkdir(folder)
    folder = find_out(folder)
    paranoia_out(folder)
    if io.exists(folder) then
	local attr = lfs.attributes(f)
	if attr.mode ~= 'directory' then
	    error("Path '%s' already exists, but it is not a directory")
	elseif false and attr.permissions == 'bad' then
	    error("Path '%s' already exists, but it is not writable")
	end
    else
	dir.makedirs(folder)
    end
end

---Unquote a quoted string
---@param fn string -- filename which might contain a quoted jobname
---@return string
local function unquote(fn)
    return (fn:gsub("\"(.-)\"", "%1"))
end


-- Restrict the rest of the script by undefining security relevant libraries
-- this defines an allow-list what functions of these libraries still should be
-- accessible
local env = {
    -- lua libraries
    arg      = arg,
    ipairs   = ipairs,
    math     = math,
    os       = { type = os.type, },
    pairs    = pairs,
    print    = print,
    table    = table,
    tonumber = tonumber,
    tostring = tostring,
    select   = select,
    pcall    = pcall,
    assert   = assert,
    error = error,
    type = type,

    -- texlua specific libraries (loaded automatically by texlua) 
    lfs      = {
	isfile = lfs.isfile,
	attributes = lfs.attributes,
    },
    kpse     = kpse,

    -- luatex specific libraries (loaded automatically by luatex but not texlua)
    file     = file,
    dir      = dir,
    io = io,

    -- our additions to file
    pathlib = pathlib,

    --for debugging
    inspect = inspect, --from lualibs-basic-merged
}

_ENV = env

---------------------------------
-- restricted area starts here --
---------------------------------

local help = [[
usage: memoize-extract.lua [-h] [-k] [-F {latex,plain,context}] [-f] [-q] [-m] [-V] pdf

Extract extern pages produced by package Memoize out of the document PDF.

positional arguments:
  pdf                   the PDF file: doc.pdf when compiling doc.pdf (doc, doc.tex and doc.mmz are accepted as well)

options:
  -h, --help            show this help message and exit
  -k, --keep            do not mark externs as extracted
  -F, --format {latex,plain,context}
                        the format of the TeX document invoking extraction
  -f, --force           extract even if the size-check fails
  -q, --quiet           describe what's happening
  -m, --mkdir           create a directory (and exit); mmz argument is interpreted as directory name
  -V, --version         show program's version number and exit

For details, see the man page or the Memoize documentation.]]

local parse_args
do
    local formats = { latex = true, plain = true, context = true }
    ---Parse some CLI arguments
    ---@param as string[] array of arguments
    ---@return table? updated_parameters
    ---@return string? err_msg
    parse_args = function(as)
        local args = { script_name = file.basename(arg[0]) }

        local i = 1
        local len = #as
        while i <= len do
            if as[i] == "--" then break end

            local a = as[i]:match("^%-([a-zA-Z])$")
            if not a then
                a = as[i]:match("^%-%-([a-zA-Z]+)$")
            end

            -- positional argument reached
            if not a then
                -- no flags are parsed after the first positional
                i = i - 1 -- "unparse" that argument
                break
            end

            if a == "h" then
		print(help)
                exit.succ()
            elseif a == "V" or a == "version" then
                print(("memoize-extract.py of Memoize %s"):format(VERSION))
                exit.succ()
            elseif a == "p" or a == "prune" then
                args.prune = true
            elseif a == "k" or a == "keep" then
                args.keep = true
            elseif a == "F" or a == "format" then
                if len < i + 1 then return nil, ("argument f/format needs an argument") end
                args.format = as[i + 1]
                if not formats[args.format] then
                    return nil, ("invalid format passed")
                end
                i = i + 1
            elseif a == "f" or a == "force" then
                args.force = true
            elseif a == "q" or a == "quiet" then
                args.quiet = true
            elseif a == "m" or a == "mkdir" then
                args.mkdir = true
            else
                return nil, ("invalid token passed '%s'"):format(as[i])
            end
            i = i + 1
        end

        if i + 1 ~= #as then
            error("wrong number of arguments passed, \z
                   exactly one positional needs to be given")
        end
        args.pdf = as[#as]

        return args
    end
end

local md5pat = ("%x"):rep(32)
---@param path string
---@return string dir_prefix
---@return string name_prefix
---@return string code_md5sum
---@return string context_md5sum
---@return string seq
local function split_extern_path(path)
    local dir_prefix, rest = path:match("^(.*/)(.*)$")
    if not dir_prefix then dir_prefix, rest = '', path end
    local name_prefix, code_md5sum, context_md5sum, seq
	= rest:match("^(.-)(" .. md5pat .. ")%-(" .. md5pat .. ")(.-).pdf$")
    assert(name_prefix and (seq == '' or seq:match("^%-%d+$")))
    return dir_prefix, name_prefix, code_md5sum, context_md5sum, seq
end

local function main(args)

    -- \paragraph{Initialization}

    -- With |--mkdir|, argument |pdf| is interpreted as the directory to create.
    if args.mkdir then
        mkdir(args.pdf)
        exit.succ()
    end

    -- Normalize the |pdf| argument into a |.pdf| filename.  This normalization
    -- will be removed in the release of the package which will drop the
    -- non-lua externalization scripts.
    do
	local suffix = file.suffix(pdf_fn)
	if suffix == "tex" or suffix == "mmz" then
	    args.pdf = file.replacesuffix(args.pdf, "pdf")
	elseif suffix ~= 'pdf' then
	    args.pdf = file.addsuffix(args.pdf, "pdf")
	end
    end

    -- Once we have the |.pdf| filename, we can open the log.
    logging.quiet = args.quiet
    logging.format = args.format
    logging.header = args.format and args.script_name .. ': ' or ''
    if args.format then
        local log_fn = find_out(file.replacesuffix(args.pdf, "mmz.log"))
        paranoia_out(log_fn)
        logging:info("Logging to " .. log_fn)
	logging:open(log_fn)
    end

    --Find the PDF file and check whether (a) we may read from it, and (b) we
    --may write to it, if --prune was given or --keep was not given.
    local pdf_fn = try_error(
	("Cannot find input PDF file '%s'"):format(args.pdf), '',
	find_in, args.pdf
    )
    paranoia_in(pdf_fn)
    if args.prune or not args.keep then
	try_error(
	    '',
	    ("I would have to write to '%s' because %s%s%s")
            :format(pdf_fn,
		    args.prune and 'option --prune/-p was given' or '',
		    args.prune and not args.keep and ' and ' or '',
		    not args.keep and 'option --keep/-k was not given'),
	    paranoia_out, pdf_fn
	)
    end

    --Open the PDF.

    local doc, catalog, pages = try_error(
	("PDF file '%s' seems corrupted. Perhaps you have to load Memoize \z
          earlier in the preamble"):format(pdf_fn),
	"In particular, Memoize must be loaded before TikZ library 'fadings' \z
         and any package deploying it, and in Beamer, load Memoize by writing \z
         \\RequirePackage{memoize} before \\documentclass{beamer}.",
        function()
            local doc = pdf.open(pdf_fn)
            local catalog = doc.trailer.Root()
            local pages = doc:get_pages()
            return doc, catalog, pages
        end
    )

    local record = try_error(
	("PDF file '%s' does not contain a Memoize record"):format(args.pdf),
	"",
        function()
            return catalog.MMIZ_Record()
        end
    )

    local current_prefix
    logging:info(("Extracting new externs from '%s'"):format(pdf_fn))

    for item_n, item in ipairs(record) do try_warn("%s", function()

        if item.Type == "/MMIZ_Prefix" then

            current_prefix = item.MMIZ_Filename
            if not current_prefix then
                error(("Malformed record item %d: missing /MMIZ_Filename \z
                        in a /MMIZ_Prefix item"):format(item_n))
            end

        elseif item.Type == "/MMIZ_NewExtern" then

	    local page = item.MMIZ_Page()
	    local page_number = item.MMIZ_PageNumber
	    assert(page and page_number,
		   ("Missing page reference or number for extern '%s'"):format(extern_path))

            assert(pages[page_number] == page,
		   ("Page number %d does not refer to the recorded page object (id=??)")
		   :format(page_number)) --todo in LuaPDFrw: a way to retrieve the object id

	    assert(item.MMIZ_Filename,
		   ("Missing /MMIZ_Filename in /MMIZ_NewExtern record item %d\z
                     for page number %d"):format(item_n, page_number))

            local extern_path = unquote(item.MMIZ_Filename)
	    local dir_prefix, name_prefix, code_md5sum, context_md5sum = reraise(
		("Illicit extern filename '%s'"):format(extern_path),
		split_extern_path, extern_path)

	    assert(current_prefix,
		   ("No prefix was encountered before extern '%s'"):format(extern_path))

            --This was missing in the py/pl script.
	    assert(pathlib.join(dir_prefix, name_prefix) == current_prefix,
		   ("Extern filename '%s' does not start with the expected prefix '%s'")
		   :format(extern_path, current_prefix))

            -- Check whether c-memo and cc-memo exist (in any input directory).
            local c_memo_file = find_in(
                file.join(file.dirname(extern_path),
			  name_prefix .. code_md5sum .. ".memo"))
            local cc_memo_file = find_in(
                file.join(file.dirname(extern_path),
			  name_prefix .. code_md5sum .. "-" .. context_md5sum .. ".memo"))

	    if not args.force then
		local access_c, access_cc = access_in(c_memo_file), access_in(cc_memo_file)
		assert(access_c and access_cc,
		       ("I refuse to extract page %d into extern '%s', \z
                         because the associated %s%s%s do%s not exist")
		       :format(page_number, extern_path,
			       not access_c and "c-memo" or '',
			       not access_c and not access_cc and ' and ' or '',
			       not access_cc and "cc-memo" or '',
			       not access_c and not access_cc and '' or 'es'))
            end

            local extern_file_out = find_out(extern_path)

            if not item.MMIZ_Extracted then
		reraise(
		    ("Failed to extract page %d into '%s': %%s")
		    :format(page_number, extern_path),
                    function()
                        local extern = pdf.new()
                        extern:insert_page(page)
                        extern:save(extern_file_out)
                        logging:info(("Page %d --> '%s'"):format(page_number, extern_path))
                        item.MMIZ_Extracted = true
                    end
                )
                if args.prune then
		    reraise(
			('I failed to remove page %d: %%s'):format(page_number),
			doc.remove_page, doc, page
		    )
                end
	    else
		logging:info(("Skipping extraction of page %d, it was already extracted")
		    :format(page_number))
            end

        end --/MMIZ_NewExtern
    end ) end --end try_warn ) end for loop

    if not args.keep or args.prune then
        if doc:update() == 0 then
            logging:info("No changes to the PDF were made")
        elseif args.prune and not args.keep then
            logging:info("The extraced extern pages were marked as extracted \z
                          and removed from the PDF")
        elseif args.prune then
            logging:info("The extraced extern pages were removed from the PDF")
        elseif not args.keep then
            logging:info("The extraced extern pages were marked as extracted in the PDF")
        end
    end

    logging:close()
    exit.succ()
end

local script_name = file.basename(arg[0])
if script_name == "memoize-extract" or script_name == "memoize-extract.lua" then
    main(parse_args(arg))
else
    -- allows this module to be loaded in LuaLaTeX via require
    return { main = main, parse_args = parse_args }
end
