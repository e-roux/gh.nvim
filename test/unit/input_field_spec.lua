describe("input_field", function()
  local input_field = require("gh.ui.input_field")
  local bufnr, namespace

  before_each(function()
    -- Create a test buffer
    bufnr = vim.api.nvim_create_buf(false, true)
    namespace = vim.api.nvim_create_namespace("test_input_field")
  end)

  after_each(function()
    -- Clean up
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("render_state_decoration", function()
    it("should render OPEN state with blue bullet", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "OPEN" })
      local extmark_ids = {}

      -- Execute
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, "state", 0)

      -- Verify
      assert.is_not_nil(extmark_ids.state_icon)
      assert.is_not_nil(extmark_ids.state_hl)
    end)

    it("should render CLOSED state with green checkmark", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "CLOSED" })
      local extmark_ids = {}

      -- Execute
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, "state", 0)

      -- Verify
      assert.is_not_nil(extmark_ids.state_icon)
      assert.is_not_nil(extmark_ids.state_hl)
    end)

    it("should not render decoration for empty state", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "" })
      local extmark_ids = {}

      -- Execute
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, "state", 0)

      -- Verify
      assert.is_nil(extmark_ids.state_icon)
      assert.is_nil(extmark_ids.state_hl)
    end)

    it("should remove existing decorations when updating", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "OPEN" })
      local extmark_ids = {}
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, "state", 0)
      local first_icon_id = extmark_ids.state_icon

      -- Execute - change to CLOSED
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "CLOSED" })
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, "state", 0)

      -- Verify - new extmark created
      assert.is_not_nil(extmark_ids.state_icon)
      assert.is_not_nil(extmark_ids.state_hl)
    end)
  end)

  describe("render_inline_label", function()
    it("should render label with icon", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "value" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        icon = "󰊢",
        read_only = false,
      }

      -- Execute
      input_field.render_inline_label(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_not_nil(extmark_ids.test)
    end)

    it("should render label without icon", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "value" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        read_only = false,
      }

      -- Execute
      input_field.render_inline_label(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_not_nil(extmark_ids.test)
    end)
  end)

  describe("render_placeholder", function()
    it("should show placeholder for empty field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        icon = "󰊢",
        placeholder = "Enter value...",
      }

      -- Execute
      input_field.render_placeholder(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_not_nil(extmark_ids.test_placeholder)
    end)

    it("should not show placeholder for non-empty field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "value" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        icon = "󰊢",
        placeholder = "Enter value...",
      }

      -- Execute
      input_field.render_placeholder(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_nil(extmark_ids.test_placeholder)
    end)

    it("should remove placeholder when field becomes non-empty", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        icon = "󰊢",
        placeholder = "Enter value...",
      }
      input_field.render_placeholder(bufnr, namespace, extmark_ids, field, 0)
      assert.is_not_nil(extmark_ids.test_placeholder)

      -- Execute - add value
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "value" })
      input_field.render_placeholder(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_nil(extmark_ids.test_placeholder)
    end)
  end)

  describe("render_readonly_highlight", function()
    it("should highlight read-only field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "readonly value" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        read_only = true,
      }

      -- Execute
      input_field.render_readonly_highlight(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_not_nil(extmark_ids.test_readonly)
    end)

    it("should not highlight editable field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "editable value" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        read_only = false,
      }

      -- Execute
      input_field.render_readonly_highlight(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_nil(extmark_ids.test_readonly)
    end)

    it("should not highlight empty read-only field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "" })
      local extmark_ids = {}
      local field = {
        name = "test",
        label = "Test",
        read_only = true,
      }

      -- Execute
      input_field.render_readonly_highlight(bufnr, namespace, extmark_ids, field, 0)

      -- Verify
      assert.is_nil(extmark_ids.test_readonly)
    end)
  end)

  describe("clear_field", function()
    it("should clear field value without deleting line", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 2, false, { "value", "next line" })

      -- Execute
      input_field.clear_field(bufnr, 1)

      -- Verify
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 2, false)
      assert.are.equal("", lines[1])
      assert.are.equal("next line", lines[2])
    end)
  end)

  describe("uppercase_field", function()
    it("should uppercase field value", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "open" })

      -- Execute
      input_field.uppercase_field(bufnr, 1)

      -- Verify
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
      assert.are.equal("OPEN", lines[1])
    end)

    it("should not modify empty field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "" })

      -- Execute
      input_field.uppercase_field(bufnr, 1)

      -- Verify
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
      assert.are.equal("", lines[1])
    end)
  end)

  describe("get_field_value", function()
    it("should return trimmed field value", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "  value  " })

      -- Execute
      local value = input_field.get_field_value(bufnr, 1)

      -- Verify
      assert.are.equal("value", value)
    end)

    it("should return empty string for empty field", function()
      -- Setup
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "" })

      -- Execute
      local value = input_field.get_field_value(bufnr, 1)

      -- Verify
      assert.are.equal("", value)
    end)
  end)
end)
