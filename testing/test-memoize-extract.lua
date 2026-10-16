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

-- In general, LUA_PATH and LUA_CPATH are set through the Makefile.  Here, we
-- merely adapt LUA_PATH to load memoize-extract from the parent directory:
package.path = package.path .. ';../?.lua'

cfg = {
  quiet = true,
}

require 'busted.runner'()

local say = require "say"
local md5 = require 'md5'

kpse.set_program_name("luatex")
--require 'lualibs-io'   --extends global io
--require 'lualibs-lpeg' --extends global lpeg, required by lualibs-file
--require 'lualibs-file' --defines global file
--require 'lualibs-dir'  --defines global dir

local utils = require'utils'(cfg)
local mkdir = utils.mkdir
local rmtree = utils.rmtree
local create = utils.create
local chmod = utils.chmod
local execute = utils.execute
local cp = utils.cp
local exists = utils.exists

package.path = package.path .. ';../?.lua'
local real_os_type = os.type
local on_windows = os.type == 'windows'
os.type = 'unix'
local unixme = {}
local unixme_module = utils.require("memoize-extract", unixme, 17)
package.loaded["memoize-extract"] = nil
os.type = 'windows'
local winme = {}
local winme_module = utils.require("memoize-extract", winme, 17)
os.type = real_os_type
local me = on_windows and winme or unixme
local me_module = on_windows and winme_module or unixme_module

local cwd = lfs.currentdir
local function uw(value,win_value)
  return on_windows and win_value or value
end

unixme.exit.error = function() error("exited with error") end
unixme.exit.warn  = function() error("exited with warn") end
unixme.exit.succ  = function() error("exited with succ") end
winme.exit.error = function() error("exited with error") end
winme.exit.warn  = function() error("exited with warn") end
winme.exit.succ  = function() error("exited with succ") end

local function setenv(openout_any, TEXMFOUTPUT, TEXMF_OUTPUT_DIRECTORY)
  os.setenv("openout_any", openout_any)
  os.setenv("TEXMFOUTPUT", TEXMFOUTPUT)
  os.setenv("TEXMF_OUTPUT_DIRECTORY", TEXMF_OUTPUT_DIRECTORY)
end


local original_cwd = cwd()
local src_dir = file.join(original_cwd, 'src')
local function create_test_dir()
  lfs.chdir(original_cwd)
  rmtree("test")
  mkdir("test")
  lfs.chdir("test")
end

