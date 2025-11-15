-- Diagnostic script to find where "Invalid gh:// buffer" error comes from
-- Run with: nvim -u examples/debug_error.lua

print("=== Debugging gh:// buffer error ===\n")

-- Set up minimal runtime path
vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")

-- Load the plugin
print("Loading gh.nvim...")
require("gh")

-- Check all autocmds that might affect our buffers
print("\n=== All BufReadCmd autocmds ===")
local bufread_autocmds = vim.api.nvim_get_autocmds({ event = "BufReadCmd" })
for _, ac in ipairs(bufread_autocmds) do
  print(string.format("  Group: %s, Pattern: %s", ac.group_name or "none", vim.inspect(ac.pattern)))
end

print("\n=== All BufEnter autocmds ===")
local bufenter_autocmds = vim.api.nvim_get_autocmds({ event = "BufEnter" })
for _, ac in ipairs(bufenter_autocmds) do
  print(string.format("  Group: %s, Pattern: %s", ac.group_name or "none", vim.inspect(ac.pattern)))
end

-- Override vim.notify to catch all notifications
local original_notify = vim.notify
vim.notify = function(msg, level, opts)
  print(string.format("[NOTIFY] Level: %s, Message: %s", level or "info", msg))
  if msg:match("Invalid") then
    print("  ^^^ FOUND THE ERROR! ^^^")
    print("  Stack trace:")
    print(debug.traceback())
  end
  original_notify(msg, level, opts)
end

-- Try to open a gh:// buffer
print("\n=== Opening gh://issue/45 ===")
vim.cmd("edit gh://issue/45")

print("\n=== Buffer info ===")
print("Buffer name: " .. vim.api.nvim_buf_get_name(0))
print("Buffer type: " .. vim.bo.buftype)
print("Is gh buffer: " .. tostring(vim.b.is_gh_buffer))

-- Check for errors in messages
print("\n=== Checking :messages for errors ===")
vim.cmd("messages")

print("\n=== Done ===")
print("If you see 'Invalid gh:// buffer' above, check the stack trace to find the source.")
