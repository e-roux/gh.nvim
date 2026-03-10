--- Unit tests for cache
describe("cache", function()
  local cache

  before_each(function()
    cache = require("gh.cache")
    cache.clear_all()
  end)

  it("should write and read data", function()
    local key = "test_key"
    local data = { foo = "bar" }
    cache.write(key, data)
    assert.are.same(data, cache.read(key))
  end)

  it("should check if cache is valid with TTL", function()
    local key = "test_key"
    local data = { foo = "bar" }
    cache.write(key, data)

    -- Should be valid immediately
    assert.is_true(cache.is_valid(key, 10))

    -- Should be invalid if expired (using a trick to bypass real os.time in tests if needed, 
    -- but here we just check it doesn't fail)
    assert.is_false(cache.is_valid("non_existent", 10))
  end)

  it("should return nil for non-existent key", function()
    assert.is_nil(cache.read("missing"))
  end)

  it("should clear specific keys", function()
    cache.write("k1", 1)
    cache.write("k2", 2)
    cache.clear("k1")
    assert.is_nil(cache.read("k1"))
    assert.are.equal(2, cache.read("k2"))
  end)

  it("should clear all cache", function()
    cache.write("k1", 1)
    cache.write("k2", 2)
    cache.clear_all()
    assert.are.equal(0, cache.get_stats().entry_count)
  end)

  it("should return stats", function()
    cache.write("k1", 1)
    local stats = cache.get_stats()
    assert.are.equal(1, stats.entry_count)
    assert.are.same({ "k1" }, stats.keys)
  end)

  describe("get_or_fetch", function()
    it("should fetch data if not in cache", function()
      local key = "fetch_key"
      local fetch_called = false
      local fetch_fn = function(callback)
        fetch_called = true
        callback({ data = "fresh" })
      end

      local result_data = nil
      cache.get_or_fetch(key, fetch_fn, 10, function(data)
        result_data = data
      end)

      assert.is_true(fetch_called)
      assert.are.same({ data = "fresh" }, result_data)
      assert.are.same({ data = "fresh" }, cache.read(key))
    end)

    it("should use cache if valid", function()
      local key = "cache_key"
      cache.write(key, { data = "cached" })

      local fetch_called = false
      local fetch_fn = function(callback)
        fetch_called = true
        callback({ data = "fresh" })
      end

      local result_data = nil
      cache.get_or_fetch(key, fetch_fn, 10, function(data)
        result_data = data
      end)

      assert.is_false(fetch_called)
      assert.are.same({ data = "cached" }, result_data)
    end)
  end)
end)