describe("unit tests", function()
    
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
        it("should parse a valid path with no name_prefix", function()
            local path = "/dir/prefix/1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-42.pdf"
            local dir_prefix, name_prefix, code_md5sum, context_md5sum = me.split_extern_path(path)
            assert.are.equal(dir_prefix, "/dir/prefix/")
            assert.are.equal(name_prefix, "")
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
       
        describe("split", function()

            local function unixsplit(fn, expected)
              local res = table.pack(unixme.pathlib.split(fn))
              res.n = nil
              assert.same(expected, res)
            end
            local function winsplit(fn, expected)
              local res = table.pack(winme.pathlib.split(fn))
              res.n = nil
              assert.same(expected, res)
            end
            
            describe("#unix", function()
                it("basic", function()
                    unixsplit('/tmp/subdir/foo.memo.dir',
                      {'','/tmp/subdir/','foo.memo.dir'})
                end)
                it("trailing slash implies an empty filename", function()
                    unixsplit('/tmp/subdir/foo.memo.dir/',
                      {'','/tmp/subdir/foo.memo.dir/',''})
                end)
                it("trailing slash*es* imply an empty filename", function()
                    unixsplit('/tmp/subdir/foo.memo.dir//',
                      {'','/tmp/subdir/foo.memo.dir//',''})
                end)
                it("should correctly return the root directory as the dirname", function()
                    unixsplit('/foo', {'','/','foo'})
                end)
                it("should work for relative paths", function()
                    unixsplit('subdir/foo.memo.dir', {'','subdir/','foo.memo.dir'})
                end)
                it("no dir part of the path --> empty dirname", function()
                    unixsplit('foo', {'','','foo'})
                end)
                it("empty path --> all parts empty", function()
                    unixsplit('',{'','',''})
                end)
                it("parent converts empty dirname into .", function()
                    assert.equal('.', unixme.pathlib.parent('foo'))
                end)
                it("empty path --> parent is .", function()
                    assert.equal('.', unixme.pathlib.parent(''))
                end)
                it("parent strips trailing /", function()
                    assert.equal('/foo', unixme.pathlib.parent('/foo/bar'))
                end)                
                it("parent strips trailing /s", function()
                    assert.equal('/foo', unixme.pathlib.parent('/foo//bar'))
                end)                
            end)
            describe("windows", function()
                it("", function()
                    winsplit('C:\\foo\\bar', {'C:', '\\foo\\', 'bar'})
                end)
                it("", function()
                    winsplit('C:/foo/bar', {'C:', '/foo/', 'bar'})
                end)
                it("", function()
                    winsplit('C:foo\\bar', {'C:','foo\\','bar'})
                end)
                it("", function()
                    winsplit('C:foo', {'C:','','foo'})
                end)
                it("", function()
                    winsplit('\\foo\\bar', {'','\\foo\\','bar'})
                end)
                it("", function()
                    winsplit('\\foo\\', {'','\\foo\\',''})
                end)
                it("", function()
                    winsplit('\\foo', {'','\\','foo'})
                end)
                it("", function()
                    winsplit('C:\\foo', {'C:','\\','foo'})
                end)
                it("", function()
                    assert.equal('C:.', winme.pathlib.parent('C:foo'))
                end)
                it("", function()
                    assert.equal('C:\\foo', winme.pathlib.parent('C:\\foo\\bar'))
                end)
            end)
        end)
    end)
    
    describe("#permissions", function()

        it("These tests should be run without TEXMFOUTPUT set in texmf.cnf", function()
            assert(not kpse.var_value("TEXMFOUTPUT"))
        end)
        
        strict_setup(function()
            setenv('p')
            drive = on_windows and 'C:' or ''
        end)
        
        describe("find_in/out", function()
            
            local function find_in(state, args)
              local result = me.find_in(args[1], 'r')
              local success = result == args[2]
              args[1] = tostring(args[1])
              args[2] = tostring(args[2])
              args[3] = tostring(result)
              return success
            end
            say:set("assertion.find_in.positive", "Expected find_in(%s) --> %s, got %s")
            assert:register("assertion", "find_in", find_in, "assertion.find_in.positive")
            
            --find_out must be the last test in every "it", because it might create a file
            local function find_out(state, args)
              local result = me.find_out(args[1], 'w')
              local success = result == args[2]
              args[1] = tostring(args[1])
              args[2] = tostring(args[2])
              args[3] = tostring(result)
              return success
            end
            say:set("assertion.find_out.positive", "Expected find_out(%s) --> %s, got %s")
            assert:register("assertion", "find_out", find_out, "assertion.find_out.positive")

            before_each(function()
                create_test_dir()
                setenv("p")
                fn = 'file.txt'
                od_fn = 'od/file.txt'
                tmp_fn = 'tmp/file.txt'
            end)
            
            describe('', function()

                it('file does not exist', function()
                    assert.find_in(fn, nil)
                    assert.find_out(fn, fn)
                end)

                it('file exists', function()
                    create(fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, fn)
                end)

                describe('same file in other directories is irrelevant', function()
                    before_each(function()
                        mkdir("tmp")
                        mkdir("od")
                        create(fn)
                        create(od_fn)
                        create(tmp_fn)
                    end)
                    it('fn=+rw', function()
                        assert.find_in(fn, fn)
                        assert.find_out(fn, fn)
                    end)
                    it('fn=-r+w', function()
                        chmod('-r', fn)
                        assert.find_in(fn, nil)
                        assert.find_out(fn, fn)
                    end)
                    it('fn=-rw', function()
                        chmod('-rw', fn)
                        assert.find_in(fn, nil)
                        assert.find_out(fn, nil)
                    end)
                    it('fn=+r-w', function()
                        chmod('-w', fn)
                        assert.find_in(fn, fn)
                        assert.find_out(fn, nil)
                    end)
                end)

                
            end)
            
            describe('TEXMFOUTPUT_is_set', function()
                before_each(function()
                    mkdir("tmp")
                    setenv("p","tmp") 
                end)
                
                describe('file exists nowhere', function()
                    it('+rw', function()
                        assert.find_in(fn, nil)
                        assert.find_out(fn, fn)
                    end)
                    it('+r-w', function()
			chmod('-w', '.')
			assert.find_in(fn, nil)
			assert.find_out(fn, tmp_fn)
                    end)
                    it('-r-w', function()
			chmod('-rw', '.')
			assert.find_in(fn, nil)
			assert.find_out(fn, tmp_fn)
                    end)
                    it('-r+w', function()
                        chmod('-r', '.')
                        assert.find_in(fn, nil)
                        assert.find_out(fn, fn)
                    end)
                end)               

                describe('file exists in the temporary directory', function()
                    before_each(function()
                        create(tmp_fn)
                    end)
                    it('+rw', function()
                        assert.find_in(fn, tmp_fn)
                        assert.find_out(fn, fn)
                    end)
                    it('+r-w', function()
			chmod('-w', '.')
			assert.find_in(fn, tmp_fn)
			assert.find_out(fn, tmp_fn)
                    end)
                    it('-rw', function()
			chmod('-rw', '.')
			assert.find_in(fn, tmp_fn)
			assert.find_out(fn, tmp_fn)
                    end)
                    it('-r+w', function()
                        chmod('-r', '.')
                        assert.find_in(fn, tmp_fn)
                        assert.find_out(fn, fn)
                    end)
                end)
                
            end)

            describe('TEXMF_OUTPUT_DIRECTORY_is_set', function()
                before_each(function()
                    mkdir("od")
                    setenv("p",nil,"od")
                end)

                describe('file exists nowhere', function()
                    it('od=+rw', function()
                        assert.find_in(fn, nil)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=+r-w', function()
			chmod('-w', 'od')
			assert.find_in(fn, nil)
			assert.find_out(fn, nil)
                    end)
                end)

                it('file exists in the current directory', function()
                    create(fn)
                    assert.find_in(fn, fn)
                    assert.find_out(fn, od_fn)
                end)

                describe('file exists in the output directory', function()
                    before_each(function()
                        create(od_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-x', function()
			chmod('-x', 'od')
			assert.find_in(fn, nil)
			assert.find_out(fn, nil)
                    end)
                    it('od=-r', function()
			chmod('-r', od_fn)
			assert.find_in(fn, nil)
                    end)
                    it('od_fn=-w', function()
                        chmod('-w', od_fn)
                        assert.find_out(fn, nil)
                    end)
                end)

                describe('file exists in both directories', function()
                    before_each(function()
                        create(fn)
                        create(od_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-x', function()
			chmod('-x', 'od')
			assert.find_in(fn, fn)
			assert.find_out(fn, nil)
                    end)
                end)
                
            end)

            describe("TEXMFOUTPUT_is_set TEXMF_OUTPUT_DIRECTORY_is_set", function()
                before_each(function() 
                    mkdir("tmp")
                    mkdir("od")
                    setenv("p","tmp","od")
                end)

                describe('file exists nowhere', function()
                    it('', function()
                        assert.find_in(fn, nil)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, tmp_fn)
                    end)
                end)

                describe('file exists in the current directory', function()
                    before_each(function() 
                        create(fn)
                    end)
                    it('', function()
                        assert.find_in(fn, fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, tmp_fn)
                    end)
                end)

                describe('file exists in the output directory', function()
                    before_each(function()
                        create(od_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, od_fn)
                    end)
                    it('od_fn=+r-w', function()
                        chmod('-w', od_fn)
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, tmp_fn)
                    end)
                    it('od_fn=-rw', function()
			chmod('-rw', od_fn)
			assert.find_in(fn, nil)
			assert.find_out(fn, tmp_fn)
                    end)
                    it('od_fn=-r+w', function()
			chmod('-r', od_fn)
			assert.find_in(fn, nil)
			assert.find_out(fn, od_fn)
                    end)
                end)

                describe('file exists in the temporary directory', function()
                    before_each(function()
                        create(tmp_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, tmp_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, tmp_fn)
                    end)
                end)

                describe('file exists in the current and in the output directory', function()
                    before_each(function()
                        create(fn)
                        create(od_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, od_fn)
                    end)
                    it('od_fn=-w', function()
			chmod('-w', od_fn)
			assert.find_out(fn, tmp_fn)
                    end)
                end)

                describe('file exists in the current and in the temporary directory', function()
                    before_each(function()
                        create(fn)
                        create(tmp_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, tmp_fn)
                    end)
                end)

                describe('file exists in the output and in the temporary directory', function()
                    before_each(function() 
                        create(od_fn)
                        create(tmp_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, od_fn)
                    end)
                    it('od_fn=-w', function()
			chmod('-w', od_fn)
			assert.find_out(fn, tmp_fn)
                    end)
                end)
                
                describe('file exists in all three directories', function()
                    before_each(function() 
                        create(fn)
                        create(od_fn)
                        create(tmp_fn)
                    end)
                    it('', function()
                        assert.find_in(fn, od_fn)
                        assert.find_out(fn, od_fn)
                    end)
                    it('od=-w', function()
			chmod('-w', 'od')
			assert.find_out(fn, od_fn)
                    end)
                    it('od_fn=-w', function()
			chmod('-w', od_fn)
			assert.find_out(fn, tmp_fn)
                    end)
                end)
            
            end)
        end)
    end)
end)

