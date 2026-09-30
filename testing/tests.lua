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

local function set_env(a,b,c)
  process.setenv("TEXMF_OUTPUT_DIRECTORY", a)
  process.setenv("TEXMFOUTPUT", b)
  process.setenv("openin_any", "a")
  process.setenv("openout_any", c)
  me.init_find()
  --print(("TEXMFOUTPUT=%s"):format(kpse.var_value("TEXMFOUTPUT")))
end
local function reset_env()
  set_env("","","p")  
end
reset_env()

local function describe_env(a,b,c,f,desc)
  desc = desc or ''
  describe(
    ("TEXMFOUTPUT=%s, TEXMF_OUTPUT_DIRECTORY=%s, openout_any=%s %s")
    :format(a,b,c,desc),
    function()
      setup(function()set_env(a,b,c)end)
      teardown(reset_env)
      f()
  end)
end

local on_windows = os.type == 'windows'
local cwd = lfs.currentdir

describe("memoize-extract.lua", function()
    
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
            
            describe("check_out_name", function()
                
                local function It(fn, assrt, win_assrt, pnding)
                  it(fn, function()
                      assrt = on_windows and (win_assrt and win_assrt or assrt) or assrt
                      if pnding then pending(pnding) end
                      assrt(function() me.check_out_name(fn) end)
                  end)
                end
                local drive = on_windows and 'C:' or ''

                describe_env(nil, nil, 'p', function()
                    --relative
                    It('foo.txt', assert.Not.errors)
                    It('rel/foo/bar.txt', assert.Not.errors)
                    It('../foo.txt', assert.errors)
                    It('rel/../foo/bar.txt', assert.errors)
                    --absolute
                    It(drive..'/abs/foo/bar.txt', assert.errors)
                    It(drive..'/abs/foo/../bar/baz.txt', assert.errors)
                end)

                describe_env(nil, '/tmp', 'p', function()
                    --relative
                    It('foo.txt', assert.Not.errors)
                    It('rel/foo/bar.txt', assert.Not.errors)
                    It('../foo.txt', assert.errors)
                    It('rel/../foo/bar.txt', assert.errors)
                    --absolute
                    It(drive..'/abs/foo/bar.txt', assert.errors)
                    It(drive..'/abs/foo/../bar/baz.txt', assert.errors)
                    It(drive..'/tmp/foo.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/bar.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/../bar/baz.txt', assert.errors)
                end)
                
                describe_env(nil, nil, 'a', function()
                    --relative
                    It('foo.txt', assert.Not.errors)
                    It('rel/foo/bar.txt', assert.Not.errors)
                    It('../foo.txt', assert.Not.errors)
                    It('rel/../foo/bar.txt', assert.Not.errors)
                    --absolute
                    It(drive..'/abs/foo/bar.txt', assert.Not.errors)
                    It(drive..'/abs/foo/../bar/baz.txt', assert.Not.errors)
                    It(drive..'/tmp/foo.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/bar.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/../bar/baz.txt', assert.Not.errors)
                end)

                describe_env(drive..'/home/user/tex/od', drive..'/tmp', 'p', function()
                    
                    It(drive..'/foo/bar/baz.txt', assert.errors)
                    It('foo/bar/baz.txt', assert.Not.errors)
                    It('../baz.txt', assert.errors)
                    It('baz.txt', assert.Not.errors)
                    It(drive..'/foo/bar/.baz.txt', assert.errors)
                    It('foo/bar/.baz.txt', assert.errors, assert.Not.errors)
                    It('../.baz.txt', assert.errors)
                    It('../.baz.txt', assert.errors)
                    It('.baz.txt', assert.errors, assert.Not.errors)
                    --It('.tex', assert.Not.errors)
                    --It('foo/.tex', assert.Not.errors)
                    It(drive..'/home/user/tex/od/foo/bar/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.errors)
                    It(drive..'/home/user/tex/od///./baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od/foo/../baz.txt', assert.errors)
                    It(drive..'/tmp/foo/bar/baz.txt', assert.Not.errors)
                    It(drive..'/tmp/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.errors)
                    It(drive..'/tmp///./baz.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/../baz.txt', assert.errors)
                    It(drive..'/tmpbaz.txt', assert.errors)
                    It(file.join(cwd(),'baz.txt'), assert.errors)
                    It(file.join(cwd(),'foo/baz.txt'), assert.errors)
                end)
                
                describe_env('od', 'tmp', 'r', function()
                    
                    It(drive..'/foo/bar/baz.txt', assert.Not.errors)
                    It('foo/bar/baz.txt', assert.Not.errors)
                    It('../baz.txt', assert.Not.errors)
                    It('baz.txt', assert.Not.errors)
                    
                    --It(drive..'/foo/bar/.baz.txt', assert.errors, assert.Not.errors)
                    It('foo/bar/.baz.txt', assert.errors, assert.Not.errors)
                    It('../.baz.txt', assert.errors, assert.Not.errors)
                    It('.baz.txt', assert.errors, assert.Not.errors)
                    --It('.tex', assert.Not.errors)
                    --It('foo/.tex', assert.Not.errors)

                    It(drive..'/home/user/tex/od/foo/bar/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od///./baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od/foo/../baz.txt', assert.Not.errors)

                    It(drive..'/tmp/foo/bar/baz.txt', assert.Not.errors)
                    It(drive..'/tmp/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.Not.errors)
                    It(drive..'/tmp///./baz.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/../baz.txt', assert.Not.errors)

                    It(file.join(cwd(),'baz.txt'), assert.Not.errors)
                    It(file.join(cwd(),'foo/baz.txt'), assert.Not.errors)
                end)
                
                describe_env('od', 'tmp', 'a', function()
                    
                    It(drive..'/foo/bar/baz.txt', assert.Not.errors)
                    It('foo/bar/baz.txt', assert.Not.errors)
                    It('../baz.txt', assert.Not.errors)
                    It('../baz.txt', assert.Not.errors)
                    It('baz.txt', assert.Not.errors)
                    It(drive..'/foo/bar/.baz.txt', assert.Not.errors)
                    It('foo/bar/.baz.txt', assert.Not.errors)
                    It('../.baz.txt', assert.Not.errors)
                    It('../.baz.txt', assert.Not.errors)
                    It('.baz.txt', assert.Not.errors)
                    --It('.tex', assert.Not.errors)
                    --It('foo/.tex', assert.Not.errors)

                    It(drive..'/home/user/tex/od/foo/bar/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od///./baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/od/foo/../baz.txt', assert.Not.errors)

                    It(drive..'/tmp/foo/bar/baz.txt', assert.Not.errors)
                    It(drive..'/tmp/baz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.Not.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.Not.errors)
                    It(drive..'/tmp///./baz.txt', assert.Not.errors)
                    It(drive..'/tmp/foo/../baz.txt', assert.Not.errors)

                    It(file.join(cwd(),'baz.txt'), assert.Not.errors)
                    It(file.join(cwd(),'foo/baz.txt'), assert.Not.errors)
                end)
                
                describe_env('od', '../tmp', 'p', function()
                    
                    It(drive..'/foo/bar/baz.txt', assert.errors)
                    It('foo/bar/baz.txt', assert.Not.errors)
                    It('../baz.txt', assert.errors)
                    It('baz.txt', assert.Not.errors)
                    
                    It(drive..'/foo/bar/.baz.txt', assert.errors)
                    It('foo/bar/.baz.txt', assert.errors, assert.Not.errors)
                    It('../.baz.txt', assert.errors)
                    It('../.baz.txt', assert.errors)
                    It('.baz.txt', assert.errors, assert.Not.errors)
                    --It('.tex', assert.Not.errors)
                    --It('foo/.tex', assert.Not.errors)

                    It('od/foo/bar/baz.txt', assert.Not.errors)
                    It('od/baz.txt', assert.Not.errors)
                    It('odbaz.txt', assert.Not.errors)
                    It('.///./baz.txt', assert.Not.errors)
                    It('foo/../baz.txt', assert.errors)

                    It('../tmp/foo/bar/baz.txt', assert.errors)
                    It('../tmp/baz.txt', assert.errors)
                    It(drive..'/home/user/tex/odbaz.txt', assert.errors)
                    It(drive..'/home/user/tex/baz.txt', assert.errors)
                    It('../tmp///./baz.txt', assert.errors)
                    It('../tmp/foo/../baz.txt', assert.errors)

                    It(file.join(cwd(),'baz.txt'), assert.errors)
                    It(file.join(cwd(),'foo/baz.txt'), assert.errors)
                    --It(file.join(texmfoutput.resolve(),'baz.txt'), assert.errors)
                    --It(file.join(texmf_output_directory.resolve(),'baz.txt'), assert.errors)
                end)
            end)
        end)
    end)
end)

-- Local Variables:
-- lua-indent-level: 2
-- End:
