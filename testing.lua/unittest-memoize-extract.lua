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

local lester = require"lester"
local describe = lester.describe
local before   = lester.before
local after    = lester.after
local it       = lester.it
local expect   = lester.expect

STAGE = "testing"
local extract = require"memoize-extract"

describe("memoize-extract.lua", function()
	before(function() end)
	after(function() end)

	describe("parse_extern_path", function()
		it("should parse a valid path with all parts", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-42.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "/dir/prefix/")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		it("should parse a valid path with no dir_prefix", function()
			local path = "file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		it("should parse a valid path with a numeric suffix", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-99.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "/dir/prefix/")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		-- Test invalid paths
		it("should return nil for invalid paths", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-invalid.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		it("should return nil for paths with missing code_md5sum", function()
			local path = "/dir/prefix/file-no-md5sum-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		-- Test paths without suffix and multiple hyphens
		it("should parse a valid path without a suffix", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "/dir/prefix/")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		-- Test paths with no context_md5sum
		it("should return nil for paths missing context_md5sum", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		-- Test edge cases
		it("should handle an empty path", function()
			local path = ""
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		it("should return nil for path with only one part", function()
			local path = "1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)
	end)

	describe("split_prefix", function()
		it("should split a valid prefix with directory and name", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/file")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, "file")
		end)

		it("should handle a prefix with no directory", function()
			local dir_prefix, name_prefix = extract.split_prefix("file")
			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "file")
		end)

		it("should return nil for an empty string", function()
			local dir_prefix, name_prefix = extract.split_prefix("")
			expect.exist(dir_prefix)
			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "")
		end)

		it("should return a slash as dir_prefix and empty name_prefix for '/'", function()
			local dir_prefix, name_prefix = extract.split_prefix("/")
			expect.equal(dir_prefix, "/")
			expect.equal(name_prefix, "")
		end)

		it("should correctly handle input with trailing slash", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, "")
		end)

		it("should handle input with multiple slashes but no name", function()
			local dir_prefix, name_prefix = extract.split_prefix("path///")
			expect.equal(dir_prefix, "path///")
			expect.equal(name_prefix, "")
		end)

		it("should handle input with special characters", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/@#$%^&*()")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, "@#$%^&*()")
		end)

		it("should handle input with whitespace", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/ file ")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, " file ")
		end)
	end)

	describe("parse_args", function()
		it("should parse valid arguments with defaults", function()
			local defaults = {pdf = nil, format = "plain", quiet = false}
			local args, err = extract.parse_args({"-P", "output.pdf", "-F", "latex", "mmz"}, defaults)
			expect.equal(args, {
				pdf    = "output.pdf",
				format = "latex",
				quiet  = false,
				mmz    = "mmz",
			})
		end)

		it("should raise an error for missing value after '-P'", function()
			local defaults = {}

			local a, err = extract.parse_args({"-P", "mmz"}, defaults)

			expect.not_exist(a)
			expect.equal(err, "wrong number of arguments passed, exactly one positional needs to be given")
		end)

		it("should raise an error for invalid format", function()
			local defaults = {}

			local a, err = extract.parse_args({"-F", "invalidformat", "mmz"}, defaults)

			expect.not_exist(a)
			expect.equal(err, "invalid format passed")
		end)

		it("should handle multiple flags correctly", function()
			local defaults = {}
			local args = extract.parse_args({"-p", "-k", "-q", "mmz"}, defaults)
			expect.equal(args, {
				quiet = true,
				prune = true,
				keep  = true,
				mmz   = "mmz",
			})
		end)

		it("should handle long argument names correctly", function()
			local defaults = {}
			local args = extract.parse_args({"--prune", "--quiet", "mmz"}, defaults)
			expect.equal(args, {
				quiet = true,
				prune = true,
				mmz   = "mmz",
			})
		end)

		it("should assign the last argument to mmz", function()
			local defaults = {}
			local args = extract.parse_args({"-P", "output.pdf", "final.mmz"}, defaults)
			expect.equal(args, {
				pdf = "output.pdf",
				mmz = "final.mmz",
			})
		end)

		it("should fail if no mmz is given", function()
			local defaults = {pdf = nil, format = "plain", quiet = false}

			local a, err = extract.parse_args({"-P", "output.pdf", "-F", "latex", "-p"}, defaults)

			expect.not_exist(a)
			expect.equal(err, "wrong number of arguments passed, exactly one positional needs to be given")
		end)

		it("should exit successfully and print help for '-h'", function()
			local defaults = {}

			expect.fail(function()
				extract.parse_args({"-h"}, defaults)
			end, "exited with succ")
		end)

		it("should exit successfully and print version for '-V'", function()
			local defaults = {}

			expect.fail(function()
				extract.parse_args({"-V"}, defaults)
			end, "exited with succ")
		end)

		it("should handle no flags and return defaults", function()
			local defaults = {pdf = nil, prune = false}
			local args = extract.parse_args({"mmz"}, defaults)
			expect.equal(args, {
				prune = false,
				mmz   = "mmz",
			})
		end)

		it("should fail with no arguments", function()
			local defaults = {pdf = nil, prune = false}

			local a, err = extract.parse_args({}, defaults)

			expect.not_exist(a)
			expect.equal(err, "wrong number of arguments passed, exactly one positional needs to be given")
		end)

		it("should raise an error for an unrecognized argument", function()
			local defaults = {}

			local args, err = extract.parse_args({"-z", "mmz"}, defaults)

			expect.not_exist(args)
			expect.equal(err, "invalid token passed '-z'")
		end)

		it("nothing flag-like is allowed for the positional", function()
			local defaults = {pdf = "main.pdf", prune = false}

			local a, err = extract.parse_args({"-P", "paper.pdf", "--mmz"}, defaults)

			expect.not_exist(a)
			expect.equal(err, "invalid token passed '--mmz'")
		end)

		it("uses -- as separator for the positionals", function()
			local defaults = {pdf = "main.pdf", prune = false}
			local args = extract.parse_args({"-P", "paper.pdf", "--", "--mmz"}, defaults)
			expect.equal(args, {
				pdf   = "paper.pdf",
				prune = false,
				mmz   = "--mmz",
			})
		end)
	end)

	describe("normalize_mmz", function()
		it("should replace .tex extension with .mmz", function()
			local input = "document.tex"
			local expected = "document.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should add .mmz to files with no extension", function()
			local input = "document"
			local expected = "document.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should add .mmz to files with non-matching extensions", function()
			local input = "document.pdf"
			local expected = "document.pdf.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should not change files that already have a .mmz extension", function()
			local input = "document.mmz"
			local expected = "document.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should handle file paths with directories for .tex files", function()
			local input = "/path/to/document.tex"
			local expected = "/path/to/document.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should handle file paths with directories for files without extensions", function()
			local input = "/path/to/document"
			local expected = "/path/to/document.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should handle file paths with directories for non-matching extensions", function()
			local input = "/path/to/document.pdf"
			local expected = "/path/to/document.pdf.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should handle file paths with directories for .mmz files", function()
			local input = "/path/to/document.mmz"
			local expected = "/path/to/document.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should handle files with multiple dots correctly", function()
			local input = "my.file.name.tex"
			local expected = "my.file.name.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)

		it("should handle files with multiple dots and non-matching extensions", function()
			local input = "my.file.name.pdf"
			local expected = "my.file.name.pdf.mmz"
			local result = extract.normalize_mmz(input)
			expect.equal(result, expected)
		end)
	end)

	describe("write_new_mmz", function()
		local function mock_file()
			local file = {content = ""}
			function file:write(...)
				for _, arg in ipairs{...} do
					self.content = self.content .. tostring(arg)
				end
			end
			return file
		end

		it("should write lines to the file correctly", function()
			local file = mock_file()
			local new_mmz = { { "line1" }, { "line2" }, { "line3" } }
			extract.write_new_mmz(file, new_mmz)
			expect.equal(file.content, "line1\nline2\nline3")
		end)

		it("should handle an empty new_mmz array", function()
			local file = mock_file()
			local new_mmz = {}
			extract.write_new_mmz(file, new_mmz)
			expect.equal(file.content, "")
		end)

		it("should handle nil values in the second element of the line tuples", function()
			local file = mock_file()
			local new_mmz = { { "line1", nil }, { "line2", nil }, { "line3", nil } }
			extract.write_new_mmz(file, new_mmz)
			expect.equal(file.content, "line1\nline2\nline3")
		end)

		it("should handle page numbers in the second element of the line tuples", function()
			local file = mock_file()
			local new_mmz = { { "line1", 4 }, { "line2" , 2}, { "line3" , 5} }
			extract.write_new_mmz(file, new_mmz)
			expect.equal(file.content, "line1\nline2\nline3")
		end)
	end)

	describe("handle_mmz_new_extern", function()
		local check_for_memo_succ = function(a,cc) return true end
		local check_for_memo_fail = function(a,cc) return false end

		it("parses a valid \\mmzNewExtern line", function()
			local pages = {}
			local current_prefix = "test_prefix"
			local line = [[\mmzNewExtern {main.memo.dir/4FECA8D15F24F18E95D6D091A6137684-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf}{1}{100.0pt}{200.0pt}]]
			local line_tab = {line}

			local result = extract.handle_mmz_new_extern(line, current_prefix, pages, false, check_for_memo_succ, line_tab)

			expect.truthy(result)
			expect.equal(pages, {{
				page = 1,
				width = "100.0",
				height = "200.0",
				fn = "main.memo.dir/4FECA8D15F24F18E95D6D091A6137684-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf",
				prefix = "test_prefix",
				line_tab = {line, 0}
			}})
			expect.equal(line_tab, {line, 0})
			-- both need to reference the same table in order being able to modify the string via pages[idx].line_tab
			expect.truthy(line_tab == pages[1].line_tab)
		end)

		it("returns false for an invalid \\mmzNewExtern line", function()
			local pages = {}
			local current_prefix = "test_prefix"
			local line = [[\mmzNewExtern {"invalid_line"}]]
			local line_tab = {line}

			local result = extract.handle_mmz_new_extern(line, current_prefix, pages, false, check_for_memo_succ, line_tab)

			expect.falsy(result) -- signals to keep trying to match this line
			expect.equal(#pages, 0)
			expect.equal(line_tab, {line}) -- unmodified
		end)

		-- TODO evaluate what should happen if check_for_memo_fail
		-- it("skips extraction if memo files are missing and force is false", function()
		-- 	local pages = {}
		-- 	local current_prefix = nil
		-- 	local line = [[\mmzNewExtern {"valid_path"}{1}{100.0pt}{200.0pt}]]
		--
		-- 	local result = extract.handle_mmz_new_extern(line, current_prefix, pages, false, check_for_memo_fail)
		--
		-- 	expect.falsy(result)
		-- 	expect.equal(#pages, 0)
		-- end)

		it("forces extraction even if memo files are missing", function()
			local pages = {}
			local current_prefix = "test_prefix"
			local line = [[\mmzNewExtern {main.memo.dir/4FECA8D15F24F18E95D6D091A6137684-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf}{1}{100.0pt}{200.0pt}]]
			local line_tab = {line}

			local result = extract.handle_mmz_new_extern(line, current_prefix, pages, true, check_for_memo_fail, line_tab)

			expect.truthy(result)
			expect.equal(pages, {{
				page = 1,
				width = "100.0",
				height = "200.0",
				fn = "main.memo.dir/4FECA8D15F24F18E95D6D091A6137684-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf",
				prefix = "test_prefix",
				line_tab = {line, 0}
			}})
			expect.equal(line_tab, {line, 0})
			-- both need to reference the same table in order being able to modify the string via pages[idx].line_tab
			expect.truthy(line_tab == pages[1].line_tab)
		end)

		it("throws an error if no prefix is parsed before the extern", function()
			local pages = {}
			local current_prefix = nil
			local line = [[\mmzNewExtern {main.memo.dir/4FECA8D15F24F18E95D6D091A6137684-E778DCCCB8AAB0BBD3F6CFEEFD2421F8.pdf}{1}{100.0pt}{200.0pt}]]
			local line_tab = {line}

			local cont, err = extract.handle_mmz_new_extern(line, current_prefix, pages, false, check_for_memo_succ, line_tab)

			expect.truthy(cont == nil)
			expect.equal(err, "no prefix was parsed before this extern")
		end)
	end)

	describe("handle_mmz_prefix", function()
		it("parses a valid \\mmzPrefix line", function()
			local dirs_to_make = {}
			local current_prefix = nil
			local gs_prefix = nil
			local line = [[\mmzPrefix {/valid_dir/valid_name}]]

			local result, new_prefix, new_gs_prefix = extract.handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)

			-- Test the return values
			expect.truthy(result)
			expect.equal(new_prefix, "/valid_dir/")
			expect.equal(new_gs_prefix, new_prefix)

			-- Test that the directory creation function was added
			expect.exist(dirs_to_make[new_prefix])
		end)

		it("keeps gs prefix if already set", function()
			local dirs_to_make = {}
			local current_prefix = nil
			local gs_prefix = "gs_prefix"
			local line = [[\mmzPrefix {/valid_dir/valid_name}]]

			local result, new_prefix, new_gs_prefix = extract.handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)

			-- Test the return values
			expect.truthy(result)
			expect.equal(new_prefix, "/valid_dir/")
			expect.equal(new_gs_prefix, gs_prefix)

			-- Test that the directory creation function was added
			expect.exist(dirs_to_make[new_prefix])
		end)

		it("parses an empty directory prefix", function()
			local line = [[\mmzPrefix {}]]
			local dirs_to_make = {}
			local current_prefix = nil
			local gs_prefix = nil

			local result, new_prefix, new_gs_prefix = extract.handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)

			-- Test the return values
			expect.truthy(result)
			expect.equal(new_prefix, "")
			expect.equal(new_gs_prefix, new_prefix)

			-- Ensure no directory creation function was added
			expect.exist(dirs_to_make[new_prefix])
		end)

		it("returns false for an invalid \\mmzPrefix line", function()
			local line = [[\mmzPrefi {}]]
			local dirs_to_make = {}
			local current_prefix = nil
			local gs_prefix = nil

			local result, new_prefix, new_gs_prefix = extract.handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)

			-- Test that the line was not valid
			expect.falsy(result)
			expect.not_exist(new_prefix)
			expect.not_exist(new_gs_prefix)

			-- Ensure no directory creation function was added
			expect.equal(dirs_to_make, {})
		end)
	end)

	describe("pathlib library", function()
		describe("sanitize_path", function()
			it("raises an error for paths with invalid characters", function()
				local input = "valid/path\0/with\tinvalid"

				local p, err = extract.pathlib.sanitize_path(input)

				expect.not_exist(p)
				expect.equal(err, "Path contains invalid characters: valid/path\000/with\tinvalid")
			end)

			it("handles valid paths without errors", function()
				local input = "valid/path/without/invalid"
				expect.not_fail(function() extract.pathlib.sanitize_path(input) end)
			end)
		end)

		describe("sanitize_name", function()
			it("raises an error for names with invalid characters", function()
				local input = "invalid/name\0\\with\tchars"

				local n, err = extract.pathlib.sanitize_name(input)

				expect.not_exist(n)
				expect.equal(err, "File has an invalid name: invalid/name\0\\with\tchars")
			end)

			it("handles valid names without errors", function()
				local input = "valid_name"
				expect.not_fail(function() extract.pathlib.sanitize_name(input) end)
			end)
		end)

		describe("sanitize_suffix", function()
			it("raises an error for suffixes with invalid characters", function()
				local input = "..\0suffix"

				local s, err = extract.pathlib.sanitize_suffix(input)

				expect.not_exist(s)
				expect.equal(err, "Suffix contains invalid characters: ..\0suffix")
			end)

			it("handles valid suffixes without errors", function()
				local input = "validsuffix"
				expect.not_fail(function() extract.pathlib.sanitize_suffix(input) end)
			end)
		end)

		describe("name", function()
			it("extracts the name from a valid path", function()
				local input = "/path/to/file.txt"
				local expected_name = "file.txt"
				local expected_remainder = "/path/to"
				local name, remainder = extract.pathlib.name(input)
				expect.equal(name, expected_name)
				expect.equal(remainder, expected_remainder)
			end)

			it("raises an error for invalid paths", function()
				local input = "/path/with\0invalid"

				local n, err = extract.pathlib.name(input)

				expect.not_exist(n)
				expect.equal(err, "Path contains invalid characters: /path/with\0invalid")
			end)
		end)

		describe("with_name", function()
			it("replaces the name in a valid path", function()
				local path = "/path/to/file.txt"
				local new_name = "newfile.txt"
				local expected = "/path/to/newfile.txt"
				local result = extract.pathlib.with_name(path, new_name)
				expect.equal(result, expected)
			end)

			it("raises an error for invalid names", function()
				local path = "/path/to/file.txt"
				local new_name = "invalid\0name"

				local p, err = extract.pathlib.with_name(path, new_name)
				expect.not_exist(p)
				expect.equal(err, "File has an invalid name: invalid\0name")
			end)
		end)

		describe("suffix", function()
			it("extracts the suffix from a valid path", function()
				local input = "file.tar.gz"
				local expected_suffix = "gz"
				local expected_remainder = "file.tar"
				local suffix, remainder = extract.pathlib.suffix(input)
				expect.equal(suffix, expected_suffix)
				expect.equal(remainder, expected_remainder)
			end)

			it("raises an error for invalid paths", function()
				local input = "file\0invalid.txt"

				local s, err = extract.pathlib.suffix(input)

				expect.not_exist(s)
				expect.equal(err, "Path contains invalid characters: file\0invalid.txt")
			end)
		end)

		describe("with_suffix", function()
			it("replaces the suffix in a valid path", function()
				local path = "file.txt"
				local new_suffix = "md"
				local expected = "file.md"
				local result = extract.pathlib.with_suffix(path, new_suffix)
				expect.equal(result, expected)
			end)

			it("raises an error for invalid suffixes", function()
				local path = "file.txt"
				local new_suffix = "\0invalid"

				local p, err = extract.pathlib.with_suffix(path, new_suffix)

				expect.not_exist(p)
				expect.equal(err, "Suffix contains invalid characters: \0invalid")
			end)
		end)

		describe("join", function()
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

			it("works with no path", function()
				local result, err = extract.pathlib.join()

				expect.not_exist(err)
				expect.equal(result, "")
			end)

			it("aborts with invalid path (1)", function()
				local result, err = extract.pathlib.join("/me\0dia", "memoize", "testing", "assets")

				expect.not_exist(result)
				expect.equal(err,  "Path contains invalid characters: /me\0dia")
			end)
			it("aborts with invalid path (2)", function()
				local result, err = extract.pathlib.join("/media", "memoize", "testing", "ass\0ets")

				expect.not_exist(result)
				expect.equal(err, "Path contains invalid characters: ass\000ets")
			end)
		end)
	end)

	-- in case we need tests working on the filesystem.
	-- This snippet allows to do this in a temporary directory
	-- (doesn't sandbox/chroot though)

	-- describe("xyz", function()
	-- 	local tmp_dir = ""
	-- 	local original_dir = ""
	--
	-- 	before(function()
	-- 		-- Save the current working directory
	-- 		original_dir = assert(lfs.currentdir())
	--
	-- 		-- Create a unique temporary directory
	-- 		tmp_dir = os.tmpname()
	-- 		os.remove(tmp_dir) -- Remove the temp file placeholder
	-- 		lfs.mkdir(tmp_dir)
	--
	-- 		-- Change to the temporary directory
	-- 		lfs.chdir(tmp_dir)
	-- 	end)
	--
	-- 	after(function()
	-- 		-- Change back to the original working directory
	-- 		lfs.chdir(original_dir)
	--
	-- 		-- Cleanup: Remove the temporary directory and its contents
	-- 		local function rmdir(path)
	-- 			for file in lfs.dir(path) do
	-- 				if file ~= "." and file ~= ".." then
	-- 					-- TODO only works on unix due to the pathsep
	-- 					local fullpath = path .. "/" .. file
	-- 					local attr = lfs.attributes(fullpath)
	-- 					if attr and attr.mode == "directory" then
	-- 						rmdir(fullpath)
	-- 					else
	-- 						os.remove(fullpath)
	-- 					end
	-- 				end
	-- 			end
	-- 			lfs.rmdir(path)
	-- 		end
	-- 		rmdir(tmp_dir)
	-- 	end)
	--
	-- 	it("xyz", function()
	-- 	end)
	-- end)
end)
