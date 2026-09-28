local utils = {}

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

return utils
