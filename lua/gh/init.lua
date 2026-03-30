--- GitHub integration module
--- Provides utilities for working with GitHub CLI in Neovim
local M = {}

-- Cache for lazy-loaded issues module
local _issues_cache

--- Get issues module (lazy-loaded)
---@return table
local function get_issues()
  if not _issues_cache then
    _issues_cache = require("gh.issues")
  end
  return _issues_cache
end

-- Expose issues as a lazy-loaded property
M.issues = setmetatable({}, {
  __index = function(_, key)
    return get_issues()[key]
  end,
  __call = function(_, ...)
    return get_issues()(...)
  end,
})

--- Initialize gh.nvim autocmds.
--- Called once by plugin/gh.lua on the first :Gh command invocation.
function M.setup()
  require("gh.ui.buffer_registry").setup_autocmd()
  get_issues().setup_autocmds()
end

--- Main entry point for :Gh command
---@param opts table Command options from nvim_create_user_command
function M.command(opts)
  local args = opts.fargs
  if #args == 0 then
    vim.notify("Usage: :Gh <subcommand> [args]", vim.log.levels.INFO)
    return
  end

  -- Pass all args directly to gh CLI
  require("gh.cli").run(args, function(success, result, error_msg)
    if not success then
      vim.notify("gh command failed: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
      return
    end
    -- Display result (could be enhanced to use quickfix, buffers, etc.)
    vim.notify(result or "Command completed", vim.log.levels.INFO)
  end)
end

--- Transform gh output into a quickfix list
---@param items string Output from gh command
---@return table[] Quickfix list items
function M.toqflist(items)
  local list = {}
  items = vim.split(items, "\n", { plain = true })
  for _, v in ipairs(items) do
    if v ~= "" then
      table.insert(list, {
        bufnr = 0,
        lnum = 1,
        col = 1,
        text = v,
        type = "I",
      })
    end
  end
  return list
end

return M
