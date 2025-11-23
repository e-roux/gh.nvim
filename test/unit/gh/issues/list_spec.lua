--- Unit tests for issues.list module
--- Mirrors: lua/gh/issues/list.lua
describe("issues.list", function()
  local list
  
  before_each(function()
    list = require("gh.issues.list")
  end)
  
  describe("_test_parse_issue_list_changes", function()
    it("should parse title changes", function()
      local collection = require("gh.models.collection").IssueCollection.new({
        { number = 1, title = "Original Title", state = "open" },
      })
      
      local lines = {
        "State: open",
        "Assignee:",
        "Author:",
        "Label:",
        "Mention:",
        "Milestone:",
        "Search:",
        "────────────────────────────────────────",
        "#1 │ Modified Title",
      }
      
      local changes, err = list._test_parse_issue_list_changes(lines, collection)
      
      assert.is_nil(err)
      assert.is_not_nil(changes)
      assert.is_not_nil(changes[1])
      assert.are.equal("Modified Title", changes[1].title)
    end)
    
    it("should detect no changes", function()
      local collection = require("gh.models.collection").IssueCollection.new({
        { number = 1, title = "Same Title", state = "open" },
      })
      
      local lines = {
        "State: open",
        "Assignee:",
        "Author:",
        "Label:",
        "Mention:",
        "Milestone:",
        "Search:",
        "────────────────────────────────────────",
        "#1 │ Same Title",
      }
      
      local changes, err = list._test_parse_issue_list_changes(lines, collection)
      
      assert.is_nil(err)
      assert.is_not_nil(changes)
      assert.is_nil(next(changes)) -- Empty table
    end)
    
    it("should handle multiple issues", function()
      local collection = require("gh.models.collection").IssueCollection.new({
        { number = 1, title = "Title 1", state = "open" },
        { number = 2, title = "Title 2", state = "open" },
      })
      
      local lines = {
        "State: open",
        "Assignee:",
        "Author:",
        "Label:",
        "Mention:",
        "Milestone:",
        "Search:",
        "────────────────────────────────────────",
        "#1 │ Modified Title 1",
        "#2 │ Modified Title 2",
      }
      
      local changes, err = list._test_parse_issue_list_changes(lines, collection)
      
      assert.is_nil(err)
      assert.is_not_nil(changes)
      assert.are.equal("Modified Title 1", changes[1].title)
      assert.are.equal("Modified Title 2", changes[2].title)
    end)
  end)
end)
