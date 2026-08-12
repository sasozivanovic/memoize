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

local VERSION = '2025/01/17 v1.4.1'

-- The following libraries are already available due to the use of LuaTeX: kpse
-- (Kpathsea), lfs (LuaFileSystem).  Furthermore, the following libraries are
-- extended in LuaTeX: lfs, os.  Finally, we also require several further
-- LuaTeX modules (note that they create global tables):

--Search for the libraries within the tex tree (see LuaTeX manual 10.7).
kpse.set_program_name("luatex")
--todo: if program name is not yet set

require 'lualibs-basic-merged' --only for debugging
require 'lualibs-lpeg' --required by lualibs-file
require 'lualibs-file'
require 'lualibs-dir'

--luacheck: read_globals dir
--luacheck: read_globals file
--luacheck: read_globals kpse
--luacheck: read_globals lfs
--luacheck: read_globals inspect

-- Load "our own" PDF writer and argument parser.
local pdf = require 'luapdfrw'
local argparse = require 'pm-argparse'

-- List all the functions used in the script as local, then empty the global
-- environment.  This way, we precisely know what the script uses.

local dir = {
    makedirs = dir.makedirs,
}
local file = {
    addsuffix = file.addsuffix,
    basename = file.basename,
    dirname = file.dirname,
    is_rootbased_path = file.is_rootbased_path,
    join = file.join,
    replacesuffix = file.replacesuffix,
    splitname = file.splitname,
    suffix = file.suffix,
}
local io = {
    exists = io.exists, ---@diagnostic disable-line
    open = io.open,
}
local kpse = {
    in_name_ok_silent_extended = kpse.in_name_ok_silent_extended,
    out_name_ok_silent_extended = kpse.out_name_ok_silent_extended,
    set_program_name = kpse.set_program_name,
    var_value = kpse.var_value,
}
local lfs = {
    attributes = lfs.attributes, ---@diagnostic disable-line
    isfile = lfs.isfile,         ---@diagnostic disable-line
}
local os = {
    exit = os.exit,
    type = os.type, ---@diagnostic disable-line
    getenv = os.getenv,
}

---@diagnostic disable-next-line
local inspect = inspect --for debugging, from lualibs-basic-merged

-- We write our own assert, because the official function lacks the level
-- parameter.  We also have different defaults: an empty message and level=0.
-- Note that we increase a non-zero level by one in the code, to function the
-- same as the official assert.
---@param v any
---@param message any
---@param level integer?
local assert = function(v, message, level)
    if not v then error(message or '', level and level+1 or 0) end
end

-- What the heck, let's also change the default level of error to 0, for
-- consistency.
---@param message any
---@param level integer?
local error = function(message, level) ---@diagnostic disable-line
    error(message or '', level and level+1 or 0)
end

--_ENV = { table = table }
--    arg, error, pairs, ipairs, pcall, print, tonumber, tostring, type

local script_name = file.basename(arg[0])

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
    package_name = '',
}
do
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
		(long ~= '' and "%s%s. (%s)" or "%s%s.")
		:format(self.header, short, long) end,
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

    ---@param fn string
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

    ---@param text string
    function logging:error(text)
	text = text:gsub("\\", "\\string\\")
	local short, long = text:match("^(.-)\t(.*)$")
	if not short then short, long = text, '' end
        if not self.quiet then
            print(ERROR.None(self, short, long))
        end
        if self.fh then
            self.fh:write(ERROR[self.format](self, short, long), "\n")
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
            self.fh:write(WARNING[self.format](self, text:gsub("\\", "\\string\\")), "\n")
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

---@param msg string
---@param f function
---@param ... any
---@return ... any
local function reraise(msg, f, ...)
    local function g(success, ...)
	if success then return ... end
	error(msg:format(tostring(...)))
    end
    return g(pcall(f,...))
end

---@param msg string
---@param f function
---@param ... any
---@return ... any
local function try_error(msg, f, ...)
    local function g(success, ...)
	if success then return ... end
	logging:error(msg:format(tostring(...)))
    end
    return g(pcall(f,...))
end

---@param msg string
---@param f function
---@param ... any
---@return ... any
local function try_warn(msg, f, ...)
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
    assert((...), "No path was given")
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
	   ("Disallowed \"semi-absolute\" path '%s'\tThe path must either contain \z
             both the drive letter and start with '\\', or none of these; paths like \z
             'C:foo' and '\\foo' are disallowed"):format(path))
    return is_rootbased
end

-- \paragraph{Permission-related functions}

kpse.set_program_name("texlua", "memoize-extract.lua")

---@param fn string
local function check_name_in(fn)
    if not kpse.in_name_ok_silent_extended(fn) then
        error(("I'm not allowed to read from '%s' (openin_any = {%s})")
            :format(fn, kpse.var_value('openin_any')))
    end
end

---@param fn string
local function check_name_out(fn)
    if not kpse.out_name_ok_silent_extended(fn) then
	error(("I'm not allowed to write to '%s' (openout_any = {%s})")
	    :format(fn, kpse.var_value('openout_any')))
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
        return permissions:sub(offset, offset) == mode
        end

    else

        local my_euid, my_egid
        local status, err = io.open("/proc/self/status")
        assert(status, err, 1)
        local lines = status:lines()
        for line in lines do
	    my_euid = line:match("^Uid:\t%d+\t(%d+)\t%d+\t%d+$")
	    if my_euid then
		my_euid = tonumber(my_euid)
		my_egid = tonumber(lines():match("^Gid:\t%d+\t(%d+)\t%d+\t%d+$"))
		assert(my_egid, "Internal error\tthe Gid line does not follow \z
                                 the Uid line in /proc/self/status", 1)
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
	    local offset = ugo_offset + rwx_offset
	    return attrs.permissions:sub(offset, offset) == mode
        end
    end
end

---@param fn string
---@param mode string?
local function check_access_in(fn, mode)
    assert(io.exists(fn), ("File '%s' does not exist"):format(fn))
    assert(os_access(fn, 'r'), ("File '%s' is not readable"):format(fn))
    assert(not mode or lfs.attributes(fn, 'mode') == mode,
	   ("'%s' exists but is not a %s"):format(fn, mode))
end

--This function can fail on Windows, reporting a non-writable file or dir as
--writable, because |os.access| does not work with Windows' |icacls|
--permissions.  Consequence: we might try to write to a read-only current or
--output directory instead of switching to the temporary directory.

---@param fn string
---@param mode string?
local function check_access_out(fn, mode)
    if io.exists(fn) then
	--An existing file should be writable, and if it's a directory, it
	--should also be executable.
	assert(os_access(fn, 'w'),
	       ("File '%s' is not writable"):format(fn))
	assert(not mode or lfs.attributes(fn, 'mode') == mode,
	       ("'%s' exists but is not a %s"):format(fn, mode))
	assert(not pathlib.is_dir(fn) or os_access(fn, 'x'),
	       ("Directory '%s' is not executable"):format(fn))
    else
	--For a non-existing file, the parent directory should be writable.
	--(This is the only place where function |pathlib.parent| is used,
	--so it's ok that it returns the logical parent.)
	local dn = file.dirname(fn)
	if dn == "" then dn = "." end
	assert(os_access(dn, 'w'),
	       ("Cannot create '%s' in a non-writable directory"):format(fn))
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
                --logging:warn(("I refuse to set %s to '%s', which is not a directory."):format(var, path))
                return
            end
	    --???? todo
	    --if os.type ~= 'windows' and pathlib.join(path) ~= pathlib.sep then
		--logging:warn(("I refuse to set %s to the root directory '%s'"):format(var, path))
	    --end
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
        for _, df in pairs(
	    {
		texmf_output_directory and pathlib.join(texmf_output_directory, fn),
		fn,
		texmfoutput and pathlib.join(texmfoutput, fn),
            }
        ) do
            if df and pcall(check_access_in, df) then return df end
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
        for _, df in pairs(
	    {
		texmf_output_directory and pathlib.join(texmf_output_directory, fn),
		not texmf_output_directory and fn,
		texmfoutput and pathlib.join(texmfoutput, fn),
            }
        ) do
            if df and pcall(check_access_out, df) then return df end
        end
	return texmf_output_directory and pathlib.join(texmf_output_directory, fn) or fn
    end
end

--A paranoid |dir.makedirs|.  The given folder is preprocessed by |find_out|.

---@param folder string
local function mkdir(folder)
    folder = find_out(folder)
    check_name_out(folder)
    check_access_out(folder)
    if io.exists(folder) then
	local attr = lfs.attributes(folder)
	if attr.mode ~= 'directory' then
	    error("Path '%s' already exists, but it is not a directory")
	elseif false and attr.permissions == 'bad' then
	    error("Path '%s' already exists, but it is not writable")
	end
    else
	dir.makedirs(folder)
    end
end

---Remove pairs of quotes from the filename, which might contain a quoted jobname.

---@param fn string
---@return string
local function unquote(fn)
    return (fn:gsub("\"(.-)\"", "%1"))
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
local MMIZ_Record_Types = {
    ['/MMIZ_NewExtern'] = true,
    ['/MMIZ_Prefix'] = true,
    ['/MMIZ_NewCMemo'] = true,
    ['/MMIZ_NewCCMemo'] = true,
    ['/MMIZ_UsedExtern'] = true,
    ['/MMIZ_UsedCMemo'] = true,
    ['/MMIZ_UsedCCMemo'] = true,
}

---@type argspec
local memoize_extract_argspec

---@type argument_parser
local parser --forward declaration because it is used in option help

memoize_extract_argspec = {
    prog = script_name,
    header = "Extract extern pages produced by package Memoize out of the document PDF.",
    positional = {
	help = "the PDF file (doc.pdf when compiling doc.tex)", arg_desc = "pdf",
	f = function(args)
	    assert(#args == 1,
		   "Exactly one positional argument, the PDF filename, should be given.")
	    args.pdf, args[1] = args[1], nil
	end
    },
    options = {
        { long = "help", short = "h", help = "show this help message and exit",
	  f = function() print(parser:help()) exit.succ() end },
        { long = "version", short = "V", help = "show program's version number and exit",
	    f = function() print(("%s of Memoize %s"):format(script_name, VERSION))
		exit.succ() end },
        { long = "quiet", short = "q", help = "don't describe what's happening",
	  f = function(args, ...) args.quiet = true return ... end },
        { long = "keep", short = "k", help = "do not mark externs as extracted",
	  f = function(args, ...) args.keep = true return ... end },
        { long = "prune", short = "p", help = "remove the extern pages after extraction",
	  f = function(args, ...) args.prune = true return ... end },
        { long = "format", short = "F", arg_desc = "{latex,plain,context}",
	  help = "the format of the TeX document invoking extraction",
	  f = function(args, format, ...)
	      args.format = format
	      assert(({latex = true, plain = true, context = true})[format],
		  ("The argument of --format/-f should be \z
                    one of 'latex', 'plain', and 'context', not '%s'.")
		  :format(format)) return ... end },
        { long = "force", short = "f",
	  help = "ignore warnings and extract problematic pages",
	  f = function(args, ...) args.force = true return ... end },
        { long = "mkdir", short = "m", help = "create the directory and exit\n\z
          (the positional argument pdf is interpreted as directory name)",
	  f = function(args, ...) args.mkdir = true return ... end },
    },
    footer = "For details, see the man page or the Memoize documentation."
}

---@class extraction_parameters
---@field quiet boolean?
---@field keep boolean?
---@field prune boolean?
---@field format 'latex'|'plain'|'context'?
---@field force boolean?
---@field mkdir boolean?
---@field pdf string

---@param args string[] | extraction_parameters
local function main(args)

    -- Convert command line arguments to extraction_parameters if necessary.
    if not args.pdf then
	parser = argparse.argument_parser(memoize_extract_argspec)
        args = parser:parse_args(args)
    end

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
	local suffix = file.suffix(args.pdf)
	if suffix == "tex" or suffix == "mmz" then
	    args.pdf = file.replacesuffix(args.pdf, "pdf")
	elseif suffix ~= 'pdf' then
	    args.pdf = file.addsuffix(args.pdf, "pdf")
	end
    end

    -- Once we have the |.pdf| filename, we can open the log.
    logging.package_name = 'memoize (lua-based extraction)'
    logging.quiet = args.quiet
    logging.format = args.format
    logging.header = args.format and script_name .. ': ' or ''
    if args.format then
        local log_fn = find_out(file.replacesuffix(args.pdf, "mmz.log"))
        check_name_out(log_fn)
        check_access_out(log_fn)
        logging:info(("Logging to '%s'"):format(log_fn))
	logging:open(log_fn)
    end

    if args.keep and args.prune then
	logging:error("Options --keep and --prune are incompatible")
    end

    --Find the PDF file and check whether (a) we may read from it, and (b) we
    --may write to it, if --prune was given or --keep was not given.
    local pdf_fn
    try_error(
	("Cannot open the PDF: %%s"):format(args.pdf),
	function()
	    pdf_fn = find_in(args.pdf)
	    check_name_in(pdf_fn)
	    check_access_in(pdf_fn)
	end
    )
    if args.prune or not args.keep then
	try_error(
	    ("Cannot open the PDF for writing: %%s. I would have to write to '%s' because %s%s%s")
            :format(pdf_fn,
		    args.prune and 'option --prune/-p was given' or '',
		    args.prune and not args.keep and ' and ' or '',
                not args.keep and 'option --keep/-k was not given'),
	    function()
		check_name_out(pdf_fn)
		check_access_out(pdf_fn)
	    end
	)
    end

    --Open the PDF.

    local doc, catalog, pages = try_error(
	("PDF file '%s' seems corrupted. Perhaps you have to load Memoize \z
          earlier in the preamble\tIn particular, Memoize must be loaded before\z
          TikZ library 'fadings' and any package deploying it, and in Beamer, \z
          load Memoize by writing \\RequirePackage{memoize} before \z
          \\documentclass{beamer}."):format(pdf_fn),
        function()
            local doc = pdf.open(pdf_fn)
            local catalog = doc.trailer.Root()
            local pages = doc:get_pages()
            return doc, catalog, pages
        end
    )

    local record = try_error(
	("PDF file '%s' does not contain a Memoize record"):format(args.pdf),
        function()
            return catalog.MMIZ_Record()
        end
    )

    local current_prefix
    logging:info(("Extracting new externs from '%s'"):format(pdf_fn))

    for item_n, item in pairs(record) do

	assert(MMIZ_Record_Types[item.Type],
	       ("/MMIZ_Record item %d: Unknown record type '%s'")
	       :format(item_n, item.Type))

	local item_str = item.MMIZ_PageNumber
	    and 'Page ' .. item.MMIZ_PageNumber
	    or  ('/MMIZ_Record item #%d (of type %s)'):format(item_n, item.Type)

	try_warn(item_str .. ": " .. "%s", function()

            if item.Type == "/MMIZ_Prefix" then

                assert (item.MMIZ_Filename, "Missing /MMIZ_Filename key")
                current_prefix = unquote(item.MMIZ_Filename)

            elseif item.Type == "/MMIZ_NewExtern" then

		local page = item.MMIZ_Page()
		local page_number = item.MMIZ_PageNumber

		assert(page, "Missing /MMIZ_Page key or invalid page reference")
		assert(args.force or page_number, "Missing /MMIZ_PageNumber key")

                assert(not page_number or args.force or pages[page_number] == page,
		       "The page number recorded in /MMIZ_PageNumber does not \z
                        refer to the page object recorded in /MMIZ_Page")
		--todo in LuaPDFrw: a way to retrieve the object id

		assert(item.MMIZ_Filename, "Missing /MMIZ_Filename")
                local extern_path = unquote(item.MMIZ_Filename)
		local dir_prefix, name_prefix, code_md5sum, context_md5sum = reraise(
		    ("%s: Illicit extern filename '%s'"):format(item_str, extern_path),
		    split_extern_path, extern_path)

		assert(current_prefix,
		       ("No /MMIZ_Prefix item was encountered before the record item \z
                         for extern '%s', or the last such item was malformed")
		       :format(extern_path))

		assert(pathlib.join(dir_prefix, name_prefix) == current_prefix,
		       ("Extern filename '%s' does not start with the expected prefix '%s'")
		       :format(extern_path, current_prefix))

                -- Check whether the c-memo and the cc-memo are accessible.
		if not args.force then
		    local c_memo_file = find_in(
			file.join(file.dirname(extern_path),
				  name_prefix .. code_md5sum .. ".memo"))
		    reraise(("I refuse to extract this page into extern '%s', \z
                              because the associated c-memo is not accessible: %%s")
			:format(extern_path),
			function()
			    check_name_in(c_memo_file)
			    check_access_in(c_memo_file)
			end
		    )

		    local cc_memo_file = find_in(
			file.join(file.dirname(extern_path),
				  name_prefix .. code_md5sum
			      .. "-" .. context_md5sum .. ".memo"))
		    reraise(("I refuse to extract this page into extern '%s', \z
                              because the associated cc-memo is not accessible: %%s")
			:format(extern_path),
			function()
			    check_name_out(cc_memo_file)
			    check_access_out(cc_memo_file)
			end
		    )
                end

                local extern_file_out = find_out(extern_path)
		check_name_out(extern_file_out)
		check_access_out(extern_file_out)

                if args.force or not item.MMIZ_Extracted then
		    reraise(
			("I failed to extract this page into '%s'\t%%s")
			:format(extern_path),
                        function()
                            local extern = pdf.new()
                            extern:insert_page(page)
                            extern:save(extern_file_out)
                            logging:info(("%s --> '%s'"):format(item_str, extern_path))
                            item.MMIZ_Extracted = true
                        end
                    )
                    if args.prune then
			reraise('I failed to remove this page\t%s',
				doc.remove_page, doc, page)
                    end
		else
		    error("Skipping extraction of this page, because it is \z
                           marked as extracted. Use option --force to force extraction")
		end

	    end --/MMIZ_NewExtern
	end ) --end try_warn )
    end -- end for loop

    if doc:update() == 0 then
	logging:info("No changes to the PDF were made")
    elseif args.prune and not args.keep then
	logging:info("The extracted extern pages were marked as extracted \z
                          and removed from the PDF")
    elseif args.prune then
	logging:info("The extracted extern pages were removed from the PDF")
    elseif not args.keep then
	logging:info("The extracted extern pages were marked as extracted in the PDF")
    else
	logging:info("No changes to the PDF were made")
    end
    
    logging:close()
    exit.succ()
end

if script_name == "memoize-extract" or script_name == "memoize-extract.lua" then
    main(arg)
else
    return main
end