local function prepare_sources(opt)
  local doc_template = assert(io.loaddata(file.join(src_dir, opt.src)), "Cannot load " .. tostring(opt.src))
  local doc_content = doc_template:format(table.unpack(opt.content_params))
  local target_path = opt.target or 'doc.tex'
  local target = file.nameonly(target_path)
  io.savedata(('%s.tex'):format(target), doc_content)
  return target
end

local function compile(opt)
  --opt: .src .content_params .target .cmd
  local target = prepare_sources(opt)
  execute(("%s -interaction batchmode '%s'"):format(opt.cmd, target))
  --check compilation results
  assert.exists(('%s.pdf'):format(target))
  assert.exists(('%s.log'):format(target))
  if opt.cmd:find("la") then --latex also produces an .aux file
    assert.exists(('%s.aux'):format(target))
  end
  return ('%s.pdf'):format(target)
end

local function compile_and_extract(opt)
  local pdf_fn = compile(opt)
  assert.memos_exist(opt.prefix, "extern", "")
  assert.memos_exist(opt.prefix, "another extern", "")
  assert.execute(('memoize-extract %s "%s"'):format(opt.opts or '', pdf_fn))
  assert.extern_exists(opt.prefix, "extern", "")
  assert.extern_exists(opt.prefix, "another extern", "")
  return pdf_fn
