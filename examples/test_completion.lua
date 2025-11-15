-- Quick test script for command completion
-- Run with: nvim -u test_completion.lua

-- Set up minimal runtime
vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append("test/runtime/plenary.nvim")

-- Load the plugin
dofile("plugin/gh.lua")

-- Get the completion function
local function get_completions(cmdline)
  local cmd_parts = vim.split(cmdline, " ", { trimempty = false })
  local arg_lead = cmd_parts[#cmd_parts]
  if cmdline:sub(-1) == " " then
    arg_lead = ""
  end
  
  -- Call the completion function via Neovim's API
  local completions = vim.fn.getcompletion(cmdline, "cmdline")
  return completions
end

-- Test cases
local tests = {
  { cmd = "Gh ", expected = { "issue", "pr", "repo", "run", "workflow" } },
  { cmd = "Gh i", expected = { "issue" } },
  { cmd = "Gh issue ", expected = { "list", "view", "create", "close", "reopen" } },
  { cmd = "Gh issue l", expected = { "list" } },
  { cmd = "Gh pr ", expected = { "list", "view", "create", "checkout", "status" } },
  { cmd = "Gh pr v", expected = { "view" } },
  -- New flag completion tests
  { cmd = "Gh issue list -", expected = { "--state", "-s", "--limit", "-L", "--repo", "-R" } },
  { cmd = "Gh issue list --s", expected = { "--state" } },
  { cmd = "Gh issue list --state ", expected = { "open", "closed", "all" } },
  -- Note: Partial matches are filtered by Neovim's completion system, not our function
  -- So "Gh issue list --state o<tab>" will show nothing because Neovim filters after we return
  { cmd = "Gh issue view 123 -", expected = { "--repo", "-R" } },
}

print("Testing command completion...")
print("========================================")

for i, test in ipairs(tests) do
  local completions = get_completions(test.cmd)
  
  print(string.format("\nTest %d: '%s'", i, test.cmd))
  print("Expected: " .. vim.inspect(test.expected))
  print("Got:      " .. vim.inspect(completions))
  
  -- Check if we got what we expected
  local match = vim.deep_equal(completions, test.expected)
  if match then
    print("✅ PASS")
  else
    print("❌ FAIL")
  end
end

print("\n========================================")
print("Manual test: Type :Gh <Tab> in command mode")
print("Press :q to quit")

-- Don't exit immediately so user can test manually
