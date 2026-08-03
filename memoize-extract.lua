#!/usr/bin/env texlua

-- This file is a part of Memoize, a TeX package for externalization of
-- graphics and memoization of compilation results in general, available at
-- https://ctan.org/pkg/memoize and https://github.com/sasozivanovic/memoize.
--
-- Copyright (c) 2025- TODO(all)
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

-------------------
-- general notes --
-------------------

-- libraries already available due to the use of texlua
-- lfs:
--  lua-filesystem: used for checking/creating/deleting files/directories
--  see https://lunarmodules.github.io/luafilesystem/manual.html#reference
--  and https://texdoc.org/serve/LuaTeX/0
--
-- pdfe:
--  interface to pdf files: used to get information about a pdf file
--  see https://texdoc.org/serve/LuaTeX/0

-- policy regarding error handling:
-- - Functions other than the main-function should not exit
--   (this includes calling log_error and log_assert) as they don't know the
--   context in which they have been called (includes what cleanup needs to be
--   done).
--
-- - Instead, functions might do return nil, "errmsg" in order to indicate an
--   error has occured and describe it. (This is quite common in lua)
--
-- - Functions without return value should return true in case of success in
--   order to be able to detect the nil in the error case

------------------
-- some globals --
------------------
local VERSION = '2025/01/17 v1.4.1' -- TODO(release)

-- global variable STAGE is used as indicator whether this is loaded as library for testing or executed directly
-- variable is "testing" if exactly this string and "production" in all other cases
STAGE = STAGE == "testing" and "testing" or "production"

local pdf = require('luapdfrw')

--luacheck: read_globals kpse (loaded by texlua)


---------------------------------------------------------------------
-- some functions also used inside the security relevant functions --
-- -> need to be defined beforehand                                --
---------------------------------------------------------------------

---@param bp number
---@return number
local function bp2pt(bp)
	return bp / 72 * 72.27
end

-- not per-se a critical function, but variable strings used as patterns in
-- critical functions make this function critical

---make an arbitrary string safe for use in a lua pattern
---@param pat string
---@return string
local function escape_pattern_for_format(pat)
	local r = pat:gsub("[%%]", "%%%0")
	return r
end

-----------------------------------------
-- security relevant functions go here --
--                libs                 --
-----------------------------------------