end

function md5.HEX(str)
  return md5.sumhexa(str):upper()
end

local function memos_exist(state, args)
  local prefix, externalized_code, context = table.unpack(args)
  local cmemo = ('%s%s.memo'):format(prefix, md5.HEX(externalized_code))
  local ccmemo = ('%s%s-%s.memo'):format(prefix, md5.HEX(externalized_code), md5.HEX(context))
  args[1] = ('%s%s(-%s).memo'):format(prefix, md5.HEX(externalized_code), md5.HEX(context))
  return (lfs.attributes(cmemo, "mode")) and (lfs.attributes(ccmemo, "mode"))
end
say:set("assertion.memos_exist.positive", "Expected memos to exist: %s")
say:set("assertion.memos_exist.negative", "Expected memos to not exist: %s")
assert:register("assertion", "memos_exist", memos_exist, "assertion.memos_exist.positive", "assertion.memos_exist.negative")

local function extern_exists(state, args)
  local prefix, externalized_code, context = table.unpack(args)
  local extern = ('%s%s-%s.pdf'):format(prefix, md5.HEX(externalized_code), md5.HEX(context))
  args[1] = extern
  return (lfs.attributes(extern, "mode"))
end
say:set("assertion.extern_exists.positive", "Expected extern to exist: %s")
say:set("assertion.extern_exists.negative", "Expected extern to not exist: %s")
assert:register("assertion", "extern_exists", extern_exists, "assertion.extern_exists.positive", "assertion.extern_exists.negative")

local function npages(state, args)
  local fn, expected_n = table.unpack(args)
  local pdf = pdfe.open(fn)
  if not pdf then error("Cannot open " .. fn) end
  local n = pdfe.getnofpages(pdf)
  pdfe.close(pdf)
  args[3] = n
  return n == expected_n
end
say:set("assertion.npages.positive", "Expected file %s to have to %s pages, but it has %s")
assert:register("assertion", "npages", npages, "assertion.npages.positive")

