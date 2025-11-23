-- TODO: See GitHub issues #25 and #22 — quickfix parsing / gh integration. Add tests and harden gh output handling.

-- Check for plenary dependency
local ok = pcall(require, "plenary.job")
if not ok then
	vim.notify("gh.nvim: Plenary not found", vim.log.levels.WARN)
	return
end

-- Load gh module
local gh_module_ok, gh = pcall(require, "gh")
if not gh_module_ok then
	vim.notify("gh.nvim: Failed to load gh module: " .. tostring(gh), vim.log.levels.ERROR)
	return
end

--- Main gh command handler - mirrors gh CLI structure
--- @param opts table
local function gh_command(opts)
	local commands = require("gh.commands")
	commands.handle(opts.fargs)
end

--- Simple command completion for Gh command
--- @param arg_lead string Current argument being typed
--- @param cmd_line string Full command line
--- @param cursor_pos integer Cursor position
--- @return string[] Completion candidates
local function gh_complete(arg_lead, cmd_line, cursor_pos)
	local commands = require("gh.commands")
	return commands.complete(arg_lead, cmd_line, cursor_pos)
end

vim.api.nvim_create_user_command("Gh", gh_command, {
	nargs = "*",
	bang = true,
	complete = gh_complete,
	desc = "GitHub CLI integration - mirrors gh command structure",
})
