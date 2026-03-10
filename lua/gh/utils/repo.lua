--- Repository utilities
local M = {}

local Job = require("plenary.job")

--- Get current repository name using gh cli
---@param callback fun(repo: string|nil, error: string|nil)
function M.get_current_repo(callback)
  Job:new({
    command = "gh",
    args = { "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner" },
    on_exit = function(job, return_val)
      vim.schedule(function()
        if return_val ~= 0 then
          callback(nil, "Could not determine repository")
        else
          local repo_name = vim.trim(table.concat(job:result(), ""))
          callback(repo_name, nil)
        end
      end)
    end,
  }):start()
end

--- Parse repository string into owner and name
---@param repo string Repository in "owner/name" format
---@return string|nil owner, string|nil name, string|nil error
function M.parse_repo(repo)
  local owner, name = repo:match("^([^/]+)/([^/]+)$")
  if not owner or not name or owner == "" or name == "" then
    return nil, nil, "Invalid repository format: " .. repo
  end
  return owner, name, nil
end

return M
