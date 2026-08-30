#!/usr/bin/env texlua

--Search for the libraries within the tex tree (see LuaTeX manual 10.7).
kpse.set_program_name("luatex")
--todo: if program name is not yet set

require 'lualibs-lpeg' --required by lualibs-file
require 'lualibs-file'
require 'lualibs-dir'

-- Load "our own" PDF writer and argument parser.
local pdf = require 'luapdfrw'
local argparse = require 'pm-argparse'

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

---@type argspec
local memoize_info_argspec

---@type argument_parser
local parser --forward declaration because it is used in option help

local script_name = file.basename(arg[0])

memoize_info_argspec = {
    prog = script_name,
    header = "Read MMIZ information from the PDF.",
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
        { long = "mmz", short = "m", help = "output a .mmz file",
	  f = function(args, ...) args.mmz = true return ... end },
    },
    footer = "For details, see the man page or the Memoize documentation."
}

parser = argparse.argument_parser(memoize_info_argspec)
args = parser:parse_args(arg)

local doc, catalog = try_error(
    "The PDF file seems corrupted.",
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
