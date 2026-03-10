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
      close.close_issue(1, { repo = "owner/repo" }, function(success, error)
        assert.is_true(success)
        assert.is_nil(error)
        done()
      end)
    end)
  end)

  describe("reopen_issue", function()
    it("should reopen an issue", function(done)
      close.reopen_issue(1, { repo = "owner/repo" }, function(success, error)
        assert.is_true(success)
        assert.is_nil(error)
        done()
      end)
    end)
  end)

  describe("get_issue_completions", function()
    it("should fetch and cache completions", function(done)
      local cache = require("gh.cache")
      close.get_issue_completions("owner/repo", "open", function(issues)
        assert.is_table(issues)
        assert.equal(1, #issues)
        assert.equal(1, issues[1].number)
        
        -- Check if it was cached
        local cached = cache.read("issues_completion_owner/repo_open")
        assert.is_table(cached)
        done()
      end)
    end)
  end)
end)
