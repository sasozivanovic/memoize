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

--Search for the libraries within the tex tree (see LuaTeX manual 10.7.1).
kpse.set_program_name("luatex")
--todo: if program name is not yet set

require 'lualibs-io'   --extends global io
require 'lualibs-lpeg' --extends global lpeg, required by lualibs-file
require 'lualibs-file' --defines global file
require 'lualibs-dir'  --defines global dir

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

local script_name = file.basename(arg[0])

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
            logging:error(errmsg_formatstring, ...)
        end
    end

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
    local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C
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
    local nosep = 1 - sep
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

-- check_in/out_name should work exactly as kpse_in/out_name_ok. In particular,
-- as of TeX Live 2026, kpse_in_name_ok always returns true, see texmf.cnf and
-- https://tug.org/pipermail/tex-live/2025-December/051965.html.

---@param fn string
local function check_in_name(fn)
    if not kpse.in_name_ok_silent_extended(fn) then
        error(("I'm not allowed to read from '%s' (openin_any = {%s})")
            :format(fn, kpse.var_value('openin_any')), 0)
    end
end

---@param fn string
local function check_out_name(fn)
    if not kpse.out_name_ok_silent_extended(fn) then
        error(("I'm not allowed to write to '%s' (openout_any = {%s})")
            :format(fn, kpse.var_value('openout_any')), 0)
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
local function check_access_in(fn)
    assert(io.exists(fn), ("File '%s' does not exist"):format(fn))
    assert(os_access(fn, 'r'), ("File '%s' is not readable"):format(fn))
end

--This function can fail on Windows, reporting a non-writable file or dir as
--writable, because |os.access| does not work with Windows' |icacls|
--permissions.  Consequence: we might try to write to a read-only current or
--output directory instead of switching to the temporary directory.

