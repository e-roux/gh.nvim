--- Unit tests for cli/core utilities
describe("cli.core", function()
  local core

  before_each(function()
    core = require("gh.cli.core")
  end)

  describe("add_flag", function()
    it("should add flag with value", function()
      local args = {}
      core.add_flag(args, "--state", "open")
      assert.are.same({ "--state", "open" }, args)
    end)

    it("should skip nil values", function()
      local args = {}
      core.add_flag(args, "--state", nil)
      assert.are.same({}, args)
    end)

    it("should convert numbers to strings", function()
      local args = {}
      core.add_flag(args, "--limit", 50)
      assert.are.same({ "--limit", "50" }, args)
    end)

    it("should handle boolean values", function()
      local args = {}
      core.add_flag(args, "--draft", true)
      assert.are.same({ "--draft", "true" }, args)
    end)
  end)

  describe("add_array_flag", function()
    it("should add single value", function()
      local args = {}
      core.add_array_flag(args, "--label", "bug")
      assert.are.same({ "--label", "bug" }, args)
    end)

    it("should add multiple values from array", function()
      local args = {}
      core.add_array_flag(args, "--label", { "bug", "feature" })
      assert.are.same({ "--label", "bug", "--label", "feature" }, args)
    end)

    it("should skip nil values", function()
      local args = {}
      core.add_array_flag(args, "--label", nil)
      assert.are.same({}, args)
    end)

    it("should handle empty array", function()
      local args = {}
      core.add_array_flag(args, "--label", {})
      assert.are.same({}, args)
    end)
  end)

  describe("add_bool_flag", function()
    it("should add flag when true", function()
      local args = {}
      core.add_bool_flag(args, "--draft", true)
      assert.are.same({ "--draft" }, args)
    end)

    it("should not add flag when false", function()
      local args = {}
      core.add_bool_flag(args, "--draft", false)
      assert.are.same({}, args)
    end)

    it("should not add flag when nil", function()
      local args = {}
      core.add_bool_flag(args, "--draft", nil)
      assert.are.same({}, args)
    end)
  end)

  describe("add_repo_flag", function()
    it("should add --repo flag", function()
      local args = {}
      core.add_repo_flag(args, "owner/repo")
      assert.are.same({ "--repo", "owner/repo" }, args)
    end)

    it("should skip nil repo", function()
      local args = {}
      core.add_repo_flag(args, nil)
      assert.are.same({}, args)
    end)
  end)

  describe("parse_json", function()
    it("should parse valid JSON", function()
      local json = '{"name": "test", "value": 123}'
      local success, data, error = core.parse_json(json)
      assert.is_true(success)
      assert.are.same({ name = "test", value = 123 }, data)
      assert.is_nil(error)
    end)

    it("should handle arrays", function()
      local json = '[{"id": 1}, {"id": 2}]'
      local success, data, error = core.parse_json(json)
      assert.is_true(success)
      assert.are.same({ { id = 1 }, { id = 2 } }, data)
      assert.is_nil(error)
    end)

    it("should return error for invalid JSON", function()
      local json = '{"invalid": }'
      local success, data, error = core.parse_json(json)
      assert.is_false(success)
      assert.is_nil(data)
      assert.are.equal("Failed to parse JSON response", error)
    end)

    it("should handle empty object", function()
      local json = '{}'
      local success, data, error = core.parse_json(json)
      assert.is_true(success)
      assert.are.same({}, data)
      assert.is_nil(error)
    end)
  end)

  describe("run", function()
    it("should be a function", function()
      assert.is_function(core.run)
    end)

    it("should accept args and callback", function()
      local ok = pcall(core.run, { "help" }, function() end)
      assert.is_true(ok)
    end)
  end)

  describe("integration: building complex args", function()
    it("should build args for issue list with multiple filters", function()
      local args = { "issue", "list" }

      core.add_flag(args, "--state", "all")
      core.add_flag(args, "--limit", 100)
      core.add_flag(args, "--assignee", "@me")
      core.add_array_flag(args, "--label", { "bug", "feature" })
      core.add_repo_flag(args, "owner/repo")

      assert.are.same({
        "issue",
        "list",
        "--state",
        "all",
        "--limit",
        "100",
        "--assignee",
        "@me",
        "--label",
        "bug",
        "--label",
        "feature",
        "--repo",
        "owner/repo",
      }, args)
    end)

    it("should build args for issue create", function()
      local args = { "issue", "create" }

      core.add_flag(args, "--title", "Bug report")
      core.add_flag(args, "--body", "Description")
      core.add_array_flag(args, "--assignee", { "user1", "user2" })
      core.add_array_flag(args, "--label", "bug")
      core.add_bool_flag(args, "--web", false)
      core.add_repo_flag(args, nil)

      assert.are.same({
        "issue",
        "create",
        "--title",
        "Bug report",
        "--body",
        "Description",
        "--assignee",
        "user1",
        "--assignee",
        "user2",
        "--label",
        "bug",
      }, args)
    end)
  end)
end)
