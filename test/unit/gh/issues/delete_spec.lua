--- Unit tests for gh.issues.delete module
describe("gh.issues.delete", function()
  local delete
  local cli_mock

  before_each(function()
    cli_mock = {
      issue = {
        delete = function(number, repo, callback)
          callback(true, nil, nil)
        end
      }
    }
    package.loaded["gh.cli"] = cli_mock
    delete = require("gh.issues.delete")
  end)

  after_each(function()
    package.loaded["gh.cli"] = nil
    package.loaded["gh.issues.delete"] = nil
  end)

  describe("delete_issue", function()
    it("should delete an issue", function()
      local result = nil
      delete.delete_issue(1, "owner/repo", function(success, error)
        result = { success = success, error = error }
      end)

      vim.wait(500, function()
        return result ~= nil
      end)

      assert.is_true(result.success)
      assert.is_nil(result.error)
    end)
  end)
end)
