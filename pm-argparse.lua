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

]]--

local function usage(argspec)
    local usages = {}
    for _, spec in pairs(argspec.options) do
	table.insert(usages, ("[-%s%s]"):format
		     (spec.short, spec.arg_desc and ' ' .. spec.arg_desc or ''))
    end
    return ("Usage: %s %s %s")
	:format(argspec.prog, table.concat(usages, ' '), argspec.positional.arg_desc)
end

local function help(argspec, help_column)
    help_column = help_column or 24
    to_help_column = '\n' .. (' '):rep(help_column)
    local missing_short_space = ''
    for _, spec in pairs(argspec.options) do
	if spec.short then missing_short_space = '   ' break end
    end
    local usages = {}
    for _, spec in pairs(argspec.options) do
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
	:format(usage(argspec),
		argspec.header and ('\n' .. argspec.header .. '\n') or '',
		table.concat(usages, '\n'),
		argspec.footer and ('\n\n' .. argspec.footer) or '')
end

local function parse_next(argspec, args, a, ...)
    if not a then
	argspec.positional.f(args)
	return args
    elseif a == '--' then
	local rest = table.unpack(...)
	return table.move(rest, 1, #rest, #args+1, args)
    elseif a:sub(1,2) == '--' then
	local opt_spec = argspec.long_options[a:sub(3)]
	assert(opt_spec, ("Unknown option '%s'."):format(a))
	return parse_next(argspec, args, opt_spec.f(args, ...))
    elseif a:sub(1,1) == '-' then
	local opt_spec = argspec.short_options[a:sub(2,2)]
	assert(opt_spec, ("Unknown option '-%s'."):format(a:sub(2,2)))
	if a:len() > 2 then
	    a = a:sub(3)
	    a = opt_spec.arg_desc and a or '-' .. a
	    return parse_next(argspec, args, opt_spec.f(args, a, ...))
	else
	    return parse_next(argspec, args, opt_spec.f(args, ...))
	end
    else
	table.insert(args, a)
	return parse_next(argspec, args, ...)
    end
end

function parse_args(argspec, argtable, error_level)
    argspec.prog = argspec.prog or file.basename(arg[0])
    argspec.long_options, argspec.short_options = {}, {}
    for _, spec in ipairs(argspec.options) do
	if spec.long then argspec.long_options[spec.long] = spec end
	if spec.short then argspec.short_options[spec.short] = spec end
    end
    local args, i = {}, 0
    while argtable[i] do args[i] = argtable[i] i = i - 1 end
    success, args = pcall(parse_next, argspec, args, table.unpack(argtable))
    if error_level then
	if success then return args end
	error(("%s\n%s"):format(args, usage(argspec)), error_level)
    else
	return success, args
    end
end

local function argument_parser(argspec)
    argspec.parse_args = function(...) return parse_args(argspec, ...) end
    argspec.usage = function() return usage(argspec) end
    argspec.help = function() return help(argspec) end
    return argspec
end

return { argument_parser = argument_parser }
