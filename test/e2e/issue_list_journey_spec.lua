--- E2E test: Issue list user journey
--- Tests the complete workflow of listing and viewing issues
describe("E2E: Issue List Journey", function()
  local gh
  
  before_each(function()
    -- Load gh module
    gh = require("gh")
    
    -- Clear any existing buffers
    vim.cmd("bufdo bwipeout!")
  end)
  
  after_each(function()
    -- Clean up buffers
    vim.cmd("bufdo bwipeout!")
  end)
  
  describe("User Journey: Browse issues", function()
    it("should open issue list buffer", function()
      -- Mock CLI response
      local cli = require("gh.cli")
      local original_list = cli.list_issues
      
      cli.list_issues = function(repo, opts, callback)
        callback(true, {
          { number = 1, title = "Test Issue 1", state = "open", labels = {}, assignees = {}, author = { login = "user1" }, createdAt = "2024-01-01T00:00:00Z", updatedAt = "2024-01-01T00:00:00Z" },
          { number = 2, title = "Test Issue 2", state = "closed", labels = {}, assignees = {}, author = { login = "user2" }, createdAt = "2024-01-02T00:00:00Z", updatedAt = "2024-01-02T00:00:00Z" },
        }, nil)
      end
      
      -- Open issue list
      gh.issues.open_issue_list(nil, { state = "all" })
      
      -- Wait for async operations
      vim.wait(1000, function() return false end)
      
      -- Verify buffer was created
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.is_true(bufname:match("gh://issues") ~= nil)
      
      -- Verify buffer type
      assert.are.equal("acwrite", vim.bo.buftype)
      
      -- Restore original function
      cli.list_issues = original_list
    end)
    
    it("should filter issues by state", function()
      local cli = require("gh.cli")
      local original_list = cli.list_issues
      local captured_opts = nil
      
      cli.list_issues = function(repo, opts, callback)
        captured_opts = opts
        callback(true, {}, nil)
      end
      
      gh.issues.open_issue_list(nil, { state = "closed" })
      vim.wait(500, function() return false end)
      
      assert.is_not_nil(captured_opts)
      assert.are.equal("closed", captured_opts.state)
      
      cli.list_issues = original_list
    end)
  end)
  
  describe("User Journey: View issue detail", function()
    it("should open issue detail buffer", function()
      local cli = require("gh.cli")
      local original_get = cli.get_issue
      
      cli.get_issue = function(number, repo, callback)
        callback(true, {
          number = 123,
          title = "Test Issue",
          body = "Issue description",
          state = "open",
          labels = {},
          assignees = {},
          author = { login = "testuser" },
          createdAt = "2024-01-01T00:00:00Z",
          updatedAt = "2024-01-01T00:00:00Z",
          url = "https://github.com/test/repo/issues/123",
        }, nil)
      end
      
      gh.issues.open_issue_detail(123, nil)
      vim.wait(1000, function() return false end)
      
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.is_true(bufname:match("gh://issue/123") ~= nil)
      
      cli.get_issue = original_get
    end)
  end)
  
  describe("User Journey: Navigate between list and detail", function()
    it("should allow navigation from list to detail", function()
      local cli = require("gh.cli")
      local original_list = cli.list_issues
      local original_get = cli.get_issue
      
      -- Mock list response
      cli.list_issues = function(repo, opts, callback)
        callback(true, {
          { number = 1, title = "Issue 1", state = "open", labels = {}, assignees = {}, author = { login = "user1" }, createdAt = "2024-01-01T00:00:00Z", updatedAt = "2024-01-01T00:00:00Z" },
        }, nil)
      end
      
      -- Mock get response
      cli.get_issue = function(number, repo, callback)
        callback(true, {
          number = number,
          title = "Issue " .. number,
          body = "Description",
          state = "open",
          labels = {},
          assignees = {},
          author = { login = "user1" },
          createdAt = "2024-01-01T00:00:00Z",
          updatedAt = "2024-01-01T00:00:00Z",
          url = "https://github.com/test/repo/issues/" .. number,
        }, nil)
      end
      
      -- Open list
      gh.issues.open_issue_list(nil)
      vim.wait(500, function() return false end)
      
      local list_bufnr = vim.api.nvim_get_current_buf()
      
      -- Open detail
      gh.issues.open_issue_detail(1, nil)
      vim.wait(500, function() return false end)
      
      local detail_bufnr = vim.api.nvim_get_current_buf()
      
      -- Verify we're in a different buffer
      assert.are_not.equal(list_bufnr, detail_bufnr)
      
      -- Verify detail buffer name
      local bufname = vim.api.nvim_buf_get_name(detail_bufnr)
      assert.is_true(bufname:match("gh://issue/1") ~= nil)
      
      cli.list_issues = original_list
      cli.get_issue = original_get
    end)
  end)
end)
