--- GitHub Issue types
--- Provides Issue and IssueCollection classes for working with GitHub issues

local M = {}

--- Issue state enumeration
---@enum gh.IssueState
M.IssueState = {
  OPEN = "open",
  CLOSED = "closed",
}

--- User/Author class
---@class gh.User
---@field login string GitHub username
---@field id string|nil User ID
---@field name string|nil Display name
---@field is_bot boolean|nil Whether user is a bot
local User = {}
User.__index = User

--- Create a new User
---@param data table User data from gh CLI
---@return gh.User
function User.new(data)
  local self = setmetatable({}, User)
  self.login = data.login
  self.id = data.id
  self.name = data.name
  self.is_bot = data.is_bot
  return self
end

--- Label class
---@class gh.Label
---@field id string|nil Label ID
---@field name string Label name
---@field description string|nil Label description
---@field color string|nil Label color
local Label = {}
Label.__index = Label

--- Create a new Label
---@param data string|table Label name or label data from gh CLI
---@return gh.Label
function Label.new(data)
  local self = setmetatable({}, Label)
  if type(data) == "string" then
    self.name = data
  else
    self.id = data.id
    self.name = data.name
    self.description = data.description
    self.color = data.color
  end
  return self
end

--- Milestone class
---@class gh.Milestone
---@field number integer Milestone number
---@field title string Milestone title
---@field description string|nil Milestone description
---@field dueOn string|nil Due date (ISO 8601)
local Milestone = {}
Milestone.__index = Milestone

--- Create a new Milestone
---@param data table Milestone data from gh CLI
---@return gh.Milestone
function Milestone.new(data)
  local self = setmetatable({}, Milestone)
  self.number = data.number
  self.title = data.title
  self.description = data.description
  self.dueOn = data.dueOn
  return self
end

--- Comment class
---@class gh.Comment
---@field id string Comment ID
---@field author gh.User Comment author
---@field body string Comment body
---@field createdAt string Created timestamp (ISO 8601)
---@field url string Comment URL
local Comment = {}
Comment.__index = Comment

--- Create a new Comment
---@param data table Comment data from gh CLI
---@return gh.Comment
function Comment.new(data)
  local self = setmetatable({}, Comment)
  self.id = data.id
  self.author = User.new(data.author)
  self.body = data.body
  self.createdAt = data.createdAt
  self.url = data.url
  return self
end

--- Issue class represents a single GitHub issue
---@class gh.Issue
---@field number integer Issue number
---@field id string Issue ID
---@field title string Issue title
---@field body string|nil Issue body
---@field state gh.IssueState Issue state
---@field stateReason string|nil State reason
---@field labels gh.Label[] Issue labels
---@field author gh.User|nil Issue author
---@field assignees gh.User[] Issue assignees
---@field milestone gh.Milestone|nil Issue milestone
---@field comments gh.Comment[]|nil Issue comments (only when fetching details)
---@field createdAt string|nil Created timestamp (ISO 8601)
---@field updatedAt string|nil Updated timestamp (ISO 8601)
---@field closedAt string|nil Closed timestamp (ISO 8601)
---@field url string|nil Issue URL
local Issue = {}
Issue.__index = Issue

--- Create a new Issue from raw data
---@param data table Raw issue data from gh CLI
---@return gh.Issue
function Issue.new(data)
  local self = setmetatable({}, Issue)
  self.number = data.number
  self.id = data.id
  self.title = data.title
  self.body = data.body
  self.stateReason = data.stateReason
  self.createdAt = data.createdAt
  self.updatedAt = data.updatedAt
  self.closedAt = data.closedAt
  self.url = data.url

  -- Normalize state to enum value
  local state_lower = data.state:lower()
  if state_lower == "open" then
    self.state = M.IssueState.OPEN
  elseif state_lower == "closed" then
    self.state = M.IssueState.CLOSED
  else
    -- Default to open for unknown states
    self.state = M.IssueState.OPEN
  end

  -- Parse author
  if data.author then
    self.author = User.new(data.author)
  end

  -- Parse labels
  self.labels = {}
  if data.labels then
    for _, label_data in ipairs(data.labels) do
      table.insert(self.labels, Label.new(label_data))
    end
  end

  -- Parse assignees
  self.assignees = {}
  if data.assignees then
    for _, assignee_data in ipairs(data.assignees) do
      table.insert(self.assignees, User.new(assignee_data))
    end
  end

  -- Parse milestone
  if data.milestone then
    self.milestone = Milestone.new(data.milestone)
  end

  -- Parse comments
  if data.comments then
    self.comments = {}
    for _, comment_data in ipairs(data.comments) do
      table.insert(self.comments, Comment.new(comment_data))
    end
  end

  return self
end

--- Check if issue is open
---@return boolean
function Issue:is_open()
  return self.state == M.IssueState.OPEN
end

--- Check if issue is closed
---@return boolean
function Issue:is_closed()
  return self.state == M.IssueState.CLOSED
end

--- Get label names as array
---@return string[]
function Issue:get_labels()
  local names = {}
  for _, label in ipairs(self.labels) do
    table.insert(names, label.name)
  end
  return names
end

--- Check if issue has a specific label
---@param label_name string Label name to check
---@return boolean
function Issue:has_label(label_name)
  for _, label in ipairs(self.labels) do
    if label.name == label_name then
      return true
    end
  end
  return false
end

--- Get assignee logins as array
---@return string[]
function Issue:get_assignees()
  local logins = {}
  for _, assignee in ipairs(self.assignees) do
    table.insert(logins, assignee.login)
  end
  return logins
end

--- Check if issue is assigned to a specific user
---@param login string GitHub username
---@return boolean
function Issue:is_assigned_to(login)
  for _, assignee in ipairs(self.assignees) do
    if assignee.login == login then
      return true
    end
  end
  return false
end

--- Check if issue has assignees
---@return boolean
function Issue:is_assigned()
  return #self.assignees > 0
end

--- Check if issue is in a milestone
---@return boolean
function Issue:has_milestone()
  return self.milestone ~= nil
end

--- Get comment count
---@return integer
function Issue:comment_count()
  return self.comments and #self.comments or 0
end

--- Format issue as a single line for list view
---@return string
function Issue:format_list_line()
  local state = self.state:upper()
  return string.format("#%d │ %s │ %s", self.number, state, self.title)
end

--- Format issue for detail view
---@return string[]
function Issue:format_detail()
  local lines = {
    "# " .. self.title,
    "---",
  }

  -- Add body
  if self.body then
    for line in self.body:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
  end

  return lines
end

--- Convert to raw table (for serialization)
---@return table
function Issue:to_table()
  local label_data = {}
  for _, label in ipairs(self.labels) do
    table.insert(label_data, {
      id = label.id,
      name = label.name,
      description = label.description,
      color = label.color,
    })
  end

  local assignee_data = {}
  for _, assignee in ipairs(self.assignees) do
    table.insert(assignee_data, {
      login = assignee.login,
      id = assignee.id,
      name = assignee.name,
      is_bot = assignee.is_bot,
    })
  end

  local comment_data = nil
  if self.comments then
    comment_data = {}
    for _, comment in ipairs(self.comments) do
      table.insert(comment_data, {
        id = comment.id,
        author = {
          login = comment.author.login,
          id = comment.author.id,
          name = comment.author.name,
          is_bot = comment.author.is_bot,
        },
        body = comment.body,
        createdAt = comment.createdAt,
        url = comment.url,
      })
    end
  end

  return {
    number = self.number,
    id = self.id,
    title = self.title,
    body = self.body,
    state = self.state,
    stateReason = self.stateReason,
    labels = label_data,
    author = self.author and {
      login = self.author.login,
      id = self.author.id,
      name = self.author.name,
      is_bot = self.author.is_bot,
    } or nil,
    assignees = assignee_data,
    milestone = self.milestone and {
      number = self.milestone.number,
      title = self.milestone.title,
      description = self.milestone.description,
      dueOn = self.milestone.dueOn,
    } or nil,
    comments = comment_data,
    createdAt = self.createdAt,
    updatedAt = self.updatedAt,
    closedAt = self.closedAt,
    url = self.url,
  }
end

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

--- Format collection for list view
---@return string[]
--- Format issues as list
---@return string[]
function IssueCollection:format_list()
  local lines = {
    "",  -- Filter input line (with virtual lines before/after via extmarks)
  }
  
  for _, issue in ipairs(self.issues) do
    table.insert(lines, issue:format_list_line())
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

M.User = User
M.Label = Label
M.Milestone = Milestone
M.Comment = Comment
M.Issue = Issue
M.IssueCollection = IssueCollection

return M
