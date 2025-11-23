--- Issue creation module with template support
local M = {}

local buffer = require("gh.ui.buffer")
local cli = require("gh.cli")
local cache = require("gh.cache")
local frontmatter = require("gh.utils.frontmatter")

--- Create a new issue buffer with template content
---@param opts table Options: { repo: string|nil, template: string|nil, title: string|nil, assignees: string[]|nil,
---  labels: string[]|nil, milestone: string|nil, project: string|nil }
function M.create_issue_buffer(opts)
	opts = opts or {}
	local repo = opts.repo

	-- Get config defaults
	local config = require("gh.config")
	local defaults = config.opts.issue_create or {}

	-- Merge with defaults
	opts.assignees = opts.assignees or defaults.default_assignees or {}
	opts.labels = opts.labels or defaults.default_labels or {}
	opts.milestone = opts.milestone or defaults.default_milestone
	opts.project = opts.project or defaults.default_project

	-- Function to create buffer with content
	local function create_buffer_with_content(template_content)
		-- Parse frontmatter from template
		local parsed_frontmatter, body_content = nil, template_content
		if template_content and template_content ~= "" then
			parsed_frontmatter, body_content = frontmatter.parse(template_content)

			-- Validate frontmatter
			if parsed_frontmatter then
				local valid, error_msg = frontmatter.validate(parsed_frontmatter)
				if not valid then
					vim.notify("Invalid template frontmatter: " .. error_msg, vim.log.levels.WARN)
					parsed_frontmatter = nil
				end
			end
		end

		-- Extract metadata from frontmatter
		local template_metadata = frontmatter.extract_metadata(parsed_frontmatter)

		-- Merge template metadata with opts (opts take precedence)
		if not opts.title and template_metadata.title then
			opts.title = template_metadata.title
		end
		if #opts.labels == 0 and #template_metadata.labels > 0 then
			opts.labels = template_metadata.labels
		end
		if #opts.assignees == 0 and #template_metadata.assignees > 0 then
			opts.assignees = template_metadata.assignees
		end

		-- Create buffer with unique name (timestamp to prevent reuse)
		local timestamp = vim.loop.hrtime()
		local buf_name = repo and string.format("gh://issue/new/%s/%d", repo, timestamp)
			or string.format("gh://issue/new/%d", timestamp)
		local bufnr = buffer.create_scratch(buf_name)

		-- Format initial content
		local lines = {}

		-- Add title line
		if opts.title then
			table.insert(lines, "# " .. opts.title)
		else
			table.insert(lines, "# Issue Title")
		end
		table.insert(lines, "")

		-- Add template body content (without frontmatter)
		if body_content and body_content ~= "" then
			for line in (body_content .. "\n"):gmatch("([^\n]*)\n") do
				table.insert(lines, line)
			end
		else
			table.insert(lines, "Issue description here...")
		end

		buffer.set_lines(bufnr, lines)

		-- Store metadata in buffer for later use
		frontmatter.apply_to_buffer(bufnr, template_metadata)

		-- Create a mock issue object for virtual text rendering
		-- Get current user (fallback to empty if fails)
		local current_user = "unknown"
		local user_result = vim.fn.system("gh api user --jq .login 2>/dev/null")
		if vim.v.shell_error == 0 then
			current_user = user_result:gsub("\n", "")
		end

		local mock_issue = {
			state = "open",
			author = { login = current_user },
			createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			labels = {},
			assignees = {},
			milestone = opts.milestone and { title = opts.milestone } or nil,
		}

		-- Convert assignee strings to assignee objects
		if opts.assignees and #opts.assignees > 0 then
			for _, assignee in ipairs(opts.assignees) do
				table.insert(mock_issue.assignees, { login = assignee })
			end
		end

		-- Convert label strings to label objects
		if opts.labels and #opts.labels > 0 then
			for _, label in ipairs(opts.labels) do
				table.insert(mock_issue.labels, { name = label, color = "888888" })
			end
		end

		-- Store metadata
		vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
		vim.api.nvim_buf_set_var(bufnr, "gh_is_new_issue", true)
		vim.api.nvim_buf_set_var(bufnr, "gh_original_issue", mock_issue)
		vim.api.nvim_buf_set_var(bufnr, "gh_issue_opts", {
			assignees = opts.assignees,
			labels = opts.labels,
			milestone = opts.milestone,
			project = opts.project,
		})

		-- Add virtual text metadata
		local render = require("gh.ui.render")
		render.render_metadata(bufnr, mock_issue)

		-- Set up write handler for creating the issue
		buffer.on_write(bufnr, function(buf)
			local current_lines = buffer.get_lines(buf)

			-- Parse title and body
			local title = ""
			local body_lines = {}

			for i, line in ipairs(current_lines) do
				if i == 1 then
					title = line:gsub("^#%s*", "")
				elseif i > 2 then
					table.insert(body_lines, line)
				end
			end

			local body = table.concat(body_lines, "\n")

			if title == "" or title == "Issue Title" then
				vim.notify("Please provide a valid issue title", vim.log.levels.ERROR)
				return false
			end

			-- Get stored options
			local issue_opts = vim.api.nvim_buf_get_var(buf, "gh_issue_opts")
			local target_repo = vim.api.nvim_buf_get_var(buf, "gh_repo")
			if target_repo == "" then
				target_repo = nil
			end

			-- Check if this is a new issue or an update
			local is_new = vim.api.nvim_buf_get_var(buf, "gh_is_new_issue")

			if is_new then
				-- Create new issue
				local create_opts = {
					title = title,
					body = body,
					assignees = issue_opts.assignees,
					labels = issue_opts.labels,
					milestone = issue_opts.milestone,
					project = issue_opts.project,
					repo = target_repo,
				}

				-- Show creating message immediately
				vim.notify("Creating issue...", vim.log.levels.INFO)

				cli.create_issue(create_opts, function(success, issue, error)
					if not success then
						vim.schedule(function()
							vim.notify("Failed to create issue: " .. (error or "unknown error"), vim.log.levels.ERROR)
						end)
						return
					end

					vim.schedule(function()
						-- Mark as no longer new
						vim.api.nvim_buf_set_var(buf, "gh_is_new_issue", false)

						-- Store issue number for future updates
						if issue.number then
							vim.api.nvim_buf_set_var(buf, "gh_issue_number", issue.number)
							vim.notify("Issue #" .. issue.number .. " created successfully", vim.log.levels.INFO)

							-- Rename buffer to reflect the issue number
							local new_name = target_repo
									and string.format("gh://issue/%s/%d", target_repo, issue.number)
								or string.format("gh://issue/%d", issue.number)
							vim.api.nvim_buf_set_name(buf, new_name)

							-- Clear cache
							local cache_module = require("gh.cache")
							local state = "open" -- New issues are always open
							local cache_key = string.format(
								"issues_%s_%s",
								target_repo and target_repo:gsub("/", "_") or "current",
								state
							)
							cache_module.clear(cache_key)

							-- Trigger autocmd to notify list buffers to refresh
							vim.defer_fn(function()
								vim.api.nvim_exec_autocmds("User", {
									pattern = "GhIssueCreated",
									data = {
										issue_number = issue.number,
										repo = target_repo,
										state = state,
									},
								})
							end, 500)

							-- Fetch the full issue data to update virtual text with actual data
							cli.get_issue(issue.number, target_repo, function(fetch_success, full_issue, _fetch_error)
								if fetch_success and full_issue then
									vim.schedule(function()
										-- Update stored issue data
										vim.api.nvim_buf_set_var(buf, "gh_original_issue", full_issue)

										-- Refresh virtual text with actual issue data
										local render_module = require("gh.ui.render")
										render_module.render_metadata(buf, full_issue)
									end)
								end
							end)
						else
							vim.notify("Issue created successfully", vim.log.levels.INFO)
						end

						vim.api.nvim_set_option_value("modified", false, { buf = buf })
					end)
				end)

				-- Return immediately, don't block
				return true
			else
				-- Update existing issue
				local issue_number = vim.api.nvim_buf_get_var(buf, "gh_issue_number")
				local original = vim.api.nvim_buf_get_var(buf, "gh_original_issue")

				local pending = 0
				local errors = {}

				-- Update title if changed
				if title ~= original.title then
					pending = pending + 1
					cli.update_title(issue_number, title, target_repo, function(success, err)
						pending = pending - 1
						if not success then
							table.insert(errors, "title: " .. (err or "unknown"))
						end
					end)
				end

				-- Update body if changed
				if body ~= original.body then
					pending = pending + 1
					cli.update_body(issue_number, body, target_repo, function(success, err)
						pending = pending - 1
						if not success then
							table.insert(errors, "body: " .. (err or "unknown"))
						end
					end)
				end

				if pending == 0 then
					vim.notify("No changes detected", vim.log.levels.INFO)
					return true
				end

				vim.wait(5000, function()
					return pending == 0
				end)

				if #errors > 0 then
					vim.notify("Errors saving changes:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
					return false
				end

				return true
			end
		end)

		-- Set up keymaps
		buffer.set_keymaps(bufnr, {
			["q"] = {
				callback = function()
					vim.cmd("close")
				end,
				desc = "Close issue creation buffer",
			},
		})

		-- Open in split with config options
		local cfg = require("gh.config")
		buffer.open_smart(bufnr, {
			reuse_window = cfg.opts.issue_detail.reuse_window,
			split_direction = cfg.opts.issue_detail.split_direction,
		})

		-- Set filetype
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
	end

	-- If template is specified, fetch it
	if opts.template then
		cli.get_issue_template(repo, opts.template, function(success, content, error)
			if not success then
				vim.notify("Failed to fetch template: " .. (error or "unknown error"), vim.log.levels.WARN)
				create_buffer_with_content("")
				return
			end
			create_buffer_with_content(content)
		end)
	else
		-- No template specified, check if templates exist and prompt user
		cli.list_issue_templates(repo, function(success, templates, _error)
			if not success or not templates or #templates == 0 then
				-- No templates, create empty buffer
				create_buffer_with_content("")
				return
			end

			-- Show template selection
			local template_names = {}
			for _, tmpl in ipairs(templates) do
				table.insert(template_names, tmpl.name)
			end
			table.insert(template_names, 1, "Empty (no template)")

			vim.ui.select(template_names, {
				prompt = "Select issue template:",
			}, function(choice)
				if not choice or choice == "Empty (no template)" then
					create_buffer_with_content("")
					return
				end

				-- Find selected template
				local selected_template = nil
				for _, tmpl in ipairs(templates) do
					if tmpl.name == choice then
						selected_template = tmpl
						break
					end
				end

				if selected_template then
					cli.get_issue_template(repo, selected_template.path, function(tmpl_success, content, tmpl_error)
						if not tmpl_success then
							vim.notify(
								"Failed to fetch template: " .. (tmpl_error or "unknown error"),
								vim.log.levels.WARN
							)
							create_buffer_with_content("")
							return
						end
						create_buffer_with_content(content)
					end)
				else
					create_buffer_with_content("")
				end
			end)
		end)
	end
end

--- Get cached or fetch assignee completions
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(assignees: string[])
function M.get_assignee_completions(repo, callback)
	local cache_key = string.format("assignees_%s", repo and repo:gsub("/", "_") or "current")

	cache.get_or_fetch(
		cache_key,
		function(cb)
			-- Add "@me" as first option
			local assignees = { "@me" }

			cli.list_contributors(repo, function(success, contributors, _error)
				if success and contributors then
					-- Limit to 10 contributors
					for i = 1, math.min(10, #contributors) do
						table.insert(assignees, contributors[i].login)
					end
				end
				cb(assignees)
			end)
		end,
		3600, -- 1 hour TTL
		callback
	)
end

--- Get cached or fetch label completions
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(labels: string[])
function M.get_label_completions(repo, callback)
	local cache_key = string.format("labels_%s", repo and repo:gsub("/", "_") or "current")

	cache.get_or_fetch(
		cache_key,
		function(cb)
			cli.list_labels(repo, function(success, labels, _error)
				if not success or not labels then
					cb({})
					return
				end

				local label_names = {}
				for _, label in ipairs(labels) do
					table.insert(label_names, label.name)
				end
				cb(label_names)
			end)
		end,
		3600, -- 1 hour TTL
		callback
	)
end

--- Get cached or fetch milestone completions
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(milestones: string[])
function M.get_milestone_completions(repo, callback)
	local cache_key = string.format("milestones_%s", repo and repo:gsub("/", "_") or "current")

	cache.get_or_fetch(
		cache_key,
		function(cb)
			cli.list_milestones(repo, function(success, milestones, _error)
				if not success or not milestones then
					cb({})
					return
				end

				local milestone_titles = {}
				for _, milestone in ipairs(milestones) do
					table.insert(milestone_titles, milestone.title)
				end
				cb(milestone_titles)
			end)
		end,
		3600, -- 1 hour TTL
		callback
	)
end

--- Get cached or fetch project completions
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(projects: string[])
function M.get_project_completions(repo, callback)
	local cache_key = string.format("projects_%s", repo and repo:gsub("/", "_") or "current")

	cache.get_or_fetch(
		cache_key,
		function(cb)
			cli.list_projects(repo, function(success, projects, _error)
				if not success or not projects then
					cb({})
					return
				end

				local project_titles = {}
				for _, project in ipairs(projects) do
					if project.title then
						table.insert(project_titles, project.title)
					end
				end
				cb(project_titles)
			end)
		end,
		3600, -- 1 hour TTL
		callback
	)
end

--- Get cached or fetch template completions
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(templates: string[])
function M.get_template_completions(repo, callback)
	local cache_key = string.format("templates_%s", repo and repo:gsub("/", "_") or "current")

	cache.get_or_fetch(
		cache_key,
		function(cb)
			cli.list_issue_templates(repo, function(success, templates, _error)
				if not success or not templates then
					cb({})
					return
				end

				local template_names = {}
				for _, template in ipairs(templates) do
					table.insert(template_names, template.name)
				end
				cb(template_names)
			end)
		end,
		3600, -- 1 hour TTL
		callback
	)
end

return M
