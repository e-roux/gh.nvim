--- Unit tests for blink.cmp completion source
describe("completion.metadata", function()
  local source
  local cache

  before_each(function()
    -- Clear cache before each test
    cache = require("gh.cache")
    cache.clear_all()

    -- Require the source module
    source = require("gh.completion.metadata")
  end)

  after_each(function()
    cache.clear_all()
  end)

  describe("source.new", function()
    it("should create a new source instance", function()
      local instance = source.new()
      assert.is_not_nil(instance)
      assert.is_table(instance)
    end)

    it("should accept optional configuration", function()
      local opts = { custom_option = "value" }
      local instance = source.new(opts)
      assert.are.same(opts, instance.opts)
    end)

    it("should use empty table for opts when none provided", function()
      local instance = source.new()
      assert.are.same({}, instance.opts)
    end)
  end)

  describe("source:enabled", function()
    it("should return true for gh:// buffers", function()
      -- Create a buffer with gh:// scheme
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "gh://test/issue/123")
      vim.api.nvim_set_current_buf(bufnr)

      local instance = source.new()
      assert.is_true(instance:enabled())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should return false for non-gh:// buffers", function()
      -- Create a regular buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, "/tmp/test.lua")
      vim.api.nvim_set_current_buf(bufnr)

      local instance = source.new()
      assert.is_false(instance:enabled())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("should return false for empty buffer name", function()
      -- Create a buffer with no name
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)

      local instance = source.new()
      assert.is_false(instance:enabled())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("source:get_completions", function()
    local instance

    before_each(function()
      instance = source.new()
    end)

    it("should return empty items for non-metadata lines", function()
      -- Set current line to something that's not a metadata field
      vim.api.nvim_set_current_line("# Some random title")

      local called = false
      instance:get_completions({}, function(result)
        called = true
        assert.are.same({}, result.items)
        assert.is_false(result.is_incomplete_backward)
        assert.is_false(result.is_incomplete_forward)
      end)

      assert.is_true(called)
    end)

    describe("State field", function()
      it("should provide OPEN and CLOSED completions", function()
        vim.api.nvim_set_current_line("󰊢 State: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(2, #result.items)

          -- Check for OPEN
          local has_open = false
          local has_closed = false
          for _, item in ipairs(result.items) do
            if item.label == "OPEN" then
              has_open = true
              assert.are.equal(vim.lsp.protocol.CompletionItemKind.Enum, item.kind)
            elseif item.label == "CLOSED" then
              has_closed = true
              assert.are.equal(vim.lsp.protocol.CompletionItemKind.Enum, item.kind)
            end
          end

          assert.is_true(has_open, "Should have OPEN completion")
          assert.is_true(has_closed, "Should have CLOSED completion")
        end)

        assert.is_true(called)
      end)
    end)

    describe("Assignees field", function()
      it("should provide cached users with @ prefix", function()
        -- Mock cached contributors
        cache.write("contributors", {
          { login = "user1" },
          { login = "user2" },
        })

        vim.api.nvim_set_current_line("󰀉 Assignees: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(2, #result.items)

          -- Check that all items have @ prefix
          for _, item in ipairs(result.items) do
            assert.is_not_nil(item.label:match("^@"), "User should have @ prefix")
            assert.are.equal(vim.lsp.protocol.CompletionItemKind.User, item.kind)
          end

          -- Check specific users
          local labels = vim.tbl_map(function(item)
            return item.label
          end, result.items)
          assert.is_true(vim.tbl_contains(labels, "@user1"))
          assert.is_true(vim.tbl_contains(labels, "@user2"))
        end)

        assert.is_true(called)
      end)

      it("should return empty when no contributors in cache", function()
        vim.api.nvim_set_current_line("󰀉 Assignees: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(0, #result.items)
        end)

        assert.is_true(called)
      end)
    end)

    describe("Author field", function()
      it("should provide cached users", function()
        -- Mock cached contributors
        cache.write("contributors", {
          { login = "author1" },
        })

        vim.api.nvim_set_current_line("󰀉 Author: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(1, #result.items)
          assert.are.equal("@author1", result.items[1].label)
          assert.are.equal(vim.lsp.protocol.CompletionItemKind.User, result.items[1].kind)
        end)

        assert.is_true(called)
      end)
    end)

    describe("Labels field", function()
      it("should provide cached labels", function()
        -- Mock cached labels
        cache.write("labels", {
          { name = "bug" },
          { name = "feature" },
          { name = "documentation" },
        })

        vim.api.nvim_set_current_line("󰓹 Labels: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(3, #result.items)

          local labels = vim.tbl_map(function(item)
            return item.label
          end, result.items)
          assert.is_true(vim.tbl_contains(labels, "bug"))
          assert.is_true(vim.tbl_contains(labels, "feature"))
          assert.is_true(vim.tbl_contains(labels, "documentation"))

          -- Check kind
          for _, item in ipairs(result.items) do
            assert.are.equal(vim.lsp.protocol.CompletionItemKind.Keyword, item.kind)
          end
        end)

        assert.is_true(called)
      end)

      it("should return empty when no labels in cache", function()
        vim.api.nvim_set_current_line("󰓹 Labels: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(0, #result.items)
        end)

        assert.is_true(called)
      end)
    end)

    describe("Milestone field", function()
      it("should provide cached milestones", function()
        -- Mock cached milestones
        cache.write("milestones", {
          { title = "v1.0" },
          { title = "v2.0" },
        })

        vim.api.nvim_set_current_line("󰄮 Milestone: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(2, #result.items)

          local titles = vim.tbl_map(function(item)
            return item.label
          end, result.items)
          assert.is_true(vim.tbl_contains(titles, "v1.0"))
          assert.is_true(vim.tbl_contains(titles, "v2.0"))

          -- Check kind
          for _, item in ipairs(result.items) do
            assert.are.equal(vim.lsp.protocol.CompletionItemKind.Value, item.kind)
          end
        end)

        assert.is_true(called)
      end)

      it("should return empty when no milestones in cache", function()
        vim.api.nvim_set_current_line("󰄮 Milestone: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.are.equal(0, #result.items)
        end)

        assert.is_true(called)
      end)
    end)

    describe("callback structure", function()
      it("should always include is_incomplete_backward and is_incomplete_forward", function()
        vim.api.nvim_set_current_line("󰊢 State: ")

        local called = false
        instance:get_completions({}, function(result)
          called = true
          assert.is_not_nil(result.is_incomplete_backward)
          assert.is_not_nil(result.is_incomplete_forward)
          assert.is_false(result.is_incomplete_backward)
          assert.is_false(result.is_incomplete_forward)
        end)

        assert.is_true(called)
      end)
    end)
  end)

  describe("edge cases", function()
    it("should handle contributors without login field", function()
      cache.write("contributors", {
        { login = "user1" },
        { name = "No Login User" }, -- Missing login field
        { login = "user2" },
      })

      vim.api.nvim_set_current_line("󰀉 Assignees: ")

      local instance = source.new()
      instance:get_completions({}, function(result)
        -- Should only get users with login field
        assert.are.equal(2, #result.items)
        local labels = vim.tbl_map(function(item)
          return item.label
        end, result.items)
        assert.is_true(vim.tbl_contains(labels, "@user1"))
        assert.is_true(vim.tbl_contains(labels, "@user2"))
      end)
    end)

    it("should handle labels without name field", function()
      cache.write("labels", {
        { name = "bug" },
        { description = "No name label" }, -- Missing name field
        { name = "feature" },
      })

      vim.api.nvim_set_current_line("󰓹 Labels: ")

      local instance = source.new()
      instance:get_completions({}, function(result)
        -- Should only get labels with name field
        assert.are.equal(2, #result.items)
        local labels = vim.tbl_map(function(item)
          return item.label
        end, result.items)
        assert.is_true(vim.tbl_contains(labels, "bug"))
        assert.is_true(vim.tbl_contains(labels, "feature"))
      end)
    end)

    it("should handle milestones without title field", function()
      cache.write("milestones", {
        { title = "v1.0" },
        { description = "No title" }, -- Missing title field
      })

      vim.api.nvim_set_current_line("󰄮 Milestone: ")

      local instance = source.new()
      instance:get_completions({}, function(result)
        -- Should only get milestones with title field
        assert.are.equal(1, #result.items)
        assert.are.equal("v1.0", result.items[1].label)
      end)
    end)
  end)
end)
