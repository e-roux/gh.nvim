--- Unit tests for cli module (entry point and backward compatibility)
describe("cli", function()
  local cli

  before_each(function()
    -- Clear any cached modules
    package.loaded["gh.cli"] = nil
    package.loaded["gh.cli.issue"] = nil
    package.loaded["gh.cli.core"] = nil

    cli = require("gh.cli")
  end)

  describe("module structure", function()
    it("should export issue submodule", function()
      assert.is_table(cli.issue)
    end)

    it("should export run function", function()
      assert.is_function(cli.run)
    end)

    it("should have issue.list", function()
      assert.is_function(cli.issue.list)
    end)

    it("should have issue.view", function()
      assert.is_function(cli.issue.view)
    end)

    it("should have issue.create", function()
      assert.is_function(cli.issue.create)
    end)

    it("should have issue.edit", function()
      assert.is_function(cli.issue.edit)
    end)

    it("should have issue.delete", function()
      assert.is_function(cli.issue.delete)
    end)
  end)

  describe("backward compatibility", function()
    it("should export deprecated list_issues", function()
      assert.is_function(cli.list_issues)
    end)

    it("should export deprecated get_issue", function()
      assert.is_function(cli.get_issue)
    end)

    it("should export deprecated create_issue", function()
      assert.is_function(cli.create_issue)
    end)

    it("should export deprecated update_title", function()
      assert.is_function(cli.update_title)
    end)

    it("should export deprecated update_body", function()
      assert.is_function(cli.update_body)
    end)

    it("should export deprecated delete_issue", function()
      assert.is_function(cli.delete_issue)
    end)
  end)

  describe("usage patterns", function()
    it("should support new nested API", function()
      local ok = pcall(cli.issue.list, function() end)
      assert.is_true(ok)
    end)

    it("should support old flat API", function()
      local ok = pcall(cli.list_issues, function() end)
      assert.is_true(ok)
    end)
  end)
end)
