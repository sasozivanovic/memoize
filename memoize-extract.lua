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
--           simple wrappers           --
-----------------------------------------

-- restricted function defined here
local mkdir
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
	-- safe the functions/libraries needed in this restricted area
	local lfs = lfs
	-- this is not inside the function but the startup code -> can error here
	if not lfs then error("lfs is not available. This script needs to be executed with texlua") end
	local os_spawn = os.spawn
	local os_rm    = os.remove

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

		-- Be aware that using the %d syntax for -sOutputFile=... does not reflect the
		-- page number in the original document. If you chose (for example) to process
		-- even pages by using -sPageList=even, then the output of -sOutputFile=out%d.png
		-- would still be out1.png, out2.png, out3.png etc.
		local rungs_path = (os.selfdir or kpse.var_value("SELFAUTOLOC")) .. "/rungs" .. (os.type == "windows" and ".exe" or "")
		local cmd = {
			rungs_path,
			"-dSAFER",
			"-sDEVICE=pdfwrite",
			"-dNOPAUSE",
			"-dQUIET",
			"-dBATCH",
			"-dAutoRotatePages=/None",
			"-dCompatibilityLevel=".. pdf_version,
			"-sPageList=".. table.concat(pages, ","),
			"-sOutputFile=".. out_pat,
			src_pdf,
		}

		local succ, err = os_spawn(cmd)

		-- removes generated files (in case they still exist)
		local cleanup = function()
			for i in ipairs(pages) do
				local fn = out_pat:format(i)
				-- this is cleanup -> fail silently, not throwing errors
				if kpse.out_name_ok_silent_extended(fn) then
					if lfs.isfile(fn) and fn:match("%.tmp") then
						return os_rm(fn)
					end
				end
			end
		end

		return succ, err, cleanup, out_pat
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

	-- luatex specific libraries
	lfs      = {isfile=lfs.isfile},
	kpse     = kpse,
	pdfe = {
		getpage    = pdfe.getpage,
		getbox     = pdfe.getbox,
		getversion = pdfe.getversion,
		close      = pdfe.close,
	},

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
		local msg = "Attempt to access an undefined index:"
		for i = 2, select("#", ...) do
			msg = msg ..tostring(select(i, ...)).." "
		end
		msg = msg.."\n\n"..debug_traceback(nil, 2)
		error(msg)
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

---------------
-- pathutils --
---------------
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
end

-----------------
-- normal code --
-----------------

local check_dimensions
do
	---check the dimensions of the pages in `src_pdf` specified in `page_dimensions`. Reports back which dimensions match (with `tolerance`) an which don't
	---@param src_pdf string
	---@param page_dimensions table
	---@param tolerance number
	---@param force boolean
	---@return integer[] matching_pages
	---@return integer[] failed_pages
	---@return string pdf_version
	---@overload fun(src_pdf:string, page_dimensions:table, tolerance:number, force:boolean): nil, string?, nil
	check_dimensions = function(src_pdf, page_dimensions, tolerance, force)
		local pdf
		if kpse.in_name_ok_silent_extended(src_pdf) then
			pdf = pdfe_open(src_pdf)
		else
			return nil, ("Opening %s not permitted."):format(src_pdf)
		end

		-- collect which pages succeded the dimension check
		local succ = {}
		-- collect which pages failed the dimension check
		local failed = {}
		for _, i in ipairs(page_dimensions) do
			local p = i.page
			local page = pdfe.getpage(pdf, p)
			if not page then
				-- page not found -> skip it
				table.insert(failed, {page=i, reason="not found"})
			else
				local mediabox = pdfe.getbox(page, "MediaBox")
				local w = bp2pt(mediabox[3] - mediabox[1])
				local h = bp2pt(mediabox[4] - mediabox[2])
				if math.abs(w - i.width) > tolerance or math.abs(h - i.height) > tolerance and not force then
					table.insert(failed, {page=i, reason="dimension", real_width=w, real_height=h})
				else
					table.insert(succ, p)
				end
			end
		end

		local v_major, v_minor = pdfe.getversion(pdf)
		local pdf_version = ("%d.%d"):format(v_major, v_minor)

		pdfe.close(pdf)

		table.sort(succ)
		table.sort(failed, function(a,b) return a.page.page < b.page.page end)
		return succ, failed, pdf_version
	end
end

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
			local p, err = pathutil.join(texmf_output_directory, fname)
			if not p then return nil, err end
			if kpse.in_name_ok_silent_extended(p) then return p end
		end
		if not texmf_output_directory then
			if kpse.in_name_ok_silent_extended(fname) then return fname end
		end
		if texmfoutput then
			local p, err = pathutil.join(texmfoutput, fname)
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
			local p, err = pathutil.join(texmf_output_directory, fname)
			if not p then return nil, err end
			texmf_od = p
			if kpse.out_name_ok_silent_extended(p) then return p end
		end
		if not texmf_output_directory then
			if kpse.out_name_ok_silent_extended(fname) then return fname end
		end
		if texmfoutput then
			local p, err = pathutil.join(texmfoutput, fname)
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
			self.file:write("\\endinput")
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
		if not quiet then
			print(ERROR.None{short=short, long=long, header=self.header})
		end
		if self.file then
			short = short:gsub("\\", "\\string\\")
			long  = long:gsub("\\", "\\string\\")
			self.file:write(ERROR[format]{short=short, long=long, package_name=package_name})
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
			self.file:write(WARNING[format]{text=text, texindent=self.texindent, package_name=self.package_name})
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
			self.file:write(INFO[format]{text=text, texindent=self.texindent, package_name=self.package_name})
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
				print([[usage: memoize-extract.lua [-h] [-P PDF] [-k] [-F {latex,plain,context}] [-f] [-q] [-m] [-V] mmz

Extract extern pages produced by package Memoize out of the document PDF.

positional arguments:
  mmz                   the record file produced by Memoize: doc.mmz when compiling doc.tex (doc and doc.tex are accepted as well)

options:
  -h, --help            show this help message and exit
  -P, --pdf PDF         extract from file PDF
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

			elseif a == "P" or a == "pdf" then
				if len < i+1 then return nil,  ("argument P/pdf needs an argument") end
				args.pdf = as[i+1]
				i = i+1

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
		args.mmz = as[#as]

		return args
	end
end

---Normalizes the mmz argument into a .mmz filename
---@param mmz string
---@return string
---@overload fun(mmz:string): nil, string?
local function normalize_mmz(mmz)
	local suffix, err = pathlib.suffix(mmz)
	if not suffix then return nil, err end

	if suffix == "tex" then
		return  pathlib.with_suffix(mmz, "mmz")
	elseif suffix ~= "mmz" then
		return pathlib.with_name(mmz, pathlib.name(mmz)..".mmz")
	end
	return mmz
end

---@class Page
---@field page integer
---@field width number
---@field height number
---@field fn string
---@field prefix string
---@field line_tab LineTab

---@alias LineTab [string,integer?]
---@alias DirsToMake table<string, fun():boolean?, string?>

--- can raise an error (careful as there is true,false,nil for first return)
---@param line string
---@param current_prefix string?
---@param pages Page[]
---@param force boolean
---@param check_for_memo fun(c:string, cc:string):boolean checks if memo files are available
---@param line_tab LineTab
---@return boolean? continue signals whether the line was identified as new_extern
---@return string? err_msg
local function handle_mmz_new_extern(line, current_prefix, pages, force, check_for_memo, line_tab)
	-- TODO maybe lpeg would be better suited for parsing this
	local extern_path, page_n, w, h = line:match("\\mmzNewExtern *{(.*)}{(%d+)}{([0-9.]*)pt}{([0-9.]*)pt}")

	if extern_path and page_n and w and h then
		-- Found \mmzNewExtern -> mark the page for extraction later
		extern_path = unquote(extern_path)
		local dir_prefix, name_prefix, code_md5sum, context_md5sum = parse_extern_path(extern_path)
		if not dir_prefix or not name_prefix or not code_md5sum or not context_md5sum then
			logging:warn("Cannot parse line "..line.." properly")
			-- returning true as the line was matched
			-- don't add to pages array -> page gets skipped
			-- line_tab will be not modifiable -> line won't get somehow commented out
			return true
		end

		local err
		page_n, err = tonumber(page_n)
		if not page_n then return nil, err end

		local extern_file_out = find_out(extern_path)

		-- check whether c-memo and cc-memo exist (in any input directory)
		local c_memo_file, err  = pathlib.with_name(extern_path, name_prefix..code_md5sum..".memo")
		if not c_memo_file then return nil, err end

		local cc_memo_file, err = pathlib.with_name(extern_path, name_prefix..code_md5sum.."-"..context_md5sum..".memo")
		if not cc_memo_file then return nil, err end

		if not force and not check_for_memo(c_memo_file, cc_memo_file) then
			logging:warn(([[I refuse to extract page %d into extern 
'%s', because the associated c-memo 
'%s' and/or cc-memo '%s' 
does not exist]]):format(page_n+1, extern_path, c_memo_file, cc_memo_file))
			-- returning true as the line was matched
			-- don't add to pages array -> page gets skipped
			-- line_tab will be not modifiable -> line won't get somehow commented out
			return true
		end

		if not current_prefix then return nil, "no prefix was parsed before this extern" end

		line_tab[2] = #pages
		table.insert(pages, {page=page_n, width=w, height=h, fn=extern_file_out, prefix=current_prefix, line_tab=line_tab})
		return true
	end
	return false
end

--- does not raise an error
---@param line string
---@param dirs_to_make DirsToMake
---@param current_prefix string?
---@param gs_prefix string?
---@return boolean continue signals whether the line was identified as new_extern
---@return string? current_prefix
---@return string? gs_prefix
local function handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)
	local m_p = line:match("\\mmzPrefix *{(.-)}")

	if m_p then
		-- Found \mmzPrefix -> store what extern directory to create later when it's needed
		m_p = unquote(m_p)
		local dir_prefix, name_prefix = split_prefix(m_p)
		if name_prefix and dir_prefix then
			dirs_to_make[dir_prefix] = function() if dir_prefix ~= "" then return mkdir(dir_prefix) end return true end
			current_prefix = dir_prefix
			-- save the first prefix that occurs
			gs_prefix = gs_prefix or current_prefix
		else
			logging:warn("Cannot parse line "..line)
		end
		return true, current_prefix, gs_prefix
	end
	return false, current_prefix, gs_prefix
end

---Fully parses the mmz file
--- can raise an error
---@param mmz_lines fun(): any iterator over the lines of the mmz file. Usually the value returned by io.lines(mmz)
---@param keep boolean
---@param force boolean
---@return Page[] pages information about the pages to be extracted
---@return [string, integer?][] new_mmz data to be inserted later into the new mmz file (elements are also referenced by pages elements -> might change
---@return string? gs_prefix first mmz prefix parsed -> might be used as prefix for the files generated by ghostscript
---@return DirsToMake dirs_to_make contains a function to mkdir the directory for each encountered prefix 
---@overload fun(mmz_lines, force, keep): nil, string?
local function parse_mmz(mmz_lines, force, keep)
	---@type Page[]
	local pages          = {}

	---@type [string,integer?][]
	local new_mmz        = {}

	local gs_prefix      = nil
	local current_prefix = nil
	local dirs_to_make   = {}

	for line in mmz_lines do
		---@type [string]
		local line_tab = {line} -- store the line in a table as this allows us to reference it (-> can be changed) instead of copying it

		local continue = false
		local err
		-- local succ, err

		-- match against NewExtern first as this is the most common case
		continue, err = handle_mmz_new_extern(line, current_prefix, pages, force, function(c, cc) return find_in(c) and find_in(cc) end, line_tab)
		if continue == nil then return nil, err end
		if continue then goto continue end

		continue, current_prefix, gs_prefix = handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)
		if continue then goto continue end

		-- nothing matched

		::continue::
		if not keep then
			table.insert(new_mmz, line_tab)
		end
	end
	return pages, new_mmz, gs_prefix, dirs_to_make
end

---Postprocess extracted pages
---renames the files resulting from the extraction like it was specified in the .mmz
---does not error
---@param pages Page[] information about the pages to be extracted
---@param dirs_to_make DirsToMake contains a function to mkdir the directory for each encountered prefix 
---@param page_pat string pattern with on %d to obtain the src paths of the pdfs containing page page contents
---@param keep boolean
local function postprocess_pages(pages, dirs_to_make, page_pat, keep)
	for p, page in ipairs(pages) do
		-- make directory if necessary
		if dirs_to_make[page.prefix] then
			dirs_to_make[page.prefix]()
			dirs_to_make[page.prefix] = nil
		end

		local extract = page_pat:format(p)
		if lfs.isfile(extract) then
			local succ, err = mv(extract, page.fn)
			if succ then
				if not keep then
					-- wait until here to comment out the line in the .mmz so that only successfully extracted pages are uncommented
					page.line_tab[1] = "%"..page.line_tab[1]
				end
			else
				logging:warn("Finalizing page "..page.page.." failed: "..err)
			end
		else
			-- make sure to skip non-existant files
			logging:warn(("file '%s' was not found -> will still be missing in the next compilation step"):format(extract))
		end
		logging:info(("Page %d --> %s"):format(page.page, page.fn))
	end
end

---Function to write the new (probably updated) contents of the mmz file
---does not error
---@param mmz file* file handle to which the content of the new mmz file should be written to
---@param new_mmz [string, integer?][] data to be inserted later into the new mmz file (elements are also referenced by pages elements -> might change
local function write_new_mmz(mmz, new_mmz)
	local first = true
	for _, line in ipairs(new_mmz) do
		mmz:write(not first and "\n" or "", line[1])
		first = false
	end
end

local function main(args)
	if not args.mmz then
		log_error("mmz needs to be provided")
	end

	-- --mkdir -> just create a directory named |mmz|
	if args.mkdir then
		mkdir(args.mmz)
		exit.succ()
	end

	args.mmz = normalize_mmz(args.mmz)
	log_assert(args.mmz:match("^.*%.mmz$"), "malformed mmz parameter provided")
	log_assert(lfs.isfile(args.mmz), ".mmz file was not found")

	-- setup logging to file
	if args.format then
		local log_file = find_out(args.mmz..".log")
		logging:info("Logging to "..log_file)
		local f, err = io_open_w(log_file)
		logging.file = f
	end

	-- infer the path to the pdf file
	args.pdf = find_in(args.pdf or pathlib.with_suffix(args.mmz, "pdf"))

	log_assert(args.pdf:match("^.*%.pdf$"), "malformed pdf parameter provided / inferred")
	log_assert(lfs.isfile(args.pdf), ".pdf file was not found")

	-- collect data from file
	local mmz = find_in(args.mmz, true)
	local pages, new_mmz, gs_prefix, dirs_to_make = parse_mmz(io_lines(mmz), args.force, args.keep)
	-- check if parsing has returned an error
	log_assert(pages ~= nil, new_mmz)

	if #pages == 0 then
		-- nothing to be processed -> terminate
		logging:info("No externs found that need processing")
		logging:close()
		exit.succ()
	end

	log_assert(gs_prefix, "at least one prefix needs to be read")
	log_assert(dirs_to_make[gs_prefix], "nothing registered to create directory for the prefix")

	-- check the dimensions
	local succ, failed, pdf_version = check_dimensions(args.pdf, pages, 0.01, args.force)
	-- check if has returned an error
	log_assert(succ ~= nil, failed)
	-- additional check
	log_assert(#succ + #failed == #pages, "Internal error: amount of pages for which the check succeded + failed does not match amount of requested pages")
	local req_pages = succ

	for _, p in ipairs(failed) do
		if p.reason == "dimension" then
			logging:warn(([[I refuse to extract page %d from '%s' 
because its size is not what I expected]]):format(p.page.page, args.pdf))
		elseif p.reason == "not found" then
			logging:warn(([[I refuse to extract page %d from '%s' 
that page was not found in the pdf file]]):format(p.page.page, args.pdf))
		else
			log_error("Internal error: Unknown dimension-check-fail-reason: "..(p.reason or ""))
		end
	end

	if #req_pages == 0 then
		-- nothing to be processed -> terminate
		logging:info("No externs found that need processing")
		logging:close()
		exit.succ()
	end

	-----------------------------------------------------------------------
	-- until here nothing was changed in the filesystem in this function --
	-- => no above this no cleanup (except opened logfile needed)        --
	-----------------------------------------------------------------------

	-- extract the requested pages
	-- Note: "mmz/0.pdf" corresponds not to the first page, but to the first page requested in req_pages

	dirs_to_make[gs_prefix]()
	dirs_to_make[gs_prefix] = nil
	local succ, err, cleanup, page_pat = extract_pages(args.pdf, gs_prefix, req_pages, pdf_version)
	-- make sure cleanup is not nil
	cleanup = cleanup or function() end
	log_assert(succ == 0, err, cleanup)

	-- postprocess extracted pages -> rename/move them
	postprocess_pages(pages, dirs_to_make, page_pat, args.keep)

	-- write new |.mmz| file with |\mmzNewExtern| lines commented out.
	if not args.keep then
		local file, err = io_open_w(mmz)
		log_assert(file ~= nil, err, cleanup)

		write_new_mmz(file, new_mmz)

		file:close()
	end

	-- if for some reason files generated by ghostscript were not used, remove them now
	cleanup()

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
		normalize_mmz         = normalize_mmz,
		write_new_mmz         = write_new_mmz,
		postprocess_pages     = postprocess_pages,
		handle_mmz_prefix     = handle_mmz_prefix,
		handle_mmz_new_extern = handle_mmz_new_extern,
		pathlib               = pathlib,
		-- logging?
	}
end
