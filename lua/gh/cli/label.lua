--- GitHub label CLI operations (gh label)
local M = {}

local core = require("gh.cli.core")

--- List labels (gh label list)
---@param callback fun(success: boolean, labels: table[]|nil, error: string|nil)
---@param opts? table Options
---  - limit? integer Number of labels to fetch (default: 1000)
---  - repo? string Repository (owner/repo)
function M.list(opts, callback)
  -- Handle signature: list(callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "label", "list" }

  core.add_flag(args, "--limit", opts.limit or 1000)
  core.add_repo_flag(args, opts.repo)

  -- Request JSON output
  table.insert(args, "--json")
  table.insert(args, "name,description,color")

  core.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    local ok, labels, parse_error = core.parse_json(result)
    if not ok then
      callback(false, nil, parse_error)
      return
    end

    callback(true, labels, nil)
  end)
end

return M
