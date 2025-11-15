-- Test configuration examples for gh.nvim
-- Following modern Neovim 0.12+ patterns

-- Example 1: Default configuration (reuse window, horizontal split)
-- Just require the plugin - it will use defaults
-- require("gh")

-- Example 2: Custom configuration - set BEFORE requiring the plugin
-- vim.g.gh_opts = {
--   issue_detail = {
--     reuse_window = false,
--     split_direction = "vertical",
--   }
-- }
-- require("gh")

-- Example 3: Reuse window with vertical splits
-- vim.g.gh_opts = {
--   issue_detail = {
--     reuse_window = true,
--     split_direction = "vertical",
--   }
-- }
-- require("gh")

-- Test the configuration
-- Note: Set vim.g.gh_opts BEFORE this line to test custom config
local config = require("gh.config")
print("gh.nvim configuration:")
print("  reuse_window: " .. tostring(config.opts.issue_detail.reuse_window))
print("  split_direction: " .. config.opts.issue_detail.split_direction)
