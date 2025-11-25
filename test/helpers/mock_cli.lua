--- Mock GitHub CLI for testing
--- This module provides utilities to mock gh CLI responses in tests
local M = {}

local fixtures = require("test.fixtures.gh_responses")

--- Currently active mock behaviors
M._mocks = {}

--- Setup mock for gh issue list command
---@param repo string|nil Repository name
---@param response table|string Response data (table or "error" for error case)
function M.mock_issue_list(repo, response)
  local key = repo or "_current"
  M._mocks["list_" .. key] = response
end

--- Setup mock for gh issue view command
---@param number integer Issue number
---@param response table|string Response data (table or "error" for error case)
function M.mock_issue_view(number, response)
  M._mocks["view_" .. number] = response
end

--- Setup mock for gh issue edit command (title)
---@param number integer Issue number
---@param should_succeed boolean Whether the operation should succeed
function M.mock_issue_edit_title(number, should_succeed)
  M._mocks["edit_title_" .. number] = should_succeed
end

--- Setup mock for gh issue edit command (body)
---@param number integer Issue number
---@param should_succeed boolean Whether the operation should succeed
function M.mock_issue_edit_body(number, should_succeed)
  M._mocks["edit_body_" .. number] = should_succeed
end

--- Setup mock for gh issue edit command (state)
---@param number integer Issue number
---@param should_succeed boolean Whether the operation should succeed
function M.mock_issue_edit_state(number, should_succeed)
  M._mocks["edit_state_" .. number] = should_succeed
end

--- Reset all mocks
function M.reset()
  M._mocks = {}
end

--- Setup default successful mocks for common scenarios
function M.setup_default_mocks()
  -- Default issue list
  M.mock_issue_list(nil, fixtures.issue_list)

  -- Default issue details
  M.mock_issue_view(1, fixtures.issue_detail_1)
  M.mock_issue_view(2, fixtures.issue_detail_2)
  M.mock_issue_view(3, fixtures.issue_detail_3)
  M.mock_issue_view(42, fixtures.issue_detail_42)

  -- Default edit operations succeed
  for _, num in ipairs({ 1, 2, 3, 42 }) do
    M.mock_issue_edit_title(num, true)
    M.mock_issue_edit_body(num, true)
    M.mock_issue_edit_state(num, true)
  end
end

--- Create a mocked version of gh.cli module
---@return table Mocked CLI module
function M.create_mock_cli()
  local mock_cli = {}

  --- Mock run function
  function mock_cli.run(args, callback)
    vim.schedule(function()
      local command = table.concat(args, " ")

      -- Parse issue list command
      if command:match("^issue list") then
        local repo = command:match("%-%-repo%s+([^%s]+)")
        local key = repo or "_current"
        local response = M._mocks["list_" .. key]

        if response == "error" then
          callback(false, nil, "Mock error: issue list failed")
        elseif response then
          callback(true, vim.json.encode(response), nil)
        else
          callback(false, nil, "Mock not configured for: " .. command)
        end
        return
      end

      -- Parse issue view command
      local view_num = command:match("^issue view (%d+)")
      if view_num then
        local num = tonumber(view_num)
        local response = M._mocks["view_" .. num]

        if response == "error" then
          callback(false, nil, "Mock error: issue view failed")
        elseif response then
          callback(true, vim.json.encode(response), nil)
        else
          callback(false, nil, "Mock not configured for: " .. command)
        end
        return
      end

      -- Parse issue edit commands
      local edit_num = command:match("^issue edit (%d+)")
      if edit_num then
        local num = tonumber(edit_num)
        local edit_type

        if command:match("%-%-title") then
          edit_type = "title"
        elseif command:match("%-%-body") then
          edit_type = "body"
        elseif command:match("%-%-state") then
          edit_type = "state"
        end

        if edit_type then
          local should_succeed = M._mocks["edit_" .. edit_type .. "_" .. num]

          if should_succeed == true then
            callback(true, "", nil)
          elseif should_succeed == false then
            callback(false, nil, "Mock error: edit " .. edit_type .. " failed")
          else
            callback(false, nil, "Mock not configured for: " .. command)
          end
          return
        end
      end

      -- Unknown command
      callback(false, nil, "Mock not configured for: " .. command)
    end)
  end

  --- Mock list_issues function
  function mock_cli.list_issues(repo, callback)
    local args = { "issue", "list", "--json", "number,title,state,labels" }
    if repo then
      table.insert(args, "--repo")
      table.insert(args, repo)
    end

    mock_cli.run(args, function(success, result, error)
      if not success then
        callback(false, nil, error)
        return
      end

      local ok, issues = pcall(vim.json.decode, result)
      if not ok then
        callback(false, nil, "Failed to parse JSON response")
        return
      end

      callback(true, issues, nil)
    end)
  end

  --- Mock get_issue function
  function mock_cli.get_issue(number, repo, callback)
    local args = { "issue", "view", tostring(number), "--json", "number,title,body,state,labels" }
    if repo then
      table.insert(args, "--repo")
      table.insert(args, repo)
    end

    mock_cli.run(args, function(success, result, error)
      if not success then
        callback(false, nil, error)
        return
      end

      local ok, issue = pcall(vim.json.decode, result)
      if not ok then
        callback(false, nil, "Failed to parse JSON response")
        return
      end

      callback(true, issue, nil)
    end)
  end

  --- Mock update_title function
  function mock_cli.update_title(number, title, repo, callback)
    local args = { "issue", "edit", tostring(number), "--title", title }
    if repo then
      table.insert(args, "--repo")
      table.insert(args, repo)
    end

    mock_cli.run(args, function(success, _, error)
      callback(success, error)
    end)
  end

  --- Mock update_body function
  function mock_cli.update_body(number, body, repo, callback)
    local args = { "issue", "edit", tostring(number), "--body", body }
    if repo then
      table.insert(args, "--repo")
      table.insert(args, repo)
    end

    mock_cli.run(args, function(success, _, error)
      callback(success, error)
    end)
  end

  return mock_cli
end

return M
