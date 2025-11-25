--- Unit tests for config module
describe("config", function()
  local config

  before_each(function()
    -- Clear any existing config
    vim.g.gh_opts = nil
    -- Reload config module
    package.loaded["gh.config"] = nil
    config = require("gh.config")
  end)

  describe("defaults", function()
    it("should have default data_source", function()
      assert.are.equal("json", config.opts.data_source)
    end)

    it("should have default issue_detail settings", function()
      assert.is_not_nil(config.opts.issue_detail)
      assert.is_true(config.opts.issue_detail.reuse_window)
      assert.are.equal("auto", config.opts.issue_detail.split_direction)
    end)

    it("should have default issue_create settings", function()
      assert.is_not_nil(config.opts.issue_create)
      assert.is_nil(config.opts.issue_create.default_assignees)
      assert.is_nil(config.opts.issue_create.default_labels)
      assert.is_nil(config.opts.issue_create.default_milestone)
      assert.is_nil(config.opts.issue_create.default_project)
    end)
  end)

  describe("user configuration", function()
    it("should merge user config with defaults", function()
      vim.g.gh_opts = {
        data_source = "api",
        issue_detail = {
          reuse_window = false,
        },
      }

      package.loaded["gh.config"] = nil
      config = require("gh.config")

      assert.are.equal("api", config.opts.data_source)
      assert.is_false(config.opts.issue_detail.reuse_window)
      -- Should keep default split_direction
      assert.are.equal("auto", config.opts.issue_detail.split_direction)
    end)

    it("should allow setting issue_create defaults", function()
      vim.g.gh_opts = {
        issue_create = {
          default_assignees = { "@me" },
          default_labels = { "bug" },
          default_milestone = "v1.0",
        },
      }

      package.loaded["gh.config"] = nil
      config = require("gh.config")

      assert.are.same({ "@me" }, config.opts.issue_create.default_assignees)
      assert.are.same({ "bug" }, config.opts.issue_create.default_labels)
      assert.are.equal("v1.0", config.opts.issue_create.default_milestone)
    end)
  end)
end)
