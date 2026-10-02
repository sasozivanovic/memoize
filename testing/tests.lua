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

package.path = table.concat(
  {
    package.path,
    '/usr/share/lua/5.3/?.lua',                   --for busted
    '/usr/share/lua/5.3/?/init.lua',
    '/usr/lib/lua/5.3/?.lua',
    '/usr/lib/lua/5.3/?/init.lua',
    '/home/saso/.luarocks/share/lua/5.3/?.lua',                   --for busted
    '/home/saso/.luarocks/share/lua/5.3/?/init.lua',
    '/home/saso/.luarocks/lib/lua/5.3/?.lua',
    '/home/saso/.luarocks/lib/lua/5.3/?/init.lua',
    ';../?.lua'                                   --for memoize-extract
  },
  ';'
)
package.cpath = table.concat(
  {
    package.cpath,
    '/usr/lib/lua/5.3/?.so',                    --for term, used by busted
    '/usr/lib/lua/5.3/loadall.so',
    '/home/saso/.luarocks/lib/lua/5.3/?.so',
    '/home/saso/.luarocks/lib/lua/5.3/loadall.so'
  },
  ';'
)

local process = require "environ.process"
require 'busted.runner'()

kpse.set_program_name("luatex")
local utils = require "unittest-utils"
local me = {}
package.path = package.path .. ';../?.lua'
me_module = utils.require("memoize-extract", me, 17)
utils.getupvalues(me.find_in, me)

me.exit.error = function() error("exited with error") end
me.exit.warn  = function() error("exited with warn") end
me.exit.succ  = function() error("exited with succ") end

local cwd = lfs.currentdir
local on_windows = os.type == 'windows'
local function uw(value,win_value)
  return on_windows and win_value or value
end

local function setenv(openout_any, TEXMFOUTPUT, TEXMF_OUTPUT_DIRECTORY)
  process.setenv("openout_any", openout_any)
  process.setenv("TEXMFOUTPUT", TEXMFOUTPUT)
  process.setenv("TEXMF_OUTPUT_DIRECTORY", TEXMF_OUTPUT_DIRECTORY)
end

local function mkdir(fn)
  assert(lfs.mkdir(fn), 'Cannot create directory ' .. fn)
  return fn
end

local function rmtree(dn)
  if on_windows then
    assert(os.execute(('rmdir /s/q "%s"'):format(dn))==0)
  else
    os.execute(('chmod -R --quiet +rwx "%s"'):format(dn))
    assert(os.execute(('rm -rf "%s"'):format(dn))==0)
  end
end  

local original_cwd = cwd()
local function create_test_dir()
  lfs.chdir(original_cwd)
  rmtree("test")
  mkdir("test")
  lfs.chdir("test")
end

local function create(fn, text)
  local fh = io.open(fn, 'w')
  assert(fh, "Cannot open " .. fn)
  if text then
    fh:write(text)
  end
  fh:close()
  return fn
end

local function chmod(mode, fn)
  if on_windows then
    error("Not yet implemented!")
  else
    os.execute(("chmod %s '%s'"):format(mode, fn))
  end
end

