--- Unit tests for gh.api module
describe("gh.api", function()
  local api
  local Job

  before_each(function()
    -- Mock plenary.job
    Job = {
      new = function(self, opts)
        return {
          start = function(_)
            -- Simulate async execution
            vim.schedule(function()
              opts.on_exit({
                result = function()
                  return { [[{"data":{"repository":{"issue":{"number":1,"title":"Test"}}}}]] }
                end,
                stderr_result = function()
                  return {}
                end,
              }, 0)
            end)
          end,
        }
      end,
    }
    package.loaded["plenary.job"] = Job
    api = require("gh.api")
  end)

  after_each(function()
    package.loaded["plenary.job"] = nil
    package.loaded["gh.api"] = nil
  end)

  describe("graphql", function()
    it("should call callback with success and data", function(done)
      api.graphql("query { viewer { login } }", {}, function(success, data, error)
        assert.is_true(success)
        assert.is_table(data)
        assert.is_nil(error)
        done()
      end)
    end)
  end)

  describe("get_issue", function()
    it("should fetch issue details", function(done)
      api.get_issue(1, "owner/repo", function(success, issue, error)
        assert.is_true(success)
        assert.is_table(issue)
        assert.equal(1, issue.number)
        assert.is_nil(error)
        done()
      end)
    end)
  end)

  describe("list_issues", function()
    it("should list issues", function(done)
      -- Mock response for list_issues
      Job.new = function(self, opts)
        return {
          start = function(_)
            vim.schedule(function()
              opts.on_exit({
                result = function()
                  return { [[{"data":{"repository":{"issues":{"nodes":[{"number":1,"title":"Test"}]}}}}}]] }
                end,
                stderr_result = function()
                  return {}
                end,
              }, 0)
            end)
          end,
        }
      end

      api.list_issues("owner/repo", {}, function(success, issues, error)
        assert.is_true(success)
        assert.is_table(issues)
        assert.equal(1, issues[1].number)
        assert.is_nil(error)
        done()
      end)
    end)
  end)
end)
