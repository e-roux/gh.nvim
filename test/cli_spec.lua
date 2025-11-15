--- Tests for gh.cli module
local mock_cli_helper = require("test.helpers.mock_cli")
local fixtures = require("test.fixtures.gh_responses")

describe("gh.cli", function()
  local mock_cli

  before_each(function()
    mock_cli_helper.reset()
    mock_cli_helper.setup_default_mocks()
    mock_cli = mock_cli_helper.create_mock_cli()
  end)

  describe("list_issues", function()
    it("returns issue list for current repo", function()
      local called = false
      local result_issues

      mock_cli.list_issues(nil, function(success, issues, error)
        called = true
        assert.is_true(success)
        assert.is_nil(error)
        result_issues = issues
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_not_nil(result_issues)
      assert.equals(4, #result_issues)
      assert.equals(1, result_issues[1].number)
      assert.equals("Add dark mode support", result_issues[1].title)
    end)

    it("returns empty list when no issues exist", function()
      mock_cli_helper.mock_issue_list(nil, {})
      mock_cli = mock_cli_helper.create_mock_cli()

      local called = false
      local result_issues

      mock_cli.list_issues(nil, function(success, issues, error)
        called = true
        assert.is_true(success)
        assert.is_nil(error)
        result_issues = issues
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_not_nil(result_issues)
      assert.equals(0, #result_issues)
    end)

    it("handles errors gracefully", function()
      mock_cli_helper.mock_issue_list(nil, "error")
      mock_cli = mock_cli_helper.create_mock_cli()

      local called = false
      local result_success, result_error

      mock_cli.list_issues(nil, function(success, issues, error)
        called = true
        result_success = success
        result_error = error
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_false(result_success)
      assert.is_not_nil(result_error)
      assert.matches("Mock error", result_error)
    end)
  end)

  describe("get_issue", function()
    it("returns issue details", function()
      local called = false
      local result_issue

      mock_cli.get_issue(1, nil, function(success, issue, error)
        called = true
        assert.is_true(success)
        assert.is_nil(error)
        result_issue = issue
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_not_nil(result_issue)
      assert.equals(1, result_issue.number)
      assert.equals("Add dark mode support", result_issue.title)
      assert.matches("Requirements", result_issue.body)
    end)

    it("handles missing issues", function()
      mock_cli_helper.mock_issue_view(999, "error")
      mock_cli = mock_cli_helper.create_mock_cli()

      local called = false
      local result_success, result_error

      mock_cli.get_issue(999, nil, function(success, issue, error)
        called = true
        result_success = success
        result_error = error
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_false(result_success)
      assert.is_not_nil(result_error)
    end)
  end)

  describe("update_title", function()
    it("successfully updates issue title", function()
      local called = false
      local result_success

      mock_cli.update_title(1, "New title", nil, function(success, error)
        called = true
        result_success = success
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_true(result_success)
    end)

    it("handles update errors", function()
      mock_cli_helper.mock_issue_edit_title(1, false)
      mock_cli = mock_cli_helper.create_mock_cli()

      local called = false
      local result_success, result_error

      mock_cli.update_title(1, "New title", nil, function(success, error)
        called = true
        result_success = success
        result_error = error
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_false(result_success)
      assert.is_not_nil(result_error)
    end)
  end)

  describe("update_body", function()
    it("successfully updates issue body", function()
      local called = false
      local result_success

      mock_cli.update_body(1, "New body content", nil, function(success, error)
        called = true
        result_success = success
      end)

      vim.wait(1000, function()
        return called
      end)

      assert.is_true(called)
      assert.is_true(result_success)
    end)
  end)
end)
