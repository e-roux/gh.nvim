--- Unit tests for buffer management
describe("ui.buffer", function()
  local buffer
  local registry

  before_each(function()
    buffer = require("gh.ui.buffer")
    registry = require("gh.ui.buffer_registry")
    registry.clear()
  end)

  describe("create_scratch", function()
    it("should create a new buffer and register it", function()
      local name = "gh://test_scratch"
      local bufnr = buffer.create_scratch(name)
      
      assert.is_number(bufnr)
      assert.are.equal(bufnr, registry.get(name))
      assert.are.equal("acwrite", vim.api.nvim_buf_get_option(bufnr, "buftype"))
    end)

    it("should reuse existing buffer from registry", function()
      local name = "gh://reuse"
      local bufnr1 = buffer.create_scratch(name)
      local bufnr2 = buffer.create_scratch(name)
      
      assert.are.equal(bufnr1, bufnr2)
    end)
  end)

  describe("set_lines/get_lines", function()
    it("should set and get buffer content", function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = { "line 1", "line 2" }
      
      buffer.set_lines(bufnr, lines)
      local result = buffer.get_lines(bufnr)
      
      assert.are.same(lines, result)
    end)
  end)

  describe("find_issue_detail_window", function()
    it("should find window with issue detail buffer", function()
      local name = "gh://issue/123"
      local bufnr = buffer.create_scratch(name)
      vim.api.nvim_set_current_buf(bufnr)
      
      local win = buffer.find_issue_detail_window()
      assert.is_not_nil(win)
      assert.are.equal(vim.api.nvim_get_current_win(), win)
    end)
  end)
end)
