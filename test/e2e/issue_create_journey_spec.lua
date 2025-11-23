--- E2E test: Issue creation user journey
--- Tests the complete workflow of creating an issue with templates
describe("E2E: Issue Creation Journey", function()
  local gh
  
  before_each(function()
    gh = require("gh")
    vim.cmd("bufdo bwipeout!")
  end)
  
  after_each(function()
    vim.cmd("bufdo bwipeout!")
  end)
  
  describe("User Journey: Create issue without template", function()
    it("should create issue buffer with empty template", function()
      local cli = require("gh.cli")
      local original_templates = cli.list_issue_templates
      
      -- Mock: no templates available
      cli.list_issue_templates = function(repo, callback)
        callback(true, {}, nil)
      end
      
      gh.issues.create_issue_buffer({})
      vim.wait(500, function() return false end)
      
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.is_true(bufname:match("gh://issue/new") ~= nil)
      assert.are.equal("acwrite", vim.bo.buftype)
      
      cli.list_issue_templates = original_templates
    end)
  end)
  
  describe("User Journey: Create issue with template", function()
    it("should load template content", function()
      local cli = require("gh.cli")
      local original_templates = cli.list_issue_templates
      local original_get_template = cli.get_issue_template
      
      cli.list_issue_templates = function(repo, callback)
        callback(true, {
          { name = "bug_report.md", path = ".github/ISSUE_TEMPLATE/bug_report.md" },
        }, nil)
      end
      
      cli.get_issue_template = function(repo, path, callback)
        callback(true, "## Bug Description\n\nDescribe the bug here.", nil)
      end
      
      gh.issues.create_issue_buffer({ template = ".github/ISSUE_TEMPLATE/bug_report.md" })
      vim.wait(500, function() return false end)
      
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local has_template_content = false
      for _, line in ipairs(lines) do
        if line:match("Bug Description") then
          has_template_content = true
          break
        end
      end
      assert.is_true(has_template_content)
      
      cli.list_issue_templates = original_templates
      cli.get_issue_template = original_get_template
    end)
  end)
  
  describe("User Journey: Create issue with metadata", function()
    it("should create buffer with assignees and labels", function()
      local cli = require("gh.cli")
      local original_templates = cli.list_issue_templates
      
      cli.list_issue_templates = function(repo, callback)
        callback(true, {}, nil)
      end
      
      gh.issues.create_issue_buffer({
        title = "Test Issue",
        assignees = { "@me" },
        labels = { "bug", "urgent" },
        milestone = "v1.0",
      })
      vim.wait(500, function() return false end)
      
      -- Verify buffer was created
      local bufname = vim.api.nvim_buf_get_name(0)
      assert.is_true(bufname:match("gh://issue/new") ~= nil)
      
      -- Verify metadata is stored
      local ok, opts = pcall(vim.api.nvim_buf_get_var, 0, "gh_issue_opts")
      assert.is_true(ok)
      assert.are.same({ "@me" }, opts.assignees)
      assert.are.same({ "bug", "urgent" }, opts.labels)
      assert.are.equal("v1.0", opts.milestone)
      
      cli.list_issue_templates = original_templates
    end)
  end)
  
  describe("User Journey: Save new issue", function()
    it("should call create_issue on save", function()
      local cli = require("gh.cli")
      local original_templates = cli.list_issue_templates
      local original_create = cli.create_issue
      local create_called = false
      local create_opts = nil
      
      cli.list_issue_templates = function(repo, callback)
        callback(true, {}, nil)
      end
      
      cli.create_issue = function(opts, callback)
        create_called = true
        create_opts = opts
        callback(true, { number = 123, url = "https://github.com/test/repo/issues/123" }, nil)
      end
      
      gh.issues.create_issue_buffer({ title = "Test Issue" })
      vim.wait(500, function() return false end)
      
      -- Modify buffer content
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { "# My Test Issue" })
      vim.api.nvim_buf_set_lines(0, 2, -1, false, { "Issue body content" })
      
      -- Trigger save
      vim.cmd("write")
      vim.wait(2000, function() return create_called end)
      
      assert.is_true(create_called)
      assert.is_not_nil(create_opts)
      assert.are.equal("My Test Issue", create_opts.title)
      assert.are.equal("Issue body content", create_opts.body)
      
      cli.list_issue_templates = original_templates
      cli.create_issue = original_create
    end)
  end)
  
  describe("User Journey: Create from issue list", function()
    it("should create issue from list with <leader>n", function()
      local cli = require("gh.cli")
      local original_list = cli.list_issues
      local original_templates = cli.list_issue_templates
      
      cli.list_issues = function(repo, opts, callback)
        callback(true, {
          { number = 1, title = "Existing Issue", state = "open", labels = {}, assignees = {}, author = { login = "user1" }, createdAt = "2024-01-01T00:00:00Z", updatedAt = "2024-01-01T00:00:00Z" },
        }, nil)
      end
      
      cli.list_issue_templates = function(repo, callback)
        callback(true, {}, nil)
      end
      
      -- Open issue list
      gh.issues.open_issue_list(nil)
      vim.wait(500, function() return false end)
      
      local list_bufnr = vim.api.nvim_get_current_buf()
      
      -- Trigger <leader>n keymap
      gh.issues.create_issue_buffer({ repo = nil })
      vim.wait(500, function() return false end)
      
      local create_bufnr = vim.api.nvim_get_current_buf()
      
      -- Verify we're in a different buffer
      assert.are_not.equal(list_bufnr, create_bufnr)
      
      -- Verify it's a new issue buffer
      local bufname = vim.api.nvim_buf_get_name(create_bufnr)
      assert.is_true(bufname:match("gh://issue/new") ~= nil)
      
      cli.list_issues = original_list
      cli.list_issue_templates = original_templates
    end)
  end)
end)