-------------
-- pathlib --
-------------
-- -> probably moved to a different library eventually
local pathlib = {}
do
	-- other projects like penlight or l3build do stuff with different pathseps, according to
	-- https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats#canonicalize-separators
	-- and
	-- https://retrocomputing.stackexchange.com/questions/28344/since-when-does-windows-support-forward-slash-as-path-separator
	-- windows since quite a while also works with / as pathsep.
	-- Thus, this pathlib will normalize paths for having / as pathsep before working on paths
	if os.type == "windows" then
		---Normalize path such that windows also uses /
		---@param path string
		---@return string
		function pathlib.path_normalize(path)
			return path:gsub("\\", "/")
		end
	else
		---Unix already uses / as pathsep -> no-op
		---@param path string
		---@return string
		function pathlib.path_normalize(path)
			return path
		end
	end

	-- still windows paths work with disk specifiers -> special handling required
	if os.type == "windows" then
		---Check if path is an absolute path
		---NOTE: Windows UNC paths aren't supported
		---(see https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats#unc-paths)
		---@param path string
		---@return boolean? is_abs
		---@return string? err_msg
		function pathlib.path_is_absolute(path)
			local err
			path, err = pathlib.sanitize_path(path)
			if not path then return nil, err end

			return path:sub(2,2) == ":" and path:sub(3,3) == "/"
		end
	else
		---Check if path is an absolute path
		---@param path string
		---@return boolean? is_abs
		---@return string? err_msg
		function pathlib.path_is_absolute(path)
			local err
			path, err = pathlib.sanitize_path(path)
			if not path then return nil, err end

			if path:match("/%.%.+/") then
				return false
			end

			return path:match("^/") and true or false
		end
	end

	---check for weird characters in the path
	---@param path string
	---@return string path
	---@overload fun(path:string):nil, string?
	function pathlib.sanitize_path(path)
		if path:match("[%c%%\t\r\n><*|]") then
			return nil, ("Path contains invalid characters: %s"):format(path)
		end
		return path
	end
	---check for weird characters in the path
	---same as sanitize_path but includes / and \
	---@param name string
	---@return string? name
	---@overload fun(name:string):nil, string?
	function pathlib.sanitize_name(name)
		if name:match("[%c%%\t\r\n><*|/\\]") then
			return nil, ("File has an invalid name: %s"):format(name)
		end
		return name
	end
	---check for invalid suffixes
	---@param suffix string
	---@return string? suffix
	---@overload fun(suffix:string):nil, string?
	function pathlib.sanitize_suffix(suffix)
		if suffix:match("[%c%%\t\r\n><*|/\\]") then
			return nil, ("Suffix contains invalid characters: %s"):format(suffix)
		end
		if suffix:match("^%.") then
			return nil, ("Suffix should not start with a dot: %s"):format(suffix)
		end
		if suffix == "" then
			return nil, ("suffix must not be empty")
		end
		return suffix
	end

	---@param path string
	---@return string name
	---@return string remainder
	---@overload fun(name:string):nil,string?
	function pathlib.name(path)
		path = pathlib.path_normalize(path)

		local err
		path, err = pathlib.sanitize_path(path)
		if not path then return nil, err end

		local r, name = path:match("^(.*)/([^/]+)/?$")
		return name or path, name and r or nil
	end

	---@param path string
	---@param name string
	---@return string
	---@overload fun(name:string, path:string):nil,string?
	function pathlib.with_name(path, name)
		path = pathlib.path_normalize(path)

		local err
		name, err = pathlib.sanitize_name(name)
		if not name then return nil, err end

		local n, r = pathlib.name(path)
		if not n then return nil, r end

		if r then
			return r.."/"..name
		end
		return name
	end

	---@param path string
	---@return string suffix
	---@return string remainder
	---@overload fun(path:string):nil,string?
	function pathlib.suffix(path)
		path = pathlib.path_normalize(path)

		local err
		path, err = pathlib.sanitize_path(path)
		if not path then return nil, err end

		local r, suffix = path:match("^(.*)%.([^./]*)$")
		if not suffix and path:match("^%.") then
			-- is hidden file
			return "", path
		end
		return suffix or "", r or path
	end

	---@param path string
	---@param suffix string
	---@return string
	---@overload fun(path:string, suffix:string):nil,string?
	function pathlib.with_suffix(path, suffix)
		path = pathlib.path_normalize(path)

		local err
		suffix, err = pathlib.sanitize_suffix(suffix)
		if not suffix then return nil, err end

		local s, r = pathlib.suffix(path)
		if not s then return nil, r end

		return r.."."..suffix
	end

	function pathlib.join(path, ...)
		if not path then return "" end

		path = pathlib.path_normalize(path)

		local err
		path, err = pathlib.sanitize_path(path)
		if not path then return nil, err end

		local r, err = pathlib.join(...)
		if not r then return nil, err end

		if r == "" then return path end

		local p_sep = path:sub(-1,-1) == "/"
		local r_sep = r:sub(1,1) == "/"

		-- avoid duplicated pathseps
		if p_sep and r_sep then
			-- remove one of the /
			return path..r:sub(2)
		elseif p_sep or r_sep then
			-- no new / needed
			return path..r
		else
			-- no / yet present
			return path.."/"..r
		end
	end

	function pathlib.iter_path(path)
		path = pathlib.path_normalize(path)
		local root = pathlib.path_is_absolute(path) and "/" or ""
		local drive = ""
		if os.type == "windows" then
			drive = path:match("^%a:")
			if drive then
				path = path:sub(3)
			end
		end
		drive = drive or ""
		local components = {}
		for component in path:gmatch("([^/]+)") do
			table.insert(components, component)
		end
		local idx = 0
		return function()
			idx = idx + 1
			if components[idx] then
				return drive .. root .. table.concat({table.unpack(components, 1, idx)}, "/")
			else
				return nil
			end
		end
	end
end

-----------------------------------------
-- security relevant functions go here --
--           simple wrappers           --
-----------------------------------------

-- restricted function defined here
local mkdir
local mkdir_rec
do
	-- safe the functions/libraries needed in this restricted area
	local lfs = lfs
	-- this is not inside the function but the startup code -> can error here
	if not lfs then error("lfs is not available. This script needs to be executed with texlua") end

	---safely make new directory (non-recursive)
	---Note: this is a nop if the directory already exists
	---@param name string
	---@return boolean? success
	---@return string? error message
	mkdir = function(name)
		if lfs.isdir(name) then
			return true
		end

		-- from https://gitlab.lisn.upsaclay.fr/texlive/luatex/-/blob/master/source/texk/web2c/luatexdir/lua/luatex-core.lua#L269
		-- why also checking for `in`? isn't mkdir only about output?
		-- -> decided to keep both checks just in case
		if kpse.out_name_ok_silent_extended(name) and kpse.in_name_ok_silent_extended(name) then
			return lfs.mkdir(name)
		else
			return nil, ("mkdir '%s' not permitted"):format(name)
		end
	end
	---safely make new directory (recursive)
	---Note: this is a nop if the directory already exists
	---@param name string
	---@return boolean? success
	---@return string? error message
	mkdir_rec = function(name)
		local succ, err
		for c in pathlib.iter_path(name) do
			succ, err = mkdir(c)
			if not succ then
				return nil, err
			end
		end
		return true
	end
end

-- restricted function defined here
local io_open_w
do
	-- safe the functions/libraries needed in this restricted area
	local io_open = io.open

	---safely open a file in write mode
	---@param name string
	---@return file*? file_handle
	---@return string? error message
	io_open_w = function(name)
		if kpse.out_name_ok_silent_extended(name) then
			return io_open(name, "w")
		else
			return nil, ("Opening (write) '%s' not permitted"):format(name)
		end
	end
end

-- restricted function defined here
local mv
do
	-- safe the functions/libraries needed in this restricted area
	local os_rename = os.rename

	---safely rename a file aka moving it
	---@param src string
	---@param dst string
	---@return boolean? success
	---@return string? error message
	mv = function(src, dst)
		if not kpse.in_name_ok_silent_extended(src) then
			return nil, ("Moving (copy) from '%s' not permitted."):format(src)
		elseif not kpse.out_name_ok_silent_extended(src) then
			return nil, ("Moving (delete) from '%s' not permitted."):format(src)
		elseif not kpse.out_name_ok_silent_extended(dst) then
			return nil, ("Moving to '%s' not permitted."):format(dst)
		else
			return os_rename(src, dst)
		end
	end
end

-- restricted function defined here
local io_lines
do
	-- safe the functions/libraries needed in this restricted area
	local _io_lines = io.lines

	---safely get an iterator over the lines of a file
	---@param name string
	---@return fun()? iterator
	---@return string? error message
	io_lines = function(name)
		if kpse.in_name_ok_silent_extended(name) then
			return _io_lines(name)
		else
			return nil, ("Opening (read) '%s' not permitted"):format(name)
		end
	end
end

local pdfe_open
do
	local _pdfe_open = pdfe.open

	---safely open a pdf file with the pdfe library, other functions of that library are exposed directly
	---@param path string
	---@return pdfe.Document
	---@return string? error message
	pdfe_open = function(path)
		if kpse.in_name_ok_silent_extended(path) then
			return _pdfe_open(path)
		else
			return nil, ("Opening (read) '%s' not permitted"):format(path)
		end
	end
end

-----------------------------------------
-- security relevant functions go here --
--       more complex functions        --
-----------------------------------------

-- restricted function defined here
local extract_pages
do
	---extract all pages specified in `pages` from `src_pdf` to dedicated files specified via `out_prefix`
	---can raise an error
	---@param src_pdf string
	---@param out_prefix string
	---@param pages [integer]
	---@param pdf_version string
	---@return integer? return_code of the underlying os.execute
	---@return string? error returned by os.execute
	---@return function? cleanup clean up all files created in the process
	---@return string? out_pat pattern to which the pages were written to
	extract_pages = function(src_pdf, out_prefix, pages, pdf_version)
		if not kpse.in_name_ok_silent_extended(src_pdf) then
			return nil, ("Opening '%s' not permitted."):format(src_pdf), nil, nil
		end

		local out_pat = ("%s%%d.pdf.tmp"):format(escape_pattern_for_format(out_prefix))
		if not kpse.out_name_ok_silent_extended(out_pat:format(0)) then
			return nil, ("Writing to '%s' (and following) not permitted."):format(out_pat:format(0)), nil, nil
		end

		if not pdf_version:find("^%d%.%d$") then
			return nil, ("Invalid pdf_version provided: %s"):format(pdf_version)
		end
	end
end

-- restrict the complete rest of the script by undefining security relevant libraries
-- this defines an allow-list what functions of these libraries still should be accessible
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
	inspect  = inspect,
	pcall    = pcall,
	assert   = assert,

	-- luatex specific libraries
	lfs      = {isfile=lfs.isfile},
	kpse     = kpse,
	pdfe = {
		getpage    = pdfe.getpage,
		getbox     = pdfe.getbox,
		getversion = pdfe.getversion,
		close      = pdfe.close,
	},

	-- own library
	pathlib = pathlib,

	-- memoize-extract specific global
	STAGE    = STAGE,
}

