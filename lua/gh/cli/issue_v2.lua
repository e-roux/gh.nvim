--- GitHub issue CLI operations (gh issue) - Using smart core
local M = {}

local core = require("gh.cli.core_v2")

--- Flag schema for issue list
local LIST_SCHEMA = {
  state = { flag = "--state", type = core.FLAG_TYPES.SINGLE, default = "open" },
  limit = { flag = "--limit", type = core.FLAG_TYPES.SINGLE, default = "30" },
  assignee = { flag = "--assignee", type = core.FLAG_TYPES.SINGLE },
  author = { flag = "--author", type = core.FLAG_TYPES.SINGLE },
  mention = { flag = "--mention", type = core.FLAG_TYPES.SINGLE },
  milestone = { flag = "--milestone", type = core.FLAG_TYPES.SINGLE },
  search = { flag = "--search", type = core.FLAG_TYPES.SINGLE },
  label = { flag = "--label", type = core.FLAG_TYPES.ARRAY },
  repo = { flag = "--repo", type = core.FLAG_TYPES.SINGLE },
}

--- Flag schema for issue view
local VIEW_SCHEMA = {
  repo = { flag = "--repo", type = core.FLAG_TYPES.SINGLE },
}

--- Flag schema for issue create
local CREATE_SCHEMA = {
  title = { flag = "--title", type = core.FLAG_TYPES.SINGLE }, -- required, handled separately
  body = { flag = "--body", type = core.FLAG_TYPES.SINGLE },
  assignee = { flag = "--assignee", type = core.FLAG_TYPES.ARRAY },
  label = { flag = "--label", type = core.FLAG_TYPES.ARRAY },
  milestone = { flag = "--milestone", type = core.FLAG_TYPES.SINGLE },
  project = { flag = "--project", type = core.FLAG_TYPES.SINGLE },
  repo = { flag = "--repo", type = core.FLAG_TYPES.SINGLE },
}

--- Flag schema for issue edit
local EDIT_SCHEMA = {
  title = { flag = "--title", type = core.FLAG_TYPES.SINGLE },
  body = { flag = "--body", type = core.FLAG_TYPES.SINGLE },
  state = { flag = "--state", type = core.FLAG_TYPES.SINGLE },
  assignee = { flag = "--add-assignee", type = core.FLAG_TYPES.ARRAY },
  label = { flag = "--add-label", type = core.FLAG_TYPES.ARRAY },
  repo = { flag = "--repo", type = core.FLAG_TYPES.SINGLE },
}

--- List issues (gh issue list)
M.list = core.create_command(
  { "issue", "list" },
  LIST_SCHEMA,
  "number,title,state,labels,assignees,author,createdAt,updatedAt"
)

--- View issue details (gh issue view)
---@param number integer Issue number
---@param opts? table Options
---@param callback function Callback
function M.view(number, opts, callback)
  -- Handle backward compat signatures
  if type(opts) == "string" then
    opts = { repo = opts }
  elseif type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}

  -- Build command
  local cmd = core.create_command(
    { "issue", "view", tostring(number) },
    VIEW_SCHEMA,
    "number,title,body,state,labels,assignees,author,createdAt,updatedAt,url"
  )

  cmd(opts, callback)
end

--- Create issue (gh issue create)
---@param opts table Options (title required)
---@param callback function Callback
function M.create(opts, callback)
  local args = { "issue", "create" }

  -- Build args using schema
  args = core.build_args(args, opts, CREATE_SCHEMA)

  core.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    -- Parse issue URL from output
    local url = result:match("https://github.com/[^/]+/[^/]+/issues/(%d+)")
    if url then
      callback(true, { number = tonumber(url), url = result }, nil)
    else
      callback(true, { url = result }, nil)
    end
  end)
end

--- Edit issue (gh issue edit)
---@param number integer Issue number
---@param fields table Fields to update
---@param opts? table Options
---@param callback function Callback
function M.edit(number, fields, opts, callback)
  -- Handle backward compat signatures
  if type(opts) == "string" then
    opts = { repo = opts }
  elseif type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}

  -- Merge fields into opts for schema processing
  local merged_opts = vim.tbl_extend("force", opts, fields)

  -- Build command
  local args = { "issue", "edit", tostring(number) }
  args = core.build_args(args, merged_opts, EDIT_SCHEMA)

  core.run(args, function(success, _, error)
    callback(success, error)
  end)
end

--- Delete issue (gh issue delete)
---@param number integer Issue number
---@param opts? table Options
---@param callback function Callback
function M.delete(number, opts, callback)
  -- Handle backward compat signatures
  if type(opts) == "string" then
    opts = { repo = opts }
  elseif type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}

  local args = { "issue", "delete", tostring(number), "--yes" }
  args = core.build_args(args, opts, { repo = { flag = "--repo" } })

  core.run(args, function(success, _, error)
    callback(success, error)
  end)
end

return M
