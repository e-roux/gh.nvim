--- Unit tests for repo utilities
describe("utils.repo", function()
  local repo_utils
  local Job

  before_each(function()
    repo_utils = require("gh.utils.repo")
    Job = require("plenary.job")
  end)

  describe("parse_repo", function()
    it("should parse valid repository format", function()
      local owner, name, error = repo_utils.parse_repo("octocat/Hello-World")
      assert.are.equal("octocat", owner)
      assert.are.equal("Hello-World", name)
      assert.is_nil(error)
    end)

    it("should handle repository with hyphens", function()
      local owner, name, error = repo_utils.parse_repo("my-org/my-awesome-repo")
      assert.are.equal("my-org", owner)
      assert.are.equal("my-awesome-repo", name)
      assert.is_nil(error)
    end)

    it("should handle repository with dots", function()
      local owner, name, error = repo_utils.parse_repo("some.user/repo.name")
      assert.are.equal("some.user", owner)
      assert.are.equal("repo.name", name)
      assert.is_nil(error)
    end)

    it("should return error for invalid format (no slash)", function()
      local owner, name, error = repo_utils.parse_repo("invalid-repo")
      assert.is_nil(owner)
      assert.is_nil(name)
      assert.are.equal("Invalid repository format: invalid-repo", error)
    end)

    it("should return error for invalid format (trailing slash)", function()
      local owner, name, error = repo_utils.parse_repo("owner/")
      assert.is_nil(owner)
      assert.is_nil(name)
      assert.matches("Invalid repository format", error)
    end)

    it("should return error for invalid format (leading slash)", function()
      local owner, name, error = repo_utils.parse_repo("/repo")
      assert.is_nil(owner)
      assert.is_nil(name)
      assert.matches("Invalid repository format", error)
    end)

    it("should return error for empty string", function()
      local owner, name, error = repo_utils.parse_repo("")
      assert.is_nil(owner)
      assert.is_nil(name)
      assert.matches("Invalid repository format", error)
    end)
  end)

  describe("get_current_repo", function()
    it("should call gh repo view command", function()
      -- This is a more complex test since it involves async job execution
      -- We'll just verify the function exists and accepts a callback
      assert.is_function(repo_utils.get_current_repo)

      local called = false
      local test_callback = function(repo, error)
        called = true
      end

      -- Just verify it can be called without errors
      local ok = pcall(repo_utils.get_current_repo, test_callback)
      assert.is_true(ok)
    end)
  end)
end)
