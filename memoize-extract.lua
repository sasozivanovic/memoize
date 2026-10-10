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

local VERSION = '2026/XX/YY v1.5.0'

-- luacheck: std lua53+texlua+lualibs

if not debug.getinfo(2) then --executed as a script
    --Search for the libraries within the tex tree (see LuaTeX manual 10.7.1).
    kpse.set_program_name("luatex")
    require 'lualibs-io'   --extends global io
    require 'lualibs-lpeg' --extends global lpeg, required by lualibs-file
    require 'lualibs-file' --defines global file
    require 'lualibs-dir'  --defines global dir
end

-- Load "our own" PDF writer.
local pdfrw = require 'luapdfrw'

local function try(f, error_handler)
    local function wrapper(success, ...)
        if success then
            -- ... = the return value
            return ...
        else
            -- ... = error message
            return error_handler(...)
        end
    end
    return wrapper(pcall(f))
end

---Remove pairs of quotes from the filename, which might contain a quoted jobname.

---@param fn string
---@return string
local function unquote(fn)
    if fn:sub(1,4) == '\\057' then --todo: fix pdfrw
        fn = '/' .. fn:sub(5)
    end
    return (fn:gsub("\"(.-)\"", "%1"))
end

-- \paragraph{Additions to lualibs-file and lualibs-dir}

local pathlib = {}

---@param path string
---@return boolean
function pathlib.is_dir(path)
    return lfs.attributes(path, 'mode') == 'directory'
end

do
    local absolute, semi_absolute, root, sep
    local P, S, R = lpeg.P, lpeg.S, lpeg.R
    if os.type == 'windows' then
        local drive = R("az","AZ") * P(":")
        sep = S("/\\")
        absolute = drive * sep
        semi_absolute = drive * -sep + sep
        root = false
    else
        sep = P'/'
        absolute = sep
        semi_absolute = false
        root = sep^1 * -1
    end
    function pathlib.is_absolute(path)
        return lpeg.match(absolute, path)
    end
    function pathlib.is_semi_absolute(path)
        return lpeg.match(semi_absolute, path)
    end
    function pathlib.is_root(path)
        return lpeg.match(root, path)
    end
    function pathlib.parent(fn)
        local i = fn:len()
        while i > 0 and lpeg.match(sep, fn, i) do
            i = i - 1
        end
        local dn = file.dirname(fn:sub(1,i))
        return dn == '' and '.' or dn
    end
end


-- \paragraph{Permission-related functions}

local function io_exists(fn)
    return (lfs.attributes(fn, "mode"))
end

-- On Windows, we disallow ``semi-absolute'' paths, i.e.\ paths starting with
-- the |\| but lacking the drive, or the reverse.

