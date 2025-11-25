--- IssueCollection model
--- Represents a collection of GitHub issues with filtering, sorting, and formatting capabilities
local Issue = require("gh.models.issue").Issue

local M = {}

--- IssueCollection class represents a collection of issues
---@class gh.IssueCollection
---@field issues gh.Issue[] Array of issues
---@field _index table<integer, gh.Issue> Index by issue number for fast lookup
local IssueCollection = {}
IssueCollection.__index = IssueCollection

--- Create a new IssueCollection from raw data array
---@param data table[] Array of raw issue data from gh CLI
---@return gh.IssueCollection
function IssueCollection.new(data)
  local self = setmetatable({}, IssueCollection)
  self.issues = {}
  self._index = {}

  for _, issue_data in ipairs(data) do
    local issue = Issue.new(issue_data)
    table.insert(self.issues, issue)
    self._index[issue.number] = issue
  end

  return self
end

--- Get number of issues in collection
---@return integer
function IssueCollection:count()
  return #self.issues
end

--- Check if collection is empty
---@return boolean
function IssueCollection:is_empty()
  return #self.issues == 0
end

--- Get issue by number
---@param number integer Issue number
---@return gh.Issue|nil
function IssueCollection:get(number)
  return self._index[number]
end

--- Filter issues by predicate function
---@param predicate fun(issue: gh.Issue): boolean Filter function
---@return gh.IssueCollection New collection with filtered issues
function IssueCollection:filter(predicate)
  local filtered_data = {}
  for _, issue in ipairs(self.issues) do
    if predicate(issue) then
      table.insert(filtered_data, issue:to_table())
    end
  end
  return IssueCollection.new(filtered_data)
end

--- Get all open issues
---@return gh.IssueCollection
function IssueCollection:get_open()
  return self:filter(function(issue)
    return issue:is_open()
  end)
end

--- Get all closed issues
---@return gh.IssueCollection
function IssueCollection:get_closed()
  return self:filter(function(issue)
    return issue:is_closed()
  end)
end

--- Get issues with a specific label
---@param label_name string Label name
---@return gh.IssueCollection
function IssueCollection:with_label(label_name)
  return self:filter(function(issue)
    return issue:has_label(label_name)
  end)
end

--- Get issues assigned to a specific user
---@param login string GitHub username
---@return gh.IssueCollection
function IssueCollection:assigned_to(login)
  return self:filter(function(issue)
    return issue:is_assigned_to(login)
  end)
end

--- Get unassigned issues
---@return gh.IssueCollection
function IssueCollection:unassigned()
  return self:filter(function(issue)
    return not issue:is_assigned()
  end)
end

--- Get issues in a specific milestone
---@param milestone_title string Milestone title
---@return gh.IssueCollection
function IssueCollection:in_milestone(milestone_title)
  return self:filter(function(issue)
    return issue.milestone and issue.milestone.title == milestone_title
  end)
end

--- Get issues by author
---@param login string GitHub username
---@return gh.IssueCollection
function IssueCollection:by_author(login)
  return self:filter(function(issue)
    return issue.author and issue.author.login == login
  end)
end

--- Sort issues by a key function
---@param key_fn fun(issue: gh.Issue): any Function that returns sort key
---@param descending boolean|nil Sort in descending order (default: false)
---@return gh.IssueCollection New sorted collection
function IssueCollection:sort_by(key_fn, descending)
  local sorted_issues = vim.deepcopy(self.issues)
  table.sort(sorted_issues, function(a, b)
    local key_a = key_fn(a)
    local key_b = key_fn(b)
    if descending then
      return key_a > key_b
    else
      return key_a < key_b
    end
  end)

  local sorted_data = {}
  for _, issue in ipairs(sorted_issues) do
    table.insert(sorted_data, issue:to_table())
  end

  return IssueCollection.new(sorted_data)
end

--- Sort issues by number
---@param descending boolean|nil Sort in descending order (default: false)
---@return gh.IssueCollection
function IssueCollection:sort_by_number(descending)
  return self:sort_by(function(issue)
    return issue.number
  end, descending)
end

--- Sort issues by title
---@param descending boolean|nil Sort in descending order (default: false)
---@return gh.IssueCollection
function IssueCollection:sort_by_title(descending)
  return self:sort_by(function(issue)
    return issue.title:lower()
  end, descending)
end

--- Sort issues by state (open first by default)
---@param descending boolean|nil Sort in descending order (default: false)
---@return gh.IssueCollection
function IssueCollection:sort_by_state(descending)
  return self:sort_by(function(issue)
    return issue.state
  end, descending)
end

--- Sort issues by author
---@param descending boolean|nil Sort in descending order (default: false)
---@return gh.IssueCollection
function IssueCollection:sort_by_author(descending)
  return self:sort_by(function(issue)
    return issue.author and issue.author.login:lower() or ""
  end, descending)
end

--- Sort issues by created date
---@param descending boolean|nil Sort in descending order (default: false, oldest first)
---@return gh.IssueCollection
function IssueCollection:sort_by_created(descending)
  return self:sort_by(function(issue)
    return issue.createdAt or ""
  end, descending)
end

--- Sort issues by updated date
---@param descending boolean|nil Sort in descending order (default: false, oldest first)
---@return gh.IssueCollection
function IssueCollection:sort_by_updated(descending)
  return self:sort_by(function(issue)
    return issue.updatedAt or ""
  end, descending)
end

--- Sort issues by label count
---@param descending boolean|nil Sort in descending order (default: false)
---@return gh.IssueCollection
function IssueCollection:sort_by_label_count(descending)
  return self:sort_by(function(issue)
    return #issue.labels
  end, descending)
end

--- Iterate over issues
---@return fun(): integer, gh.Issue Iterator function
function IssueCollection:iter()
  local i = 0
  return function()
    i = i + 1
    if i <= #self.issues then
      return i, self.issues[i]
    end
  end
end

--- Format collection as issue list buffer lines
---@param filter_context table|nil Optional filter context to pre-populate filter lines
---@return string[] Buffer lines
function IssueCollection:format_list(filter_context)
  filter_context = filter_context or {}

  -- Load filter definitions to get label widths
  local filter_ui = require("gh.ui.filter")

  -- Start with an empty header line (line 0) for help text virtual overlay
  local lines = { "" }

  -- Create filter input lines (7 lines for all filter types)
  -- Pre-fill with spaces to position cursor after virtual label
  local filter_inputs = require("gh.ui.filter_inputs")
  if not filter_inputs or not filter_inputs.inputs then
    error(
      "filter_inputs module not loaded correctly. "
        .. "Please restart Neovim or run :lua package.loaded['gh.ui.filter_inputs'] = nil"
    )
  end
  for _, filter in ipairs(filter_inputs.inputs) do
    local value = ""

    -- Get the filter value from context
    if filter.name == "state" then
      value = filter_context.state or ""
    elseif filter.name == "assignee" then
      value = filter_context.assignee or ""
    elseif filter.name == "author" then
      value = filter_context.author or ""
    elseif filter.name == "label" then
      -- Convert array to comma-separated string
      if filter_context.label then
        if type(filter_context.label) == "table" then
          value = table.concat(filter_context.label, ", ")
        else
          value = filter_context.label
        end
      end
    elseif filter.name == "mention" then
      value = filter_context.mention or ""
    elseif filter.name == "milestone" then
      value = filter_context.milestone or ""
    elseif filter.name == "search" then
      value = filter_context.search or ""
    end

    -- Calculate label width and pre-fill with spaces if empty
    -- This positions the cursor after the virtual label
    -- Use strlen (byte length) instead of strwidth for cursor positioning
    if value == "" then
      local label_text = filter.label .. ": "
      local label_byte_length = vim.fn.strlen(label_text)
      value = string.rep(" ", label_byte_length)
    end

    table.insert(lines, value)
  end

  -- Calculate fixed width for issue numbers based on max issue number
  local max_number = 0
  for _, issue in ipairs(self.issues) do
    if issue.number > max_number then
      max_number = issue.number
    end
  end
  local width = max_number > 0 and #tostring(max_number) or 1

  -- Add issue lines after filters with fixed-width numbers
  for _, issue in ipairs(self.issues) do
    table.insert(lines, issue:format_list_line(width))
  end

  return lines
end

--- Convert to raw table array (for serialization)
---@return table[]
function IssueCollection:to_table()
  local data = {}
  for _, issue in ipairs(self.issues) do
    table.insert(data, issue:to_table())
  end
  return data
end

--- Map issues to a new array
---@param fn fun(issue: gh.Issue): any Mapping function
---@return any[]
function IssueCollection:map(fn)
  local results = {}
  for _, issue in ipairs(self.issues) do
    table.insert(results, fn(issue))
  end
  return results
end

--- Find first issue matching predicate
---@param predicate fun(issue: gh.Issue): boolean Predicate function
---@return gh.Issue|nil
function IssueCollection:find(predicate)
  for _, issue in ipairs(self.issues) do
    if predicate(issue) then
      return issue
    end
  end
  return nil
end

--- Check if any issue matches predicate
---@param predicate fun(issue: gh.Issue): boolean Predicate function
---@return boolean
function IssueCollection:any(predicate)
  return self:find(predicate) ~= nil
end

--- Check if all issues match predicate
---@param predicate fun(issue: gh.Issue): boolean Predicate function
---@return boolean
function IssueCollection:all(predicate)
  for _, issue in ipairs(self.issues) do
    if not predicate(issue) then
      return false
    end
  end
  return true
end

M.IssueCollection = IssueCollection

return M
