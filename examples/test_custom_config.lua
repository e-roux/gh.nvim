-- Test custom configuration
vim.g.gh_opts = {
  issue_detail = {
    reuse_window = false,
    split_direction = "vertical",
  }
}

local config = require("gh.config")
print("Custom configuration test:")
print(vim.inspect(config.opts))

-- Verify values
assert(config.opts.issue_detail.reuse_window == false, "reuse_window should be false")
assert(config.opts.issue_detail.split_direction == "vertical", "split_direction should be vertical")

print("\n✓ Custom configuration works correctly!")
