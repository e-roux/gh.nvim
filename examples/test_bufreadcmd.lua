-- Minimal test to check BufReadCmd for gh://issue/* pattern

-- Setup
vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")

-- Load the plugin
require("gh")

-- Create a test autocmd to see what's happening
vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = "*",
  callback = function(args)
    print("BufReadCmd triggered for: " .. args.file)
    print("Pattern matched: " .. vim.inspect(args.match))
  end,
})

-- Print all BufReadCmd autocmds
print("\n=== All BufReadCmd autocmds ===")
local autocmds = vim.api.nvim_get_autocmds({ event = "BufReadCmd" })
for _, autocmd in ipairs(autocmds) do
  print(string.format("Group: %s, Pattern: %s", autocmd.group_name or "none", vim.inspect(autocmd.pattern)))
end

-- Try to trigger the autocmd
print("\n=== Testing buffer creation ===")
vim.cmd("edit gh://issue/45")
print("Buffer name: " .. vim.api.nvim_buf_get_name(0))

-- Wait a bit
vim.wait(2000)
