--- Filter/Search UI for issue list buffer
--- Provides inline filtering with virtual lines and auto-updating
local M = {}

--- Namespace for virtual text
M.namespace = vim.api.nvim_create_namespace("gh_filter")

--- Namespace for error messages (separate to avoid overwriting filter labels)
M.error_namespace = vim.api.nvim_create_namespace("gh_filter_errors")

--- Floating window ID for sticky filter header (if enabled)
M.float_win = nil
M.float_buf = nil

--- Floating window for error messages
M.error_win = nil
M.error_buf = nil

--- Debounce timer for filter updates
M.debounce_timer = nil
M.debounce_ms = 500 -- Wait 500ms after last keystroke before applying filter

--- Flag to prevent concurrent filter requests
M.is_fetching = false

--- Flag to prevent TextChanged from triggering during programmatic buffer updates
M.is_updating_buffer = false

--- Filter definitions with line numbers and labels
M.FILTERS = {
	{
		line = 2,
		key = "state",
		keymap = "s",
		label = "◉ State",
		placeholder = "OPEN | CLOSED | ALL",
	},
	{
		line = 3,
		key = "assignee",
		keymap = "a",
		label = "👤 Assignee",
		placeholder = "@username or leave empty",
	},
	{
		line = 4,
		key = "author",
		keymap = "u",
		label = "✍ Author",
		placeholder = "@username or leave empty",
	},
	{
		line = 5,
		key = "label",
		keymap = "l",
		label = "🏷 Label",
		placeholder = "bug, enhancement, ... (comma-separated)",
	},
	{
		line = 6,
		key = "mention",
		keymap = "m",
		label = "@ Mention",
		placeholder = "@username or leave empty",
	},
	{
		line = 7,
		key = "milestone",
		keymap = "t",
		label = "🚩 Milestone",
		placeholder = "milestone name or leave empty",
	},
	{
		line = 8,
		key = "search",
		keymap = "/",
		label = "🔍 Search",
		placeholder = "search query or leave empty",
	},
}

--- Number of filter lines
M.FILTER_LINE_COUNT = #M.FILTERS

--- First line after filters where issues start (1-indexed, accounting for header line)
M.FIRST_ISSUE_LINE = M.FILTER_LINE_COUNT + 2 -- +1 for header, +1 for 1-indexed

--- Parse filter lines from buffer and build filter context
---@param bufnr integer Buffer number
---@return table|nil Filter context with keys: state, assignee, author, label, mention, milestone, search,
---  or nil if validation failed
---@return string|nil Error message if validation failed
function M.parse_filter_context(bufnr)
	local context = {}
	local errors = {}

	for _, filter in ipairs(M.FILTERS) do
		local lines = vim.api.nvim_buf_get_lines(bufnr, filter.line - 1, filter.line, false)
		local value = lines[1] or ""
		value = value:gsub("^%s*", ""):gsub("%s*$", "") -- trim whitespace

		if value ~= "" then
			if filter.key == "label" then
				-- Parse comma-separated labels
				local labels = {}
				for label in value:gmatch("[^,]+") do
					label = label:gsub("^%s*", ""):gsub("%s*$", "")
					if label ~= "" then
						table.insert(labels, label)
					end
				end
				if #labels > 0 then
					context[filter.key] = labels
				end
			elseif filter.key == "state" then
				-- Validate and normalize state
				local state_lower = value:lower()
				if state_lower ~= "open" and state_lower ~= "closed" and state_lower ~= "all" then
					table.insert(errors, string.format("State must be 'open', 'closed', or 'all' (got '%s')", value))
				else
					context[filter.key] = state_lower
				end
			else
				context[filter.key] = value
			end
		end
	end

	-- Return errors if any validation failed
	if #errors > 0 then
		return nil, table.concat(errors, "\n")
	end

	-- Default state if not specified
	if not context.state or context.state == "" then
		context.state = "all"
	end

	return context, nil
end

