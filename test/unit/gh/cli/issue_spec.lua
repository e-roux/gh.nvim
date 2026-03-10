--- Unit tests for cli.issue module
describe("cli.issue", function()
  local issue
  local core

  before_each(function()
    issue = require("gh.cli.issue")
    core = require("gh.cli.core")
  end)

  describe("list", function()
    it("should accept callback only", function()
      local ok = pcall(issue.list, function() end)
      assert.is_true(ok)
    end)

    it("should accept opts and callback", function()
      local ok = pcall(issue.list, { state = "all" }, function() end)
      assert.is_true(ok)
    end)

    it("should handle empty opts", function()
      local ok = pcall(issue.list, {}, function() end)
      assert.is_true(ok)
    end)
  end)

  describe("view", function()
    it("should accept number and callback", function()
      local ok = pcall(issue.view, 123, function() end)
      assert.is_true(ok)
    end)

    it("should accept number, opts, and callback", function()
      local ok = pcall(issue.view, 123, { repo = "owner/repo" }, function() end)
      assert.is_true(ok)
    end)

    it("should accept number, repo string, and callback (backward compat)", function()
      local ok = pcall(issue.view, 123, "owner/repo", function() end)
      assert.is_true(ok)
    end)
  end)

  describe("create", function()
    it("should require title", function()
      local ok = pcall(issue.create, { title = "Bug" }, function() end)
      assert.is_true(ok)
    end)

    it("should accept optional fields", function()
      local ok = pcall(issue.create, {
        title = "Bug",
        body = "Description",
        assignee = { "user1" },
        label = { "bug" },
        milestone = "v1.0",
      }, function() end)
      assert.is_true(ok)
    end)
  end)

  describe("edit", function()
    it("should accept number, fields, and callback", function()
      local ok = pcall(issue.edit, 123, { title = "New title" }, function() end)
      assert.is_true(ok)
    end)

    it("should accept number, fields, opts, and callback", function()
      local ok = pcall(issue.edit, 123, { title = "New" }, { repo = "owner/repo" }, function() end)
      assert.is_true(ok)
    end)

    it("should accept number, fields, repo string, and callback (backward compat)", function()
      local ok = pcall(issue.edit, 123, { body = "New body" }, "owner/repo", function() end)
      assert.is_true(ok)
    end)
  end)

  describe("delete", function()
    it("should accept number and callback", function()
      local ok = pcall(issue.delete, 123, function() end)
      assert.is_true(ok)
    end)

    it("should accept number, opts, and callback", function()
      local ok = pcall(issue.delete, 123, { repo = "owner/repo" }, function() end)
      assert.is_true(ok)
    end)

    it("should accept number, repo string, and callback (backward compat)", function()
      local ok = pcall(issue.delete, 123, "owner/repo", function() end)
      assert.is_true(ok)
    end)
  end)

  describe("module structure", function()
    it("should export list function", function()
      assert.is_function(issue.list)
    end)

    it("should export view function", function()
      assert.is_function(issue.view)
    end)

    it("should export create function", function()
      assert.is_function(issue.create)
    end)

    it("should export edit function", function()
      assert.is_function(issue.edit)
    end)

    it("should export delete function", function()
      assert.is_function(issue.delete)
    end)
  end)
end)
