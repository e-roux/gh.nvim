--- Smart CLI builder with metadata-driven flag handling
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

--- Flag type definitions
M.FLAG_TYPES = {
  SINGLE = "single", -- Single value: --flag value
  ARRAY = "array", -- Multiple values: --flag value1 --flag value2
  BOOL = "bool", -- Boolean: --flag (no value)
}

--- Build args from opts using flag schema
---@param base_args string[] Base command args (e.g., {"issue", "list"})
---@param opts table Options table
---@param schema table Flag schema mapping opts keys to gh flags
---@return string[] Complete args array
function M.build_args(base_args, opts, schema)
  local args = vim.deepcopy(base_args)

  for opt_key, flag_def in pairs(schema) do
    local value = opts[opt_key]

    if value ~= nil then
      local flag_name = flag_def.flag or "--" .. opt_key
      local flag_type = flag_def.type or M.FLAG_TYPES.SINGLE

      if flag_type == M.FLAG_TYPES.BOOL then
        if value then
          table.insert(args, flag_name)
        end
      elseif flag_type == M.FLAG_TYPES.ARRAY then
        -- Convert single value to array
        local values = type(value) == "table" and value or { value }
        for _, v in ipairs(values) do
          table.insert(args, flag_name)
          table.insert(args, tostring(v))
        end
      else -- SINGLE
        table.insert(args, flag_name)
        table.insert(args, tostring(value))
      end
    elseif flag_def.default then
      -- Apply default value
      table.insert(args, flag_def.flag or "--" .. opt_key)
      table.insert(args, tostring(flag_def.default))
    end
  end

  return args
end

--- Create a command builder with flag schema
---@param base_cmd string[] Base command (e.g., {"issue", "list"})
---@param schema table Flag schema
---@param json_fields string|nil JSON fields to request
---@return fun(opts: table|nil, callback: function)
function M.create_command(base_cmd, schema, json_fields)
  return function(opts, callback)
    -- Handle signature: command(callback)
    if type(opts) == "function" then
      callback = opts
      opts = {}
    end

    opts = opts or {}

    -- Build args from opts using schema
    local args = M.build_args(base_cmd, opts, schema)

    -- Add JSON output if specified
    if json_fields then
      table.insert(args, "--json")
      table.insert(args, json_fields)
    end

    -- Execute command
    M.run(args, function(success, result, error)
      if not success then
        callback(false, nil, error)
        return
      end

      -- Parse JSON if applicable
      if json_fields then
        local ok, data, parse_error = M.parse_json(result)
        callback(ok, data, ok and nil or parse_error)
      else
        callback(true, result, nil)
      end
    end)
  end
end

return M
