--- In-memory cache for GitHub data (issues, PRs, etc)
--- Cache is session-scoped and cleared on restart
local M = {}

local default_ttl = 300 -- 5 minutes

--- Cache entry structure
---@class CacheEntry
---@field data table Cached data
---@field timestamp number Timestamp when cached

--- In-memory cache storage
---@type table<string, CacheEntry>
local cache_store = {}

--- Check if cache is valid
---@param key string Cache key
---@param ttl number|nil Time to live in seconds (default: 300)
---@return boolean True if cache is valid
function M.is_valid(key, ttl)
  ttl = ttl or default_ttl
  local entry = cache_store[key]

  if not entry then
    return false
  end

  local now = os.time()
  return (now - entry.timestamp) < ttl
end

--- Read from cache
---@param key string Cache key
---@return table|nil Cached data or nil if not found/invalid
function M.read(key)
  local entry = cache_store[key]

  if not entry then
    return nil
  end

  return entry.data
end

--- Write to cache
---@param key string Cache key
---@param data table Data to cache
---@return boolean Success
function M.write(key, data)
  cache_store[key] = {
    data = data,
    timestamp = os.time(),
  }
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
  cache_store[key] = nil
end

--- Clear all cache
function M.clear_all()
  cache_store = {}
end

--- Get cache statistics
---@return table Statistics about cache usage
function M.get_stats()
  local count = 0
  for _ in pairs(cache_store) do
    count = count + 1
  end

  return {
    entry_count = count,
    keys = vim.tbl_keys(cache_store),
  }
end

return M
