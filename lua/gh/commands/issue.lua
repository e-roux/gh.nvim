--- Issue command handlers
--- Handles all :Gh issue subcommands
local M = {}

--- Parse issue list command arguments
---@param args string[] Command arguments starting after "issue list"
---@return string|nil repo Repository name
---@return table filter_opts Filter options
local function parse_list_args(args)
  local filter_opts = {
    state = "open", -- Default to open, mirroring gh CLI
  }
  local repo = nil

  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--state" or arg == "-s" then
      filter_opts.state = args[i + 1]
      i = i + 2
    elseif arg == "--limit" or arg == "-L" then
      filter_opts.limit = tonumber(args[i + 1])
      i = i + 2
    elseif arg == "--repo" or arg == "-R" then
      repo = args[i + 1]
      i = i + 2
    elseif arg == "--assignee" or arg == "-a" then
      filter_opts.assignee = args[i + 1]
      i = i + 2
    elseif arg == "--author" or arg == "-A" then
      filter_opts.author = args[i + 1]
      i = i + 2
    elseif arg == "--label" or arg == "-l" then
      -- Labels can be specified multiple times
      if not filter_opts.label then
        filter_opts.label = {}
      end
      table.insert(filter_opts.label, args[i + 1])
      i = i + 2
    elseif arg == "--mention" then
      filter_opts.mention = args[i + 1]
      i = i + 2
    elseif arg == "--milestone" or arg == "-m" then
      filter_opts.milestone = args[i + 1]
      i = i + 2
    elseif arg == "--search" or arg == "-S" then
      filter_opts.search = args[i + 1]
      i = i + 2
    else
      -- Positional argument (repo without flag)
      repo = arg
      i = i + 1
    end
  end

  return repo, filter_opts
end

--- Parse issue view command arguments
---@param args string[] Command arguments starting after "issue view"
---@return integer|nil number Issue number
---@return string|nil repo Repository name
local function parse_view_args(args)
  local number = nil
  local repo = nil

  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--repo" or arg == "-R" then
      repo = args[i + 1]
      i = i + 2
    elseif not number then
      number = tonumber(arg)
      i = i + 1
    else
      i = i + 1
    end
  end

  return number, repo
end

--- Parse issue create command arguments
---@param args string[] Command arguments starting after "issue create"
---@return table create_opts Creation options
local function parse_create_args(args)
  local create_opts = {
    title = nil,
    assignees = {},
    labels = {},
    milestone = nil,
    project = nil,
    template = nil,
    repo = nil,
  }

  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--title" or arg == "-t" then
      create_opts.title = args[i + 1]
      i = i + 2
    elseif arg == "--assignee" or arg == "-a" then
      table.insert(create_opts.assignees, args[i + 1])
      i = i + 2
    elseif arg == "--label" or arg == "-l" then
      table.insert(create_opts.labels, args[i + 1])
      i = i + 2
    elseif arg == "--milestone" or arg == "-m" then
      create_opts.milestone = args[i + 1]
      i = i + 2
    elseif arg == "--project" or arg == "-p" then
      create_opts.project = args[i + 1]
      i = i + 2
    elseif arg == "--template" then
      create_opts.template = args[i + 1]
      i = i + 2
    elseif arg == "--repo" or arg == "-R" then
      create_opts.repo = args[i + 1]
      i = i + 2
    else
      i = i + 1
    end
  end

  return create_opts
end

--- Handle issue list command
---@param args string[] Command arguments starting after "issue list"
function M.list(args)
  local repo, filter_opts = parse_list_args(args)
  local gh = require("gh")
  gh.issues.open_issue_list(repo, filter_opts)
end

--- Handle issue view command
---@param args string[] Command arguments starting after "issue view"
function M.view(args)
  local number, repo = parse_view_args(args)

  if not number then
    vim.notify("Usage: :Gh issue view <number> [--repo owner/repo]", vim.log.levels.ERROR)
    return
  end

  local gh = require("gh")
  gh.issues.open_issue_detail(number, repo)
end

--- Handle issue create command
---@param args string[] Command arguments starting after "issue create"
function M.create(args)
  local create_opts = parse_create_args(args)
  local gh = require("gh")
  gh.issues.create_issue_buffer(create_opts)
end

--- Main issue command dispatcher
---@param args string[] Full command arguments starting after "issue"
function M.handle(args)
  if #args == 0 then
    vim.notify("Usage: :Gh issue <subcommand> [args]", vim.log.levels.ERROR)
    return
  end

  local subcommand = args[1]
  local subargs = vim.list_slice(args, 2)

  if subcommand == "list" or subcommand == "ls" then
    M.list(subargs)
  elseif subcommand == "view" then
    M.view(subargs)
  elseif subcommand == "create" then
    M.create(subargs)
  else
    vim.notify("Unknown issue subcommand: " .. subcommand, vim.log.levels.ERROR)
  end
