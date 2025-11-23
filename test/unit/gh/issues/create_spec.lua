--- Unit tests for issues.create module
--- Mirrors: lua/gh/issues/create.lua
describe("issues.create", function()
  local create
  
  before_each(function()
    create = require("gh.issues.create")
  end)
  
  describe("get_assignee_completions", function()
    it("should return cached assignees", function()
      local cache = require("gh.cache")
      cache.write("assignees_test_repo", { "@me", "user1", "user2" })
      
      local result = nil
      create.get_assignee_completions("test/repo", function(assignees)
        result = assignees
      end)
      
      vim.wait(100, function() return result ~= nil end)
      
      assert.is_not_nil(result)
      assert.is_true(vim.tbl_contains(result, "@me"))
    end)
  end)
  
  describe("get_label_completions", function()
    it("should fetch and cache labels", function()
      local cli = require("gh.cli")
      local original_list = cli.list_labels
      
      cli.list_labels = function(repo, callback)
        callback(true, {
          { name = "bug" },
          { name = "enhancement" },
        }, nil)
      end
      
      local result = nil
      create.get_label_completions("test/repo", function(labels)
        result = labels
      end)
      
      vim.wait(500, function() return result ~= nil end)
      
      assert.is_not_nil(result)
      assert.is_true(vim.tbl_contains(result, "bug"))
      assert.is_true(vim.tbl_contains(result, "enhancement"))
      
      cli.list_labels = original_list
    end)
  end)
  
  describe("get_milestone_completions", function()
    it("should fetch and cache milestones", function()
      local cli = require("gh.cli")
      local original_list = cli.list_milestones
      
      cli.list_milestones = function(repo, callback)
        callback(true, {
          { title = "v1.0" },
          { title = "v2.0" },
        }, nil)
      end
      
      local result = nil
      create.get_milestone_completions("test/repo", function(milestones)
        result = milestones
      end)
      
      vim.wait(500, function() return result ~= nil end)
      
      assert.is_not_nil(result)
      assert.is_true(vim.tbl_contains(result, "v1.0"))
      assert.is_true(vim.tbl_contains(result, "v2.0"))
      
      cli.list_milestones = original_list
    end)
  end)
  
  describe("get_template_completions", function()
    it("should fetch and cache templates", function()
      local cli = require("gh.cli")
      local original_list = cli.list_issue_templates
      
      cli.list_issue_templates = function(repo, callback)
        callback(true, {
          { name = "bug_report.md" },
          { name = "feature_request.md" },
        }, nil)
      end
      
      local result = nil
      create.get_template_completions("test/repo", function(templates)
        result = templates
      end)
      
      vim.wait(500, function() return result ~= nil end)
      
      assert.is_not_nil(result)
      assert.is_true(vim.tbl_contains(result, "bug_report.md"))
      assert.is_true(vim.tbl_contains(result, "feature_request.md"))
      
      cli.list_issue_templates = original_list
    end)
  end)
end)