describe('memoize-extract', function()

    setup(function()
        require 'lualibs-io'
        setenv('p')
    end)

    describe("#mkdir", function()
        
        before_each(function()
            create_test_dir()
            setenv("p")
        end)

        it('create a subdir', function()
            assert.execute("memoize-extract --mkdir foo")
            assert.exists("foo")
        end)
        
        it("don't create a parallel dir", function()
            mkdir("foo") lfs.chdir("foo")
            assert.Not.execute("memoize-extract --mkdir ../bar")
            assert.Not.exists("bar")
        end)
        
        it('create a subsubdir', function()
            assert.execute("memoize-extract --mkdir foo/bar")
            assert.exists("foo/bar")
        end)
        
        it("don't create a subdir containing ..", function()
            assert.Not.execute("memoize-extract --mkdir foo/bar/../baz")
            assert.Not.exists("foo/baz")
        end)

        --todo: TEXMF_*
        
    end)
    
    describe('', function()

        before_each(function()
            create_test_dir()
            setenv('p')
        end)

        describe('extraction with no memo dir, all engines and formats', function()
            
            it('pdftex', function() compile_and_extract({
                    src = 'doc_plain.tex', content_params = { 'no memo dir' }, cmd = 'pdftex', prefix = 'doc.'
            }) end)
            it('xetex', function() compile_and_extract({
                    src = 'doc_plain.tex', content_params = { 'no memo dir' }, cmd = 'xetex', prefix = 'doc.'
            }) end)
            it('luatex', function() compile_and_extract({
                    src = 'doc_plain.tex', content_params = { 'no memo dir' }, cmd = 'luatex', prefix = 'doc.'
            }) end)

            it('pdflatex', function() compile_and_extract({
                    src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex', prefix = 'doc.',
            }) end)
            it('xelatex', function() compile_and_extract({
                    src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'xelatex', prefix = 'doc.',
            }) end)
            it('lualatex', function() compile_and_extract({
                    src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'lualatex', prefix = 'doc.',
            }) end)

        end)
        
        describe('extraction with memo dir, all engines and formats', function()
            
            it('pdftex', function() compile_and_extract({
                    src = 'doc_plain.tex', content_params = { 'memo dir' }, cmd = 'pdftex', prefix = 'doc.memo.dir/',
            }) end)
            it('xetex', function() compile_and_extract({
                    src = 'doc_plain.tex', content_params = { 'memo dir' }, cmd = 'xetex', prefix = 'doc.memo.dir/',
            }) end)
            it('luatex', function() compile_and_extract({
                    src = 'doc_plain.tex', content_params = { 'memo dir' }, cmd = 'luatex', prefix = 'doc.memo.dir/',
            }) end)
            
            it('pdflatex', function() compile_and_extract({
                    src = 'doc_latex.tex', content_params = { 'memo dir' }, cmd = 'pdflatex', prefix = 'doc.memo.dir/',
            }) end)
            it('xelatex', function() compile_and_extract({
                    src = 'doc_latex.tex', content_params = { 'memo dir' }, cmd = 'xelatex', prefix = 'doc.memo.dir/',
            }) end)
            it('lualatex', function() compile_and_extract({
                    src = 'doc_latex.tex', content_params = { 'memo dir' }, cmd = 'lualatex', prefix = 'doc.memo.dir/',
            }) end)

        end)

        describe('spaces in file names', function()
            
            it('pdftex', function()
                compile_and_extract({
                    src = 'doc_plain.tex', target = 'doc with spaces.tex', content_params = { 'prefix=doc with spaces.memo.dir/prefix with spaces.' },
                    cmd = 'pdftex', prefix = 'doc with spaces.memo.dir/prefix with spaces.',
            }) end)

            it('pdflatex', function()
                compile_and_extract({
                    src = 'doc_latex.tex', target = 'doc with spaces.tex', content_params = { 'prefix=doc with spaces.memo.dir/prefix with spaces.' },
                    cmd = 'pdflatex', prefix = 'doc with spaces.memo.dir/prefix with spaces.',
            }) end)
            
        end)

        describe("removed memo files", function()

            before_each(function()
                compile({src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex'})
                os.remove(('doc.%s.memo'):format(md5.HEX("extern")))
                os.remove(('doc.%s.memo'):format(md5.HEX("another extern")))
                os.remove(('doc.%s-%s.memo'):format(md5.HEX("extern"), md5.HEX("")))
                os.remove(('doc.%s-%s.memo'):format(md5.HEX("another extern"), md5.HEX("")))
            end)
            
            it('refuse extraction', function()
                assert.Not.execute('memoize-extract doc.pdf')
                assert.Not.extern_exists("doc.", "extern", "")
                assert.Not.extern_exists("doc.", "another extern", "")
            end)
            
            it('forced extraction', function()
                assert.execute('memoize-extract -f doc.pdf')
                assert.extern_exists("doc.", "extern", "")
                assert.extern_exists("doc.", "another extern", "")
            end)
        end)

        describe("#prune", function()
            
            it("should remove extern pages from the pdf", function()
                local pdf_fn = compile({src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex'})
                assert.memos_exist('doc.', "extern", "")
                assert.memos_exist('doc.', "another extern", "")
                assert.npages(pdf_fn, 3)
                
                assert.execute('memoize-extract -p doc.pdf')
                assert.extern_exists('doc.', "extern", "", true)
                assert.extern_exists('doc.', "another extern", "", true)
                assert.npages(pdf_fn, 1)
            end)

            it("another extraction after pruning is ok", function()
                compile_and_extract({src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex', prefix = 'doc.', opts = '-p'})
                os.remove(('%s%s-%s.pdf'):format(prefix, md5.HEX("extern"), md5.HEX("")))
                os.remove(('%s%s-%s.pdf'):format(prefix, md5.HEX("another extern"), md5.HEX("")))
                assert.npages("doc.pdf", 1)
                assert.execute('memoize-extract doc.pdf')
                assert.extern_exists('doc.', "extern", "")
                assert.extern_exists('doc.', "another extern", "")
            end)
            
        end)
        
    end)

    describe('Extraction from a PDF in a subdirectory', function()
        
        lazy_setup(function()
            create_test_dir()
            setenv("p")
            mkdir("foo")
            lfs.chdir("foo")
            compile({src = 'doc_plain.tex', content_params = { 'no memo dir' }, cmd = 'pdftex'})
            lfs.chdir("..")
        end)

        it('fail because no memos', function()
            assert.Not.execute('memoize-extract foo/doc.pdf')
            assert.Not.extern_exists("foo/doc.", "extern", "")
            assert.Not.extern_exists("foo/doc.", "another extern", "")
        end)

        it('ok because forced', function()
            assert.execute('memoize-extract -f foo/doc.pdf')
        end)

        it('ok because we have memos now', function()
            cp(('foo/doc.%s.memo'):format(md5.HEX("extern")), ".")
            cp(('foo/doc.%s-%s.memo'):format(md5.HEX("extern"),md5.HEX("")), ".")
            cp(('foo/doc.%s.memo'):format(md5.HEX("another extern")), ".")
            cp(('foo/doc.%s-%s.memo'):format(md5.HEX("another extern"),md5.HEX("")), ".")
            assert.execute('memoize-extract foo/doc.pdf')
        end)
        
        it('pruning is fine', function()
            assert.execute('memoize-extract -pf foo/doc.pdf')
        end)
        
    end)

    describe('Extraction from a PDF in a parallel directory', function()

        lazy_setup(function()
            create_test_dir()
            setenv("p")
            mkdir("foo") mkdir("bar")
            lfs.chdir("foo")
            compile({src = 'doc_plain.tex', content_params = { 'memo dir' }, cmd = 'pdftex'})
            lfs.chdir("../bar")
        end)

        it("fail with pruning", function()
            assert.Not.execute('memoize-extract -pf ../foo/doc.pdf')
            assert.Not.extern_exists("../foo/doc.", "extern", "")
            assert.Not.extern_exists("../foo/doc.", "another extern", "")
            assert.npages("../foo/doc.pdf", 3)
        end)

        it("fail without -f", function()
            assert.Not.execute('memoize-extract ../foo/doc.pdf')
            assert.Not.extern_exists("../foo/doc.", "extern", "")
            assert.Not.extern_exists("../foo/doc.", "another extern", "")
        end)
        
        it("succeed with -f", function()
            assert.execute('memoize-extract -f ../foo/doc.pdf')
        end)
        
    end)

    describe('TEXMFOUTPUT', function()

        --This test would fail with latex, because compilation couldn't open .aux
        it("current dir not writable, extract into temp dir", function()
            create_test_dir()
            mkdir("tmp")
            setenv("p", "tmp")
            prepare_sources({src = 'doc_plain.tex', content_params = { 'no memo dir' }})
            chmod("-w", ".")
            assert.execute('pdftex doc')
            assert.exists("tmp/doc.pdf")
            assert.exists("tmp/doc.log")
            assert.execute('memoize-extract doc.pdf')
            assert.extern_exists('tmp/doc.', 'extern', '')
            assert.extern_exists('tmp/doc.', 'another extern', '')
        end)

        it("current dir not writable, non-existing temp dir", function()
            create_test_dir()
            setenv("p", "bad_tmp")
            compile({src = 'doc_plain.tex', content_params = { 'no memo dir' }, cmd = 'pdftex'})
            chmod("-w", ".")
            assert.Not.execute('memoize-extract doc.pdf')
            assert.Not.extern_exists("doc.", "extern", "")
            assert.Not.extern_exists("doc.", "another extern", "")
        end)

        it("current dir not writable, temp dir outside .", function()
            create_test_dir()
            mkdir("foo") mkdir("tmp") lfs.chdir("foo")
            setenv("p")
            compile({src = 'doc_plain.tex', content_params = { 'no memo dir' }, cmd = 'pdftex'})
            setenv("p", "../tmp")
            chmod("-w", ".")
            assert.Not.execute('memoize-extract doc.pdf')
            assert.Not.extern_exists("doc.", "extern", "")
            assert.Not.extern_exists("doc.", "another extern", "")
        end)
        
    end)

    describe('TEXMF_OUTPUT_DIRECTORY', function()

        before_each(function()
            create_test_dir()
            mkdir("od")
            setenv("p", nil, "od")
        end)
        
        it("", function()
            prepare_sources({src = 'doc_latex.tex', content_params = { 'no memo dir' }})
            assert.execute('pdflatex doc')
            assert.exists("od/doc.pdf")
            assert.exists("od/doc.log")
            assert.exists("od/doc.aux")
            assert.execute('memoize-extract doc.pdf')
            assert.extern_exists('od/doc.', 'extern', '')
            assert.extern_exists('od/doc.', 'another extern', '')
            --pruning works too
            assert.execute('memoize-extract -p doc.pdf')
            assert.npages("od/doc.pdf", 1)
        end)

        it("", function()
            prepare_sources({src = 'doc_latex.tex', content_params = { 'no memo dir' }})
            assert.execute('pdflatex doc')
            assert.exists("od/doc.pdf")
            assert.exists("od/doc.log")
            assert.exists("od/doc.aux")
            chmod("-w", "od")
            assert.Not.execute('memoize-extract doc.pdf')
            assert.Not.extern_exists("od/doc.", "extern", "")
            assert.Not.extern_exists("od/doc.", "another extern", "")
        end)
        
    end)

    describe('output format', function()

        before_each(function()
            create_test_dir()
            setenv("p")
            P = lpeg.P
        end)
        
        it("all good", function()
            compile_and_extract({src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex', prefix = 'doc.', opts = '-F latex'})
            assert.content("doc.mmz.log", {
                P"\\PackageInfo",
                P"\\PackageInfo",
                P"\\PackageInfo",
                P"\\PackageInfo",
                P"\\endinput",
            })
        end)

        it("no doc", function()
            execute("memoize-extract -F latex nodoc.pdf")
            assert.content("nodoc.mmz.log", {
                P"\\PackageInfo",
                P"\\endinput",
            })
        end)

        it("no memos", function()
            compile({src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex'})
            os.remove(('doc.%s.memo'):format(md5.HEX("extern")))
            os.remove(('doc.%s-%s.memo'):format(md5.HEX("extern"),md5.HEX("")))
            execute("memoize-extract -F latex doc.pdf")
            assert.content("doc.mmz.log", {
                P"\\PackageInfo",
                P"\\PackageWarning",
                P"\\PackageInfo",
                P"\\PackageInfo",
                P"\\endinput",
            })
        end)
        
        it("non-writable pdf", function()
            compile({src = 'doc_latex.tex', content_params = { 'no memo dir' }, cmd = 'pdflatex'})
            chmod('-w', 'doc.pdf')
            execute("memoize-extract -F latex --prune doc.pdf")
            assert.content("doc.mmz.log", {
                P"\\PackageError",
                P"\\endinput",
            })
        end)
    end)
    
end)

-- Local Variables:
-- lua-indent-level: 2
-- End:
