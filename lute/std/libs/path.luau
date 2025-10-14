local system = require("@lute/system")

export type PathObj = {
    parts: { string },
    isAbsolute: boolean,
    isUNCPath: boolean,
    driveLetter: string?,
    isWindows: boolean
}

export type PathLike = string | PathObj

function basename(path: PathLike): string?
    if typeof(path) == "string" then
        path = parse(path)
    end
    path = path :: PathObj
    return if #path.parts > 0 then path.parts[#path.parts] else nil
end

function dirname(path: PathLike): string
    if typeof(path) == "string" then
        path = parse(path)
    end

    path = path :: PathObj

    if #path.parts == 0 then
        return format(path)
    else
        return format({
            parts = { table.unpack(path.parts, 1, #path.parts - 1) },
            isAbsolute = path.isAbsolute,
            isUNCPath = path.isUNCPath,
            driveLetter = path.driveLetter,
            isWindows = path.isWindows
        })
    end
end

function extname(path: PathLike): string
    if typeof(path) == "string" then
        path = parse(path)
    end

    path = path :: PathObj

    if #path.parts == 0 then
        return ""
    end

    local filename = path.parts[#path.parts]

    if filename == "." or filename == ".." then
        return ""
    end

    local dotIndex, _ = filename:find("%.[^%.]*$")
    if dotIndex == nil or dotIndex == 1 then
        return ""
    end
    
    return filename:sub(dotIndex)
end

function format(path: PathLike): string
    if typeof(path) == "string" then
        return path
    end

    path = path :: PathObj

    if #path.parts == 0 then
        if path.isWindows then
            if path.isUNCPath then
                return "\\\\"
            elseif path.driveLetter ~= nil then
                return path.driveLetter .. ":" .. (if path.isAbsolute then "\\" else "")
            else
                return "."
            end
        else
            return if path.isAbsolute then "/" else "."
        end
    elseif path.isWindows then
        if path.isUNCPath then
            return "\\\\" .. table.concat(path.parts, "\\")
        elseif path.driveLetter ~= nil then
            local drive = path.driveLetter .. ":"
            if path.isAbsolute then
                drive = drive .. "\\"
            end
            return drive .. table.concat(path.parts, "\\")
        else
            return table.concat(path.parts, "\\")
        end
    else
        return (if path.isAbsolute then "/" else "") .. table.concat(path.parts, "/")
    end
end

function isabsolute(path: PathLike): boolean
    if typeof(path) == "table" then
        return path.isAbsolute
    end
    error("TODO")
end

function join(parts: { PathLike }): string
    return table.concat(parts, "/")
end

function normalize(path: PathLike): string
    error("TODO")
end

function parse(path: PathLike): PathObj
    if typeof(path) == "table" then
        return path
    end
    if typeof(path) ~= "string" then
        error("Expected string or PathObj")
    end
    
    local isAbs = false
    local isUNC = false
    local driveLetter = nil
    
    -- If the path contains a backslash, treat it as a Windows path
    local isWindows = string.find(path, "\\") ~= nil

    -- Check if path is absolute and if it's a UNC path on Windows
    if isWindows then
        if string.sub(path, 1, 2) == "\\\\" then
            -- UNC path
            isAbs = true
            isUNC = true
        elseif string.match(path, "^%a:") ~= nil then
            driveLetter = string.sub(path, 1, 1)
            -- Windows: starts with drive letter + backslash (C:\)
            isAbs = string.sub(path, 3, 3) == "\\"
        end
    else
        -- Unix-like: starts with /
        isAbs = string.sub(path, 1, 1) == "/"
    end

    local parts = {}
    if isWindows then
        -- Windows supports mixed separators, so sub forward slashes for backslashes first
        path = path:gsub("/", "\\")

        if isUNC then
            -- Strip out the leading \\ for UNC paths
            parts = path:sub(3):split("\\")
        elseif isAbs then
            -- Strip out the drive letter, colon, and backslash (C:\)
            parts = path:sub(4):split("\\")
        elseif driveLetter ~= nil then
            -- Strip out the drive letter and colon (C:)
            parts = path:sub(3):split("\\")
        else
            parts = path:split("\\")
        end
    else
        -- Unix-like
        if isAbs then
            -- Strip out the leading / for absolute paths
            parts = path:sub(2):split("/")
        else
            parts = path:split("/")
        end
    end

    -- Filter out empty parts (can happen with leading/trailing separators)
    if #parts > 0 then
        if parts[#parts] == "" then
            table.remove(parts, #parts)
        end
        if #parts > 0 and parts[1] == "" then
            table.remove(parts, 1)
        end
    end
    
    return {
        parts = parts,
        isAbsolute = isAbs,
        isUNCPath = isUNC,
        driveLetter = driveLetter,
        isWindows = isWindows
    }
end

function resolve(parts: { PathLike }): string
    error("TODO")
end

return table.freeze(
    {
        basename = basename,
        dirname = dirname,
        extname = extname,
        format = format,
        isAbsolute = isabsolute,
        join = join,
        normalize = normalize,
        parse = parse,
        resolve = resolve
    }
)