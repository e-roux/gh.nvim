--- Core gh CLI runner and utilities
local M = {}

local Job = require("plenary.job")

--- Run gh command asynchronously
---@param args string[] Command arguments
---@param callback fun(success: boolean, result: string|nil, error: string|nil)
function M.run(args, callback)
  Job:new({
    command = "gh",
    args = args,
    on_exit = function(j, return_val)
      vim.schedule(function()
        if return_val ~= 0 then
          local error_msg = table.concat(j:stderr_result(), "\n")
          callback(false, nil, error_msg)
        else
          local result = table.concat(j:result(), "\n")
          callback(true, result, nil)
        end
      end)
    end,
  }):start()
end

--- Parse JSON response
---@param json_str string JSON string to parse
---@return boolean success, table|nil data, string|nil error
function M.parse_json(json_str)
  local ok, data = pcall(vim.json.decode, json_str)
  if not ok then
    return false, nil, "Failed to parse JSON response"
  end
  return true, data, nil
end

--- Add a single flag if value is provided
---@param args table Arguments array
---@param flag string Flag name (e.g., "--state")
---@param value any Value (nil values are skipped)
function M.add_flag(args, flag, value)
  if value ~= nil then
    table.insert(args, flag)
    table.insert(args, tostring(value))
  end
end

--- Add array flag (for multi-value flags like --label)
---@param args table Arguments array
---@param flag string Flag name (e.g., "--label")
---@param values string[]|string|nil Array of values or single value
function M.add_array_flag(args, flag, values)
  if not values then
    return
  end

  -- Convert single value to array
  local array = type(values) == "table" and values or { values }

  for _, value in ipairs(array) do
    table.insert(args, flag)
    table.insert(args, tostring(value))
  end
end

--- Add boolean flag (flags without values)
---@param args table Arguments array
---@param flag string Flag name (e.g., "--web", "--draft")
---@param enabled boolean Whether to add the flag
function M.add_bool_flag(args, flag, enabled)
  if enabled then
    table.insert(args, flag)
  end
end

--- Add --repo flag
---@param args table Arguments array
---@param repo string|nil Repository (owner/repo)
function M.add_repo_flag(args, repo)
  M.add_flag(args, "--repo", repo)
end

return M
