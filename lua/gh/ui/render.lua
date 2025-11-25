--- Rendering utilities for GitHub issue/PR metadata
--- Implements grug-far-style inline metadata rendering
local M = {}

local metadata_inputs = require("gh.ui.metadata_inputs")

--- Namespace for virtual text
M.namespace = vim.api.nvim_create_namespace("gh_render")

--- Extmark IDs for tracking
M.extmark_ids = {}

--- Render metadata as virtual lines (grug-far style)
---@param bufnr integer Buffer number
---@param item table Issue or PR data
---@param start_line? integer Line to render after (defaults to 1, after title)
function M.render_metadata(bufnr, item, start_line)
  -- Clear existing metadata
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  M.extmark_ids = {}

  -- Extract values from issue data
  local values = metadata_inputs.extract_values(item)

  -- Render metadata inputs as virtual lines after the title
  metadata_inputs.render(bufnr, M.namespace, M.extmark_ids, values, start_line or 1)
end

--- Clear metadata rendering
---@param bufnr integer Buffer number
function M.clear_metadata(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  M.extmark_ids = {}
end

return M
