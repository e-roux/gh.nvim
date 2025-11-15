--- Shared cache for GitHub data (issues, PRs, etc)
--- Cache location: $XDG_CACHE_HOME/nvim/gh/
--- This cache is designed to be shared with zsh completions
local M = {}

local cache_dir = vim.fn.expand("$XDG_CACHE_HOME/nvim/gh")
local default_ttl = 300 -- 5 minutes

--- Ensure cache directory exists
local function ensure_cache_dir()
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
  end
end

--- Get cache file path for a key
---@param key string Cache key (e.g., "issues_open", "prs_merged")
---@return string Cache file path
local function get_cache_path(key)
  return cache_dir .. "/" .. key .. ".json"
end

--- Check if cache is valid
---@param key string Cache key
---@param ttl number|nil Time to live in seconds (default: 300)
---@return boolean True if cache is valid
function M.is_valid(key, ttl)
  ttl = ttl or default_ttl
  local cache_path = get_cache_path(key)
  
  if vim.fn.filereadable(cache_path) == 0 then
    return false
  end
  
  local mtime = vim.fn.getftime(cache_path)
  local now = os.time()
  
  return (now - mtime) < ttl
end

--- Read from cache
---@param key string Cache key
---@return table|nil Cached data or nil if not found/invalid
function M.read(key)
  local cache_path = get_cache_path(key)
  
  if vim.fn.filereadable(cache_path) == 0 then
    return nil
  end
  
  local file = io.open(cache_path, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  
  return data
end

--- Write to cache
---@param key string Cache key
---@param data table Data to cache
---@return boolean Success
function M.write(key, data)
  ensure_cache_dir()
  local cache_path = get_cache_path(key)
  
  local ok, json = pcall(vim.json.encode, data)
  if not ok then
    return false
  end
  
  local file = io.open(cache_path, "w")
  if not file then
    return false
  end
  
  file:write(json)
  file:close()
  
  return true
end

--- Get cached data or fetch from function
---@param key string Cache key
---@param fetch_fn fun(callback: fun(data: table|nil)) Function to fetch data
---@param ttl number|nil Time to live in seconds
---@param callback fun(data: table|nil) Callback with data
function M.get_or_fetch(key, fetch_fn, ttl, callback)
  -- Check if cache is valid
  if M.is_valid(key, ttl) then
    local data = M.read(key)
    if data then
      callback(data)
      return
    end
  end
  
  -- Fetch fresh data
  fetch_fn(function(data)
    if data then
      M.write(key, data)
    end
    callback(data)
  end)
end

--- Clear cache for a specific key
---@param key string Cache key
function M.clear(key)
  local cache_path = get_cache_path(key)
  if vim.fn.filereadable(cache_path) == 1 then
    vim.fn.delete(cache_path)
  end
end

--- Clear all cache
function M.clear_all()
  if vim.fn.isdirectory(cache_dir) == 1 then
    local files = vim.fn.glob(cache_dir .. "/*.json", false, true)
    for _, file in ipairs(files) do
      vim.fn.delete(file)
    end
  end
end

--- Get cache directory path
---@return string Cache directory path
function M.get_cache_dir()
  return cache_dir
end

return M
