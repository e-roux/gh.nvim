-- TODO: See GitHub issues #25 and #22 — quickfix parsing / gh integration. Add tests and harden gh output handling.

-- Check for plenary dependency
local ok, Job = pcall(require, "plenary.job")
if not ok then
  vim.notify("gh.nvim: Plenary not found", vim.log.levels.WARN)
  return
end

-- Load gh module
local gh_module_ok, gh = pcall(require, "gh")
if not gh_module_ok then
  vim.notify("gh.nvim: Failed to load gh module: " .. tostring(gh), vim.log.levels.ERROR)
  return
end

local GH = "gh"

--- Main gh command handler - mirrors gh CLI structure
--- @param opts table
local function gh_command(opts)
  local args = opts.fargs
  
  -- Check if this is an issue subcommand
  if args[1] == "issue" then
    if args[2] == "list" then
      -- :Gh issue list [repo]
      local repo = args[3]
      gh.issues.open_issue_list(repo)
      return
    elseif args[2] == "view" then
      -- :Gh issue view <number> [repo]
      local number = tonumber(args[3])
      local repo = args[4]
      
      if not number then
        vim.notify("Usage: :Gh issue view <number> [repo]", vim.log.levels.ERROR)
        return
      end
      
      gh.issues.open_issue_detail(number, repo)
      return
    end
  end
  
  -- Default: passthrough to gh CLI and populate quickfix list
  Job:new({
    command = GH,
    args = args,
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.schedule(function()
          vim.notify("gh command failed", vim.log.levels.ERROR)
        end)
        return
      end
      local result = table.concat(j:result(), "\n")
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

--- Simple command completion for Gh command
--- @param arg_lead string Current argument being typed
--- @param cmd_line string Full command line
--- @param cursor_pos integer Cursor position
--- @return string[] Completion candidates
local function gh_complete(arg_lead, cmd_line, cursor_pos)
  local args = vim.split(cmd_line, "%s+", { trimempty = true })
  
  -- Remove "Gh" command itself from args
  table.remove(args, 1)
  
  -- If we're still typing the first arg (or first arg is empty)
  if #args == 0 or (#args == 1 and cmd_line:sub(-1) ~= " ") then
    local candidates = { "issue", "pr", "repo", "run", "workflow" }
    return vim.tbl_filter(function(item)
      return vim.startswith(item, arg_lead)
    end, candidates)
  end
  
  -- Second argument: issue subcommands
  if args[1] == "issue" and (#args == 1 or (#args == 2 and cmd_line:sub(-1) ~= " ")) then
    local candidates = { "list", "view", "create", "close", "reopen" }
    return vim.tbl_filter(function(item)
      return vim.startswith(item, arg_lead)
    end, candidates)
  end
  
  -- Second argument: pr subcommands
  if args[1] == "pr" and (#args == 1 or (#args == 2 and cmd_line:sub(-1) ~= " ")) then
    local candidates = { "list", "view", "create", "checkout", "status" }
    return vim.tbl_filter(function(item)
      return vim.startswith(item, arg_lead)
    end, candidates)
  end
  
  return {}
end

vim.api.nvim_create_user_command("Gh", gh_command, {
  nargs = "*",
  bang = true,
  complete = gh_complete,
  desc = "GitHub CLI integration - mirrors gh command structure",
})