local function sanitize_filename(path)
    if path and pathlib.is_semi_absolute(path) then
        error(("\"Semi-absolute\" paths are disallowed: '%s'\t\z
            The path must either contain both the drive letter and \z
            start with '\\', or none of these; paths like \z
            'C:foo' and '\\foo' are disallowed"):format(path), 0)
    end
    return path
end

-- An output directory should exist, and may not point to the root on Linux
-- (Karl Berry, p.c.). On Windows, it may point to the root of a drive,
-- because we only allow absolute filenames containing the drive, e.g.\
-- |F:\|; see |sanitize_filename|.

---@param f function
---@param var string
---@return string?
local function sanitize_output_dir(d)
    return d
        and sanitize_filename(d)
        and pathlib.is_dir(d)
        and not pathlib.is_root(d)
        and d or nil
end

local wanna_read_pattern = lpeg.P{lpeg.S"r+" + 1 * lpeg.V(1)}
local wanna_write_pattern = lpeg.P{lpeg.S"wa+" + 1 * lpeg.V(1)}

--If the filename fn is absolute, check whether it is allowed and open it if it
--is.  If fn is relative, first try to open it under TEXMF_OUTPUT_DIRECTORY (if
--it is set) or under the current directory (if TEXMF_OUTPUT_DIRECTORY is not
--set). If this fails, try to open it under TEXMFOUTPUT.
local function find_and_open(fn, in_out, mode)

    sanitize_filename(fn)
    
    assert(in_out == "in" or in_out == 'out')
    assert(type(mode) == "string")
    local wanna_read = lpeg.match(wanna_read_pattern, mode)
    local wanna_write = lpeg.match(wanna_write_pattern, mode)
    assert(wanna_read or wanna_write)
    assert(not (wanna_write and in_out == 'in'))

    local function check_name(path)
        return
            (not wanna_read or kpse.in_name_ok_silent_extended(path))
            and
            (not wanna_write or kpse.out_name_ok_silent_extended(path))
    end
    
    local path, fh
    
    if pathlib.is_absolute(fn) then
        path = fn
        if check_name(path) then
            fh = io.open(path, mode)
        end
    else
        --try TEXMF_OUTPUT_DIRECTORY
        local texmf_output_directory = sanitize_output_dir(
            kpse.var_value("TEXMF_OUTPUT_DIRECTORY"))
        if texmf_output_directory then
            path = file.join(texmf_output_directory, fn)
            if check_name(path) then
                fh = io.open(path, mode)
            end
        end
        --try the current directory
        if not fh and (in_out == 'in' or not texmf_output_directory) then
            path = fn
            if check_name(path) then
                fh = io.open(path, mode)
            end
        end
        --try TEXMFOUTPUT
        if not fh then
            local texmfoutput = sanitize_output_dir(
                kpse.var_value("TEXMFOUTPUT"))
            if texmfoutput then
                path = file.join(texmfoutput, fn)
                if check_name(path) then
                    fh = io.open(path, mode)
                end
            end
        end
    end
    if fh then
        return fh, path
    end
end

local function find_and_open_in(fn, mode)
    return find_and_open(fn, 'in', mode)
end

local function find_and_open_out(fn, mode)
    return find_and_open(fn, 'out', mode)
end

--This function finds the location for an input file, respecting
--|TEXMF_OUTPUT_DIRECTORY| and |TEXMFOUTPUT|, and the permissions in the
--filesystem.  It returns an absolute file as-is.  For a relative file, it
--tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current directory
--(always), and |TEXMFOUTPUT| directory (if defined), in this order.  The
--first readable file found is returned; if no readable file is found, the
--file in the current directory is returned.

local function find_in(fn, mode)
    local fh, path = find_and_open(fn, 'in', mode)
    if fh then
        fh:close()
        return path
    end
end

--This function finds the location for an output file, respecting
--|TEXMF_OUTPUT_DIRECTORY| and |TEXMFOUTPUT|, and the permissions in the
--filesystem.  It returns an absolute file as-is.  For a relative file, it
--tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current directory
--(unless |TEXMF_OUTPUT_DIRECTORY| is defined), and |TEXMFOUTPUT| directory
--(if defined), in this order.  The first writable file found is returned;
--if no writable file is found, the file in either the current or the
--output directory is returned.

local function find_out(fn, mode)
    local fh, path = find_and_open(fn, 'out', mode)
    if fh then
        fh:close()
        return path
    end
end

--A paranoid |dir.makedirs|.

---@param folder string
local function mkdir(folder)
    if folder == '.' then
        return true
    end
    local texmf_output_directory = sanitize_output_dir(
        kpse.var_value("TEXMF_OUTPUT_DIRECTORY"))
    local path = texmf_output_directory
        and file.join(texmf_output_directory, folder)
        or folder
    if lfs.attributes(path, "mode") == 'directory' then
        return true
    end
    local _path, success
    if kpse.out_name_ok_silent_extended(path) then
        _path, success = dir.makedirs(path)
    end
    if not success then
        local texmfoutput = sanitize_output_dir(
            kpse.var_value("TEXMFOUTPUT"))
        if texmfoutput then
            path = file.join(texmfoutput, folder)
            if lfs.attributes(path, "mode") == 'directory' then
                return true
            end
            if kpse.out_name_ok_silent_extended(path) then
                _path, success = dir.makedirs(path)
            end
        end
    end
    return success, path
end




--\paragraph{Messages}

--The messages are written both to the extraction log and the terminal (we
--output to stdout rather than stderr so that messages on the TeX terminal and
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
    file = nil,
    headers = {},
    footer = '',
    indent = "",
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
                :format(self:_header(), short, long) end,
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
                :format(self:_header(), self.indent, text)          end,
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
                :format(self:_header(), self.indent, text)          end,
    }

    function logging:_header()
        local result = ''
        for _, header in ipairs(self.headers) do
            result = result .. header .. ': '
        end
        return result
    end

    ---@param fn string
    function logging:open(fn)
        local path
        self.fh, path = find_and_open_out(fn, "w")
        return path
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
    function logging:error(formatstring, ...)
        local text = formatstring:format(...)
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
    function logging:warn(formatstring, ...)
        local text = formatstring:format(...)
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
    function logging:info(formatstring, ...)
        local text = formatstring:format(...)
        if not self.quiet then
            print(INFO.None(self, text))
        end
        if self.fh then
            self.fh:write(INFO[self.format](self, text:gsub("\\", "\\string\\")), "\n")
        end
    end

    function logging:assert(v, errmsg_formatstring, ...)
        if v then
            return v
        else
            self:error(errmsg_formatstring, ...)
        end
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

local MMIZ_Record_Types = {
    ['/NewExtern'] = true,
    ['/Prefix'] = true,
    ['/NewCMemo'] = true,
    ['/NewCCMemo'] = true,
    ['/UsedExtern'] = true,
    ['/UsedCMemo'] = true,
    ['/UsedCCMemo'] = true,
}

local function parse_args(args)
    local argparse = require 'argparse'
    local script_name = file.basename(arg[0])    
    local parser = argparse()
        :name(script_name)
        :description "Extract extern pages produced by package Memoize \z
            out of the document PDF."
                :epilog "For details, see the man page or the Memoize documentation."
            parser:flag "--version -V"
                :description "show program's version number and exit"
                :action(function()
                        print(script_name .. " of Memoize " .. VERSION)
                        exit.succ()
                       end)
            parser:argument "pdf"
                :description "the PDF file (doc.pdf when compiling doc.tex)"
            parser:flag "--quiet -q"
                :description "don't describe what's happening"
            parser:flag "--prune -p"
                :description "remove the extern pages after extraction"
            parser:option "--format -F"
                :description "the format of the TeX document invoking extraction"
                :choices {"latex", "plain", "context"}
            parser:flag "--force -f"
                :description "ignore warnings and extract problematic pages"
            parser:flag "--mkdir -m"
                :description "create the directory and exit\n\z
                    (the positional argument pdf is interpreted as directory name)"
                    
                    local parsed_args = parser:parse(args)
                    parsed_args.script_name = script_name
                    return parsed_args
end

---@class extraction_parameters
---@field quiet boolean?
---@field prune boolean?
---@field format 'latex'|'plain'|'context'?
---@field force boolean?
---@field mkdir boolean?
---@field pdf string

---@param args extraction_parameters
local function extract(args)
    -- \paragraph{Initialization}

    -- With |--mkdir|, argument |pdf| is interpreted as the directory to create.
    if args.mkdir then
        local success, path = mkdir(args.pdf)
        if success then
            if path then
                logging:info("Created directory '%s'", path)
            end
            exit.succ()
        else
            logging:error("Cannot create directory '%s'", args.pdf)
        end
    end

    -- Open the log.
    logging.package_name = 'memoize (lua-based extraction)'
    logging.quiet = args.quiet
    logging.format = args.format
    if args.format then
        if args.script_name then
            table.insert(logging.headers, args.script_name)
        end
        local log_fn = file.replacesuffix(args.pdf, "mmz.log")
        logging:info("Logging to '%s'", log_fn)
        local log_path = logging:open(log_fn)
        if not log_path then
            logging:info("Cannot open log file '%s'", log_fn)
        end
    end

    --Find the PDF file and check whether (a) we may read from it, and (b) we
    --may write to it, if --prune was given.
    local pdf_path = find_out(args.pdf, 'r')
    if not pdf_path then
        logging:info(
            "Cannot open file '%s', assuming there's nothing to do",
            args.pdf
        )
        exit.succ()
    end
    if args.prune then
        local fh
        if kpse.out_name_ok_silent_extended(pdf_path) then
            fh = io.open(pdf_path, 'r+')
        end
        if fh then
            fh:close()
        else
            logging:error(
                "Cannot open '%s' for writing.\tI would have to write to this \z
                    file because option --prune/-p was given",
                    pdf_path)
        end
    end
    
    --Open the PDF.
    local doc, catalog = try(
        function()
            local doc = pdfrw.open(pdf_path)
            local catalog = doc.trailer.Root()
            return doc, catalog
        end,
        function(errmsg)
            logging:error(
                "PDF file '%s' seems corrupted\tThe underlying error was: %s. \z
                    Perhaps you have to load Memoize earlier in the preamble. \z
                    In particular, Memoize must be loaded before TikZ library 'fadings' \z
                    and any package deploying it, and in Beamer, load Memoize by writing \z
                    \\RequirePackage{memoize} before \\documentclass{beamer}.",
                    pdf_path, errmsg
            )
        end
    )

    local mmiz_record = try(
        function()
            return catalog.MMIZ_Record().Kids()
        end,
        function()
            logging:info("File '%s' does not contain a Memoize record, \z
                assuming there's nothing to do",
                args.pdf)
            exit.succ()
        end
    )

    local pages = doc:get_pages()
    for i, page in ipairs(pages) do
        pages[page] = i
    end

    local current_prefix
    logging:info("Extracting new externs from '%s'", pdf_path)
    local done_message = 'Done (there was nothing to extract)'

    logging.indent = '  '
    logging.texindent = '\\space\\space '

    for item_n, item in pairs(mmiz_record) do

        local item_desc = ('/MMIZ_Record/Kids[%d]'):format(item_n)
        logging:assert(item.Type, "%s: Undefined item type", item_desc)
        logging:assert(MMIZ_Record_Types[item.Type],
            "%s: Unknown record type %s", item_desc, item.Type)
        logging:assert(item.Filename, "%s: Missing /Filename key", item_desc)

        if item.Type == "/Prefix" then
            current_prefix = unquote(item.Filename)
            local dir_prefix = current_prefix:sub(-1) == '/'
                and current_prefix or pathlib.parent(current_prefix)
            mkdir(dir_prefix)

        elseif item.Type == "/NewExtern" then
            done_message = 'Done'

            local extern_path = unquote(item.Filename)

            local page_ref = logging:assert(item.Page, "%s: Missing /Page key", item_desc)
            local page = logging:assert(page_ref(), "%s: Invalid page reference", item_desc)
            local page_desc = pages[page] or page_ref

            local dir_prefix, name_prefix, code_md5sum, context_md5sum = try(
                function() return split_extern_path(extern_path) end,
                function() logging:error("Illicit extern filename '%s'", extern_path) end
            )

            logging:assert(current_prefix,
                "%s: No /Prefix item was encountered before this record item", item_desc)

            logging:assert(file.join(dir_prefix, name_prefix) == current_prefix,
                "%s: Extern filename '%s' does not start with the expected prefix '%s'",
                item_desc, extern_path, current_prefix)

            -- Check whether the c-memo and the cc-memo are accessible.
            local forced = ''
            for typ, memo_file in pairs({
                    c = name_prefix .. code_md5sum .. ".memo",
                    cc = name_prefix .. code_md5sum .. "-" .. context_md5sum .. ".memo"
            }) do
                if not find_in(file.join(file.dirname(extern_path), memo_file), 'r') then
                    if args.force then
                        forced = ' (forced)'
                    else
                        logging:warn(
                            "Page %s will not be extracted \z
                                because the associated %s-memo '%s' is not accessible",
                                page_desc, typ, memo_file
                        )
                        goto next_item
                    end
                end
            end

            local extern_file_out = find_out(extern_path, 'w')

            try(
                function()
                    local extern = pdfrw.new()
                    extern:insert_page(page)
                    extern:save(extern_file_out)
                    logging:info("Page %s --> '%s'%s", page_desc, extern_file_out, forced)
                end,
                function()
                    logging:warn(
                        "Page %s could not be extracted into '%s'",
                        page_desc, extern_file_out
                    )
                end
            )

            if args.prune then
                try(
                    function()
                        doc.remove_page(doc, page)
                    end,
                    function(errmsg)
                        logging:error(
                            'Pruning failed to remove page %s\t%s',
                            page_desc, errmsg
                        )
                    end
                )
            end

        end --/NewExtern
        ::next_item::
    end -- end for loop

    logging.indent = ''
    logging.texindent = ''

    if args.prune then
        doc:update()
        logging:info("The extracted extern pages were removed from the PDF")
    end
    logging:info(done_message)

    logging:close()
    exit.succ()

end

local function main(args)
    extract(parse_args(args))
end

if debug.getinfo(2) then --required as a module
    return { main = main, extract = extract }
else --executed as a script
    main(arg)
end

-- Local Variables:
-- lua-indent-level: 4
-- tab-width: 4
-- End:
