--- Unit tests for buffer registry
describe("ui.buffer_registry", function()
  local registry

  before_each(function()
    registry = require("gh.ui.buffer_registry")
    registry.clear()
  end)

  it("should register and get a buffer", function()
    local name = "gh://test"
    local bufnr = 123
    -- Mock vim.api.nvim_buf_is_valid to return true for 123
    local original_is_valid = vim.api.nvim_buf_is_valid
    vim.api.nvim_buf_is_valid = function(buf) return buf == 123 end

    registry.register(name, bufnr)
    assert.are.equal(bufnr, registry.get(name))

    vim.api.nvim_buf_is_valid = original_is_valid
  end)

  it("should return nil for invalid or un-registered buffer", function()
    assert.is_nil(registry.get("gh://notfound"))
  end)

  it("should handle invalid buffers", function()
    local name = "gh://invalid"
    registry.register(name, 456)
    
    -- Mock vim.api.nvim_buf_is_valid to return false
    local original_is_valid = vim.api.nvim_buf_is_valid
    vim.api.nvim_buf_is_valid = function() return false end

    assert.is_nil(registry.get(name))
    
    vim.api.nvim_buf_is_valid = original_is_valid
  end)

  it("should unregister by name", function()
    registry.register("test", 1)
    registry.unregister("test")
    assert.is_nil(registry.get("test"))
  end)

  it("should unregister by bufnr", function()
    registry.register("test1", 1)
    registry.register("test2", 2)
    registry.unregister_by_bufnr(1)
    assert.is_nil(registry.get("test1"))
    assert.is_not_nil(registry.get("test2"))
  end)

  it("should find by pattern", function()
    registry.register("gh://issue/1", 1)
    registry.register("gh://issue/2", 2)
    registry.register("gh://issues", 3)
    
    local original_is_valid = vim.api.nvim_buf_is_valid
    vim.api.nvim_buf_is_valid = function() return true end

    local matches = registry.find_by_pattern("^gh://issue/%d+$")
    local count = 0
    for _ in pairs(matches) do count = count + 1 end
    assert.are.equal(2, count)
    assert.is_not_nil(matches["gh://issue/1"])
    assert.is_not_nil(matches["gh://issue/2"])
    assert.is_nil(matches["gh://issues"])

    vim.api.nvim_buf_is_valid = original_is_valid
  end)
end)
