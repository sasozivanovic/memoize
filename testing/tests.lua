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

local say = require "say"
say:set_namespace("en")

local function out_name_ok(state, args)
  return (pcall(me.check_out_name, args[1]))
end
say:set("assertion.out_name_ok.positive", "Expected out_name %s to be bad")
say:set("assertion.out_name_ok.negative", "Expected out_name %s to be ok")
assert:register("assertion", "out_name_ok", out_name_ok, "assertion.out_name_ok.positive", "assertion.out_name_ok.negative")

local function access_in_ok(state, args)
  return (pcall(me.check_access_in, args[1]))
end
say:set("assertion.access_in_ok.positive", "Expected %s to be inaccessible for writing")
say:set("assertion.access_in_ok.negative", "Expected %s to be accessible for writing")
assert:register("assertion", "access_in_ok", access_in_ok, "assertion.access_in_ok.positive", "assertion.access_in_ok.negative")

local function access_out_ok(state, args)
  return (pcall(me.check_access_out, args[1]))
end
say:set("assertion.access_out_ok.positive", "Expected %s to be inaccessible for writing")
say:set("assertion.access_out_ok.negative", "Expected %s to be accessible for writing")
assert:register("assertion", "access_out_ok", access_out_ok, "assertion.access_out_ok.positive", "assertion.access_out_ok.negative")

local function find_in(state, args)
  args[3] = me.find_in(args[1])
  return args[3] == args[2]
end
say:set("assertion.find_in.positive", "Expected find_in(%s) --> %s, got %s")
assert:register("assertion", "find_in", find_in, "assertion.find_in.positive")

local function find_out(state, args)
  args[3] = me.find_out(args[1])
  return args[3] == args[2]
