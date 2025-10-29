--[[

    The poor man's argument parser.  It supports long (--option) and short (-o)
    options, positional arguments may occur between options (-a <positional>
    -b), short options may be merged (-io) and don't require space before the
    argument (-o file and -ofile are both ok).  It automatically generates
    usage and help, options occur in the order listed in code.  For usage, see
    memoize-extract.lua of TeX package memoize (https://ctan.org/pkg/memoize).

    Module pm-argparse is free software distributed under the terms of the MIT
    license reproduced below.

    Copyright (c) 2025- Saso Zivanovic <saso.zivanovic@guest.arnes.si>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.

]] --

---@class argument_parser
---@field spec argspec
---@field parse_args function
---@field private parse_next function
---@field usage function
---@field help function
---@field private long_options table
---@field private short_options table
local argument_parser = {}

---@class argspec
---@field prog string
---@field header string?
---@field positional pos_arg
---@field options opt_arg[]
---@field footer string?

---@class pos_arg
---@field f function
---@field arg_desc string?
---@field help string?

---@class opt_arg
---@field long string?
---@field short string?     --either long or short shoudl should be non-nil
---@field f function
---@field arg_desc string?
---@field help string?

---@return string
function argument_parser:usage()
    local usages = {}
    for _, spec in pairs(self.spec.options) do
	table.insert(usages, ("[-%s%s]"):format
		     (spec.short, spec.arg_desc and ' ' .. spec.arg_desc or ''))
    end
    return ("Usage: %s %s %s")
	:format(self.spec.prog, table.concat(usages, ' '), self.spec.positional.arg_desc)
end

---@return string
function argument_parser:help(help_column)
    help_column = help_column or 24
    local to_help_column = '\n' .. (' '):rep(help_column)
    local missing_short_space = ''
    for _, spec in pairs(self.spec.options) do
	if spec.short then missing_short_space = '   ' break end
    end
    local usages = {}
    for _, spec in pairs(self.spec.options) do
	local option = ("  %s%s %s%s"):format(
	    spec.short and '-' .. spec.short or missing_short_space,
	    spec.short and spec.long and ',' or '',
	    spec.long and '--' .. spec.long or '',
	    spec.arg_desc and ' ' .. spec.arg_desc or '')
	local sep = (option:len() <= help_column or not spec.help)
	    and (' '):rep(help_column - option:len())
	    or to_help_column
	local option_help = spec.help and spec.help:gsub('\n', to_help_column) or ''
	table.insert(usages, ("%s%s%s"):format(option, sep, option_help))
    end
    return ("%s\n%s\noptions:\n%s%s")
	:format(self:usage(),
		self.spec.header and ('\n' .. self.spec.header .. '\n') or '',
		table.concat(usages, '\n'),
		self.spec.footer and ('\n\n' .. self.spec.footer) or '')
end

---@param args table
---@param a string?
---@param ... any # it's actually ... string
---@return table
function argument_parser:parse_next(args, a, ...)
    if not a then
	self.spec.positional.f(args)
	return args
    elseif a == '--' then
	local rest = table.unpack(...)
	return table.move(rest, 1, #rest, #args+1, args)
    elseif a:sub(1, 2) == '--' then
	local opt_spec = self.long_options[a:sub(3)]
        assert(opt_spec, ("Unknown option '%s'."):format(a))
	return self:parse_next(args, opt_spec.f(args, ...))
    elseif a:sub(1,1) == '-' then
	local opt_spec = self.short_options[a:sub(2,2)]
	assert(opt_spec, ("Unknown option '-%s'."):format(a:sub(2,2)))
	if a:len() > 2 then
	    a = a:sub(3)
            a = opt_spec.arg_desc and a or '-' .. a
	    return self:parse_next(args, opt_spec.f(args, a, ...))
	else
	    return self:parse_next(args, opt_spec.f(args, ...))
	end
    else
	table.insert(args, a)
	return self:parse_next(args, ...)
    end
end

---@param self argument_parser
---@param argtable string[]
---@param error_level integer?
---@return table
---@return boolean
function argument_parser:parse_args(argtable, error_level)
    self.long_options, self.short_options = {}, {}
    for _, spec in ipairs(self.spec.options) do
	if spec.long then self.long_options[spec.long] = spec end
	if spec.short then self.short_options[spec.short] = spec end
    end
    local success
    local args, i = {}, 0
    while argtable[i] do args[i] = argtable[i] i = i - 1 end
    success, args = pcall(self.parse_next, self, args, table.unpack(argtable))
    if error_level then
        if success then return args, true end
	error(("%s\n%s"):format(args, self:usage()), error_level)
    else
	return args, success
    end
end

---@param argspec argspec
---@return argument_parser
local function create_argument_parser(argspec)
    local parser = { spec = argspec }
    for k, f in pairs(argument_parser) do parser[k] = f end
    return parser
end

return { argument_parser = create_argument_parser }
