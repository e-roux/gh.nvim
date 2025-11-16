--- Tests for gh.issues module
local fixtures = require("test.fixtures.gh_responses")
local types = require("gh.types")

-- Set test environment variable before requiring the module
vim.env.PLENARY_TEST = "1"
local issues = require("gh.issues")

describe("gh.issues", function()
  describe("issue list parsing", function()
    local collection

    before_each(function()
      collection = types.IssueCollection.new(fixtures.issue_list)
    end)

    it("formats issue list correctly", function()
      local lines = collection:format_list()
      
      -- 7 filter lines + 4 issues = 11 lines (horizontal rule is virtual)
      assert.equals(11, #lines)
      
      -- Filter lines should be present (lines 1-7)
      -- They should be either empty or contain filter values
      for i = 1, 7 do
        assert.is_not_nil(lines[i])
      end
      
      -- Issue lines start at line 8 (new format without state column)
      assert.equals("#01 │ Add dark mode support", lines[8])
      assert.equals("#02 │ Fix navigation bug in sidebar", lines[9])
      assert.equals("#03 │ Update documentation", lines[10])
      assert.equals("#42 │ Refactor authentication module", lines[11])
    end)

    it("detects no changes when buffer is unchanged", function()
      local original_lines = collection:format_list()
      
      -- Parse the unchanged buffer back (skip 7 filter lines)
      local changes = {}
      local filter_ui = require("gh.filter")
      for i = filter_ui.FIRST_ISSUE_LINE, #original_lines do
        local line = original_lines[i]
        -- New format: "#0001 │ Issue title" (no state column)
        local number, title = line:match("^#0*(%d+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            if title ~= original.title then
              changes[number] = { title = title }
            end
          end
        end
      end
      
      assert.equals(0, vim.tbl_count(changes))
    end)

    it("detects title change", function()
      local lines = collection:format_list()
      
      -- Modify issue #1 title (now on line 8 - after 7 filter lines)
      lines[8] = "#01 │ Add dark mode with auto-detection"
      
      -- Parse changes (skip 7 filter lines)
      local filter_ui = require("gh.filter")
      local changes = {}
      for i = filter_ui.FIRST_ISSUE_LINE, #lines do
        local line = lines[i]
        local number, title = line:match("^#0*(%d+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            local change = {}
            if title ~= original.title then
              change.title = title
            end
            if next(change) then
              changes[number] = change
            end
          end
        end
      end
      
      assert.equals(1, vim.tbl_count(changes))
      assert.is_not_nil(changes[1])
      assert.equals("Add dark mode with auto-detection", changes[1].title)
    end)

    -- State changes are now managed via filter lines, not issue lines
    -- These tests are removed as they're no longer applicable

    it("detects title changes for multiple issues", function()
      local lines = collection:format_list()
      
      -- Change multiple issues (lines 8, 9, 11 after 7 filter lines)
      lines[8] = "#01 │ Dark mode implementation"
      lines[11] = "#42 │ Refactored authentication module"
      
      -- Parse changes
      local filter_ui = require("gh.filter")
      local changes = {}
      for i = filter_ui.FIRST_ISSUE_LINE, #lines do
        local line = lines[i]
        local number, title = line:match("^#0*(%d+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            local change = {}
            if title ~= original.title then
              change.title = title
            end
            if next(change) then
              changes[number] = change
            end
          end
        end
      end
      
      assert.equals(2, vim.tbl_count(changes))
      assert.is_not_nil(changes[1])
      assert.equals("Dark mode implementation", changes[1].title)
      assert.is_not_nil(changes[42])
      assert.equals("Refactored authentication module", changes[42].title)
    end)

    it("handles empty lines gracefully", function()
      local lines = collection:format_list()
      
      -- Add empty line
      table.insert(lines, "")
      
      -- Parse changes
      local filter_ui = require("gh.filter")
      local changes = {}
      for i = filter_ui.FIRST_ISSUE_LINE, #lines do
        local line = lines[i]
        if line and line ~= "" then
          local number, title = line:match("^#0*(%d+)%s+│%s+(.+)%s*$")
          if number then
            number = tonumber(number)
            local original = collection:get(number)
            if original then
              local change = {}
              if title ~= original.title then
                change.title = title
              end
              if next(change) then
                changes[number] = change
              end
            end
          end
        end
      end
      
      -- Should not crash
      assert.equals(0, vim.tbl_count(changes))
    end)

    it("ignores malformed lines", function()
      local lines = collection:format_list()
      
      -- Add malformed line
      table.insert(lines, "This is not a valid issue line")
      
      -- Parse changes
      local filter_ui = require("gh.filter")
      local changes = {}
      for i = filter_ui.FIRST_ISSUE_LINE, #lines do
        local line = lines[i]
        if line and line ~= "" then
          local number, title = line:match("^#0*(%d+)%s+│%s+(.+)%s*$")
          if number then
            number = tonumber(number)
            local original = collection:get(number)
            if original then
              local change = {}
              if title ~= original.title then
                change.title = title
              end
              if next(change) then
                changes[number] = change
              end
            end
          end
        end
      end
      
      -- Should not crash
      assert.equals(0, vim.tbl_count(changes))
    end)

    -- State validation tests removed - state is now managed via filter lines
    -- Client-side validation happens in parse_filter_context()

    it("only includes modified issues in changes", function()
      local lines = collection:format_list()
      
      -- Only modify issue #1 (line 8), leave others unchanged
      lines[8] = "#01 │ Add dark mode with system detection"
      
      -- Call the actual parse function
      local changes, error = issues._test_parse_issue_list_changes(lines, collection)
      
      -- Should succeed
      assert.is_not_nil(changes)
      assert.is_nil(error)
      
      -- Only issue #1 should be in changes
      assert.equals(1, vim.tbl_count(changes))
      assert.is_not_nil(changes[1])
      assert.equals("Add dark mode with system detection", changes[1].title)
      
      -- Other issues should NOT be in changes
      assert.is_nil(changes[2])
      assert.is_nil(changes[3])
      assert.is_nil(changes[42])
    end)

    it("does not include issues with no actual changes", function()
      local lines = collection:format_list()
      
      -- Keep everything the same (no changes)
      -- lines remain as formatted
      
      -- Call the actual parse function
      local changes, error = issues._test_parse_issue_list_changes(lines, collection)
      
      -- Should succeed
      assert.is_not_nil(changes)
      assert.is_nil(error)
      
      -- No issues should be in changes
      assert.equals(0, vim.tbl_count(changes))
    end)
  end)

  describe("issue detail parsing", function()
    local issue

    before_each(function()
      issue = types.Issue.new(fixtures.issue_detail_1)
    end)

    it("formats issue detail correctly", function()
      local lines = issue:format_detail()
      
      assert.equals("# Add dark mode support", lines[1])
      assert.equals("---", lines[2])
      assert.is_true(#lines > 2) -- Should have body content
    end)

    it("detects title change in detail view", function()
      local lines = issue:format_detail()
      
      -- Change title
      lines[1] = "# Add dark mode with system detection"
      
      -- Parse title
      local new_title = lines[1]:gsub("^#%s*", "")
      
      assert.equals("Add dark mode with system detection", new_title)
      assert.is_not.equals(issue.title, new_title)
    end)

    it("detects body change in detail view", function()
      local original_lines = issue:format_detail()
      local lines = vim.deepcopy(original_lines)
      
      -- Modify body
      table.insert(lines, "## Additional Notes")
      table.insert(lines, "This is a new section")
      
      -- Parse body (skip title and separator)
      local body_lines = {}
      for i = 2, #lines do
        table.insert(body_lines, lines[i])
      end
      local new_body = table.concat(body_lines, "\n")
      
      -- Parse original body
      local original_body_lines = {}
      for i = 2, #original_lines do
        table.insert(original_body_lines, original_lines[i])
      end
      local original_body = table.concat(original_body_lines, "\n")
      
      assert.is_not.equals(original_body, new_body)
    end)
  end)
end)
