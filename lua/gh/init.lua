--- GitHub integration module
--- Provides utilities for working with GitHub CLI in Neovim
local M = {}

M.cache = require("gh.cache")
M.cli = require("gh.cli")
M.issues = require("gh.issues")
M.buffer = require("gh.buffer")
M.config = require("gh.config")

--- Initialize gh.nvim autocmds
--- This is called automatically on require, no need to call explicitly
function M.setup()
  -- Set up autocmds for gh:// buffers
  M.issues.setup_autocmds()
end

-- Auto-setup on require
M.setup()

--- Main entry point for :Gh command
---@param opts table Command options from nvim_create_user_command
function M.command(opts)
  local args = opts.fargs
  if #args == 0 then
    vim.notify("Usage: :Gh <subcommand> [args]", vim.log.levels.INFO)
    return
  end

  -- Pass all args directly to gh CLI
  M.cli.run(args, function(success, result, error_msg)
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