local exit
if STAGE == "testing" then
	-- in testing environment avoid exiting the whole test
	-- -> instead raise an error which can be catched

	-- store the error function independent of the environment
	local error = error
	exit = {
		error = function() error("exited with error") end,
		warn  = function() error("exited with warn") end,
		succ  = function() error("exited with succ") end,
	}
else
	local os_exit = os.exit
	exit = {
		error = function() os_exit(11) end,
		warn  = function() os_exit(10) end,
		succ  = function() os_exit(0) end,
	}
end

do
	-- I don't like using the debug library, but getting a traceback here is a
	-- must to find where the error originates from
	local debug_traceback = debug.traceback
	-- use the lua error function -> exits immediately
	local error = error

	-- Prevent trying to change the environment.
	local function bad_index(...)
		local msg = "Attempt to access an undefined index: "
		for i = 2, select("#", ...) do
			msg = msg ..tostring(select(i, ...)).." "
		end
		msg = msg.."\n\n"..debug_traceback(nil, 2)
		error(msg,2)
	end
	setmetatable(env, {
		__index     = bad_index,
		__metatable = false,
		__newindex  = bad_index,
	})
end

_ENV = env
----------------------------------
-- restricted area startes here --
----------------------------------

-----------------
-- normal code --
-----------------

-- setup kpse
kpse.set_program_name("texlua", "memoize-extract.lua")