---@param fn string
local function check_access_out(fn)
    if io.exists(fn) then
        --An existing file should be writable, and if it's a directory, it
        --should also be executable.
        assert(os_access(fn, 'w'),
            ("File '%s' is not writable"):format(fn))
        assert(not pathlib.is_dir(fn) or os_access(fn, 'x'),
            ("Directory '%s' is not executable"):format(fn))
    else
        --For a non-existing file, the parent directory should be writable.
        --(This is the only place where function |pathlib.parent| is used,
        --so it's ok that it returns the logical parent.)
        local dn = pathlib.parent(fn)
        assert(os_access(dn, 'w'),
            ("Cannot create '%s' in a non-writable directory '%s'"):format(fn, dn))
    end
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
        and d
end

local texmf_output_directory, texmfoutput

--First, get the values of |TEXMFOUTPUT| and |TEXMF_OUTPUT_DIRECTORY|.

--This function finds the location for an input file, respecting
--|TEXMF_OUTPUT_DIRECTORY| and |TEXMFOUTPUT|, and the permissions in the
--filesystem.  It returns an absolute file as-is.  For a relative file, it
--tries |TEXMF_OUTPUT_DIRECTORY| (if defined), the current directory
--(always), and |TEXMFOUTPUT| directory (if defined), in this order.  The
--first readable file found is returned; if no readable file is found, the
--file in the current directory is returned.

local function init_find()
    texmf_output_directory
        = sanitize_output_dir(kpse.var_value("TEXMF_OUTPUT_DIRECTORY"))
    texmfoutput
        = sanitize_output_dir(kpse.var_value("TEXMFOUTPUT"))
end
---@param fn string
---@return string
local function find_in(fn)
    print(texmf_output_directory, texmfoutput)
    sanitize_filename(path)
    if pathlib.is_absolute(fn) then return fn end
    for _, df in pairs(
        {
            texmf_output_directory and file.join(texmf_output_directory, fn),
            fn,
            texmfoutput and file.join(texmfoutput, fn),
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
local function find_out(fn)
    sanitize_filename(path)
    if pathlib.is_absolute(fn) then return fn end
    for _, df in pairs(
        {
            texmf_output_directory and file.join(texmf_output_directory, fn),
                not texmf_output_directory and fn,
            texmfoutput and file.join(texmfoutput, fn),
        }
    ) do
        if df and pcall(check_access_out, df) then return df end
    end
    return texmf_output_directory and file.join(texmf_output_directory, fn) or fn
end

--A paranoid |dir.makedirs|.  The given folder is preprocessed by |find_out|.

---@param folder string
local function mkdir(folder)
    folder = find_out(folder)
    check_out_name(folder)
    -- We don't call "check_access_out(folder)" because it would fail if
    -- multiple subdirectories need to be created.
    if not io.exists(folder) then
        dir.makedirs(folder)
        logging:info("Created directory %s", folder)
    end
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

---@class extraction_parameters
---@field quiet boolean?
---@field prune boolean?
---@field format 'latex'|'plain'|'context'?
---@field force boolean?
---@field mkdir boolean?
---@field pdf string

---@param args string[] | extraction_parameters
local function main(args)
    -- Convert command line arguments to extraction_parameters if necessary.
    if not args.pdf then
        local argparse = require 'argparse'
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
                        args = parser:parse(args)
    end

    -- \paragraph{Initialization}

    init_find()
    
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
    if args.format then
        table.insert(logging.headers, script_name)
        local log_fn = find_out(file.replacesuffix(args.pdf, "mmz.log"))
        check_out_name(log_fn)
        logging:info("Logging to '%s'", log_fn)
        logging:open(log_fn)
    end

    --Find the PDF file and check whether (a) we may read from it, and (b) we
    --may write to it, if --prune was given.
    local pdf_fn
    try(
        function()
            --todo: "find_in" below should actually search the same directories
            --as "find_out", but of course check for an existing and
            --(in_accessible) files, because the file we want to open (even if
            --for reading) is a file which was just produced by TeX.
            pdf_fn = find_in(args.pdf)
            check_in_name(pdf_fn)
            check_access_in(pdf_fn)
        end,
        function()
            logging:info(
                "Cannot open file '%s', assuming there's nothing to do",
                args.pdf
            )
            exit.succ()
        end
    )
    if args.prune then
        try(function()
                check_out_name(pdf_fn)
                check_access_out(pdf_fn)
        end, function(errmsg)
                logging:error(
                    "Cannot open '%s' for writing. \z
                        (I would have to write to this file because \z
                        option --prune/-p was given.)\t%s",
                        pdf_fn, errmsg)
        end
        )
    end

    --Open the PDF.
    local doc, catalog = try(
        function()
            local doc = pdfrw.open(pdf_fn)
            local catalog = doc.trailer.Root()
            return doc, catalog
        end,
        function(errmsg)
            logging:error(
                "PDF file '%s' seems corrupted.\tThe underlying error was: %s.\n\z
                    Perhaps you have to load Memoize earlier in the preamble. \z
                    In particular, Memoize must be loaded before TikZ library 'fadings' \z
                    and any package deploying it, and in Beamer, load Memoize by writing \z
                    \\RequirePackage{memoize} before \\documentclass{beamer}.",
                    pdf_fn, errmsg
            )
        end
    )
    
    local mmiz_record = try(
        function()
            return catalog.MMIZ_Record().Kids()
        end,
        function(errmsg)
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
    logging:info("Extracting new externs from '%s'", pdf_fn)
    local done_message = 'Done (there was nothing to extract)'

    logging.indent = '  '
    logging.texindent = '\\space\\space '

    for item_n, item in pairs(mmiz_record) do

        local err_prefix = ('/MMIZ_Record/Kids[%d]: '):format(item_n)
        logging:assert(item.Type, "%sUndefined item type", err_prefix)
        logging:assert(MMIZ_Record_Types[item.Type],
            "%sUnknown record type %s", err_prefix, item.Type)
        err_prefix = ('/MMIZ_Record/Kids[%d] of type %s: '):format(item_n, item.Type)
        logging:assert(item.Filename, "Missing /Filename key")

        if item.Type == "/Prefix" then
            current_prefix = unquote(item.Filename)
            local dir_prefix = current_prefix:sub(-1) == '/'
                and current_prefix or pathlib.parent(current_prefix)
            mkdir(dir_prefix)

        elseif item.Type == "/NewExtern" then
            done_message = 'Done'
            
            local extern_path = unquote(item.Filename)
            
            local page_ref = logging:assert(item.Page, "Missing /Page key")
            local page = logging:assert(page_ref(), "Invalid page reference")
            local page_number = pages[page]
            if page_number then
                err_prefix = ("Page %s: "):format(page_number)
            end

            local dir_prefix, name_prefix, code_md5sum, context_md5sum = try(
                function() return split_extern_path(extern_path) end,
                function() logging:error("Illicit extern filename '%s'", extern_path) end
            )

            logging:assert(
                current_prefix,
                "No /Prefix item was encountered before this record item.",
                extern_path
            )

            logging:assert(file.join(dir_prefix, name_prefix) == current_prefix,
                "Extern filename '%s' does not start with the expected prefix '%s'",
                extern_path, current_prefix)
            
            -- Check whether the c-memo and the cc-memo are accessible.
            for typ, memo_file in pairs(
                { c = file.join(file.dirname(extern_path),
                        name_prefix .. code_md5sum .. ".memo"),
                    cc = file.join(file.dirname(extern_path),
                        name_prefix .. code_md5sum
                        .. "-" .. context_md5sum .. ".memo") }) do
                if try(
                    function()
                        check_in_name(memo_file)
                        check_access_in(memo_file)
                    end,
                    function(errmsg)
                        if args.force then
                            logging:warn(
                                "The associated %s-memo '%s' is not accessible: %s",
                                typ, extern_path, errmsg
                            )
                        else      
                            logging:warn(
                                "I refuse to extract this page into extern '%s', \z
                                    because the associated %s-memo is not accessible: %s",
                                    typ, extern_path, errmsg
                            )
                            return true
                        end
                    end
                ) then
                    goto next_item
                end
            end

            local extern_file_out = find_out(extern_path)
            check_out_name(extern_file_out)
            
            try(
                function()
                    local extern = pdfrw.new()
                    extern:insert_page(page)
                    extern:save(extern_file_out)
                    logging:info("Page %s --> '%s'", page_number, extern_path)
                end,
                function(errmsg)
                    logging:warn(
                        "I failed to extract this page into '%s'\t%s",
                        extern_path, errmsg
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
                            'I failed to remove this page\t%s',
                            errmsg
                        )
                    end
                )
            end
            
        end --/NewExtern
        ::next_item::
    end -- end for loop

    logging.indent = ''
    logging.texindent = ''

    logging:info(done_message)
    if args.prune then
        doc:update()
        logging:info("The extracted extern pages were removed from the PDF")
    end

    logging:close()
    exit.succ()

end

if debug.getinfo(2) then
    return { main = main }
else
    main(arg)
end

-- Local Variables:
-- lua-indent-level: 4
-- tab-width: 4
-- End:
