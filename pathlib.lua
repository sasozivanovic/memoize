local pathlib = {}

do
    -- other projects like penlight or l3build do stuff with different pathseps, according to
    -- https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats#canonicalize-separators
    -- and
    -- https://retrocomputing.stackexchange.com/questions/28344/since-when-does-windows-support-forward-slash-as-path-separator
    -- windows since quite a while also works with / as pathsep.
    -- Thus, this pathlib will normalize paths for having / as pathsep before working on paths
    if os.type == "windows" then
        ---Normalize path such that windows also uses /
        ---@param path string
        ---@return string
        function pathlib.path_normalize(path)
            return path:gsub("\\", "/")
        end
    else
        ---Unix already uses / as pathsep -> no-op
        ---@param path string
        ---@return string
        function pathlib.path_normalize(path)
            return path
        end
    end

    -- still windows paths work with disk specifiers -> special handling required
    if os.type == "windows" then
        ---Check if path is an absolute path
        ---NOTE: Windows UNC paths aren't supported
        ---(see https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats#unc-paths)
        ---@param path string
        ---@return boolean? is_abs
        ---@return string? err_msg
        function pathlib.path_is_absolute(path)
            local err
            path, err = pathlib.sanitize_path(path)
            if not path then return nil, err end

            return path:sub(2, 2) == ":" and path:sub(3, 3) == "/"
        end
    else
        ---Check if path is an absolute path
        ---@param path string
        ---@return boolean? is_abs
        ---@return string? err_msg
        function pathlib.path_is_absolute(path)
            local err
            path, err = pathlib.sanitize_path(path)
            if not path then return nil, err end

            if path:match("/%.%.+/") then
                return false
            end

            return path:match("^/") and true or false
        end
    end

    ---check for weird characters in the path
    ---@param path string
    ---@return string path
    ---@overload fun(path:string):nil, string?
    function pathlib.sanitize_path(path)
        if path:match("[%c%%\t\r\n><*|]") then
            return nil, ("Path contains invalid characters: %s"):format(path)
        end
        return path
    end

    ---check for weird characters in the path
    ---same as sanitize_path but includes / and \
    ---@param name string
    ---@return string? name
    ---@overload fun(name:string):nil, string?
    function pathlib.sanitize_name(name)
        if name:match("[%c%%\t\r\n><*|/\\]") then
            return nil, ("File has an invalid name: %s"):format(name)
        end
        return name
    end

    ---check for invalid suffixes
    ---@param suffix string
    ---@return string? suffix
    ---@overload fun(suffix:string):nil, string?
    function pathlib.sanitize_suffix(suffix)
        if suffix:match("[%c%%\t\r\n><*|/\\]") then
            return nil, ("Suffix contains invalid characters: %s"):format(suffix)
        end
        if suffix:match("^%.") then
            return nil, ("Suffix should not start with a dot: %s"):format(suffix)
        end
        if suffix == "" then
            return nil, ("suffix must not be empty")
        end
        return suffix
    end

    ---@param path string
    ---@return string name
    ---@return string remainder
    ---@overload fun(name:string):nil,string?
    function pathlib.name(path)
        path = pathlib.path_normalize(path)

        local err
        path, err = pathlib.sanitize_path(path)
        if not path then return nil, err end

        local r, name = path:match("^(.*)/([^/]+)/?$")
        return name or path, name and r or nil
    end

    ---@param path string
    ---@param name string
    ---@return string
    ---@overload fun(name:string, path:string):nil,string?
    function pathlib.with_name(path, name)
        path = pathlib.path_normalize(path)

        local err
        name, err = pathlib.sanitize_name(name)
        if not name then return nil, err end

        local n, r = pathlib.name(path)
        if not n then return nil, r end

        if r then
            return r .. "/" .. name
        end
        return name
    end

    ---@param path string
    ---@return string suffix
    ---@return string remainder
    ---@overload fun(path:string):nil,string?
    function pathlib.suffix(path)
        path = pathlib.path_normalize(path)

        local err
        path, err = pathlib.sanitize_path(path)
        if not path then return nil, err end

        local r, suffix = path:match("^(.*)%.([^./]*)$")
        if not suffix and path:match("^%.") then
            -- is hidden file
            return "", path
        end
        return suffix or "", r or path
    end

    ---@param path string
    ---@param suffix string
    ---@return string
    ---@overload fun(path:string, suffix:string):nil,string?
    function pathlib.with_suffix(path, suffix)
        path = pathlib.path_normalize(path)

        local err
        suffix, err = pathlib.sanitize_suffix(suffix)
        if not suffix then return nil, err end

        local s, r = pathlib.suffix(path)
        if not s then return nil, r end

        return r .. "." .. suffix
    end

    function pathlib.join(path, ...)
        if not path then return "" end

        path = pathlib.path_normalize(path)

        local err
        path, err = pathlib.sanitize_path(path)
        if not path then return nil, err end

        local r, err = pathlib.join(...)
        if not r then return nil, err end

        if r == "" then return path end

        local p_sep = path:sub(-1, -1) == "/"
        local r_sep = r:sub(1, 1) == "/"

        -- avoid duplicated pathseps
        if p_sep and r_sep then
            -- remove one of the /
            return path .. r:sub(2)
        elseif p_sep or r_sep then
            -- no new / needed
            return path .. r
        else
            -- no / yet present
            return path .. "/" .. r
        end
    end

    function pathlib.iter_path(path)
        path = pathlib.path_normalize(path)
        local root = pathlib.path_is_absolute(path) and "/" or ""
        local drive = ""
        if os.type == "windows" then
            drive = path:match("^%a:")
            if drive then
                path = path:sub(3)
            end
        end
        drive = drive or ""
        local components = {}
        for component in path:gmatch("([^/]+)") do
            table.insert(components, component)
        end
        local idx = 0
        return function()
            idx = idx + 1
            if components[idx] then
                return drive .. root .. table.concat({ table.unpack(components, 1, idx) }, "/")
            else
                return nil
            end
        end
    end
end

return pathlib