--- Apply filtering based on filter context
---@param bufnr integer Buffer number
---@return boolean success Whether filtering was applied
function M.apply_filters(bufnr)
	-- Skip if buffer is still initializing
	local ok, initializing = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_initializing")
	if ok and initializing then
		return false
	end

	-- Prevent concurrent filter requests
	if M.is_fetching then
		return false
	end

	-- Parse all filter lines
	local filter_context, validation_error = M.parse_filter_context(bufnr)

	-- Clear any previous error messages
	vim.api.nvim_buf_clear_namespace(bufnr, M.error_namespace, 0, -1)

	-- If validation failed, show error as virtual text and don't fetch
	if validation_error then
		-- Show validation error at end of line 1 using separate namespace
		vim.api.nvim_buf_set_extmark(bufnr, M.error_namespace, 0, 0, {
			virt_text = { { " ⚠ " .. validation_error, "ErrorMsg" } },
			virt_text_pos = "eol",
		})
		return false
	end

	-- Get repo from buffer
	local repo_ok, repo = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_repo")
	if not repo_ok then
		repo = nil
	end
	if repo == "" then
		repo = nil
	end

	-- Get stored issue count or calculate based on window height
	local ok_loaded, issues_loaded = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_loaded")
	local limit
	if ok_loaded and issues_loaded then
		-- Use the count of currently loaded issues to maintain consistency
		limit = issues_loaded
	else
		-- Fall back to window height calculation
		local win = vim.fn.bufwinid(bufnr)
		local height = win > 0 and vim.api.nvim_win_get_height(win) or 30
		limit = math.max(10, height - 4)
	end

	-- Add limit to filter context
	filter_context.limit = limit

	-- Fetch issues with filters applied via CLI
	M.is_fetching = true
	local cli = require("gh.cli")
	cli.list_issues(repo, filter_context, function(success, issues, error)
		M.is_fetching = false

		if not success then
			-- Extract meaningful error from CLI output
			local meaningful_error = error or "unknown error"

			-- Try to extract just the first line (the actual error)
			local first_line = meaningful_error:match("^([^\n]+)")
			if first_line and #first_line < 200 then
				meaningful_error = first_line
			end

			-- If it's a validation error, show a cleaner message
			if meaningful_error:find("invalid argument") then
				-- Extract the specific error part
				local arg, flag, values = meaningful_error:match('invalid argument "([^"]+)" for "([^"]+)" flag: (.+)')
				if arg and flag and values then
					meaningful_error = string.format("Invalid value '%s' for %s: %s", arg, flag, values)
				end
			end

			-- Show error as virtual text instead of notification
			vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, M.FILTER_LINE_COUNT)
			vim.api.nvim_buf_set_extmark(bufnr, M.namespace, 0, 0, {
				virt_text = { { "⚠ " .. meaningful_error, "ErrorMsg" } },
				virt_text_pos = "eol",
			})
			return
		end

		local IssueCollection = require("gh.models.collection").IssueCollection
		local collection = IssueCollection.new(issues)

		-- Generate issue lines
		local issue_lines = {}
		for _, issue in collection:iter() do
			table.insert(issue_lines, issue:format_list_line())
		end

		-- Update buffer: keep filter lines, update issues
		M.is_updating_buffer = true
		local filter_lines = vim.api.nvim_buf_get_lines(bufnr, 0, M.FILTER_LINE_COUNT, false)
		local all_lines = vim.list_extend(filter_lines, issue_lines)

		vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
		vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
		M.is_updating_buffer = false

		-- Update stored collection
		vim.api.nvim_buf_set_var(bufnr, "gh_issues_collection", collection:to_table())
		vim.api.nvim_buf_set_var(bufnr, "gh_filter_context", filter_context)

		-- Update virtual text display
		M.update_filter_display(bufnr)

		-- Show success message with issue count and filter context
		local count = collection:count()
		local ctx_parts = {}

		-- Build a compact filter context string (only show non-default values)
		if filter_context.state and filter_context.state ~= "all" then
			table.insert(ctx_parts, filter_context.state)
		end
		if filter_context.assignee then
			table.insert(ctx_parts, "@" .. filter_context.assignee)
		end
		if filter_context.author then
			table.insert(ctx_parts, "by:" .. filter_context.author)
		end
		if filter_context.label then
			local labels = type(filter_context.label) == "table" and table.concat(filter_context.label, ",")
				or filter_context.label
			table.insert(ctx_parts, labels)
		end

		local ctx_str = #ctx_parts > 0 and (" [" .. table.concat(ctx_parts, " ") .. "]") or ""
		vim.notify(string.format("%d issues%s", count, ctx_str), vim.log.levels.INFO)
	end)

	return true
