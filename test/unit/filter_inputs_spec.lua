--- Tests for filter_inputs module
local filter_inputs = require("gh.ui.filter_inputs")

describe("filter_inputs", function()
  local bufnr
  local namespace
  local extmark_ids

  before_each(function()
    -- Create test buffer
    bufnr = vim.api.nvim_create_buf(false, true)
    namespace = vim.api.nvim_create_namespace("test_filter")
    extmark_ids = {}
  end)

  after_each(function()
    -- Clean up test buffer
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("inputs", function()
    it("should have 7 filter inputs defined", function()
      assert.equals(7, #filter_inputs.inputs)
    end)

    it("should have correct input names", function()
      local names = {}
      for _, input in ipairs(filter_inputs.inputs) do
        table.insert(names, input.name)
      end

      assert.same({
        "state",
        "assignee",
        "author",
        "label",
        "mention",
        "milestone",
        "search",
      }, names)
    end)
  end)

  describe("render", function()
    it("should render all inputs without error", function()
      assert.has_no.errors(function()
        filter_inputs.render(bufnr, namespace, extmark_ids)
      end)
    end)

    it("should create extmarks for all inputs", function()
      filter_inputs.render(bufnr, namespace, extmark_ids)

      -- Check that extmarks were created
      for _, input in ipairs(filter_inputs.inputs) do
        assert.is_not_nil(extmark_ids[input.name])
      end

      -- Check that results_header extmark was created
      assert.is_not_nil(extmark_ids.results_header)
    end)
  end)

  describe("get_value", function()
    it("should return empty string for empty input", function()
      filter_inputs.render(bufnr, namespace, extmark_ids)

      local value = filter_inputs.get_value(bufnr, namespace, extmark_ids, "state")
      assert.equals("", value)
    end)

    it("should return trimmed value for non-empty input", function()
      -- Set content BEFORE rendering (so extmarks are positioned correctly)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "", -- line 1 (header)
        "  OPEN  ", -- line 2 (state)
        "", -- line 3 (assignee)
        "", -- line 4 (author)
        "", -- line 5 (label)
        "", -- line 6 (mention)
        "", -- line 7 (milestone)
        "", -- line 8 (search)
      })

      filter_inputs.render(bufnr, namespace, extmark_ids)

      local value = filter_inputs.get_value(bufnr, namespace, extmark_ids, "state")
      assert.equals("OPEN", value)
    end)
  end)

  describe("get_values", function()
    it("should return all input values", function()
      -- Set content BEFORE rendering
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "", -- line 1 (header)
        "OPEN", -- line 2 (state)
        "@octocat", -- line 3 (assignee)
        "", -- line 4 (author)
        "", -- line 5 (label)
        "", -- line 6 (mention)
        "", -- line 7 (milestone)
        "", -- line 8 (search)
      })

      filter_inputs.render(bufnr, namespace, extmark_ids)

      local values = filter_inputs.get_values(bufnr, namespace, extmark_ids)

      assert.equals("OPEN", values.state)
      assert.equals("@octocat", values.assignee)
      assert.equals("", values.author)
    end)
  end)

  describe("update_display", function()
    it("should update placeholders without error", function()
      filter_inputs.render(bufnr, namespace, extmark_ids)

      assert.has_no.errors(function()
        filter_inputs.update_display(bufnr, namespace, extmark_ids)
      end)
    end)
  end)

  describe("jump_to_input", function()
    it("should jump to specified input", function()
      filter_inputs.render(bufnr, namespace, extmark_ids)

      -- Open buffer in a window
      vim.cmd("split")
      vim.api.nvim_win_set_buf(0, bufnr)

      -- Jump to assignee input (line 3)
      filter_inputs.jump_to_input(bufnr, namespace, extmark_ids, "assignee")

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1]) -- Should be on line 3

      -- Clean up window
      vim.cmd("close")
    end)
  end)
end)
