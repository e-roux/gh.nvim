--- Mock GitHub CLI JSON responses for testing
local M = {}

--- Mock response for 'gh issue list --json number,title,state,labels'
M.issue_list = {
  {
    number = 1,
    title = "Add dark mode support",
    state = "open",
    labels = {
      { name = "enhancement" },
      { name = "ui" },
    },
  },
  {
    number = 2,
    title = "Fix navigation bug in sidebar",
    state = "open",
    labels = {
      { name = "bug" },
      { name = "high-priority" },
    },
  },
  {
    number = 3,
    title = "Update documentation",
    state = "closed",
    labels = {
      { name = "documentation" },
    },
  },
  {
    number = 42,
    title = "Refactor authentication module",
    state = "open",
    labels = {},
  },
}

--- Mock response for 'gh issue view 1 --json number,title,body,state,labels'
M.issue_detail_1 = {
  number = 1,
  title = "Add dark mode support",
  body = [[This issue tracks the implementation of dark mode support across the application.

## Requirements
- [ ] Add theme toggle in settings
- [ ] Create dark color palette
- [ ] Update all components to support theming
- [ ] Add persistence for user preference

## Design considerations
We should follow system preference by default but allow manual override.]],
  state = "open",
  labels = {
    { name = "enhancement" },
    { name = "ui" },
  },
}

--- Mock response for issue #2
M.issue_detail_2 = {
  number = 2,
  title = "Fix navigation bug in sidebar",
  body = "The sidebar navigation breaks when resizing the window below 768px width.\n\nSteps to reproduce:\n1. Open the app\n2. Resize window to < 768px\n3. Try to navigate using sidebar\n\nExpected: Navigation should work\nActual: Menu items are not clickable",
  state = "open",
  labels = {
    { name = "bug" },
    { name = "high-priority" },
  },
}

--- Mock response for issue #3
M.issue_detail_3 = {
  number = 3,
  title = "Update documentation",
  body = "Documentation has been updated to reflect the new API changes in v2.0.",
  state = "closed",
  labels = {
    { name = "documentation" },
  },
}

--- Mock response for issue #42
M.issue_detail_42 = {
  number = 42,
  title = "Refactor authentication module",
  body = "",
  state = "open",
  labels = {},
}

--- Empty issue list response
M.empty_issue_list = {}

--- Issue list for a different repo (e.g., owner/other-repo)
M.issue_list_other_repo = {
  {
    number = 100,
    title = "Setup CI/CD pipeline",
    state = "open",
    labels = {
      { name = "infrastructure" },
      { name = "devops" },
    },
  },
  {
    number = 101,
    title = "Add unit tests",
    state = "closed",
    labels = {
      { name = "testing" },
    },
  },
}

--- Get issue detail by number
---@param number integer
---@return table|nil
function M.get_issue_detail(number)
  local details = {
    [1] = M.issue_detail_1,
    [2] = M.issue_detail_2,
    [3] = M.issue_detail_3,
    [42] = M.issue_detail_42,
  }
  return details[number]
end

--- Get issue list by repo
---@param repo string|nil Repository name or nil for default
---@return table
function M.get_issue_list(repo)
  if repo == "owner/other-repo" then
    return M.issue_list_other_repo
  end
  return M.issue_list
end

return M
