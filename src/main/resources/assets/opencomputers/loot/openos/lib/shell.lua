local fs = require("filesystem")
local text = require("text")
local unicode = require("unicode")
local process = require("process")

local shell = {}

-- Cache loaded shells for command execution. This puts the requirement on
-- shells that they do not keep a global state, since they may be called
-- multiple times, but reduces memory usage a lot.
local shells = setmetatable({}, {__mode="v"})

function shell.getShell()
  local shellPath = os.getenv("SHELL") or "/bin/sh"
  local shellName, reason = shell.resolve(shellPath, "lua")
  if not shellName then
    return nil, "cannot resolve shell `" .. shellPath .. "': " .. reason
  end
  if shells[shellName] then
    return shells[shellName]
  end
  local sh, reason = loadfile(shellName, "t")
  if sh then
    shells[shellName] = sh
  end
  return sh, reason
end

local function findFile(name, ext)
  checkArg(1, name, "string")
  local function findIn(dir)
    if dir:sub(1, 1) ~= "/" then
      dir = shell.resolve(dir)
    end
    dir = fs.concat(fs.concat(dir, name), "..")
    local name = fs.name(name)
    local list = fs.list(dir)
    if list and name then
      local files = {}
      for file in list do
        files[file] = true
      end
      if ext and name:sub(-(1 + ext:len())) == "." .. ext then
        -- Name already contains extension, prioritize.
        if files[name] then
          return true, fs.concat(dir, name)
        end
      elseif files[name] then
        -- Check exact name.
        return true, fs.concat(dir, name)
      elseif ext then
        -- Check name with automatially added extension.
        local name = name .. "." .. ext
        if files[name] then
          return true, fs.concat(dir, name)
        end
      end
    end
    return false
  end
  if name:sub(1, 1) == "/" then
    local found, where = findIn("/")
    if found then return where end
  elseif name:sub(1, 2) == "./" then
    local found, where = findIn(shell.getWorkingDirectory())
    if found then return where end
  else
    for path in string.gmatch(shell.getPath(), "[^:]+") do
      local found, where = findIn(path)
      if found then return where end
    end
  end
  return false
end

-------------------------------------------------------------------------------

function shell.prime()
  local data = process.info().data
  for _,key in ipairs({'aliases','vars'}) do
    -- first time get need to populate
    local raw = rawget(data, key)
    if not raw then
      -- current process does not have the key
      local current = data[key]
      data[key] = {}
      if current then
        for k,v in pairs(current) do
          data[key][k] = v
        end
      end
    end
  end
end

function shell.getAlias(alias)
  return process.info().data.aliases[alias]
end

function shell.setAlias(alias, value)
  checkArg(1, alias, "string")
  checkArg(2, value, "string", "nil")
  process.info().data.aliases[alias] = value
end

function shell.aliases()
  return pairs(process.info().data.aliases)
end

function shell.resolveAlias(command, args)
  checkArg(1, command, "string")
  checkArg(2, args, "table", "nil")
  args = args or {}
  local program, lastProgram = command, nil
  while true do
    local tokens = text.tokenize(shell.getAlias(program) or program)
    program = tokens[1]
    if program == lastProgram then
      break
    end
    lastProgram = program
    for i = #tokens, 2, -1 do
      table.insert(args, 1, tokens[i])
    end
  end
  return program, args
end

function shell.getWorkingDirectory()
  -- if no env PWD default to /
  return os.getenv("PWD") or "/"
end

function shell.setWorkingDirectory(dir)
  checkArg(1, dir, "string")
  -- ensure at least /
  -- and remove trailing /
  dir = fs.canonical(dir):gsub("^$", "/"):gsub("(.)/$", "%1")
  if fs.isDirectory(dir) then
    os.setenv("PWD", dir)
    return true
  else
    return nil, "not a directory"
  end
end

function shell.getPath()
  return os.getenv("PATH")
end

function shell.setPath(value)
  os.setenv("PATH", value)
end

function shell.resolve(path, ext)
  if ext then
    checkArg(2, ext, "string")
    local where = findFile(path, ext)
    if where then
      return where
    else
      return nil, "file not found"
    end
  else
    if path:sub(1, 1) == "/" then
      return fs.canonical(path)
    else
      return fs.concat(shell.getWorkingDirectory(), path)
    end
  end
end

function shell.execute(command, env, ...)
  local sh, reason = shell.getShell()
  if not sh then
    return false, reason
  end
  local result = table.pack(coroutine.resume(process.load(function(...)
    return sh(...)
  end), env, command, ...))
  if not result[1] and type(result[2]) == "table" and result[2].reason == "terminated" then
    if result[2].code then
      return true
    else
      return false, "terminated"
    end
  end
  return table.unpack(result, 1, result.n)
end

function shell.parse(...)
  local params = table.pack(...)
  local args = {}
  local options = {}
  local doneWithOptions = false
  for i = 1, params.n do
    local param = params[i]
    if not doneWithOptions and type(param) == "string" then
      if param == "--" then
        doneWithOptions = true -- stop processing options at `--`
      elseif param:sub(1, 2) == "--" then
        if param:match("%-%-(.-)=") ~= nil then
          options[param:match("%-%-(.-)=")] = param:match("=(.*)")
        else
          options[param:sub(3)] = true
        end
      elseif param:sub(1, 1) == "-" and param ~= "-" then
        for j = 2, unicode.len(param) do
          options[unicode.sub(param, j, j)] = true
        end
      else
        table.insert(args, param)
      end
    else
      table.insert(args, param)
    end
  end
  return args, options
end

-------------------------------------------------------------------------------

return shell
