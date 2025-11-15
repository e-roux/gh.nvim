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
      
      assert.equals(6, #lines) -- 2 header lines + 4 issues
      assert.equals("# GitHub Issues (edit and :w to save)", lines[1])
      assert.equals("# Format: #number │ STATE │ title", lines[2])
      assert.equals("#1 │ OPEN │ Add dark mode support", lines[3])
      assert.equals("#2 │ OPEN │ Fix navigation bug in sidebar", lines[4])
      assert.equals("#3 │ CLOSED │ Update documentation", lines[5])
      assert.equals("#42 │ OPEN │ Refactor authentication module", lines[6])
    end)

    it("detects no changes when buffer is unchanged", function()
      local original_lines = collection:format_list()
      
      -- Parse the unchanged buffer back
      local changes = {}
      for i = 3, #original_lines do
        local line = original_lines[i]
        local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            if title ~= original.title or state:lower() ~= original.state then
              changes[number] = { title = title, state = state:lower() }
            end
          end
        end
      end
      
      assert.equals(0, vim.tbl_count(changes))
    end)

    it("detects title change", function()
      local lines = collection:format_list()
      
      -- Modify issue #1 title
      lines[3] = "#1 │ OPEN │ Add dark mode with auto-detection"
      
      -- Parse changes
      local changes = {}
      for i = 3, #lines do
        local line = lines[i]
        local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            local change = {}
            if title ~= original.title then
              change.title = title
            end
            if state:lower() ~= original.state then
              change.state = state:lower()
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
      assert.is_nil(changes[1].state)
    end)

    it("detects state change", function()
      local lines = collection:format_list()
      
      -- Change issue #1 from OPEN to CLOSED
      lines[3] = "#1 │ CLOSED │ Add dark mode support"
      
      -- Parse changes
      local changes = {}
      for i = 3, #lines do
        local line = lines[i]
        local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            local change = {}
            if title ~= original.title then
              change.title = title
            end
            if state:lower() ~= original.state then
              change.state = state:lower()
            end
            if next(change) then
              changes[number] = change
            end
          end
        end
      end
      
      assert.equals(1, vim.tbl_count(changes))
      assert.is_not_nil(changes[1])
      assert.is_nil(changes[1].title)
      assert.equals("closed", changes[1].state)
    end)

    it("detects both title and state changes", function()
      local lines = collection:format_list()
      
      -- Change both title and state for issue #2
      lines[4] = "#2 │ CLOSED │ Fixed navigation bug in sidebar"
      
      -- Parse changes
      local changes = {}
      for i = 3, #lines do
        local line = lines[i]
        local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            local change = {}
            if title ~= original.title then
              change.title = title
            end
            if state:lower() ~= original.state then
              change.state = state:lower()
            end
            if next(change) then
              changes[number] = change
            end
          end
        end
      end
      
      assert.equals(1, vim.tbl_count(changes))
      assert.is_not_nil(changes[2])
      assert.equals("Fixed navigation bug in sidebar", changes[2].title)
      assert.equals("closed", changes[2].state)
    end)

    it("detects multiple issue changes", function()
      local lines = collection:format_list()
      
      -- Change multiple issues
      lines[3] = "#1 │ OPEN │ Dark mode implementation"
      lines[4] = "#2 │ CLOSED │ Fix navigation bug in sidebar"
      lines[6] = "#42 │ CLOSED │ Refactor authentication module"
      
      -- Parse changes
      local changes = {}
      for i = 3, #lines do
        local line = lines[i]
        local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
        if number then
          number = tonumber(number)
          local original = collection:get(number)
          if original then
            local change = {}
            if title ~= original.title then
              change.title = title
            end
            if state:lower() ~= original.state then
              change.state = state:lower()
            end
            if next(change) then
              changes[number] = change
            end
          end
        end
      end
      
      assert.equals(3, vim.tbl_count(changes))
      assert.is_not_nil(changes[1])
      assert.equals("Dark mode implementation", changes[1].title)
      assert.is_not_nil(changes[2])
      assert.equals("closed", changes[2].state)
      assert.is_not_nil(changes[42])
      assert.equals("closed", changes[42].state)
    end)

    it("handles empty lines gracefully", function()
      local lines = collection:format_list()
      
      -- Add empty line
      table.insert(lines, "")
      
      -- Parse changes
      local changes = {}
      for i = 3, #lines do
        local line = lines[i]
        if line and line ~= "" then
          local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
          if number then
            number = tonumber(number)
            local original = collection:get(number)
            if original then
              local change = {}
              if title ~= original.title then
                change.title = title
              end
              if state:lower() ~= original.state then
                change.state = state:lower()
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
      local changes = {}
      for i = 3, #lines do
        local line = lines[i]
        if line and line ~= "" then
          local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
          if number then
            number = tonumber(number)
            local original = collection:get(number)
            if original then
              local change = {}
              if title ~= original.title then
                change.title = title
              end
              if state:lower() ~= original.state then
                change.state = state:lower()
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

    it("validates state values and rejects invalid states", function()
      local lines = collection:format_list()
      
      -- Change state to invalid value
      lines[3] = "#1 │ FOO │ Add dark mode support"
      
      -- Call the actual parse function
      local changes, error = issues._test_parse_issue_list_changes(lines, collection)
      
      -- Should return nil and error message
      assert.is_nil(changes)
      assert.is_not_nil(error)
      assert.is_true(error:find("Invalid state 'FOO'") ~= nil)
      assert.is_true(error:find("must be OPEN or CLOSED") ~= nil)
    end)

    it("validates multiple invalid states", function()
      local lines = collection:format_list()
      
      -- Change multiple states to invalid values
      lines[3] = "#1 │ PENDING │ Add dark mode support"
      lines[4] = "#2 │ INVALID │ Fix navigation bug"
      
      -- Call the actual parse function
      local changes, error = issues._test_parse_issue_list_changes(lines, collection)
      
      -- Should return nil and error message with both errors
      assert.is_nil(changes)
      assert.is_not_nil(error)
      assert.is_true(error:find("PENDING") ~= nil)
      assert.is_true(error:find("INVALID") ~= nil)
    end)

    it("accepts valid states in different cases", function()
      local lines = collection:format_list()
      
      -- Change to valid states in different cases (keep original titles to avoid title changes)
      lines[3] = "#1 │ closed │ Add dark mode support"
      lines[4] = "#2 │ Open │ Fix navigation bug in sidebar"
      
      -- Call the actual parse function
      local changes, error = issues._test_parse_issue_list_changes(lines, collection)
      
      -- Should succeed
      assert.is_not_nil(changes)
      assert.is_nil(error)
      assert.equals("closed", changes[1].state)
      -- #2 was already open, so no change detected
      assert.is_nil(changes[2])
    end)

    it("only includes modified issues in changes", function()
      local lines = collection:format_list()
      
      -- Only modify issue #1, leave others unchanged
      lines[3] = "#1 │ CLOSED │ Add dark mode support"
      -- lines[4], lines[5], lines[6] remain unchanged
      
      -- Call the actual parse function
      local changes, error = issues._test_parse_issue_list_changes(lines, collection)
      
      -- Should succeed
      assert.is_not_nil(changes)
      assert.is_nil(error)
      
      -- Only issue #1 should be in changes
      assert.equals(1, vim.tbl_count(changes))
      assert.is_not_nil(changes[1])
      assert.equals("closed", changes[1].state)
      
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
      for i = 3, #lines do
        table.insert(body_lines, lines[i])
      end
      local new_body = table.concat(body_lines, "\n")
      
      -- Parse original body
      local original_body_lines = {}
      for i = 3, #original_lines do
        table.insert(original_body_lines, original_lines[i])
      end
      local original_body = table.concat(original_body_lines, "\n")
      
      assert.is_not.equals(original_body, new_body)
    end)
  end)
end)
