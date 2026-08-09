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

local lfs = require 'lfs'

local lester   = require "lester"
local describe = lester.describe
local before   = lester.before
local after    = lester.after
local it       = lester.it
local expect   = lester.expect

local extract --receives all locals from module memoize-extract
do
  function debug_get_locals(f)
    locals = {}
    local i = 1
    repeat
      var, val = debug.getlocal(f, i)
      if var and var:sub(1,1) ~= '(' then
	locals[var] = val
      end
      i = i + 1
    until not var
    return locals
  end

  function hook(_event)
    if debug.getinfo(2).what == 'main' then
      extract = debug_get_locals(3)
    end
  end

  debug.sethook(hook, 'r')
  require "memoize-extract"
  debug.sethook(nil, 'r')

  extract.exit.error = function() error("exited with error") end
  extract.exit.warn  = function() error("exited with warn") end
  extract.exit.succ  = function() error("exited with succ") end
end

describe(
  "memoize-extract.lua",
  function()
    before(function() end)
    after(function() end)

    describe(
      "split_extern_path",
      function()
	it("should parse a valid path with all parts", function()
	     local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-42.pdf"
	     local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path)

	     expect.equal(dir_prefix, "/dir/prefix/")
	     expect.equal(name_prefix, "file")
	     expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
	     expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
	end)

	it("should parse a valid path with no dir_prefix", function()
	     local path = "file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
	     local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path)
	     
	     expect.equal(dir_prefix, "")
	     expect.equal(name_prefix, "file")
	     expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
	     expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
	end)

	it("should parse a valid path with a numeric suffix", function()
	     local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-99.pdf"
	     local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path)

	     expect.equal(dir_prefix, "/dir/prefix/")
	     expect.equal(name_prefix, "file")
	     expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
	     expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
	end)

	-- Test invalid paths
	it("should fail for invalid paths", function()
	     local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-invalid.pdf"
	     expect.fail(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path) end)
	end)

	it("should fail for paths with missing code_md5sum", function()
	     local path = "/dir/prefix/file-no-md5sum-1234567890abcdef1234567890abcdef.pdf"
	     expect.fail(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path) end)
	end)

	-- Test paths without suffix and multiple hyphens
	it("should parse a valid path without a suffix", function()
	     local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
	     local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path)

	     expect.equal(dir_prefix, "/dir/prefix/")
	     expect.equal(name_prefix, "file")
	     expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
	     expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
	end)

	-- Test paths with no context_md5sum
	it("should fail for paths missing context_md5sum", function()
	     local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-.pdf"
	     expect.fail(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path) end)
	end)

	-- Test edge cases
	it("should fail for an empty path", function()
	     local path = ""
	     expect.fail(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path) end)
	end)

	it("should return nil for path with only one part", function()
	     local path = "1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
	     local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.split_extern_path(path)

	     expect.equal(dir_prefix, "")
	     expect.equal(name_prefix, "")
	     expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
	     expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
	end)
    end)

    describe(
      "parse_args",
      function()

	local parser = extract.argparse.argument_parser(extract.memoize_extract_argspec)
	extract.parse_args = function(args) return parser:parse_args(args) end

	it("should parse valid arguments", function()
	     local args = extract.parse_args({"-F", "latex", "pdf"})
	     expect.equal(args, { format = "latex", pdf    = "pdf",})
	end)

	it("should raise an error for invalid format", function()
	     expect.fail(function()
		 extract.parse_args({"-F", "invalidformat", "pdf"},0)
	     end)
	end)

	it("should handle multiple flags correctly", function()
	     local args = extract.parse_args({"-p", "-k", "-q", "pdf"}, defaults)
	     expect.equal(args, {
			    quiet = true,
			    prune = true,
			    keep  = true,
			    pdf   = "pdf",
	     })
	end)

	it("should handle long argument names correctly", function()
	     local args = extract.parse_args({"--prune", "--quiet", "pdf"}, defaults)
	     expect.equal(args, {
			    quiet = true,
			    prune = true,
			    pdf   = "pdf",
	     })
	end)

	it("should assign the last argument to pdf", function()
	     local args = extract.parse_args({"-F", "latex", "final.pdf"}, defaults)
	     expect.equal(args, {
			    format = "latex",
			    pdf = "final.pdf",
	     })
	end)

	it("should fail if no pdf is given", function()
	     expect.fail(function()
		 extract.parse_args({"-F", "latex", "-p"}, defaults)
	     end)
	end)

	-- -h and -V are difficult to test because they use upvalue parser
	--it("should exit successfully and print help for '-h'", function()
	--     expect.fail(function()
	--	 extract.parse_args({"-h"})
	--     end, "exited with succ")
	--end)
	--
	--it("should exit successfully and print version for '-V'", function()
	--     local defaults = {}
	--
	--     expect.fail(function()
	--	 extract.parse_args({"-V"})
	--     end, "exited with succ")
	--end)

	it("should handle no flags and return defaults", function()
	     local args = extract.parse_args({"pdf"})
	     expect.equal(args, {
			    pdf   = "pdf",
	     })
	end)

	it("should fail with no arguments", function()
	     expect.fail(function()extract.parse_args({})end)
	end)

	it("should raise an error for an unrecognized argument", function()
	     expect.fail(function()extract.parse_args({"-z", "pdf"})end)
	end)

	it("nothing flag-like is allowed for the positional", function()
	     expect.fail(function()extract.parse_args({"-F", "latex", "--pdf"})end)
	end)

	it("uses -- as separator for the positionals", function()
	     local args = extract.parse_args({"-F", "latex", "--", "--pdf"})
	     expect.equal(args, {
			    format   = "latex",
			    pdf   = "--pdf",
	     })
	end)
    end)

    if false then describe(
      "normalize_pdf",
      function()
	it("should replace .tex extension with .pdf", function()
	     local input = "document.tex"
	     local expected = "document.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should add .pdf to files with no extension", function()
	     local input = "document"
	     local expected = "document.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should add .pdf to files with non-matching extensions", function()
	     local input = "document.unknown"
	     local expected = "document.unknown.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should not change files that already have a .pdf extension", function()
	     local input = "document.pdf"
	     local expected = "document.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should handle file paths with directories for .tex files", function()
	     local input = "/path/to/document.tex"
	     local expected = "/path/to/document.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should handle file paths with directories for files without extensions", function()
	     local input = "/path/to/document"
	     local expected = "/path/to/document.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should handle file paths with directories for non-matching extensions", function()
	     local input = "/path/to/document.unknown"
	     local expected = "/path/to/document.unknown.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should handle file paths with directories for .pdf files", function()
	     local input = "/path/to/document.pdf"
	     local expected = "/path/to/document.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should handle files with multiple dots correctly", function()
	     local input = "my.file.name.tex"
	     local expected = "my.file.name.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)

	it("should handle files with multiple dots and non-matching extensions", function()
	     local input = "my.file.name.unknown"
	     local expected = "my.file.name.unknown.pdf"
	     local result = extract.normalize_pdf(input)
	     expect.equal(result, expected)
	end)
    end) end

    describe(
      "pathlib library",
      function()
	describe(
	  "join",
	  function()
	    it("joins two valid paths", function()
		 local result, err = extract.pathlib.join("/media", "memoize")

		 expect.not_exist(err)
		 expect.equal(result, "/media/memoize")
	    end)

	    it("joins multiple valid paths", function()
		 local result, err = extract.pathlib.join("/media", "memoize", "testing", "assets")

		 expect.not_exist(err)
		 expect.equal(result, "/media/memoize/testing/assets")
	    end)

	    it("no duplicated pathsep", function()
		 local result, err = extract.pathlib.join("/media/", "memoize", "/testing", "assets")

		 expect.not_exist(err)
		 expect.equal(result, "/media/memoize/testing/assets")
	    end)

	    it("throws an error if no path is given", function()
		 expect.fail(function() extract.pathlib.join() end)
	    end)

	end)

    end)
end)

-- Local Variables:
-- lua-indent-level: 2
-- End:
