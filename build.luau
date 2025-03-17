--[[
    Used to build the rbxts version.
]]

--!strict
local fs = require("@lune/fs")

local SRC_PATH = "./src"
local OUT_PATH = "./rbxts/src"
local INCLUDE_PATH = `./rbxts/include`
local OTHER_INCLUDED_PATHS = {
    "LICENSE.md",
    "default.project.json"
}

if fs.isDir(OUT_PATH) then fs.removeDir(OUT_PATH) end
fs.writeDir(OUT_PATH)

local function CopyDirContentsRecursiveMain(cloneFromPath: string, cloneToPath: string)
    local cloneFromDir = fs.readDir(cloneFromPath)

    for _, entryPath in cloneFromDir do
        local fullEntryPath = `{cloneFromPath}/{entryPath}`
        local cloneToFullEntryPath = `{cloneToPath}/{entryPath}`

        if fs.isDir(fullEntryPath) then
            fs.writeDir(cloneToFullEntryPath)
            CopyDirContentsRecursiveMain(fullEntryPath, cloneToFullEntryPath)

        else
            fs.writeFile(cloneToFullEntryPath, fs.readFile(fullEntryPath))
        end
    end
end

-- this function exists because `fs.copy` overwrites everything instead of just the conflicts.
local function CopyDirContentsRecursive(cloneFromPath: string, cloneToPath: string)
    if not fs.isDir(cloneFromPath) then
        print(`Skipping "{cloneFromPath}": Not a valid directory!`)
        return
    end

    if not fs.isDir(cloneToPath) then fs.writeDir(cloneToPath) end

    return CopyDirContentsRecursiveMain(cloneFromPath, cloneToPath)
end

CopyDirContentsRecursive(SRC_PATH, OUT_PATH)
CopyDirContentsRecursive(INCLUDE_PATH, OUT_PATH)
for _, path in OTHER_INCLUDED_PATHS do
    fs.copy(path, `{OUT_PATH}/../{path}`, true)
end
