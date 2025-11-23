--- Unit tests for cache module
describe("cache", function()
  local cache
  
  before_each(function()
    cache = require("gh.cache")
    cache.clear_all()
  end)
  
  after_each(function()
    cache.clear_all()
  end)
  
  describe("write and read", function()
    it("should write and read data", function()
      local data = { foo = "bar", baz = 123 }
      cache.write("test_key", data)
      
      local result = cache.read("test_key")
      assert.are.same(data, result)
    end)
    
    it("should return nil for non-existent key", function()
      local result = cache.read("non_existent")
      assert.is_nil(result)
    end)
    
    it("should overwrite existing data", function()
      cache.write("test_key", { value = 1 })
      cache.write("test_key", { value = 2 })
      
      local result = cache.read("test_key")
      assert.are.equal(2, result.value)
    end)
  end)
  
  describe("is_valid", function()
    it("should return false for non-existent key", function()
      assert.is_false(cache.is_valid("non_existent"))
    end)
    
    it("should return true for fresh data", function()
      cache.write("test_key", { data = "test" })
      assert.is_true(cache.is_valid("test_key", 300))
    end)
    
    it("should return false for expired data", function()
      cache.write("test_key", { data = "test" })
      -- Mock expired by setting TTL to 0
      assert.is_false(cache.is_valid("test_key", 0))
    end)
  end)
  
  describe("clear", function()
    it("should clear specific key", function()
      cache.write("key1", { data = 1 })
      cache.write("key2", { data = 2 })
      
      cache.clear("key1")
      
      assert.is_nil(cache.read("key1"))
      assert.is_not_nil(cache.read("key2"))
    end)
  end)
  
  describe("clear_all", function()
    it("should clear all keys", function()
      cache.write("key1", { data = 1 })
      cache.write("key2", { data = 2 })
      cache.write("key3", { data = 3 })
      
      cache.clear_all()
      
      assert.is_nil(cache.read("key1"))
      assert.is_nil(cache.read("key2"))
      assert.is_nil(cache.read("key3"))
    end)
  end)
  
  describe("get_or_fetch", function()
    it("should fetch when cache is empty", function()
      local fetched = false
      local fetch_fn = function(callback)
        fetched = true
        callback({ data = "fetched" })
      end
      
      cache.get_or_fetch("test_key", fetch_fn, 300, function(data)
        assert.is_true(fetched)
        assert.are.same({ data = "fetched" }, data)
      end)
    end)
    
    it("should use cache when valid", function()
      cache.write("test_key", { data = "cached" })
      
      local fetched = false
      local fetch_fn = function(callback)
        fetched = true
        callback({ data = "fetched" })
      end
      
      cache.get_or_fetch("test_key", fetch_fn, 300, function(data)
        assert.is_false(fetched)
        assert.are.same({ data = "cached" }, data)
      end)
    end)
  end)
  
  describe("get_stats", function()
    it("should return correct stats", function()
      cache.write("key1", { data = 1 })
      cache.write("key2", { data = 2 })
      
      local stats = cache.get_stats()
      assert.are.equal(2, stats.entry_count)
      assert.is_true(vim.tbl_contains(stats.keys, "key1"))
      assert.is_true(vim.tbl_contains(stats.keys, "key2"))
    end)
  end)
end)