end

--- Update the filter display with virtual lines and labels
---@param bufnr integer Buffer number
function M.update_filter_display(bufnr)
	-- Clear existing virtual text
	local total_lines = vim.api.nvim_buf_line_count(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, total_lines)

	-- Add help line as overlay on line 1 (0-indexed line 0)
	local localleader = vim.g.maplocalleader or "\\"

	local help_virt_text = {}
	for i, filter in ipairs(M.FILTERS) do
		-- Add filter name in normal color (strip emoji)
		local filter_name = filter.label:match("^[%s%p]*(.+)$") or filter.label
		filter_name = filter_name:gsub("^%s+", ""):gsub("%s+$", "")
		table.insert(help_virt_text, { filter_name, "Normal" })
		table.insert(help_virt_text, { " ", "Normal" })
		table.insert(help_virt_text, { localleader .. filter.keymap, "Cyan" })

		if i < #M.FILTERS then
			table.insert(help_virt_text, { "  ", "Normal" })
		end
	end

	-- Add help text as overlay on line 1 (0-indexed: 0)
	vim.api.nvim_buf_set_extmark(bufnr, M.namespace, 0, 0, {
		virt_text = help_virt_text,
		virt_text_pos = "overlay",
	})

	-- Add empty virtual line after header for spacing
	vim.api.nvim_buf_set_extmark(bufnr, M.namespace, 0, 0, {
		virt_lines = {
			{}, -- Empty line for spacing
		},
	})

	-- Add labels and placeholders for each filter line
	for _, filter in ipairs(M.FILTERS) do
		local line_num = filter.line - 1 -- 0-indexed
		local lines = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)
		local current_text = lines[1] or ""

		-- Check if line is empty or contains only spaces (our cursor positioning spaces)
		local is_empty = current_text:match("^%s*$") ~= nil

		if is_empty then
			-- Show label at col 0, then space, then placeholder at n+2
			-- Label text without trailing space or colon
			local label_only = filter.label
			vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line_num, 0, {
				virt_text = {
					{ label_only, "Title" },
					{ ":  ", "Title" }, -- colon + 2 spaces (positions placeholder at n+2)
					{ filter.placeholder, "Comment" },
				},
				virt_text_pos = "overlay",
			})
		else
			-- When line has actual content, show label inline (with colon and space)
			vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line_num, 0, {
				virt_text = { { filter.label .. ":  ", "Title" } }, -- colon + 2 spaces to match overlay format
				virt_text_pos = "inline",
			})
		end
	end

	-- Show horizontal rule below the last filter line
	-- Last filter line is M.FILTERS[#M.FILTERS].line, convert to 0-indexed
	local last_filter_line = M.FILTERS[#M.FILTERS].line - 1

	vim.api.nvim_buf_set_extmark(bufnr, M.namespace, last_filter_line, 0, {
		virt_lines = {
			{
				{
					"─────────────────────────────────────────────────────────────",
					"Comment",
				},
			},
		},
	})

	-- Add state indicators to issue lines
	local ok, collection_data = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_collection")
	if ok and collection_data then
		local IssueCollection = require("gh.models.collection").IssueCollection
		local collection = IssueCollection.new(collection_data)

		local buf_lines = vim.api.nvim_buf_line_count(bufnr)
		local issue_line_num = M.FIRST_ISSUE_LINE - 1 -- Start at 0-indexed line 7

		for _, issue in collection:iter() do
			if issue_line_num < buf_lines then
				-- Choose color based on state
				local state_text = issue.state == "open" and "OPEN" or "CLOSED"
				local state_hl = issue.state == "open" and "DiagnosticOk" or "Comment"

				vim.api.nvim_buf_set_extmark(bufnr, M.namespace, issue_line_num, 0, {
					virt_text = { { " " .. state_text, state_hl } },
					virt_text_pos = "eol",
				})
				issue_line_num = issue_line_num + 1
			end
		end
	end
end

--- Set up keymaps to jump to filter fields
---@param bufnr integer Buffer number
function M.setup_filter_keymaps(bufnr)
	local buffer_module = require("gh.ui.buffer")
	local keymaps = {}

	for _, filter in ipairs(M.FILTERS) do
		local key = "<localleader>" .. filter.keymap
		keymaps[key] = {
			callback = function()
				-- Jump to the filter line and enter insert mode at the correct position
				local line_num = filter.line
				local target_col = vim.fn.strlen(filter.label) + vim.fn.strlen(":  ")

				-- Move cursor to the line
				vim.api.nvim_win_set_cursor(0, { line_num, target_col })

				-- Enter insert mode
				vim.cmd("startinsert")
			end,
			desc = string.format("Jump to %s filter", filter.key),
		}
	end

	buffer_module.set_keymaps(bufnr, keymaps)
end

--- Set up auto-filter on text change for filter input line
---@param bufnr integer Buffer number
function M.setup_auto_filter(bufnr)
	-- Create autocmd group
	local group = vim.api.nvim_create_augroup("gh_filter_" .. bufnr, { clear = true })

	-- Flag to prevent initial autocmd triggers from causing unnecessary fetches
	local initial_setup_complete = false

	-- Track last filter state to detect actual changes
	local last_filter_state = nil

	-- Function to get current filter state as string for comparison
	local function get_filter_state()
		local state_parts = {}
		for _, filter in ipairs(M.FILTERS) do
			local lines = vim.api.nvim_buf_get_lines(bufnr, filter.line - 1, filter.line, false)
			local value = lines[1] or ""
			table.insert(state_parts, value)
		end
		return table.concat(state_parts, "|")
	end

	-- Function to position cursor on filter lines (only in insert mode)
	local function position_cursor()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line_num = cursor[1]
		local col = cursor[2]

		-- Check if we're on a filter line (lines 2-8, since line 1 is header)
		local filter = nil
		for _, f in ipairs(M.FILTERS) do
			if f.line == line_num then
				filter = f
				break
			end
		end

		if filter then
			local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
			local current_text = lines[1] or ""
			local is_empty = current_text:match("^%s*$") ~= nil

			-- If line is empty, position cursor at n+2 (after label + ": " + space)
			if is_empty then
				-- Cursor position is in bytes, so we need to convert
				-- display positions = strlen(label) + strlen(": ")
				local target_col = vim.fn.strlen(filter.label) + vim.fn.strlen(":  ")
				if col ~= target_col then
					vim.api.nvim_win_set_cursor(0, { line_num, target_col })
				end
			end
		elseif line_num > M.FIRST_ISSUE_LINE - 1 then
			-- We're on an issue line - only reposition in insert mode
			local mode = vim.api.nvim_get_mode().mode
			if mode == "i" or mode == "R" then
				local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
				local current_text = lines[1] or ""

				-- Parse issue line format: "#0001 │ Issue title"
				-- Find the separator and position cursor after it
				local sep_start, sep_end = current_text:find("│")
				if sep_start then
					-- Position cursor after "│ " (separator + space)
					local target_col = sep_end + 1
					if col < target_col then
						vim.api.nvim_win_set_cursor(0, { line_num, target_col })
					end
				end
			end
		end
	end

	-- Listen for text changes on any filter line
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = bufnr,
		callback = function()
			-- Skip if we're programmatically updating the buffer
			if M.is_updating_buffer then
				return
			end

			-- Skip if initial setup is not complete (prevents autocmd from firing during buffer creation)
			if not initial_setup_complete then
				return
			end

			-- Check if filter content actually changed
			local current_state = get_filter_state()
			if current_state == last_filter_state then
				-- No actual change, just cursor movement or mode change
				return
			end
			last_filter_state = current_state

			-- Get cursor position
			local cursor = vim.api.nvim_win_get_cursor(0)
			local line_num = cursor[1]

			-- Only process if cursor is on one of the filter lines (lines 1-7)
			if line_num >= 1 and line_num <= M.FILTER_LINE_COUNT then
				-- Cancel existing timer if any
				if M.debounce_timer then
					M.debounce_timer:stop()
					M.debounce_timer:close()
					M.debounce_timer = nil
				end

				-- Create new debounced timer
				M.debounce_timer = vim.loop.new_timer()
				M.debounce_timer:start(
					M.debounce_ms,
					0,
					vim.schedule_wrap(function()
						-- Apply filters (will parse all filter lines)
						M.apply_filters(bufnr)
						M.debounce_timer = nil
					end)
				)
			end
		end,
	})

	-- Consolidated cursor handler to avoid infinite loops
	-- Only updates display and keeps filter lines visible
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = bufnr,
		callback = function()
			-- Update virtual text display (to show/hide placeholders)
			M.update_filter_display(bufnr)

			local cursor = vim.api.nvim_win_get_cursor(0)
			local line_num = cursor[1]
			local col = cursor[2]

			-- Prevent cursor from being on line 1 (help line)
			if line_num == 1 then
				-- Move to first filter line
				local first_filter = M.FILTERS[1]
				local target_col = vim.fn.strlen(first_filter.label) + vim.fn.strlen(":  ")
				vim.cmd(string.format("noautocmd call nvim_win_set_cursor(0, [%d, %d])", first_filter.line, target_col))
				return
			end

			-- In normal mode, auto-position cursor at n+2 on empty filter lines
			local mode = vim.api.nvim_get_mode().mode
			if mode == "n" or mode == "v" or mode == "V" then
				-- Check if we're on a filter line
				if line_num >= 1 and line_num <= M.FILTER_LINE_COUNT then
					local filter = M.FILTERS[line_num]
					if filter then
						local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
						local current_text = lines[1] or ""
						local is_empty = current_text:match("^%s*$") ~= nil

						-- If line is empty, position cursor at n+2
						if is_empty then
							local target_col = vim.fn.strlen(filter.label) + vim.fn.strlen(":  ")
							if col ~= target_col then
								-- Use noautocmd to prevent infinite loop
								vim.cmd(
									string.format(
										"noautocmd call nvim_win_set_cursor(0, [%d, %d])",
										line_num,
										target_col
									)
								)
							end
						end
					end
				end
			end

			-- Keep filter lines visible (scroll adjustment only)
			local win = vim.api.nvim_get_current_win()
			local buf = vim.api.nvim_win_get_buf(win)
			if buf == bufnr then
				local top_line = vim.fn.line("w0")
				if top_line > 1 then
					vim.fn.winrestview({ topline = 1 })
				end
			end
		end,
	})

	-- Separate handler for insert mode entry and buffer entry
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group,
		buffer = bufnr,
		callback = position_cursor,
	})

	-- InsertEnter needs vim.schedule to position cursor after mode change completes
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		buffer = bufnr,
		callback = function()
			vim.schedule(position_cursor)
		end,
	})

	-- Initial display update and cursor positioning
	M.update_filter_display(bufnr)
	vim.schedule(function()
		-- Position cursor on the first filter field (State) at column 0
		local first_filter = M.FILTERS[1]
		vim.api.nvim_win_set_cursor(0, { first_filter.line, 0 })

		-- Initialize last filter state
		last_filter_state = get_filter_state()
		-- Mark setup as complete after initial positioning
		-- This prevents TextChanged autocmds from firing during buffer creation
		initial_setup_complete = true
	end)
end

return M