end

--- Get completion candidates for issue subcommands
---@param arg_lead string Current argument being typed
---@param args string[] All arguments so far
---@return string[] Completion candidates
function M.complete(arg_lead, args)
  local subcommands = { "list", "ls", "view", "create", "close", "reopen" }

  -- If we're completing the subcommand (no args, empty first arg, or single partial arg)
  if #args == 0 or (#args == 1 and args[1] == "") then
    return vim.tbl_filter(function(item)
      return vim.startswith(item, arg_lead)
    end, subcommands)
  end

  -- If we have only one arg, check if it's a partial subcommand or a complete one
  if #args == 1 then
    local arg = args[1]
    -- Check if this matches any subcommand exactly
    local is_complete_subcommand = false
    for _, cmd in ipairs(subcommands) do
      if arg == cmd then
        is_complete_subcommand = true
        break
      end
    end

    -- If not a complete subcommand, treat as partial completion
    if not is_complete_subcommand then
      return vim.tbl_filter(function(item)
        return vim.startswith(item, arg_lead)
      end, subcommands)
    end
  end

  local subcommand = args[1]

  -- Completion for issue list flags
  if subcommand == "list" or subcommand == "ls" then
    local prev_arg = #args > 1 and args[#args] or nil

    -- Complete state values
    if prev_arg == "--state" or prev_arg == "-s" then
      local candidates = { "open", "closed", "all" }
      return vim.tbl_filter(function(item)
        return vim.startswith(item, arg_lead)
      end, candidates)
    end

    -- Complete flags
    if vim.startswith(arg_lead, "-") then
      local candidates = {
        "--state",
        "-s",
        "--limit",
        "-L",
        "--repo",
        "-R",
        "--assignee",
        "-a",
        "--author",
        "-A",
        "--label",
        "-l",
        "--mention",
        "--milestone",
        "-m",
        "--search",
        "-S",
      }
      return vim.tbl_filter(function(item)
        return vim.startswith(item, arg_lead)
      end, candidates)
    end
  end

  -- Completion for issue view flags
  if subcommand == "view" then
    if vim.startswith(arg_lead, "-") then
      local candidates = { "--repo", "-R" }
      return vim.tbl_filter(function(item)
        return vim.startswith(item, arg_lead)
      end, candidates)
    end
  end

  -- Completion for issue create flags
  if subcommand == "create" then
    local prev_arg = #args > 1 and args[#args] or nil

    -- Get repo from args if specified
    local repo = nil
    for i = 2, #args do
      if (args[i] == "--repo" or args[i] == "-R") and args[i + 1] then
        repo = args[i + 1]
        break
      end
    end

    -- Complete assignee values
    if prev_arg == "--assignee" or prev_arg == "-a" then
      local issues = require("gh.issues")
      issues.get_assignee_completions(repo, function(_assignees)
        -- Cache for next completion attempt
      end)
      return { "@me" }
    end

    -- Complete label values
    if prev_arg == "--label" or prev_arg == "-l" then
      local issues = require("gh.issues")
      issues.get_label_completions(repo, function(_labels)
        -- Cache for next completion attempt
      end)
      return {}
    end

    -- Complete milestone values
    if prev_arg == "--milestone" or prev_arg == "-m" then
      local issues = require("gh.issues")
      issues.get_milestone_completions(repo, function(_milestones)
        -- Cache for next completion attempt
      end)
      return {}
    end

    -- Complete project values
    if prev_arg == "--project" or prev_arg == "-p" then
      local issues = require("gh.issues")
      issues.get_project_completions(repo, function(_projects)
        -- Cache for next completion attempt
      end)
      return {}
    end

    -- Complete template values
    if prev_arg == "--template" then
      local issues = require("gh.issues")
      issues.get_template_completions(repo, function(_templates)
        -- Cache for next completion attempt
      end)
      return {}
    end

    -- Complete flags
    if vim.startswith(arg_lead, "-") then
      local candidates = {
        "--title",
        "-t",
        "--assignee",
        "-a",
        "--label",
        "-l",
        "--milestone",
        "-m",
        "--project",
        "-p",
        "--template",
        "--repo",
        "-R",
      }
      return vim.tbl_filter(function(item)
        return vim.startswith(item, arg_lead)
      end, candidates)
    end
  end

  return {}
end

return M