local find_in
do
	local texmf_output_directory = kpse.var_value("TEXMF_OUTPUT_DIRECTORY")
	local texmfoutput            = kpse.var_value("TEXMFOUTPUT")

	---@param fname string
	---@return string?
	---@return string? -- error
	find_in = function(fname)
		local abs, err = pathlib.path_is_absolute(fname)
		if abs == nil then return nil, err end
		if abs then return fname end

		if texmf_output_directory then
			local p, err = pathlib.join(texmf_output_directory, fname)
			if not p then return nil, err end
			if kpse.in_name_ok_silent_extended(p) then return p end
		end
		if not texmf_output_directory then
			if kpse.in_name_ok_silent_extended(fname) and lfs.isfile(fname) then return fname end
		end
		if texmfoutput then
			local p, err = pathlib.join(texmfoutput, fname)
			if not p then return nil, err end
			if kpse.in_name_ok_silent_extended(p) then return p end
		end

		return fname
	end
end

local find_out
do
	local texmf_output_directory = kpse.var_value("TEXMF_OUTPUT_DIRECTORY")
	local texmfoutput            = kpse.var_value("TEXMFOUTPUT")

	---@param fname string
	---@return string?
	---@return string?
	find_out = function(fname)
		local abs, err = pathlib.path_is_absolute(fname)
		if abs == nil then return nil, err end
		if abs then return fname end

		local texmf_od
		if texmf_output_directory then
			local p, err = pathlib.join(texmf_output_directory, fname)
			if not p then return nil, err end
			texmf_od = p
			if kpse.out_name_ok_silent_extended(p) then return p end
		end
		if not texmf_output_directory then
			if kpse.out_name_ok_silent_extended(fname) then return fname end
		end
		if texmfoutput then
			local p, err = pathlib.join(texmfoutput, fname)
			if not p then return nil, err end
			if kpse.out_name_ok_silent_extended(p) then return p end
		end

		return texmf_od or fname
	end
end

-- setup something like a logging library
local logging = {
	file      = nil,
	header    = "memoize-extract.lua: ",
	indent    = "",
	texindent = "",
}
do
	local package_name = "memoize (texlua-based extraction)"
	local ERROR   = {
		latex     = function(a) return ("\\PackageError{%s}{%s}{%s}"):format(a.package_name or "", a.short or "", a.long or "") end,
		plain     = function(a) return ("\\errhelp{%s}\\errmessage{%s: %s}"):format(a.long or "", a.package_name or "", a.short or "") end,
		context   = function(a) return ("\\errhelp{%s}\\errmessage{%s: %s}"):format(a.long or "", a.package_name or "", a.short or "") end,
		None      = function(a) return ("%s%s.\n%s"):format(a.header or "", a.short or "", a.long or "") end,
	}

	local WARNING = {
		latex     = function(a) return ("\\PackageWarning{%s}{%s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		plain     = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		context   = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		None      = function(a) return ("%s%s%s."):format(a.header or "", a.indent or "", a.text or "") end,
	}

	local INFO    = {
		latex     = function(a) return ("\\PackageInfo{%s}{%s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		plain     = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		context   = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		None      = function(a) return ("%s%s%s."):format(a.header or "", a.indent or "", a.text or "") end,
	}

	---Marks the log as complete
	function logging:close()
		if self.file then
			self.file:write("\\endinput\n")
			self.file:close()

			-- avoid working with the closed file at all cost
			self.file = nil
		end
	end

	---Setup logging with specific arguments to avoid needing to pass quiet and format arguments to each logging call
	---@param args table
	function logging:set_args(args)
		self.error = function(self, short, long) return self:_error(short, long, args.quiet, args.format) end
		self.info  = function(self, text) return self:_info(text, args.quiet, args.format) end
		self.warn  = function(self, text) return self:_warn(text, args.quiet, args.format) end
	end

	---Log an error
	---@param short string
	---@param long string
	---@param quiet boolean
	---@param format string
	function logging:_error(short, long, quiet, format)
		format = format or "None"
		short = short or ''
		long = long or ''
		if not quiet then
			print(ERROR.None{short=short, long=long, header=self.header})
		end
		if self.file then
			short = short:gsub("\\", "\\string\\")
			long  = long:gsub("\\", "\\string\\")
			self.file:write(ERROR[format]{short=short, long=long, package_name=package_name},"\n")
		end
		-- set the exitcode this way
		exit.succ = exit.error
	end
	logging.error = logging._error

	---Log a warning
	---@param text string
	---@param quiet boolean
	---@param format string
	function logging:_warn(text, quiet, format)
		format = format or "None"
		if not quiet then
			print(WARNING.None{text=text, header=self.header, indent=self.indent})
		end
		if self.file then
			text = text:gsub("\\", "\\")
			self.file:write(WARNING[format]{text=text, texindent=self.texindent, package_name=self.package_name},"\n")
		end
		-- set the exitcode this way
		exit.succ = exit.warn
	end
	logging.warn = logging._warn

	---Log info message
	---@param text string
	---@param quiet boolean
	---@param format string
	function logging:_info(text, quiet, format)
		format = format or "None"
		if not quiet then
			print(INFO.None{text=text, header=self.header, indent=self.indent})
		end
		if self.file then
			text = text:gsub("\\", "\\")
			self.file:write(INFO[format]{text=text, texindent=self.texindent, package_name=self.package_name},"\n")
		end
	end
	logging.info = logging._info
end

-- "forward declarations" for logging versions of error/assert
local log_assert
local log_error

---analog to lua's assert, define a function which uses logging for the message instead
---@param cond boolean condition to be checked by this assertion
---@param msg string? message shown when the assertion fails
---@param cleanup fun()? function invoked after logging the message used for additional cleanup (can still use logging, the log-file is not yet closed). Might be omitted
log_assert = function(cond, msg, cleanup)
	if not cond then
		logging:error("", msg or "")
		if cleanup then cleanup() end
		logging:close()
		exit.error()
	end
end

---analog to lua's error, define a function which uses logging for the message instead
---@param msg string? message shown
---@param cleanup fun()? function invoked after logging the message used for additional cleanup (can still use logging, the log-file is not yet closed). Might be omitted
log_error = function(msg, cleanup)
	logging:error("", msg)
	if cleanup then cleanup() end
	logging:close()
	exit.error()
end

---Unquote a quoted string
---@param fn string quoted filename
---@return string
local function unquote(fn)
	local r = fn:gsub("\"(.-)\"", "%1")
	return r
end

local md5pat = ("%x"):rep(32)
--- Parses the extern_path
-- in python this is a simple regex, but lua patterns cannot do the same things,
-- so we need multiple ones
---@param path string
---@return string? dir_prefix
---@return string? name_prefix
---@return string? code_md5sum
---@return string? context_md5sum
local function parse_extern_path(path)
	-- TODO maybe lpeg would be better suited for parsing this
	-- first split into d_prefix, name_prefix and rest
	local dir_prefix, name_prefix, code_md5sum, context_md5sum, remaining = path:match("^(.*/)(.-)("..md5pat..")%-("..md5pat..")(.-).pdf$")

	if not remaining then
		-- pattern did not match -> maybe the optional dir_prefix was not given
		dir_prefix = ""
		name_prefix, code_md5sum, context_md5sum, remaining = path:match("^(.-)("..md5pat..")%-("..md5pat..")(.-).pdf$")
	end

	if not remaining then
		-- If the pattern didn't match, return nil
		return nil
	end

	-- check if remaining fits the scheme
	if remaining ~= "" and not remaining:find("^%-%d+$") then
		return nil
	end

	-- Return the extracted components
	return dir_prefix, name_prefix, code_md5sum, context_md5sum
end

---Split a mmz prefix
-- in python this is a simple regex, but lua patterns cannot do the same things,
-- so we need multiple ones
---@param prefix string
---@return string? dir_prefix
---@return string? name_prefix
local function split_prefix(prefix)
	-- try with dir_prefix and name_prefix
	local dir_prefix, name_prefix = prefix:match("^(.*/)(.-)$")
	if not name_prefix then
		-- pattern did not match -> maybe the optional dir_prefix was not given
		dir_prefix = ""
		name_prefix = prefix:match("^(.-)$")
	end

	if not name_prefix then
		return nil
	end

	return dir_prefix, name_prefix
end

local parse_args
do
	local formats = {latex=true, plain=true, context=true}
	---Parse some CLI arguments
	---@param as string[] array of arguments
	---@param defaults table default values for the parameters
	---@return table? updated_parameters
	---@return string? err_msg
	parse_args = function(as, defaults)
		local args = defaults

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
				print([[usage: memoize-extract.lua [-h] [-k] [-F {latex,plain,context}] [-f] [-q] [-m] [-V] pdf

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

For details, see the man page or the Memoize documentation.]])
				exit.succ()
			elseif a == "V" or a == "version" then
				print(("memoize-extract.py of Memoize %s"):format(VERSION))
				exit.succ()

			elseif a == "p" or a == "prune" then
				args.prune = true

			elseif a == "k" or a == "keep" then
				args.keep = true

			elseif a == "F" or a == "format" then
				if len < i+1 then return nil, ("argument f/format needs an argument") end
				args.format = as[i+1]
				if not formats[args.format] then
					return nil, ("invalid format passed")
				end
				i = i+1

			elseif a == "f" or a == "force" then
				args.force = true

			elseif a == "q" or a == "quiet" then
				args.quiet = true

			elseif a == "m" or a == "mkdir" then
				args.mkdir = true

			else
				return nil, ("invalid token passed '%s'"):format(as[i])
			end
			i = i+1
		end

		if i+1 ~= #as then return nil, ("wrong number of arguments passed, exactly one positional needs to be given") end
		args.pdf = as[#as]

		return args
	end
end

---Normalizes the pdf argument into a .pdf filename
---@param pdf string
---@return string
---@overload fun(pdf:string): nil, string?
local function normalize_pdf(pdf)
	local suffix, err = pathlib.suffix(pdf)
	if not suffix then return nil, err end

	if suffix == "tex" or suffix == "mmz" then
		return pathlib.with_suffix(pdf, "pdf")
	elseif suffix ~= "pdf" then
		return pathlib.with_name(pdf, pathlib.name(pdf)..".pdf")
	end
	return pdf
end

local function main(args)
	if not args.pdf then
		log_error("pdf needs to be provided")
	end

	-- --mkdir -> just create a directory named |pdf|
	if args.mkdir then
		local succ, err = mkdir_rec(args.pdf)
		if not succ then
			log_error(err)
		end
		exit.succ()
	end

	local err, pdf_fn
	args.pdf, err = normalize_pdf(args.pdf)
	if not args.pdf then
		log_error(err)
	end
	--assert(args.pdf) -- only for the linter
	pdf_fn, err = find_in(args.pdf)
	if not args.pdf then
		log_error(err)
	end
	--assert(pdf_fn) -- only for the linter
	log_assert(args.pdf:match("^.*%.pdf$"), "malformed mmz parameter provided")
	log_assert(lfs.isfile(pdf_fn), ".pdf file was not found")
	--todo: access_in(pdf_fn), and access_out(pdf_fn) when not args.keep or args.prune

	-- setup logging to file
	if args.format then
		local log_file = find_out(args.pdf..".log")
		logging:info("Logging to "..log_file)
		local f, err = io_open_w(log_file)
		logging.file = f
	end

	local success_doc, doc, catalog, pages = pcall(
		function()
			local doc = pdf.open(args.pdf)
			local catalog = doc.trailer.Root()
			local pages = doc:get_pages()
			return doc, catalog, pages
		end
	)
	if not success_doc then
		logging:error(
			("PDF file '%s' seems corrupted. Perhaps you have to load Memoize \z
		     earlier in the preamble"):format(args.pdf),
			"In particular, Memoize must be loaded before TikZ library 'fadings' \z
		    and any package deploying it, and in Beamer, load Memoize by writing \z
		    \\RequirePackage{memoize} before \\documentclass{beamer}.")
		exit.error()
	end

	local success_record, record = pcall(
		function()
			return catalog.MMIZ_Record()
		end
	)
	if not success_record then
		logging:error(("PDF file '%s' does not contain a Memoize record"):format(args.pdf))
		exit.error()
	end

	local current_prefix
	
	for i,item in ipairs(record) do

		if item.Type == "/MMIZ_Prefix" then

			current_prefix = item.MMIZ_Filename
			if not current_prefix then
				logging:warn(
					"Malformed record: missing /MMIZ_Filename in a /MMIZ_Prefix item")
			end

		elseif item.Type == "/MMIZ_NewExtern" then

			if not item.MMIZ_Filename then
				logging:warn(
					"Malformed record: missing /MMIZ_Filename in a /MMIZ_NewExtern item")
				goto dont_extract
			end

			local extern_path = unquote(item.MMIZ_Filename)
			local dir_prefix, name_prefix, code_md5sum, context_md5sum
				= parse_extern_path(extern_path)
			if not (dir_prefix and name_prefix and code_md5sum and context_md5sum) then
				logging:warn(("Illicit extern filename '%s'"):format(extern_path))
				goto dont_extract
			end

			if not current_prefix then
				logging:warn(("No prefix was encountered before extern '%s'")
					:format(extern_path))
				goto dont_extract
			end

			--This was missing in the py/pl script.
			if pathlib.join(dir_prefix, name_prefix) ~= current_prefix then
				logging:warn(
					("Extern filename '%s' does not start with the expected prefix '%s'")
					:format(extern_path, current_prefix))
				goto dont_extract
			end

			-- Check whether c-memo and cc-memo exist (in any input directory).
			local c_memo_file = find_in(
				pathlib.with_name(extern_path, name_prefix .. code_md5sum .. ".memo"))
			local cc_memo_file = find_in(
				pathlib.with_name(
					extern_path,
					name_prefix .. code_md5sum .. "-" .. context_md5sum .. ".memo"))

			--todo: access_in(c_memo_file) and access_in(cc_memo_file)
			if not args.force and not (c_memo_file and cc_memo_file) then
				logging:warn(("I refuse to extract page %d into extern \z
		                    '%s', because the associated c-memo \z
		                    '%s' and/or cc-memo '%s' does not exist")
					:format(page_n+1, extern_path, c_memo_file, cc_memo_file))
				goto dont_extract
			end

			local extern_file_out = find_out(extern_path)

			local success_page, page, page_number = pcall(
				function()
					local page = item.MMIZ_Page()
					local page_number = item.MMIZ_PageNumber
					assert(page and page_number)
					return page, page_number
				end
			)
			if not success_page then
				logging:warn(("Missing page reference or number for extern '%s'")
					:format(extern_path))
				goto dont_extract
			end

			if pages[page_number] ~= page then
				--todo: phrase the warning better
				logging:warn(("Page number %d is not what was expected")
					:format(page_number))
				goto dont_extract
			end
			
			if not item.MMIZ_Extracted then

				local success_extract = pcall(
					function()
						local extern = pdf.new()
						extern:insert_page(page)
						extern:save(extern_file_out)
						logging:info(("Page %d --> %s"):format(page_number, extern_path))
						item.MMIZ_Extracted = true
					end
				)
				if not success_extract then
					logging:warn(("Failed to extract page %d into %s")
						:format(page_number, extern_path))
					goto dont_extract
				end
				
				if args.prune then
					local success_prune = pcall(
						function()
							doc:remove_page(page)
						end
					)
					if not success_prune then
						logging:warn(('I failed to remove page %d'):format(page_number))
					end
				end

			end

		end

		::dont_extract::

	end

	if doc and (not args.keep or args.prune) then
		if doc:update() == 0 then
			logging:info("No changes to the PDF were made")
		elseif args.prune then
			logging:info("The extracted extern pages were removed from the PDF")
		elseif not args.keep then
			logging:info("The extracted extern pages were marked as extracted in the PDF")
		end
	end

	logging:close()
	exit.succ()
end

if STAGE == "production" then
	-----------------------------------------------
	-- parsing + validating + deriving arguments --
	-----------------------------------------------
	local defaults = {
		pdf = nil,
		prune = false,
		keep = false,
		format = nil,
		force = false,
		quiet = false,
		mkdir = false,
		mmz = nil,
	}

	local args, err = parse_args(arg, defaults)
	if not args then
		print(err)
		exit.error()
	end

	logging:set_args(args)
	main(args)
elseif STAGE == "LIBRARY" then
	-- theoretically allows this to be loaded as library in LuaLaTeX via require
	return main
else
	-- expose functions for tests
	return {
		parse_extern_path     = parse_extern_path,
		split_prefix          = split_prefix,
		parse_args            = parse_args,
		normalize_pdf         = normalize_pdf,
		write_new_mmz         = write_new_mmz,
		postprocess_pages     = postprocess_pages,
		handle_mmz_prefix     = handle_mmz_prefix,
		handle_mmz_new_extern = handle_mmz_new_extern,
		pathlib               = pathlib,
		-- logging?
	}
end
