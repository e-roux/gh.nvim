--- Buffer management for Oil.nvim-style editing
--- Provides editable buffers for GitHub issues and PRs
local M = {}

local registry = require("gh.ui.buffer_registry")

--- Create a new scratch buffer with common settings
---@param name string Buffer name
---@return integer bufnr Buffer number
function M.create_scratch(name)
	-- Check registry first for existing buffer
	local existing_bufnr = registry.get(name)
	if existing_bufnr then
		return existing_bufnr
	end

	-- Check if a buffer with this name already exists (fallback)
	existing_bufnr = vim.fn.bufnr(name)
	if existing_bufnr ~= -1 then
		-- Register and reuse existing buffer
		registry.register(name, existing_bufnr)
		return existing_bufnr
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, name)

	-- Register the new buffer
	registry.register(name, bufnr)

	-- Set buffer options for editing
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
	vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

	-- Set window-local options when buffer is displayed
	vim.api.nvim_create_autocmd("BufWinEnter", {
		buffer = bufnr,
		callback = function()
			vim.wo.number = false
			vim.wo.relativenumber = false
			-- Keep filter lines visible by setting scrolloff to ensure they stay on screen
			vim.wo.scrolloff = 8 -- Keep 8 lines visible above cursor (covers 7 filter lines + hrule)
		end,
	})

	return bufnr
end

--- Set buffer content with lines
---@param bufnr integer Buffer number
---@param lines string[] Lines to set
function M.set_lines(bufnr, lines)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
end

--- Get buffer content as lines
---@param bufnr integer Buffer number
---@return string[] Lines from buffer
function M.get_lines(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

--- Open buffer in current window
---@param bufnr integer Buffer number
function M.open(bufnr)
	vim.api.nvim_set_current_buf(bufnr)
end

--- Open buffer in split
---@param bufnr integer Buffer number
---@param vertical boolean|nil Open vertical split
function M.open_split(bufnr, vertical)
	if vertical then
		vim.cmd("vsplit")
	else
		vim.cmd("split")
	end
	vim.api.nvim_set_current_buf(bufnr)
end

--- Find window displaying an issue detail buffer (gh://issue/*)
---@return integer|nil Window ID if found, nil otherwise
function M.find_issue_detail_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bufname = vim.api.nvim_buf_get_name(buf)
		-- Check if buffer name matches issue detail pattern
		if bufname:match("^gh://issue/") then
			return win
		end
	end
	return nil
end

--- Find window displaying an issue list buffer (gh://issues)
---@return integer|nil Window ID if found, nil otherwise
function M.find_issue_list_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bufname = vim.api.nvim_buf_get_name(buf)
		-- Check if buffer name matches issue list pattern
		if bufname:match("^gh://issues") then
			return win
		end
	end
	return nil
end

--- Open buffer, optionally reusing an existing issue detail window
---@param bufnr integer Buffer number
---@param opts table|nil Options: { reuse_window: boolean, split_direction: "auto"|"horizontal"|"vertical" }
function M.open_smart(bufnr, opts)
	opts = opts or {}
	local reuse = opts.reuse_window
	local split_direction = opts.split_direction or "horizontal"

	if reuse then
		-- Try to find and reuse an existing issue detail window
		local existing_win = M.find_issue_detail_window()
		if existing_win then
			vim.api.nvim_set_current_win(existing_win)
			vim.api.nvim_set_current_buf(bufnr)
			return
		end
	end

	-- Check if issue list window is visible
	local issue_list_win = M.find_issue_list_window()

	if not issue_list_win then
		-- No issue list visible, open in current window
		vim.api.nvim_set_current_buf(bufnr)
		return
	end

	-- Issue list is visible, open in split
	-- Determine vertical split based on split_direction
	local vertical = false
	if split_direction == "auto" then
		-- Auto-detect: use vertical if window is wide (panorama mode)
		-- Threshold: 120 columns is a reasonable cutoff for panorama
		local width = vim.api.nvim_win_get_width(0)
		vertical = width >= 120
	elseif split_direction == "vertical" then
		vertical = true
	end

	M.open_split(bufnr, vertical)
end

--- Set up autocmd for buffer write
---@param bufnr integer Buffer number
---@param callback fun(bufnr: integer): boolean Write callback, return true on success
function M.on_write(bufnr, callback)
	-- Clear existing BufWriteCmd autocmds for this buffer
	vim.api.nvim_clear_autocmds({ event = "BufWriteCmd", buffer = bufnr })

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = bufnr,
		callback = function()
			local success = callback(bufnr)
			if success then
				vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
				vim.notify("Changes saved to GitHub", vim.log.levels.INFO)
			else
				vim.notify("Failed to save changes", vim.log.levels.ERROR)
			end
		end,
	})
end

--- Add buffer-local keymaps
---@param bufnr integer Buffer number
---@param mappings table<string, {callback: function, desc: string}>
function M.set_keymaps(bufnr, mappings)
	for key, config in pairs(mappings) do
		vim.keymap.set("n", key, config.callback, {
			buffer = bufnr,
			desc = config.desc,
			noremap = true,
			silent = true,
		})
	end
end

return M
