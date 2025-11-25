--- Buffer registry for tracking gh.nvim buffers
--- Prevents duplicate buffers and provides central tracking
local M = {}

--- Registry mapping buffer names to buffer numbers
--- @type table<string, integer>
local registry = {}

--- Register a buffer in the registry
--- @param buf_name string Buffer name (e.g., "gh://issues", "gh://issue/123")
--- @param bufnr integer Buffer number
function M.register(buf_name, bufnr)
  if not buf_name or buf_name == "" then
    return
  end
  registry[buf_name] = bufnr
end

--- Get buffer number for a given buffer name
--- Returns nil if buffer doesn't exist or is no longer valid
--- @param buf_name string Buffer name
--- @return integer|nil Buffer number or nil
function M.get(buf_name)
  if not buf_name or buf_name == "" then
    return nil
  end

  local bufnr = registry[buf_name]
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  -- Buffer is invalid, clean up registry
  registry[buf_name] = nil
  return nil
end

--- Unregister a buffer from the registry
--- @param buf_name string Buffer name
function M.unregister(buf_name)
  if not buf_name or buf_name == "" then
    return
  end
  registry[buf_name] = nil
end

--- Unregister a buffer by its buffer number
--- @param bufnr integer Buffer number
function M.unregister_by_bufnr(bufnr)
  for name, buf in pairs(registry) do
    if buf == bufnr then
      registry[name] = nil
      return
    end
  end
end

--- Check if a buffer is registered
--- @param buf_name string Buffer name
--- @return boolean True if buffer is registered and valid
function M.is_registered(buf_name)
  return M.get(buf_name) ~= nil
end

--- Get all registered buffer names
--- @return string[] List of buffer names
function M.get_all_names()
  local names = {}
  for name, bufnr in pairs(registry) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      table.insert(names, name)
    else
      -- Clean up invalid buffers
      registry[name] = nil
    end
  end
  return names
end

--- Get all registered buffer numbers
--- @return integer[] List of buffer numbers
function M.get_all_buffers()
  local buffers = {}
  for name, bufnr in pairs(registry) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      table.insert(buffers, bufnr)
    else
      -- Clean up invalid buffers
      registry[name] = nil
    end
  end
  return buffers
end

--- Clear the entire registry
--- Useful for testing or plugin reload
function M.clear()
  registry = {}
end

--- Get registry statistics for debugging
--- @return table Statistics about registered buffers
function M.stats()
  local valid = 0
  local invalid = 0

  for name, bufnr in pairs(registry) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      valid = valid + 1
    else
      invalid = invalid + 1
      registry[name] = nil
    end
  end

  return {
    valid = valid,
    invalid = invalid,
    total = valid,
  }
end

--- Find buffer by pattern matching
--- @param pattern string Lua pattern to match against buffer names
--- @return table<string, integer> Map of matching buffer names to buffer numbers
function M.find_by_pattern(pattern)
  local matches = {}
  for name, bufnr in pairs(registry) do
    if vim.api.nvim_buf_is_valid(bufnr) and name:match(pattern) then
      matches[name] = bufnr
    end
  end
  return matches
end

--- Setup autocmd to automatically unregister buffers when they're deleted
function M.setup_autocmd()
  vim.api.nvim_create_autocmd("BufDelete", {
    group = vim.api.nvim_create_augroup("GhBufferRegistry", { clear = true }),
    pattern = "gh://*",
    callback = function(args)
      M.unregister_by_bufnr(args.buf)
    end,
  })
end

return M
