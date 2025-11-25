--- GitHub Issue model
--- Represents a single GitHub issue with all its associated data

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
---@param width integer|nil Optional fixed width for issue number padding
---@return string
function Issue:format_list_line(width)
  if width then
    return string.format("#%0" .. width .. "d │ %s", self.number, self.title)
  else
    return string.format("#%d │ %s", self.number, self.title)
  end
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

-- Export module
M.User = User
M.Label = Label
M.Milestone = Milestone
M.Comment = Comment
M.Issue = Issue

return M
