#!/usr/bin/env texlua

local VERSION = '2025/01/17 v1.4.1'

--Search for the libraries within the tex tree (see LuaTeX manual 10.7).
kpse.set_program_name("luatex")
--todo: if program name is not yet set

require 'lualibs-lpeg' --required by lualibs-file
require 'lualibs-file'
require 'lualibs-dir'

local argparse = require 'argparse'

-- Load "our own" PDF writer.
local pdf = require 'luapdfrw'

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

local function info(args)

    local doc, catalog = try_error(
	("The PDF file '%s' seems corrupted."):format(args.pdf),
	function()
	    local doc = pdf.open(args.pdf)
	    local catalog = doc.trailer.Root()
	    return doc, catalog
	end
    )

    local mmiz = try_error(
	"The PDF file does not contain a Memoize record.",
	function()
	    return catalog.MMIZ_Record()
	end
    )

    if args.mmz then

	for _, item in pairs(mmiz) do

	    assert(
		item.Type:sub(1,6) == "/MMIZ_",
		("Unrecognized prefix in type %s"):format(item.Type)
	    )
	    local type = item.Type:sub(7)
	    
	    assert(
		type == 'NewExtern' or type == 'UsedExtern' or
		type == 'NewCMemo' or type == 'UsedCMemo' or
		type == 'NewCCMemo' or type == 'UsedCCMemo' or
		type == 'Prefix',
		("Unrecognized type %s"):format(item.Type)
	    )

	    if type == 'NewExtern' then

		extracted = item.MMIZ_Extracted and '%' or ''
		print(("%s\\mmz%s {%s}{%s}{%spt}{%spt}"):format(
			extracted, type,
			item.MMIZ_Filename, item.MMIZ_PageNumber,
			item.MMIZ_PageWidth, item.MMIZ_PageHeight)
		)

	    else

		print(("\\mmz%s {%s}"):format(type, item.MMIZ_Filename))

	    end
	end

	print("\\endinput ")

    else

	print(mmiz)

    end

end


local function clean(args)
    print("Cleaning ... todo")
end

local script_name = file.basename(arg[0])
local epilog = "For details, see the man page or the Memoize documentation \z
                (https://ctan.org/pkg/memoize)."
	     
parser = argparse()
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
    :description "the PDF file (doc.pdf when compiling doc.tex)"

args = parser:parse()
