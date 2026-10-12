require 'lualibs-io'   --extends global io
require 'lualibs-lpeg' --extends global lpeg, required by lualibs-file
require 'lualibs-file' --defines global file
require 'lualibs-dir'  --defines global dir

local busted = require 'busted'
--local assert = busted.assert
local say = require "say"

local on_windows = os.type == 'windows'

local utils = {}
local cfg

--Require module "name", collecting into table "tbl" (a) its locals and (b) any
--functions defined in the module executed during the loading of the module.
function utils.require(name, tbl, magic_depth)
    magic_depth = magic_depth or 6
    function store(_event)
	local info = debug.getinfo(2)
	if info.name and info.source:find(name..".lua", 1, true) then
	    tbl[info.name] = info.func
	elseif info.what == 'main' and not debug.getinfo(magic_depth) then
	    utils.getlocals(3, tbl)
	end
    end
    debug.sethook(store, 'r')
    local module = require(name)
    debug.sethook(nil, 'r')
    return module
end

--Store upvalues/locals of function "f" into table "t". If "which" is given, is
--should be an array of names to store; if not given, all upvalues are
--retrieved.
local function get(f, tbl, which, debug_f, what)
    if which then
	for _, name in ipairs(which) do which[name] = name end
    end
    local i = 1
    repeat
	local var, val = debug_f(f, i)
	local target = which and which[var] or var
	if tbl[target] then
	    if tbl[target] ~= val then
		print(("Cannot store %s '%s', name already exists"):format(what, target))
	    end
	elseif target and target:sub(1,1) ~= '(' then
	    tbl[target] = val
	end
	i = i + 1
    until not var
end

function utils.getupvalues(f, tbl, which)
    return get(f, tbl, which, debug.getupvalue, "upvalue")
end

function utils.getlocals(f, tbl, which)
    return get(f, tbl, which, debug.getlocal, "local")
end

function utils.mkdir(fn)
    assert(lfs.mkdir(fn), 'Cannot create directory ' .. fn)
    return fn
end

function utils.rmtree(dn)
    if on_windows then
	assert(os.execute(('icacls "%s" /remove:d "%%USERNAME%%" /T /C'):format(dn))==0)
	assert(os.execute(('rmdir /s/q "%s"'):format(dn))==0)
    else
	assert(os.execute(('chmod -R --quiet +rwx "%s"'):format(dn))==0)
	assert(os.execute(('rm -rf "%s"'):format(dn))==0)
    end
end  

function utils.create(fn, text)
    local fh = io.open(fn, 'w')
    assert(fh, "Cannot open " .. fn)
    if text then
	fh:write(text)
    end
    fh:close()
    return fn
end

-- allow only removing permissions ... easier to translate from chmod to icacls
allowed_modes = lpeg.P("-") * lpeg.S("rwx")^1
function utils.chmod(mode, fn)
    assert(lpeg.match(allowed_modes, mode))
    if on_windows then
	assert(os.execute(('icacls "%s" /deny "%%USERNAME%%":(%s) ')
		:format(fn, mode:sub(2):upper()))==0)
    else
	assert(os.execute(("chmod %s '%s'"):format(mode, fn))==0)
    end
end

function utils.execute(cmd)
    if cfg.quiet then
	local proc = io.popen(cmd)
	while proc:read() do end
	return proc:close()
    else
	return os.execute(cmd)
    end
end

local function assert_execute(state, args)
    local res = utils.execute(args[1])
    return res == 0 or res == true
end
say:set("assertion.execute.positive", "Expected successful execution of %s")
say:set("assertion.execute.negative", "Expected unsuccessful execution of %s")
busted.assert:register("assertion", "execute", assert_execute,
    "assertion.execute.positive", "assertion.execute.negative")

function utils.cp(from, to)
    if on_windows then
	os.execute(('copy "%s" "%s"'):format(from, to))
    else
	os.execute(('cp "%s" "%s"'):format(from, to))
    end
end

function utils.exists(state, args)
    return (lfs.attributes(args[1], "mode"))
end
say:set("assertion.exists.positive", "Expected file %s to exist")
say:set("assertion.exists.negative", "Expected file %s to not exist")
busted.assert:register("assertion", "exists", utils.exists,
    "assertion.exists.positive", "assertion.exists.negative")

local function assert_content(state, args)
    local fn, expected_lines = table.unpack(args)
    local fh = io.open(fn)
    lines = fh:lines()
    for n, eline in ipairs(expected_lines) do
	line = lines()
	if line then
	    if not lpeg.match(eline, line) then
		args[2] = n
		args[3] = line
		return false
	    end
	else
	    args[2] = 'missing'
	    args[3] = ''
	    return false
	end
    end
    line = lines()
    if line then
	args[2] = 'at the end'
	args[3] = line
	return false
    end
    return true
end
say:set("assertion.content.positive", "File %s, unexpected line %s:\n%s")
busted.assert:register("assertion", "content", assert_content,
    "assertion.content.positive")

return function(conf)
    cfg = conf
    return utils
end