describe("unittests", function()
    
    describe("split_extern_path", function()
        it("should parse a valid path with all parts", function()
            local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-42.pdf"
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path)
            assert.are.equal(dir_prefix, "/dir/prefix/")
            assert.are.equal(name_prefix, "file")
            assert.are.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
            assert.are.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
        end)
        it("should parse a valid path with no dir_prefix", function()
            local path = "file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path)
            assert.are.equal(dir_prefix, "")
            assert.are.equal(name_prefix, "file")
            assert.are.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
            assert.are.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
        end)
        it("should parse a valid path with a numeric suffix", function()
            local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-99.pdf"
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path)
            assert.are.equal(dir_prefix, "/dir/prefix/")
            assert.are.equal(name_prefix, "file")
            assert.are.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
            assert.are.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
        end)
        -- Test invalid paths
        it("should fail for invalid paths", function()
            local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-invalid.pdf"
            assert.has_error(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path) end)
        end)
        it("should fail for paths with missing code_md5sum", function()
            local path = "/dir/prefix/file-no-md5sum-1234567890abcdef1234567890abcdef.pdf"
            assert.has_error(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path) end)
        end)
        -- Test paths without suffix and multiple hyphens
        it("should parse a valid path without a suffix", function()
            local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path)
            assert.are.equal(dir_prefix, "/dir/prefix/")
            assert.are.equal(name_prefix, "file")
            assert.are.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
            assert.are.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
        end)
        -- Test paths with no context_md5sum
        it("should fail for paths missing context_md5sum", function()
            local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-.pdf"
            assert.has_error(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path) end)
        end)
        -- Test edge cases
        it("should fail for an empty path", function()
            local path = ""
            assert.has_error(function() local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path) end)
        end)
        it("should return nil for path with only one part", function()
            local path = "1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path)
            assert.are.equal(dir_prefix, "")
            assert.are.equal(name_prefix, "")
            assert.are.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
            assert.are.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
        end)
    end)
    
    describe("pathlib", function()
       
        describe("parent", function()
            it("should return the parent", function()
                assert.are.equal(
                  me.pathlib.parent('/tmp/subdir/foo.memo.dir'),
                  '/tmp/subdir'
                )
            end)
            it("should ignore the trailing slashes", function()
                assert.are.equal(
                  me.pathlib.parent('/tmp/subdir/foo.memo.dir//'),
                  '/tmp/subdir'
                )
            end)
            it("should work for relative paths", function()
                assert.are.equal(
                  me.pathlib.parent('subdir/foo.memo.dir'),
                  'subdir'
                )
            end)
            it("should return the current directory if there is not dir part of the path", function()
                assert.are.equal(
                  me.pathlib.parent('foo'),
                  '.'
                )
            end)
            it("the parent of an empty string is the current directory", function()
                assert.are.equal(
                  me.pathlib.parent(''),
                  '.'
                )
            end)
        end)
    end)
    
    describe("#permissions", function()

        it("These tests should be run without TEXMFOUTPUT set in texmf.cnf", function()
            assert(not kpse.var_value("TEXMFOUTPUT"))
        end)
        
        strict_setup(function() drive = on_windows and 'C:' or '' end)
        
        describe("check_out_name", function()

            describe("", function()
                setup(function() setenv('p') end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('rel/foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../foo.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('rel/../foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/abs/foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/abs/foo/../bar/baz.txt') end) end)
            end)

            describe('TEXMFOUTPUT', function()
                setup(function() setenv('p', "/tmp") end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('rel/foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../foo.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('rel/../foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/abs/foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/abs/foo/../bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/bar.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/tmp/foo/../bar/baz.txt') end) end)
            end)
            
            describe('relative TEXMFOUTPUT & TEXMF_OUTPUT_DIRECTORY', function()
                setup(function() setenv('p', "../tmp", "od") end)
                
                it('', function() assert.errors(function() me.check_out_name(drive..'/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo/bar/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('baz.txt') end) end)
                
                it('', function() assert.errors(function() me.check_out_name(drive..'/foo/bar/.baz.txt') end) end)
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('foo/bar/.baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('.baz.txt') end) end)
                --it(function() assert.Not.errors(function() me.check_out_name('.tex') end) end) --since TeX Live 2026
                --it(function() assert.Not.errors(function() me.check_out_name('foo/.tex') end) end) --since TeX Live 2026

                it('', function() assert.Not.errors(function() me.check_out_name('od/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('od/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('odbaz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('.///./baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('foo/../baz.txt') end) end)

                it('', function() assert.errors(function() me.check_out_name('../tmp/foo/bar/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../tmp/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../tmp///./baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../tmp/foo/../baz.txt') end) end)

                it('', function() assert.errors(function() me.check_out_name(file.join(cwd(),'baz.txt')) end) end)
                it('', function() assert.errors(function() me.check_out_name(file.join(cwd(),'foo/baz.txt')) end) end)
                it(function() pending("") assert.errors(function() me.check_out_name(file.join(texmfoutput.resolve(),'baz.txt')) end) end)
                it(function() pending("") assert.errors(function() me.check_out_name(file.join(texmf_output_directory.resolve(),'baz.txt')) end) end)
            end)

            describe('absolute TEXMFOUTPUT & TEXMF_OUTPUT_DIRECTORY', function()
                setup(function() setenv('p', drive.."/tmp", drive..'/home/user/tex/od') end)
                
                it('', function() assert.errors(function() me.check_out_name(drive..'/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo/bar/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/foo/bar/.baz.txt') end) end)
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('foo/bar/.baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('.baz.txt') end) end)
                --it(function() assert.Not.errors(function() me.check_out_name('.tex') end) end) --since TeX Live 2026
                --it(function() assert.Not.errors(function() me.check_out_name('foo/.tex') end) end) --since TeX Live 2026
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od///./baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/od/foo/../baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp///./baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/tmp/foo/../baz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(drive..'/tmpbaz.txt') end) end)
                it('', function() assert.errors(function() me.check_out_name(file.join(cwd(),'baz.txt')) end) end)
                it('', function() assert.errors(function() me.check_out_name(file.join(cwd(),'foo/baz.txt')) end) end)
            end)
            
            describe('openout_any=r, relative TEXMFOUTPUT & TEXMF_OUTPUT_DIRECTORY', function()
                setup(function() setenv("r", "tmp", "od") end)
                
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('../baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('baz.txt') end) end)
                
                --it(function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name(drive..'/foo/bar/.baz.txt') end) end) --since TeX Live 2026
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('foo/bar/.baz.txt') end) end)
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() uw(assert.errors, assert.Not.errors)(function() me.check_out_name('.baz.txt') end) end)
                --it(function() assert.Not.errors(function() me.check_out_name('.tex') end) end) --since TeX Live 2026
                --it(function() assert.Not.errors(function() me.check_out_name('foo/.tex') end) end) --since TeX Live 2026

                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od///./baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/foo/../baz.txt') end) end)

                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp///./baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/../baz.txt') end) end)

                it('', function() assert.Not.errors(function() me.check_out_name(file.join(cwd(),'baz.txt')) end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(file.join(cwd(),'foo/baz.txt')) end) end)
            end)
            
            describe('openout_any=a', function()
                setup(function() setenv("a") end)
                
                it('', function() assert.Not.errors(function() me.check_out_name('foo.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('rel/foo/bar.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('../foo.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('rel/../foo/bar.txt') end) end)
                
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/abs/foo/bar.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/abs/foo/../bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/bar.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/../bar/baz.txt') end) end)
            end)
            
            describe('openout_any=a, relative TEXMF_OUTPUT_DIRECTORY & TEXMFOUTPUT', function()
                setup(function() setenv('a', 'tmp', 'od') end)
                
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('../baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('../baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/foo/bar/.baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('foo/bar/.baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('../.baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name('.baz.txt') end) end)
                --it(function() assert.Not.errors(function() me.check_out_name('.tex') end) end) --since TeX Live 2026
                --it(function() assert.Not.errors(function() me.check_out_name('foo/.tex') end) end) --since TeX Live 2026

                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od///./baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/od/foo/../baz.txt') end) end)

                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/bar/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/odbaz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/home/user/tex/baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp///./baz.txt') end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(drive..'/tmp/foo/../baz.txt') end) end)

                it('', function() assert.Not.errors(function() me.check_out_name(file.join(cwd(),'baz.txt')) end) end)
                it('', function() assert.Not.errors(function() me.check_out_name(file.join(cwd(),'foo/baz.txt')) end) end)
            end)
            
        end)

        describe('check_access_in', function()
            before_each(function() create_test_dir() end)
            it('', function()
                local fn = 'file.txt'
                assert.errors(function() me.check_access_in(fn) end)
                create(fn)
                assert.Not.errors(function() me.check_access_in(fn) end)
                chmod('-w', fn)
                assert.Not.errors(function() me.check_access_in(fn) end)
                chmod('-r', fn)
                assert.errors(function() me.check_access_in(fn) end)
            end)
            it('', function()
                local dn = 'foo'
                local fn = file.join(dn, 'file.txt')
                assert.errors(function() me.check_access_in(fn) end)
                mkdir(dn)
                assert.errors(function() me.check_access_in(fn) end)
                create(fn)
                assert.Not.errors(function() me.check_access_in(fn) end)
                chmod('-w', dn)
                assert.Not.errors(function() me.check_access_in(fn) end)
                chmod('-r', dn)
                assert.Not.errors(function() me.check_access_in(fn) end)
                chmod('-x', dn)
                assert.errors(function() me.check_access_in(fn) end)
            end)
        end)
        
        describe("find_in & find_out", function()
            
            before_each(create_test_dir)
            
            it('basics', function()
                mkdir("tmp") mkdir("od")
                setenv("p")
                local none = 'none.txt'
                local cur = create('cur.txt')
                
                assert.equal(cur, me.find_in(cur))
                assert.equal(none, me.find_in(none))
                assert.equal(cur, me.find_out(cur))
                assert.equal(none, me.find_out(none))
                
                local od_cur = create('od/cur.txt')
                local tmp_cur = create('tmp/cur.txt')
                
                assert.equal(cur, me.find_in(cur))
                assert.equal(cur, me.find_out(cur))
                chmod('-r', cur)
                assert.equal(cur, me.find_in(cur))
                assert.equal(cur, me.find_out(cur))
                chmod('-w', cur)
                assert.equal(cur, me.find_in(cur))
                assert.equal(cur, me.find_out(cur))
                chmod('+r', cur)
                assert.equal(cur, me.find_in(cur))
                assert.equal(cur, me.find_out(cur))
            end)
            
            it('TEXMFOUTPUT_is_set', function()
                mkdir("tmp")
                setenv("p","tmp") 
                local none = 'none.txt'
                local tmp_none = 'tmp/none.txt'
                local tmp = 'tmp.txt'
                local tmp_tmp = create('tmp/tmp.txt')

                assert.equal(none, me.find_in(none))
                assert.equal(tmp_tmp, me.find_in(tmp))
                assert.equal(none, me.find_out(none))
                assert.equal(tmp, me.find_out(tmp))
                
                chmod('-w', '.')
                assert.equal(none, me.find_in(none))
                assert.equal(tmp_tmp, me.find_in(tmp))
                if not on_windows then assert.equal(tmp_none, me.find_out(none)) end
                if not on_windows then assert.equal(tmp_tmp, me.find_out(tmp)) end
                
                chmod('-r', '.')
                assert.equal(me.find_in(none), none)
                assert.equal(me.find_in(tmp), tmp_tmp)
                if not on_windows then assert.equal(tmp_none, me.find_out(none)) end
                if not on_windows then assert.equal(tmp_tmp, me.find_out(tmp)) end
                
                chmod('+w', '.')
                assert.equal(none, me.find_in(none))
                assert.equal(tmp_tmp, me.find_in(tmp))
                assert.equal(none, me.find_out(none))
                assert.equal(tmp, me.find_out(tmp))
            end)

            it('TEXMF_OUTPUT_DIRECTORY_is_set', function()
                mkdir("od")
                setenv("p",nil,"od")
                
                local none = 'none.txt'
                local od_none = 'od/none.txt'
                
                local cur = create('cur.txt')
                local od_cur = 'od/cur.txt'
                
                local od = 'od.txt'
                local od_od = create('od/od.txt')
                
                local curod = create('curod.txt')
                local od_curod = create('od/curod.txt')
                
                assert.equal(none, me.find_in(none))
                assert.equal(od_none, me.find_out(none))
                assert.equal(cur, me.find_in(cur))
                assert.equal(od_cur, me.find_out(cur))
                assert.equal(od_od, me.find_in(od))
                assert.equal(od_od, me.find_out(od))
                assert.equal(od_curod, me.find_in(curod))
                assert.equal(od_curod, me.find_out(curod))
                
                chmod('-w', 'od')
                assert.equal(none, me.find_in(none))
                assert.equal(od_none, me.find_out(none))
                chmod('+w', 'od')
                chmod('-x', 'od')
                assert.equal(uw(od, od_od), me.find_in(od)) -- fail on win --> od_od
                assert.equal(od_od, me.find_out(od))
                assert.equal(uw(curod,od_curod), me.find_in(curod)) -- fail on win --> od_curod
                assert.equal(od_curod, me.find_out(curod))
                chmod('+x', 'od')
                
                chmod('-r', od_od)
                assert.equal(uw(od,od_od), me.find_in(od)) -- fail on win --> od_od
                chmod('+r', od_od)
                chmod('-w', od_od)
                assert.equal(od_od, me.find_out(od))
                chmod('+w', od_od)
            end)

            it("TEXMFOUTPUT_is_set TEXMF_OUTPUT_DIRECTORY_is_set", function()
                mkdir("tmp") mkdir("od")
                setenv("p","tmp","od")

                local none = 'none.txt'
                local od_none = 'od/none.txt'
                local tmp_none = 'tmp/none.txt'
                
                local cur = create('cur.txt')
                local od_cur = 'od/cur.txt'
                local tmp_cur = 'tmp/cur.txt'
                
                local od = 'od.txt'
                local od_od = create('od/od.txt')
                local tmp_od = 'tmp/od.txt'
                
                local tmp = 'tmp.txt'
                local od_tmp = 'od/tmp.txt'
                local tmp_tmp = create('tmp/tmp.txt')
                
                curod = create('curod.txt')
                od_curod = create('od/curod.txt')
                tmp_curod = 'tmp/curod.txt'
                
                curtmp = create('curtmp.txt')
                od_curtmp = 'od/curtmp.txt'
                tmp_curtmp = create('tmp/curtmp.txt')
                
                odtmp = 'odtmp.txt'
                od_odtmp = create('od/odtmp.txt')
                tmp_odtmp = create('tmp/odtmp.txt')
                
                curodtmp = create('curodtmp.txt')
                od_curodtmp = create('od/curodtmp.txt')
                tmp_curodtmp = create('tmp/curodtmp.txt')

                assert.equal(none, me.find_in(none))
                assert.equal(od_none, me.find_out(none))
                assert.equal(cur, me.find_in(cur))
                assert.equal(od_cur, me.find_out(cur))
                assert.equal(od_od, me.find_in(od))
                assert.equal(od_od, me.find_out(od))
                assert.equal(tmp_tmp, me.find_in(tmp))
                assert.equal(od_tmp, me.find_out(tmp))
                assert.equal(od_curod, me.find_in(curod))
                assert.equal(od_curod, me.find_out(curod))
                assert.equal(curtmp, me.find_in(curtmp))
                assert.equal(od_curtmp, me.find_out(curtmp))
                assert.equal(od_odtmp, me.find_in(odtmp))
                assert.equal(od_odtmp, me.find_out(odtmp))
                assert.equal(od_curodtmp, me.find_in(curodtmp))
                assert.equal(od_curodtmp, me.find_out(curodtmp))
                
                chmod('-w', 'od')
                assert.equal(uw(tmp_none, od_none), me.find_out(none)) -- fail on win --> od_none
                assert.equal(uw(tmp_cur, od_cur), me.find_out(cur)) -- fail on win --> od_cur
                assert.equal(od_od, me.find_out(od))
                assert.equal(uw(tmp_tmp,od_tmp), me.find_out(tmp)) --fail on win --> od_tmp
                assert.equal(od_curod, me.find_out(curod))
                assert.equal(uw(tmp_curtmp, od_curtmp), me.find_out(curtmp)) -- fail on win --> od_curtmp
                assert.equal(od_odtmp, me.find_out(odtmp))
                assert.equal(od_curodtmp, me.find_out(curodtmp))
                chmod('+w', 'od')
                
                chmod('-w', od_od)
                assert.equal(od_od, me.find_in(od))
                assert.equal(tmp_od, me.find_out(od))
                chmod('-r', od_od)
                assert.equal(uw(od,od_od), me.find_in(od)) -- fail on win --> od_od
                print()
                assert.equal(tmp_od, me.find_out(od))
                chmod('+w', od_od)
                assert.equal(uw(od,od_od), me.find_in(od)) --fail on win --> od_od
                assert.equal(od_od, me.find_out(od))
                chmod('+r', od_od)
            
            end)
        end)
        
    end)
end)

-- Local Variables:
-- lua-indent-level: 2
-- End:
