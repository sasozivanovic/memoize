#!/usr/bin/env texlua

local VERSION = '2025/01/17 v1.4.1'

-- luacheck: std lua53+texlua+lualibs

--Search for the libraries within the tex tree (see LuaTeX manual 10.7).
kpse.set_program_name("luatex")
--todo: if program name is not yet set

--require "lualibs-lua"--for testing
require 'lualibs-lpeg' --required by lualibs-file
require 'lualibs-file'
require 'lualibs-dir'

require "lualibs-table"--for testing

local argparse = require 'argparse'

-- Load "our own" PDF writer.
local pdfrw = require 'luapdfrw'

-- Utilities

---@param msg string
---@param f function
---@param ... any
---@return ... any
local function try_error(msg, f, ...)
    local function g(success, ...)
	if success then return ... end
	error(msg:format(tostring(...)))
    end
    return g(pcall(f,...))
end

local function mmiz_open(pdf_fn)
    local doc, catalog = try_error(
	("PDF file '%s' seems corrupted."):format(pdf_fn),
	function()
	    local doc = pdfrw.open(pdf_fn)
	    local catalog = doc.trailer.Root()
	    return doc, catalog
	end
    )
    local mmiz = try_error(
	("PDF file '%s' does not contain a Memoize record."):format(pdf_fn),
	function()
	    return catalog.MMIZ_Record()
	end
    )
    return mmiz, doc, catalog
end

local function mmiz_type(item)
    assert(item.Type:sub(1,1) == '/')
    local type = item.Type:sub(2)
    assert(
	type == 'NewExtern' or type == 'UsedExtern' or
	type == 'NewCMemo' or type == 'UsedCMemo' or
	type == 'NewCCMemo' or type == 'UsedCCMemo' or
	type == 'Prefix',
	("Unrecognized type %s"):format(item.Type)
    )
    return type
end

local function info(args)
    local mmiz = mmiz_open(args.pdf)
    if args.mmz then
	for _, item in ipairs(mmiz.Kids) do
	    local type = mmiz_type(item)
	    if type == 'NewExtern' then
		print(("\\mmzNewExtern {%s}{%s}{%spt}{%spt}"):format(
			item.Filename, item.PageNumber,
			item.PageWidth, item.PageHeight))
	    else
		print(("\\mmz%s {%s}"):format(type, item.Filename))
	    end
	end
	print("\\endinput ")
    else
	print(mmiz)
    end
end

local function parent(fn)
    local parent_fn = file.dirname(fn)
    return parent_fn == '' and '.' or parent_fn
end

local MMIZ_Record_Types = {
    ['/NewExtern'] = true,
    ['/Prefix'] = true,
    ['/NewCMemo'] = true,
    ['/NewCCMemo'] = true,
    ['/UsedExtern'] = true,
    ['/UsedCMemo'] = true,
    ['/UsedCCMemo'] = true,
}

local function clean(args)
    -- We loop through the given .mmz files, adding prefixes to whatever
    -- manually specified by the user, and collecting the files to keep.
    local prefixes = {}
    if args.prefix then
	for i, prefix in ipairs(args.prefix) do
	    prefixes[i] = prefix --todo: resolve
	end
    end
    local keep = {}
    for _, pdf in ipairs(args.pdf) do
	local pdf_parent = parent(pdf)
	local mmiz = mmiz_open(pdf)
	local prefix, empty
	for _, item in ipairs(mmiz.Kids) do
	    local type = mmiz_type(item)
	    if type == 'Prefix' then
		prefix = item.Filename
		table.insert(prefixes, file.join(pdf_parent, prefix)) --todo: resolve
		if empty == nil then
		    empty = true
		end
	    else
		assert(prefix,
		       ("Bailing out, no prefix announced before file %s in %s")
		       :format(item.Filename, pdf))
		assert(item.Filename:sub(1,prefix:len())==prefix,
		       ("Bailing out, prefix of file %s does not match \z
                         the last announced prefix %s in %s")
		       :format(item.Filename, prefix, pdf))
		keep[file.join(pdf_parent, item.Filename)] = true
		empty = false
	    end
	end
	assert(not empty or args.all,
	       ('Bailing out, /MMIZ_Record of file %s is empty.'):format(pdf))
    end

    local tbdeleted = {}
    local function populate_tbdeleted(folder, basename_prefix)
	local P, R = lpeg.P, lpeg.R
	local hex = R"09"+R"AF"
	local aux_pattern =
	    P(basename_prefix)
	    * hex^32
	    * (P"-" * hex^32)^-1
	    * (".memo" + ((P"-" * R"09"^1)^-1 * ".pdf") + ".log")
	    * P(-1)
	for basename in lfs.dir(folder) do
	    local fn = file.join(folder, basename)
	    if lpeg.match(aux_pattern, basename) and (args.all or not keep[fn]) then
		table.insert(tbdeleted, fn)
	    end
	end
    end
    for _, prefix in ipairs(prefixes) do
	if lfs.isdir(prefix) then
	    populate_tbdeleted(prefix, '')
	end
	populate_tbdeleted(parent(prefix), file.basename(prefix))
    end
    if #tbdeleted > 0 then
	table.sort(tbdeleted)
	local a = args.yes
	if not args.yes then
	    print('I will delete the following files:')
	    for _, fn in ipairs(tbdeleted) do
		print(fn)
	    end
	    print("Proceed (y/n)? ")
	    a = io.stdin:read()
	end
	if args.yes or a == 'y' or a == 'yes' then
	    for _, fn in ipairs(tbdeleted) do
		local ok, err = os.remove(fn)
		if not args.quiet then
		    if ok then
			print("Deleted " .. fn)
		    else
			print("Deleting " .. err)
		    end
		end
	    end
	else
	    print("Bailing out.")
	end
    elseif not args.quiet then
	print('Nothing to do, the directory seems clean.')
    end
end

local script_name = file.basename(arg[0])
local epilog = "For details, see the man page or the Memoize documentation \z
                (https://ctan.org/pkg/memoize)."

local parser = argparse()
    :name(script_name)
    :description "Memoize utilities."
    :epilog(epilog)
parser:flag "--version -V"
    :description "show program's version number and exit"
    :action(function()
	    print(script_name .. " of Memoize " .. VERSION)
	    os.exit()
	   end)

local cmd_info = parser:command "info"
    :description "Read MMIZ information from the PDF."
    :epilog(epilog)
    :action(info)
cmd_info:argument "pdf"
    :description "the PDF file (doc.pdf when compiling doc.tex)"
cmd_info:flag "--mmz -m"
    :description "output data in the .mmz format"

local cmd_clean = parser:command "clean"
    :description "Remove (stale) memo and extern files."
    :epilog(epilog)
    :action(clean)
cmd_clean:argument "pdf"
    :args '*'
    :description "the PDF file (doc.pdf when compiling doc.tex)"
cmd_clean:option "--prefix -p"
    :description "a path prefix to clean"
    :args '*'
cmd_clean:flag "--yes -y"
    :description "do not ask for confirmation"
cmd_clean:flag "--all -a"
    :description "remove all (not just stale) memos and externs"
cmd_clean:flag "--quiet -q"
    :description "don't describe what's happening"

parser:parse()
