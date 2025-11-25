--- Command dispatcher for gh.nvim
--- Routes commands to appropriate subcommand handlers
local M = {}

--- Main command handler
---@param args string[] Command arguments from nvim_create_user_command
function M.handle(args)
  if #args == 0 then
    vim.notify("Usage: :Gh <subcommand> [args]", vim.log.levels.INFO)
    return
  end

  local command = args[1]
  local subargs = vim.list_slice(args, 2)

  -- Route to appropriate command handler
  if command == "issue" then
    local issue_cmd = require("gh.commands.issue")
    issue_cmd.handle(subargs)
  elseif command == "pr" then
    -- PR commands not yet fully implemented
    if #subargs > 0 and (subargs[1] == "list" or subargs[1] == "ls") then
      vim.notify("PR list not yet implemented. Use: gh pr list", vim.log.levels.WARN)
    elseif #subargs > 0 and subargs[1] == "view" then
      vim.notify("PR detail not yet implemented. Use: gh pr view", vim.log.levels.WARN)
    else
      -- Fallback to gh CLI
      M.passthrough(args)
    end
  else
    -- Fallback: passthrough to gh CLI
    M.passthrough(args)
  end
end

--- Passthrough command to gh CLI and populate quickfix list
---@param args string[] Command arguments
function M.passthrough(args)
  local Job = require("plenary.job")

  Job:new({
    command = "gh",
    args = args,
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.schedule(function()
          vim.notify("gh command failed", vim.log.levels.ERROR)
        end)
        return
      end
      local result = table.concat(j:result(), "\n")
      local gh = require("gh")
      local items = gh.toqflist(result)
      vim.schedule(function()
        vim.fn.setqflist({}, " ", { title = "gh", items = items })
        if #items > 0 then
          print(#items .. " items found!")
        else
          print("No items found.")
        end
      end)
    end,
  }):start()
end

--- Command completion handler
---@param arg_lead string Current argument being typed
---@param cmd_line string Full command line
---@param cursor_pos integer Cursor position
---@return string[] Completion candidates
function M.complete(arg_lead, cmd_line, _cursor_pos)
  local args = vim.split(cmd_line, "%s+", { trimempty = true })

  -- Remove "Gh" command itself from args
  table.remove(args, 1)

  -- If we're completing the first argument (main command)
  if #args == 0 or (#args == 1 and cmd_line:sub(-1) ~= " ") then
    local candidates = { "issue", "pr", "repo", "run", "workflow" }
    return vim.tbl_filter(function(item)
      return vim.startswith(item, arg_lead)
    end, candidates)
  end

  local command = args[1]

  -- Route to appropriate completion handler
  if command == "issue" then
    local issue_cmd = require("gh.commands.issue")
    return issue_cmd.complete(arg_lead, vim.list_slice(args, 2))
  elseif command == "pr" then
    -- Basic PR completion
    if #args == 1 or (#args == 2 and cmd_line:sub(-1) ~= " ") then
      local candidates = { "list", "view", "create", "close", "merge" }
      return vim.tbl_filter(function(item)
        return vim.startswith(item, arg_lead)
      end, candidates)
    end
  end

  return {}
end

return M