end
say:set("assertion.find_out.positive", "Expected find_out(%s) --> %s, got %s")
assert:register("assertion", "find_out", find_out, "assertion.find_out.positive")

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
                it('', function() assert.out_name_ok('foo.txt') end)
                it('', function() assert.out_name_ok('rel/foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok('../foo.txt') end)
                --
                it('', function() assert.Not.out_name_ok('rel/../foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/abs/foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/abs/foo/../bar/baz.txt') end)
            end)

            describe('TEXMFOUTPUT', function()
                setup(function() setenv('p', "/tmp") end)
                it('', function() assert.out_name_ok('foo.txt') end)
                it('', function() assert.out_name_ok('rel/foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok('../foo.txt') end)
                it('', function() assert.Not.out_name_ok('rel/../foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/abs/foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/abs/foo/../bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo/bar.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/tmp/foo/../bar/baz.txt') end)
            end)
            
            describe('relative TEXMFOUTPUT & TEXMF_OUTPUT_DIRECTORY', function()
                setup(function() setenv('p', "../tmp", "od") end)
                
                it('', function() assert.Not.out_name_ok(drive..'/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('foo/bar/baz.txt') end)
                it('', function() assert.Not.out_name_ok('../baz.txt') end)
                it('', function() assert.out_name_ok('baz.txt') end)
                
                it('', function() assert.Not.out_name_ok(drive..'/foo/bar/.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('foo/bar/.baz.txt') end)
                it('', function() assert.Not.out_name_ok('../.baz.txt') end)
                it('', function() assert.Not.out_name_ok('../.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('.baz.txt') end)
                --it('', function() assert.out_name_ok('.tex') end)
                --it('', function() assert.out_name_ok('foo/.tex') end)

                it('', function() assert.out_name_ok('od/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('od/baz.txt') end)
                it('', function() assert.out_name_ok('odbaz.txt') end)
                it('', function() assert.out_name_ok('.///./baz.txt') end)
                it('', function() assert.Not.out_name_ok('foo/../baz.txt') end)

                it('', function() assert.Not.out_name_ok('../tmp/foo/bar/baz.txt') end)
                it('', function() assert.Not.out_name_ok('../tmp/baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.Not.out_name_ok('../tmp///./baz.txt') end)
                it('', function() assert.Not.out_name_ok('../tmp/foo/../baz.txt') end)

                it('', function() assert.Not.out_name_ok(file.join(cwd(),'baz.txt')) end)
                it('', function() assert.Not.out_name_ok(file.join(cwd(),'foo/baz.txt')) end)
                it('', function() pending("") assert.Not.out_name_ok(file.join(texmfoutput.resolve(),'baz.txt')) end)
                it('', function() pending("") assert.Not.out_name_ok(file.join(texmf_output_directory.resolve(),'baz.txt')) end)
            end)

            describe('absolute TEXMFOUTPUT & TEXMF_OUTPUT_DIRECTORY', function()
                setup(function() setenv('p', drive.."/tmp", drive..'/home/user/tex/od') end)
                
                it('', function() assert.Not.out_name_ok(drive..'/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('foo/bar/baz.txt') end)
                it('', function() assert.Not.out_name_ok('../baz.txt') end)
                it('', function() assert.out_name_ok('baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/foo/bar/.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('foo/bar/.baz.txt') end)
                it('', function() assert.Not.out_name_ok('../.baz.txt') end)
                it('', function() assert.Not.out_name_ok('../.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('.baz.txt') end)
                --it('', function() assert.out_name_ok('.tex') end)
                --it('', function() assert.out_name_ok('foo/.tex') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od///./baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/od/foo/../baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp///./baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/tmp/foo/../baz.txt') end)
                it('', function() assert.Not.out_name_ok(drive..'/tmpbaz.txt') end)
                it('', function() assert.Not.out_name_ok(file.join(cwd(),'baz.txt')) end)
                it('', function() assert.Not.out_name_ok(file.join(cwd(),'foo/baz.txt')) end)
            end)
            
            describe('openout_any=r, relative TEXMFOUTPUT & TEXMF_OUTPUT_DIRECTORY', function()
                setup(function() setenv("r", "tmp", "od") end)
                
                it('', function() assert.out_name_ok(drive..'/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('../baz.txt') end)
                it('', function() assert.out_name_ok('baz.txt') end)
                
                --it('', function() uw(assert.Not,assert).out_name_ok(drive..'/foo/bar/.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('foo/bar/.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('../.baz.txt') end)
                it('', function() uw(assert.Not,assert).out_name_ok('.baz.txt') end)
                --it('', function() assert.out_name_ok('.tex') end)
                --it('', function() assert.out_name_ok('foo/.tex') end)

                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od///./baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/foo/../baz.txt') end)

                it('', function() assert.out_name_ok(drive..'/tmp/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp///./baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo/../baz.txt') end)

                it('', function() assert.out_name_ok(file.join(cwd(),'baz.txt')) end)
                it('', function() assert.out_name_ok(file.join(cwd(),'foo/baz.txt')) end)
            end)
            
            describe('openout_any=a', function()
                setup(function() setenv("a") end)
                
                it('', function() assert.out_name_ok('foo.txt') end)
                it('', function() assert.out_name_ok('rel/foo/bar.txt') end)
                it('', function() assert.out_name_ok('../foo.txt') end)
                it('', function() assert.out_name_ok('rel/../foo/bar.txt') end)
                
                it('', function() assert.out_name_ok(drive..'/abs/foo/bar.txt') end)
                it('', function() assert.out_name_ok(drive..'/abs/foo/../bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo/bar.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo/../bar/baz.txt') end)
            end)
            
            describe('openout_any=a, relative TEXMF_OUTPUT_DIRECTORY & TEXMFOUTPUT', function()
                setup(function() setenv('a', 'tmp', 'od') end)
                
                it('', function() assert.out_name_ok(drive..'/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok('../baz.txt') end)
                it('', function() assert.out_name_ok('../baz.txt') end)
                it('', function() assert.out_name_ok('baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/foo/bar/.baz.txt') end)
                it('', function() assert.out_name_ok('foo/bar/.baz.txt') end)
                it('', function() assert.out_name_ok('../.baz.txt') end)
                it('', function() assert.out_name_ok('../.baz.txt') end)
                it('', function() assert.out_name_ok('.baz.txt') end)
                --it('', function() assert.out_name_ok('.tex') end)
                --it('', function() assert.out_name_ok('foo/.tex') end)

                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od///./baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/od/foo/../baz.txt') end)

                it('', function() assert.out_name_ok(drive..'/tmp/foo/bar/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/odbaz.txt') end)
                it('', function() assert.out_name_ok(drive..'/home/user/tex/baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp///./baz.txt') end)
                it('', function() assert.out_name_ok(drive..'/tmp/foo/../baz.txt') end)

                it('', function() assert.out_name_ok(file.join(cwd(),'baz.txt')) end)
                it('', function() assert.out_name_ok(file.join(cwd(),'foo/baz.txt')) end)
            end)
            
        end)

        describe('check_access', function()
            before_each(function() create_test_dir() end)
            it('various file permissions', function()
                local fn = 'file.txt' --no file yet
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
                create(fn) -- +rw
                assert.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('+r-w', fn)
                assert.access_in_ok(fn)
                assert.Not.access_out_ok(fn)
                chmod('-r+w', fn)
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('-r-w', fn)
                assert.Not.access_in_ok(fn)
                assert.Not.access_out_ok(fn)
            end)
            it('no file, various folder permissions', function()
                local dn = 'foo'
                local fn = 'foo/file.txt'  --no file or dir yet
                assert.Not.access_in_ok(fn)
                assert.Not.access_out_ok(fn)
                mkdir(dn) --+rwx dir, no file yet
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('-w+rx', dn)
                assert.Not.access_in_ok(fn)
                assert.Not.access_out_ok(fn)
                chmod('-r+wx', dn)
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('-x+rw', dn)
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
            end)
            it('existing file, various folder and file permissions', function()
                local dn = 'foo'
                local fn = 'foo/file.txt'  --no file or dir yet
                assert.Not.access_in_ok(fn)
                assert.Not.access_out_ok(fn)
                mkdir(dn) --+rwx dir, no file yet
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
                create(fn) -- +rw
                assert.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('-w+rx', dn)
                assert.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('-r+wx', dn)
                assert.access_in_ok(fn)
                assert.access_out_ok(fn)
                chmod('-x+rw', dn)
                assert.Not.access_in_ok(fn)
                assert.access_out_ok(fn)
                
            end)
        end)
        
        describe("#this find_in/out", function()
            
            before_each(function()
                create_test_dir()
                fn = 'file.txt'
                od_fn = 'od/file.txt'
                tmp_fn = 'tmp/file.txt'
            end)
            
            describe('', function()

                it('file does not exist', function()
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                end)

                it('file exists', function()
                    create(fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                end)

                it('same file in other directories is irrelevant', function()
                    mkdir("tmp") mkdir("od")
                    setenv("p")
                    create(fn)
                    
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                    chmod('-r', fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                    chmod('-w', fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                    chmod('+r', fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                    
                end)

                
            end)
            
            describe('TEXMFOUTPUT_is_set', function()
                before_each(function()
                    mkdir("tmp")
                    setenv("p","tmp") 
                end)

                it('file exists nowhere', function()
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                    chmod('-w', '.')
                    assert.find_in(fn, fn)
                    if not on_windows then
                      assert.find_out(fn, tmp_fn)
                    end
                    chmod('-r', '.')
                    assert.equal(me.find_in(fn), fn)
                    if not on_windows then
                      assert.find_out(fn, tmp_fn)
                    end
                    chmod('+w', '.')
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                end)                

                it('file exists in the temporary directory', function()
                    create(tmp_fn)
                    assert.find_in(fn, tmp_fn)
                    assert.find_out(fn, fn)
                    chmod('-w', '.')
                    if not on_windows then
                      assert.find_out(fn, tmp_fn)
                    end
                    chmod('-r', '.')
                    assert.find_in(fn, tmp_fn)
                    if not on_windows then
                      assert.find_out(fn, tmp_fn)
                    end
                    chmod('+w', '.')
                    assert.find_in(fn, tmp_fn)
                    assert.find_out(fn, fn)
                end)
                
            end)

            describe('TEXMF_OUTPUT_DIRECTORY_is_set', function()
                before_each(function()
                    mkdir("od")
                    setenv("p",nil,"od")
                end)

                it('file exists nowhere', function()
                    assert.find_in(fn, fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_in(fn, fn)
                      assert.find_out(fn, od_fn)
                      chmod('+w', 'od')
                    end
                end)

                it('file exists in the current directory', function()
                    create(fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, od_fn)
                end)

                it('file exists in the output directory', function()
                    create(od_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, od_fn)
                    chmod('-x', 'od')
                    if not on_windows then --no directory permissions on windows
                      assert.find_in(fn, fn)
                    end
                    assert.find_out(fn, od_fn)
                    chmod('+x', 'od')
                    if not on_windows then --no directory permissions on windows
                      chmod('-r', od_fn)
                      assert.find_in(fn, fn)
                      chmod('+r', od_fn)
                    end
                    chmod('-w', od_fn)
                    assert.find_out(fn, od_fn)
                    chmod('+w', od_fn)
                end)

                it('file exists in both directories', function()
                    create(fn)
                    create(od_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, od_fn)
                    chmod('-x', 'od')
                    if not on_windows then --no directory permissions on windows
                      assert.find_in(fn, fn)
                    end
                    assert.find_out(fn, od_fn)
                    chmod('+x', 'od')
                end)
                
            end)

            describe("TEXMFOUTPUT_is_set TEXMF_OUTPUT_DIRECTORY_is_set", function()
                before_each(function() 
                    mkdir("tmp")
                    mkdir("od")
                    setenv("p","tmp","od")
                end)

                it('file exists nowhere', function()
                    assert.find_in(fn, fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, tmp_fn)
                    end
                end)

                it('file exists in the current directory', function()
                    create(fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, tmp_fn)
                    end
                end)

                it('file exists in the output directory', function()
                    create(od_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, od_fn)
                      chmod('+w', 'od')
                    end
                    chmod('-w', od_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, tmp_fn)
                    chmod('-r', od_fn)
                    if not on_windows then
                      assert.find_in(fn, fn)
                    end
                    assert.find_out(fn, tmp_fn)
                    chmod('+w', od_fn)
                    if not on_windows then
                      assert.find_in(fn, fn)
                    end
                    assert.find_out(fn, od_fn)
                end)

                it('file exists in the temporary directory', function()
                    create(tmp_fn)
                    assert.find_in(fn, tmp_fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, tmp_fn)
                    end
                end)

                it('file exists in the current and in the output directory', function()
                    create(fn)
                    create(od_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, od_fn)
                    end
                end)

                it('file exists in the current and in the temporary directory', function()
                    create(fn)
                    create(tmp_fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, tmp_fn)
                    end
                end)

                it('file exists in the output and in the temporary directory', function()
                    create(od_fn)
                    create(tmp_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, od_fn)
                    end
                end)
                
                it('file exists in all three directories', function()
                    create(fn)
                    create(od_fn)
                    create(tmp_fn)
                    assert.find_in(fn, od_fn)
                    assert.find_out(fn, od_fn)
                    if not on_windows then --no directory permissions on windows
                      chmod('-w', 'od')
                      assert.find_out(fn, od_fn)
                    end
                end)
            
            end)
        end)
        
    end)
    
end)

-- Local Variables:
-- lua-indent-level: 2
-- End:
