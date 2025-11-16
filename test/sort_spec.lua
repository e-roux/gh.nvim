--- Test sorting functionality for issue lists
local types = require("gh.types")

-- Create test issues
local test_issues = {
  {
    number = 123,
    id = "1",
    title = "Fix navigation bug",
    state = "open",
    author = { login = "alice" },
    labels = { { name = "bug" }, { name = "ui" } },
    assignees = {},
    createdAt = "2024-01-15T10:00:00Z",
    updatedAt = "2024-01-20T15:30:00Z",
  },
  {
    number = 45,
    id = "2",
    title = "Add dark mode support",
    state = "closed",
    author = { login = "bob" },
    labels = { { name = "enhancement" } },
    assignees = {},
    createdAt = "2024-01-10T08:00:00Z",
    updatedAt = "2024-01-18T12:00:00Z",
  },
  {
    number = 89,
    id = "3",
    title = "Update documentation",
    state = "open",
    author = { login = "charlie" },
    labels = {},
    assignees = {},
    createdAt = "2024-01-20T14:00:00Z",
    updatedAt = "2024-01-21T09:00:00Z",
  },
  {
    number = 200,
    id = "4",
    title = "API refactoring",
    state = "open",
    author = { login = "alice" },
    labels = { { name = "refactor" }, { name = "api" }, { name = "breaking" } },
    assignees = {},
    createdAt = "2024-01-05T16:00:00Z",
    updatedAt = "2024-01-22T11:00:00Z",
  },
}

describe("Issue sorting", function()
  local collection

  before_each(function()
    collection = types.IssueCollection.new(test_issues)
  end)

  it("sorts by number ascending", function()
    local sorted = collection:sort_by_number(false)
    assert.equals(45, sorted.issues[1].number)
    assert.equals(89, sorted.issues[2].number)
    assert.equals(123, sorted.issues[3].number)
    assert.equals(200, sorted.issues[4].number)
  end)

  it("sorts by number descending", function()
    local sorted = collection:sort_by_number(true)
    assert.equals(200, sorted.issues[1].number)
    assert.equals(123, sorted.issues[2].number)
    assert.equals(89, sorted.issues[3].number)
    assert.equals(45, sorted.issues[4].number)
  end)

  it("sorts by title ascending", function()
    local sorted = collection:sort_by_title(false)
    assert.equals("Add dark mode support", sorted.issues[1].title)
    assert.equals("API refactoring", sorted.issues[2].title)
    assert.equals("Fix navigation bug", sorted.issues[3].title)
    assert.equals("Update documentation", sorted.issues[4].title)
  end)

  it("sorts by state ascending (closed first)", function()
    local sorted = collection:sort_by_state(false)
    assert.equals("closed", sorted.issues[1].state)
    assert.equals("open", sorted.issues[2].state)
  end)

  it("sorts by author ascending", function()
    local sorted = collection:sort_by_author(false)
    assert.equals("alice", sorted.issues[1].author.login)
    assert.equals("alice", sorted.issues[2].author.login)
    assert.equals("bob", sorted.issues[3].author.login)
    assert.equals("charlie", sorted.issues[4].author.login)
  end)

  it("sorts by created date ascending (oldest first)", function()
    local sorted = collection:sort_by_created(false)
    assert.equals(200, sorted.issues[1].number) -- 2024-01-05
    assert.equals(45, sorted.issues[2].number)  -- 2024-01-10
    assert.equals(123, sorted.issues[3].number) -- 2024-01-15
    assert.equals(89, sorted.issues[4].number)  -- 2024-01-20
  end)

  it("sorts by created date descending (newest first)", function()
    local sorted = collection:sort_by_created(true)
    assert.equals(89, sorted.issues[1].number)  -- 2024-01-20
    assert.equals(123, sorted.issues[2].number) -- 2024-01-15
    assert.equals(45, sorted.issues[3].number)  -- 2024-01-10
    assert.equals(200, sorted.issues[4].number) -- 2024-01-05
  end)

  it("sorts by updated date ascending", function()
    local sorted = collection:sort_by_updated(false)
    assert.equals(45, sorted.issues[1].number)  -- 2024-01-18
    assert.equals(123, sorted.issues[2].number) -- 2024-01-20
    assert.equals(89, sorted.issues[3].number)  -- 2024-01-21
    assert.equals(200, sorted.issues[4].number) -- 2024-01-22
  end)

  it("sorts by label count ascending", function()
    local sorted = collection:sort_by_label_count(false)
    assert.equals(0, #sorted.issues[1].labels) -- Update documentation (0 labels)
    assert.equals(1, #sorted.issues[2].labels) -- Add dark mode (1 label)
    assert.equals(2, #sorted.issues[3].labels) -- Fix navigation (2 labels)
    assert.equals(3, #sorted.issues[4].labels) -- API refactoring (3 labels)
  end)

  it("sorts by label count descending", function()
    local sorted = collection:sort_by_label_count(true)
    assert.equals(3, #sorted.issues[1].labels) -- API refactoring (3 labels)
    assert.equals(2, #sorted.issues[2].labels) -- Fix navigation (2 labels)
    assert.equals(1, #sorted.issues[3].labels) -- Add dark mode (1 label)
    assert.equals(0, #sorted.issues[4].labels) -- Update documentation (0 labels)
  end)
end)
