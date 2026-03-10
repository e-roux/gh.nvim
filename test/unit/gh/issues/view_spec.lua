--- Unit tests for gh.issues.view module
describe("gh.issues.view", function()
  local view
  local cli_mock

  before_each(function()
    cli_mock = {
      issue = {
        view = function(number, repo, callback)
          callback(true, { 
            number = number, 
            title = "Test", 
            body = "Body",
            state = "OPEN",
            author = { login = "user" },
            createdAt = "2024-01-01T00:00:00Z"
          }, nil)
        end,
        edit = function(number, opts, repo, callback)
          callback(true, nil, nil)
        end
      }
    }
    package.loaded["gh.cli"] = cli_mock
    view = require("gh.issues.view")
  end)

  after_each(function()
    package.loaded["gh.cli"] = nil
    package.loaded["gh.issues.view"] = nil
  end)

  describe("open_issue_detail", function()
    it("should open an issue detail buffer", function()
      -- Mock nvim API
      local old_buf_set_lines = vim.api.nvim_buf_set_lines
      vim.api.nvim_buf_set_lines = function() end
      
      view.open_issue_detail(1, "owner/repo")
      
      vim.api.nvim_buf_set_lines = old_buf_set_lines
    end)
  end)
end)
