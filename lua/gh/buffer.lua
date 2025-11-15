--- Buffer management for Oil.nvim-style editing
--- Provides editable buffers for GitHub issues and PRs
local M = {}

--- Create a new scratch buffer with common settings
---@param name string Buffer name
---@return integer bufnr Buffer number
function M.create_scratch(name)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, name)
  
  -- Set buffer options for editing
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  
  return bufnr
end

--- Set buffer content with lines
---@param bufnr integer Buffer number
---@param lines string[] Lines to set
function M.set_lines(bufnr, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
end

--- Get buffer content as lines
---@param bufnr integer Buffer number
---@return string[] Lines from buffer
function M.get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

--- Open buffer in current window
---@param bufnr integer Buffer number
function M.open(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
end

--- Open buffer in split
---@param bufnr integer Buffer number
---@param vertical boolean|nil Open vertical split
function M.open_split(bufnr, vertical)
  if vertical then
    vim.cmd("vsplit")
  else
    vim.cmd("split")
  end
  vim.api.nvim_set_current_buf(bufnr)
end

--- Set up autocmd for buffer write
---@param bufnr integer Buffer number
---@param callback fun(bufnr: integer): boolean Write callback, return true on success
function M.on_write(bufnr, callback)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local success = callback(bufnr)
      if success then
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        vim.notify("Changes saved to GitHub", vim.log.levels.INFO)
      else
        vim.notify("Failed to save changes", vim.log.levels.ERROR)
      end
    end,
  })
end

--- Add buffer-local keymaps
---@param bufnr integer Buffer number
---@param mappings table<string, {callback: function, desc: string}>
function M.set_keymaps(bufnr, mappings)
  for key, config in pairs(mappings) do
    vim.keymap.set("n", key, config.callback, {
      buffer = bufnr,
      desc = config.desc,
      noremap = true,
      silent = true,
    })
  end
end

return M
