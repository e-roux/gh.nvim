--- E2E test: Command flow
--- Tests the complete command execution flow from user input to result
describe("E2E: Command Flow", function()
  local commands
  
  before_each(function()
    commands = require("gh.commands")
    vim.cmd("bufdo bwipeout!")
  end)
  
  after_each(function()
    vim.cmd("bufdo bwipeout!")
  end)
  
  describe("User Journey: Execute issue list command", function()
    it("should handle :Gh issue list", function()
      local cli = require("gh.cli")
      local original_list = cli.list_issues
      local list_called = false
      
      cli.list_issues = function(repo, opts, callback)
        list_called = true
        callback(true, {
          { number = 1, title = "Test", state = "open", labels = {}, assignees = {}, author = { login = "user" }, createdAt = "2024-01-01T00:00:00Z", updatedAt = "2024-01-01T00:00:00Z" },
        }, nil)
      end
      
      commands.handle({ "issue", "list" })
      vim.wait(500, function() return list_called end)
      
      assert.is_true(list_called)
      
      cli.list_issues = original_list
    end)
    
    it("should handle :Gh issue list --state closed", function()
      local cli = require("gh.cli")
      local original_list = cli.list_issues
      local captured_opts = nil
      
      cli.list_issues = function(repo, opts, callback)
        captured_opts = opts
        callback(true, {}, nil)
      end
      
      commands.handle({ "issue", "list", "--state", "closed" })
      vim.wait(500, function() return false end)
      
      assert.is_not_nil(captured_opts)
      assert.are.equal("closed", captured_opts.state)
      
      cli.list_issues = original_list
    end)
  end)
  
  describe("User Journey: Execute issue view command", function()
    it("should handle :Gh issue view 123", function()
      local cli = require("gh.cli")
      local original_get = cli.get_issue
      local get_called = false
      local captured_number = nil
      
      cli.get_issue = function(number, repo, callback)
        get_called = true
        captured_number = number
        callback(true, {
          number = number,
          title = "Test Issue",
          body = "Description",
          state = "open",
          labels = {},
          assignees = {},
          author = { login = "user" },
          createdAt = "2024-01-01T00:00:00Z",
          updatedAt = "2024-01-01T00:00:00Z",
          url = "https://github.com/test/repo/issues/" .. number,
        }, nil)
      end
      
      commands.handle({ "issue", "view", "123" })
      vim.wait(500, function() return get_called end)
      
      assert.is_true(get_called)
      assert.are.equal(123, captured_number)
      
      cli.get_issue = original_get
    end)
  end)
  
  describe("User Journey: Execute issue create command", function()
    it("should handle :Gh issue create", function()
      local cli = require("gh.cli")
      local original_templates = cli.list_issue_templates
      local templates_called = false
      
      cli.list_issue_templates = function(repo, callback)
        templates_called = true
        callback(true, {}, nil)
      end
      
      commands.handle({ "issue", "create" })
      vim.wait(500, function() return templates_called end)
      
      assert.is_true(templates_called)
      
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.is_true(bufname:match("gh://issue/new") ~= nil)
      
      cli.list_issue_templates = original_templates
    end)
    
    it("should handle :Gh issue create --title 'Test' --label bug", function()
      local cli = require("gh.cli")
      local original_templates = cli.list_issue_templates
      
      cli.list_issue_templates = function(repo, callback)
        callback(true, {}, nil)
      end
      
      commands.handle({ "issue", "create", "--title", "Test Issue", "--label", "bug" })
      vim.wait(500, function() return false end)
      
      -- Verify buffer was created with metadata
      local ok, opts = pcall(vim.api.nvim_buf_get_var, 0, "gh_issue_opts")
      assert.is_true(ok)
      assert.are.same({ "bug" }, opts.labels)
      
      cli.list_issue_templates = original_templates
    end)
  end)
  
  describe("User Journey: Command completion", function()
    it("should complete issue subcommands", function()
      local completions = commands.complete("", "Gh issue ", 10)
      assert.is_not_nil(completions, "Completions should not be nil")
      assert.is_true(type(completions) == "table", "Completions should be a table")
      assert.is_true(#completions > 0, "Completions should not be empty, got: " .. vim.inspect(completions))
      
      -- Check if list is in completions
      local has_list = false
      for _, v in ipairs(completions) do
        if v == "list" then
          has_list = true
          break
        end
      end
      assert.is_true(has_list, "Should contain 'list', got: " .. vim.inspect(completions))
      assert.is_true(vim.tbl_contains(completions, "view"), "Should contain 'view'")
      assert.is_true(vim.tbl_contains(completions, "create"), "Should contain 'create'")
    end)
    
    it("should complete flags", function()
      local completions = commands.complete("--", "Gh issue list --", 16)
      assert.is_true(vim.tbl_contains(completions, "--state"))
      assert.is_true(vim.tbl_contains(completions, "--limit"))
    end)
  end)
  
  describe("User Journey: Error handling", function()
    it("should handle invalid subcommand", function()
      local notified = false
      local original_notify = vim.notify
      
      vim.notify = function(msg, level)
        if msg:match("Unknown") then
          notified = true
        end
      end
      
      commands.handle({ "issue", "invalid" })
      
      assert.is_true(notified)
      
      vim.notify = original_notify
    end)
    
    it("should handle missing issue number", function()
      local notified = false
      local original_notify = vim.notify
      
      vim.notify = function(msg, level)
        if msg:match("Usage") then
          notified = true
        end
      end
      
      commands.handle({ "issue", "view" })
      
      assert.is_true(notified)
      
      vim.notify = original_notify
    end)
  end)
end)
