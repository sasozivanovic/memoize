#!/usr/bin/env texlua

-- This file is a part of Memoize, a TeX package for externalization of
-- graphics and memoization of compilation results in general, available at
-- https://ctan.org/pkg/memoize and https://github.com/sasozivanovic/memoize.
--
-- Copyright (c) 2025  Lukas ?? (atticus-sullivan @ github.com)
--               2026- Saso Zivanovic <saso.zivanovic@guest.arnes.si>
--
-- This work may be distributed and/or modified under the conditions of the
-- LaTeX Project Public License, either version 1.3c of this license or (at
-- your option) any later version.  The latest version of this license is in
-- https://www.latex-project.org/lppl.txt and version 1.3c or later is part of
-- all distributions of LaTeX version 2008 or later.
--
-- This work has the LPPL maintenance status `maintained'.
-- The Current Maintainer of this work is Saso Zivanovic.
--
-- The files belonging to this work and covered by LPPL are listed in
-- <texmf>/doc/generic/memoize/FILES.

local VERSION = '2026/10/17 v1.5.0-rc1'

-- luacheck: std lua53+texlua+lualibs

--- Initialize kpathsea and load some standard LuaTeX libraries when executed
--- as a script.
if not debug.getinfo(2) then
    kpse.set_program_name("luatex")
    require 'lualibs-io'   --extends global io
    require 'lualibs-lpeg' --extends global lpeg, required by lualibs-file
    require 'lualibs-file' --defines global file
    require 'lualibs-dir'  --defines global dir
end

--- Load ``our own'' PDF writer.
local pdfrw = require 'pdfrw'

--- \subsubsection{Utilities}

--- \function{try} Try to execute function |f|. If it succeeds,
--- return what it returned.  It if fails, execute function |error_handler|.
--- The error handler receives the error message.
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

--- \function{pathlib} This table contains additions to lualibs-file and
--- lualibs-dir.

local pathlib = {}

--- Is the given |path| a directory?
function pathlib.is_dir(path)
    return lfs.attributes(path, 'mode') == 'directory'
end

do
    local absolute, semi_absolute, root, sep, drive
    local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C
    if os.type == 'windows' then
        drive = R("az","AZ") * P(":")
        --- On Windows, we accept both |/| and |\| as path separators.
        sep = S("/\\")
        --- On Windows, an absolute path must start with the drive.
        absolute = drive * sep
        --- A ``semi-absolute'' path is a drive with a relative directory, or
        --- an absolute directory without a drive.
        semi_absolute = drive * -sep + sep
        --- There is no concept of an absolute filesystem root on Windows.
        root = P(false)
    else
        drive = P(false)
        sep = P'/'
        absolute = sep
        semi_absolute = P(false)
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
    --- Split the given string |path| into drive (complete with a colon),
    --- directory name (it will end in a separator) and filename (everything
    --- behind the final separator).  Joining these parts back (as strings)
    --- yields the original path.
    function pathlib.split(path)
        local drive_str = lpeg.match(C(drive), path) or ''
        local start = drive_str:len() + 1
        --filename is everything behind the last /
        local i = path:len()
        while i >= start and lpeg.match(nosep, path, i) do
            i = i - 1
        end
        local filename = path:sub(i+1)
        local dirname = path:sub(start,i)
        return drive_str, dirname, filename
    end
    --- Returns the |drive|+|dirname| part of the split, but with the trailing
    --- separator(s) removed.  It also replaced an empty |dirname| by a |.|
    --- (the current directory).
    function pathlib.parent(path)
        local drive_str, dirname = pathlib.split(path)
        dirname = dirname == '' and '.' or dirname
        local i = dirname:len()
        while i > 0 and lpeg.match(sep, dirname, i) do
            i = i - 1
        end
        return drive_str .. dirname:sub(1,i)
    end
end

--- \subsubsection{Permission-related functions}

--- \function{sanitize_filename} In a discussion with Karl Berry, it was
--- decided to impose some further restrictions on file and directory names.
--- On Windows, we disallow ``semi-absolute'' paths, i.e.\ paths starting with
--- the |\| but lacking the drive, or the reverse.  On Unix, we disallow the
--- root directory as |TEXMF_OUTPUT_DIRECTORY| or |TEXMFOUTPUT|.

--- This functions either returns the given |path|, or raises an error it this
--- path is illicit (semi-absolute).
local function sanitize_filename(path)
    if path and pathlib.is_semi_absolute(path) then
        error(("\"Semi-absolute\" paths are disallowed: '%s'\t\z
            The path must either contain both the drive letter and \z
            start with '\\', or none of these; paths like \z
            'C:foo' and '\\foo' are disallowed"):format(path), 0)
    end
    return path
end

--- \function{sanitize_output_dir} This function returns either the given
--- directory |d|, or |nil| if the directory does not fulfill the requirements:
--- it should not be semi-absolute, it should exist, and it should not be the
--- root.
local function sanitize_output_dir(d)
    return d
        and sanitize_filename(d)
        and pathlib.is_dir(d)
        and not pathlib.is_root(d)
        and d or nil
end

--- \function{iter_candidates} is a utility function used by |find_and_open|
--- and |mkdir|. Given filename |fn|, this function attempts to find a |path|
--- where |fn| can be found or created while respecting TeX's input/output
--- restrictions.  More precisely, it returns an iterator which produces all
--- appropriate candidates.  (Note that the iterator does not check e.g.\
--- whether files are accessible.  It merely produces the appropriate
--- candidates, as described below, and performs |kpathsea|'s |in/out_name_ok|
--- checks as well as additional |sanitize_| checks defined in this script.)
---
--- The function consideres the following candidates:
--- 
--- \begin{itemize}
--- 
--- \item If |fn| is absolute, it is the only candidate.
--- 
--- \item If |fn| is relative and |search_mode=in|, the function produces
--- candidates under |TEXMF_OUTPUT_DIRECTORY| (if defined), the current
--- directory (always), and |TEXMFOUTPUT| directory (if defined), in this
--- order.
---
--- \item If |fn| is relative and |search_mode=out|, the function produces
--- candidates under |TEXMF_OUTPUT_DIRECTORY| (if defined), the current
--- directory (unless |TEXMF_OUTPUT_DIRECTORY| is defined), and |TEXMFOUTPUT|
--- directory (if defined), in this order.
---
--- \end{itemize}
---
--- While |search_mode| determines which candidates are considered, boolean
--- |check_in| and |check_out| determine whether to check a considered
--- candidate using |in_name_ok| or |out_name_ok| (or both).  Normally (when
--- given as |nil|), |check_in| and |check_out| are determined by
--- |search_mode|: if |search_mode=in|, |check_in=true| and |check_out=false|,
--- and if |search_mode=out|, |check_in=false| and |check_out=true|.  However,
--- we allow certain mismatches, because in the script (assuming it is called
--- without |--prune|), we want to search for the input PDF only in output
--- directories (as it was just created by TeX, presumably under the same
--- settings) but we only want to open it for reading.  |check_in| and
--- |check_out| may therefore be given explicitly. Combination of
--- |search_mode=in| and |check_out=true| is disallowed, as it might result in
--- writing to a file in the current directory even when
--- |TEXMF_OUTPUT_DIRECTORY| is set.
--- 
--- Note that |check_mode=in| is vacuous since TeX Live 2026, see |texmf.cnf|
--- and \url{https://tug.org/pipermail/tex-live/2025-December/051965.html}, but
--- we retain it for backwards compatibility.

local function iter_candidates(fn, search_mode, check_in, check_out)
    assert(type(fn) == 'string')
    assert(search_mode == 'in' or search_mode == 'out')
    check_in = check_in == nil and search_mode == 'in' or check_in
    check_out = check_out == nil and search_mode == 'out' or check_out
    assert(not (search_mode == 'in' and check_out))
    local function check_name(path)
        sanitize_filename(path)
        return (not check_in or kpse.in_name_ok_silent_extended(path))
            and (not check_out or kpse.out_name_ok_silent_extended(path))
    end
    local n = 1
    if pathlib.is_absolute(fn) then
        return function()
            if n == 1 then
                n = 0
                if check_name(fn) then
                    return fn
                end
            end
        end
    else
        return function()
            if n == 1 then --try TEXMF_OUTPUT_DIRECTORY
                local texmf_output_directory = sanitize_output_dir(
                    kpse.var_value("TEXMF_OUTPUT_DIRECTORY"))
                if texmf_output_directory then
                    local path = file.join(texmf_output_directory, fn)
                    if check_name(path) then
                        n = search_mode == "in" and 2 or 3
                        return path
                    end
                else
                    n = 2
                end
            end
            if n == 2 then --try the current directory
                n = 3
                if check_name(fn) then
                    return fn
                end
            end
            if n == 3 then --try TEXMFOUTPUT
                n = 0
                local texmfoutput = sanitize_output_dir(
                    kpse.var_value("TEXMFOUTPUT"))
                if texmfoutput then
                    path = file.join(texmfoutput, fn)
                    if check_name(path) then
                        return path
                    end
                end
            end
        end
    end
end

--- \function{find_and_open} This function iterates through the candidates for
--- the |path| of filename |fn|, and attempts to open the file at each |path|
--- until successful.  Upon success, the function returns both the file handle
--- |fh| and the |path| where the file was opened; if the path cannot be found,
--- |nil| is returned.
---
--- The meaning of |search_mode| (|in| or |out|) is as for |iter_candidates|
--- above.  |open_mode| is the |io.open| mode used when attempting to open the
--- file, e.g.\ |r| or |w| (it must be given explicitly).  If a candidate can't
--- be opened, the next one is tried.
---
--- |open_mode| also determines |iter_candidates|'s |check_in/out|, so certain
--- combinations of |search_mode| and |open_mode| are disallowed: one may not
--- open the file for writing if searching for it in the input directories.

local wanna_read_pattern = lpeg.P{lpeg.S"r+" + 1 * lpeg.V(1)}
local wanna_write_pattern = lpeg.P{lpeg.S"wa+" + 1 * lpeg.V(1)}

local function find_and_open(fn, search_mode, open_mode)
    assert(search_mode == "in" or search_mode == 'out')
    assert(type(open_mode) == "string")
    --- Convert |nil| to |false|, because for |check_in/out| of
    --- |iter_candidates|, |nil| is interpreted as the |search_mode|-dependent
    --- default.
    local wanna_read = lpeg.match(wanna_read_pattern, open_mode) or false
    local wanna_write = lpeg.match(wanna_write_pattern, open_mode) or false
    assert(wanna_read or wanna_write)

    for path in iter_candidates(fn, search_mode, wanna_read, wanna_write) do
        local fh = io.open(path, open_mode)
        if fh then
            return fh, path
        end
    end
end

--- \function{find_in/out} search the directories as described in
--- |iter_candidates| to locate (but in contrast to |find_and_open|, not open)
--- a path to filename |fn| respecting TeX's input/output requirements.  They
--- return the path to the file if successful and |nil| otherwise.
---
--- Warning: as these function test (via |find_and_open|) whether the file can
--- be opened in the given |open_mode| by actually opening it (though the file
--- is then immediately closed), |find_out| may create a new (empty) file in
--- the filesystem (this will happen in modes |w|, |w+|, |a| and |a+|), or even
--- worse, destroy the file contents of an existing file (in modes |w| and
--- |w+|).  Only use these functions if you actually intend to open (and write
--- to) the returned path!

local function find_in(fn, open_mode)
    local fh, path = find_and_open(fn, 'in', open_mode)
    if fh then
        fh:close()
        return path
    end
end

local function find_out(fn, open_mode)
    local fh, path = find_and_open(fn, 'out', open_mode)
    if fh then
        fh:close()
        return path
    end
end

--- \function{mkdir} A variant of |dir.makedirs| which conforms to TeX's output
--- requirements.  Argument |folder| is transformed into an output |path| in
--- accord to TeX's output rules.  The function returns |(true, path)| if it
--- successfully created the directory, |true| if the directory already
--- existed, and |nil| if it cannot be created.

local function mkdir(folder)
    if folder == '.' then
        return true
    end
    for path in iter_candidates(folder, "out") do
        if pathlib.is_dir(path) then
            return true
        else
            local _path, success = dir.makedirs(path)
            if success then
                return success, path
            end
        end
    end
end


--- \subsubsection{Messages}

--- The messages are written both to the extraction log and the terminal (we
--- output to |stdout| rather than |stderr| so that messages on the TeX
--- terminal and document |.log| appear in chronological order).  Messages are
--- automatically adapted to the TeX |--format|.

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
    headers = {}, -- todo: back to a simple header.
    footer = '',
    indent = "",
    texindent = "",
    quiet = false,
    format = "None",
    package_name = '',
}

do

    --- The format of the messages.  It depends on the given |--format|; the
    --- last entry (|None|) is for the terminal output.

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

    --- \function{logging:open} Open the log, respecting TeX rules for opening
    --- output files.
    function logging:open(fn)
        local path
        self.fh, path = find_and_open(fn, "out", "w")
        return path
    end

    --- \function{logging:close} Closes the file after marking the log as
    --- complete.
    function logging:close()
        if self.fh then
            self.fh:write("\\endinput\n")
            self.fh:close()
            self.fh = nil
        end
    end

    --- \function{logging:error} Outputs the given error message to the log (if
    --- it is open) and to the terminal (unless |.quiet|), and exits the script
    --- with the appropriate exit code.  The message is given as a format
    --- string followed by parameters, to avoid a gazillion
    --- |("..."):format(...)|.  The message is split into the short and long
    --- error message at a tab (|\t|).
    -- todo: check error codes
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
        exit.error()
    end

    --- \function{logging:warn} Outputs the given warning message to the log
    --- (if it is open) and to the terminal (unless |.quiet|), and sets the
    --- exit code to a warning code --- but does not exit immediately.  As for
    --- error messages, the message is given as a format string followed by
    --- parameters.
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

    --- \function{logging:info} Outputs the given informational message to the
    --- log (if it is open) and to the terminal (unless |.quiet|).  As for
    --- error messages, the message is given as a format string followed by
    --- parameters.
    function logging:info(formatstring, ...)
        local text = formatstring:format(...)
        if not self.quiet then
            print(INFO.None(self, text))
        end
        if self.fh then
            self.fh:write(INFO[self.format](self, text:gsub("\\", "\\string\\")), "\n")
        end
    end

    --- \function{logging:assert} If assertion |v| fails, raise an error
    --- through the logging system.  The arguments behind |v| are the same as
    --- for |logging:error|.
    function logging:assert(v, errmsg_formatstring, ...)
        if v then
            return v
        else
            self:error(errmsg_formatstring, ...)
        end
    end

end


--- \subsubsection{Extraction}

--- \function{unquote} This utility function removes pairs of quotes from the
--- filename, which might contain a quoted jobname.
local function unquote(fn)
    if fn:sub(1,4) == '\\057' then --todo: fix pdfrw
        fn = '/' .. fn:sub(5)
    end
    return (fn:gsub("\"(.-)\"", "%1"))
end

--- \function{split_extern_path} This utility function parses an extern path
--- (from /NewExtern) into the directory prefix, filename prefix, code MD5 sum,
--- context MD5 sum, and the local sequential number of the extern.
local name_code_context_seq_pattern =
    "^(.-)(" .. ("%x"):rep(32) .. ")%-(" .. ("%x"):rep(32) .. ")(.-).pdf$"

local function split_extern_path(path)
    local drive, dir_prefix, rest = pathlib.split(path)
    dir_prefix = drive .. dir_prefix
    local name_prefix, code_md5sum, context_md5sum, seq
        = rest:match(name_code_context_seq_pattern)
    assert(seq == '' or seq:match("^%-%d+$"))
    return dir_prefix, name_prefix, code_md5sum, context_md5sum, seq
end

--- \function{MMIZ_Record_Types} A list of all PDF object types allowed within
--- |/MMIZ_Record/Kids|.
local MMIZ_Record_Types = {
    ['/NewExtern'] = true,
    ['/Prefix'] = true,
    ['/NewCMemo'] = true,
    ['/NewCCMemo'] = true,
    ['/UsedExtern'] = true,
    ['/UsedCMemo'] = true,
    ['/UsedCCMemo'] = true,
}

--- \function{parse_args} This function parses a command-line-like argument
--- table (such as the global |arg|) into a form used by function |extract|.
--- It uses module |argparse|, \url{https://github.com/mpeterv/argparse}.
local function parse_args(cmdline_args)
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
    local parsed_args = parser:parse(cmdline_args)
    parsed_args.script_name = script_name
    return parsed_args
end

--- \function{extract} This function performs the actual extraction.  |args|
--- should be a table with the fields as produced by |parse_args|.
local function extract(args)
    --- With |--mkdir|, argument |pdf| is interpreted as the directory to
    --- create.
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

    --- Open the log (if |--format| is given).
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

    --- Find the PDF file.  We only search the \emph{output} directories (thus
    --- |find_out|) because the file was presumably just produced by TeX under
    --- the same texmf configuration, but we check whether the file is
    --- \emph{readable}.  (This is an intentional difference from the Perl and
    --- Python version of the extraction script.) We don't raise an error if we
    --- cannot find the file, because we don't want to get an error in TeX
    --- every time we compile without a pre-existing PDF.
    local pdf_path = find_out(args.pdf, 'r')
    if not pdf_path then
        logging:info(
            "Cannot open file '%s', assuming there's nothing to do",
            args.pdf
        )
        exit.succ()
    end
    --- If we are asked to prune the input PDF, we also have to write to it.
    --- We first ask |kpathsea| whether the file we found conforms to TeX's
    --- output requirements, and then try to open it in read-write mode.  Note
    --- that we use |io.open| rather than |find_and_open|, because we have
    --- already found the file.
    if args.prune then
        local fh
        if kpse.out_name_ok_silent_extended(pdf_path) then
            fh = io.open(pdf_path, 'a+') -- todo: explain "a"
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

    --Ask |pdfrw| to open the PDF.  Here, we do complain if anything goes
    --wrong.
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

    --- We try to open the |/MMIZ_Record|. Not finding it is ok, because the
    --- user might have just added Memoize to the document (or similar).
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

    --- Build a table of pages.  A |/NewExtern| object contains only a
    --- reference to the page-to-be-extracted, as this suffices for extraction
    --- and is more robust than a page number (for example, it allows us to
    --- extract externs even from a pruned document).  However, info messages
    --- are prettier with page numbers than page references, and we will
    --- convert the latter into the former using the table constructed below.
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

        --- As a general policy, we complain if anything seems amiss within the
        --- |/MMIZ_Record|.  For starters, it we find a |/Kids| entry without a
        --- |/Type| or with an unknown |/Type|, or an entry without a
        --- |/Filename| key (all allowed record entries need one).
        local item_desc = ('/MMIZ_Record/Kids[%d]'):format(item_n)
        logging:assert(item.Type, "%s: Undefined item type", item_desc)
        logging:assert(MMIZ_Record_Types[item.Type],
            "%s: Unknown record type %s", item_desc, item.Type)
        logging:assert(item.Filename, "%s: Missing /Filename key", item_desc)

        --- We could have simply ignored |/Prefix| entries, but we use them for
        --- a sanity check: the prefix part of a |/Filename| of a |/NewExtern|
        --- must match the |/Filename| of the final preceding |/Prefix|.
        if item.Type == "/Prefix" then
            current_prefix = unquote(item.Filename)
            local dir_prefix = pathlib.parent(current_prefix)
            mkdir(dir_prefix)

        elseif item.Type == "/NewExtern" then
            done_message = 'Done'

            --- The given |/Filename| might contain double quotes produced by
            --- TeX.  We need to remove them.
            local extern_path = unquote(item.Filename)

            --- Having a valid page reference (|/Page|) is a must.
            local page_ref = logging:assert(item.Page, "%s: Missing /Page key", item_desc)
            local page = logging:assert(page_ref(), "%s: Invalid page reference", item_desc)
            --- If |page| is visible, we'll refer to it by its page number,
            --- otherwise by the object number.  |page_desc| is only used in
            --- messages.
            local page_desc = pages[page] or page_ref

            --- Extract the directory prefix, filename prefix, code MD5 sum and
            --- the context MD5 sum from the extern path given in |/Filename|.
            --- (We don't need the sequential number.)
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = try(
                function() return split_extern_path(extern_path) end,
                function() logging:error("Illicit extern filename '%s'", extern_path) end
            )

            --- Sanity check: does the prefix part of the extern name equal the
            --- last seen |/Prefix|?
            logging:assert(current_prefix,
                "%s: No /Prefix item was encountered before this record item", item_desc)
            logging:assert(file.join(dir_prefix, name_prefix) == current_prefix,
                "%s: Extern filename '%s' does not start with the expected prefix '%s'",
                item_desc, extern_path, current_prefix)

            -- Check whether the c-memo and the cc-memo are accessible.  Raise
            -- a warning and skip extraction if they are not, unless |--force|
            -- is in effect.  In that case, don't raise the warning, but merely
            -- note (in the info message) that the extraction was forced.
            local forced = ''
            for typ, memo_file in pairs({
                    c = name_prefix .. code_md5sum .. ".memo",
                    cc = name_prefix .. code_md5sum .. "-" .. context_md5sum .. ".memo"
            }) do
                if not find_in(file.join(pathlib.parent(extern_path), memo_file), 'r') then
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

            --- Find the output file for the extern, conforming to TeX's output
            --- requirements.
            local extern_file_out = find_out(extern_path, 'w')
            -- todo: if nil
            -- todo: mkdir

            --- Try to extract the extern.  Produce a warning if we don't
            --- succeed.
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

            --- Remove the extern page from the original PDF if |--prune| was
            --- given.  This is an in-memory operation, nothing is saved to
            --- disk until later.
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

    --- Save the pruned original document.  |:update| merely appends to the
    --- original file, producing a new version; this is why pruning with this
    --- script is practically instantaneous.  As a consequence, the extracted
    --- extern pages remain in the file, but are not visible, as they have been
    --- removed from the page tree.
    if args.prune then
        doc:update()
        logging:info("The extracted extern pages were removed from the PDF")
    end
    logging:info(done_message)

    logging:close()
    exit.succ()

end

--- \paragraph{Execute, or return the module}

--- When this file is run as a script, we execute function |main|.  When it is
--- |require|d as a module, we export functions |main| and |extract|, so that
--- the caller can provide the arguments in either command-line or parsed form.
local function main(args)
    extract(parse_args(args))
end

if debug.getinfo(2) then --required as a module
    return { main = main, extract = extract }
else --executed as a script
    main(arg)
end

--- \endinput
--- Local Variables:
--- lua-indent-level: 4
--- tab-width: 4
--- End:
