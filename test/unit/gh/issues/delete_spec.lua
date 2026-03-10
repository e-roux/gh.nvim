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
    it("should delete an issue", function(done)
      delete.delete_issue(1, "owner/repo", function(success, error)
        assert.is_true(success)
        assert.is_nil(error)
        done()
      end)
    end)
  end)
end)
