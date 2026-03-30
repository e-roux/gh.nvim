--- Unit tests for gh.issues.close module
describe("gh.issues.close", function()
  local close
  local cli_mock

  before_each(function()
    cli_mock = {
      issue = {
        edit = function(number, opts, repo, callback)
          callback(true, nil, nil)
        end,
        view = function(number, repo, callback)
          callback(true, { number = number, state = "OPEN" }, nil)
        end,
        list = function(opts, callback)
          callback(true, { { number = 1, title = "Test" } }, nil)
        end,
        close = function(number, opts, callback)
          callback(true, nil)
        end,
        reopen = function(number, opts, callback)
          callback(true, nil)
        end,
      }
    }
    package.loaded["gh.cli"] = cli_mock
    close = require("gh.issues.close")
  end)

  after_each(function()
    package.loaded["gh.cli"] = nil
    package.loaded["gh.issues.close"] = nil
  end)

  describe("close_issue", function()
    it("should close an issue", function(done)
      close.close_issue(1, "owner/repo", {}, function(success, error)
        assert.is_true(success)
        assert.is_nil(error)
        done()
      end)
    end)
  end)

  describe("reopen_issue", function()
    it("should reopen an issue", function(done)
      close.reopen_issue(1, "owner/repo", {}, function(success, error)
        assert.is_true(success)
        assert.is_nil(error)
        done()
      end)
    end)
  end)

  describe("get_issue_completions", function()
    it("should fetch and cache completions", function()
      local cache = require("gh.cache")
      local result = nil
      close.get_issue_completions("owner/repo", "open", function(issues)
        result = issues
      end)

      vim.wait(500, function()
        return result ~= nil
      end)

      assert.is_table(result)
      assert.equal(1, #result)
      assert.equal(1, result[1].number)

      local cached = cache.read("issues_completion_owner/repo_open")
      assert.is_table(cached)
    end)
  end)
end)
