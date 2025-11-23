--- GitHub CLI wrapper module
local M = {}

--- Run gh command asynchronously
---@param args string[] Command arguments
---@param callback fun(success: boolean, result: string|nil, error: string|nil)
function M.run(args, callback)
	local Job = require("plenary.job")

	Job:new({
		command = "gh",
		args = args,
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val ~= 0 then
					local error_msg = table.concat(j:stderr_result(), "\n")
					callback(false, nil, error_msg)
				else
					local result = table.concat(j:result(), "\n")
					callback(true, result, nil)
				end
			end)
		end,
	}):start()
end

--- List issues for a repository
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param opts table|nil Options: { limit: number, state: string, assignee: string, author: string, label: string[],
---  mention: string, milestone: string, search: string }
---@param callback fun(success: boolean, issues: table[]|nil, error: string|nil)
function M.list_issues(repo, opts, callback)
	-- Handle old signature: list_issues(repo, callback)
	if type(opts) == "function" then
		callback = opts
		opts = {}
	end

	opts = opts or {}
	local limit = opts.limit or 30
	local state = opts.state or "open"

	local args = {
		"issue",
		"list",
		"--json",
		"number,title,state,labels,assignees,author,createdAt,updatedAt",
		"--limit",
		tostring(limit),
		"--state",
		state,
	}

	-- Add optional filters
	if opts.assignee then
		table.insert(args, "--assignee")
		table.insert(args, opts.assignee)
	end

	if opts.author then
		table.insert(args, "--author")
		table.insert(args, opts.author)
	end

	if opts.label then
		-- Labels can be a string or array of strings
		local labels = type(opts.label) == "table" and opts.label or { opts.label }
		for _, label in ipairs(labels) do
			table.insert(args, "--label")
			table.insert(args, label)
		end
	end

	if opts.mention then
		table.insert(args, "--mention")
		table.insert(args, opts.mention)
	end

	if opts.milestone then
		table.insert(args, "--milestone")
		table.insert(args, opts.milestone)
	end

	if opts.search then
		table.insert(args, "--search")
		table.insert(args, opts.search)
	end

	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		local ok, issues = pcall(vim.json.decode, result)
		if not ok then
			callback(false, nil, "Failed to parse JSON response")
			return
		end

		callback(true, issues, nil)
	end)
end

--- Get issue details
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, issue: table|nil, error: string|nil)
function M.get_issue(number, repo, callback)
	local args = {
		"issue",
		"view",
		tostring(number),
		"--json",
		"number,title,body,state,labels,assignees,author,createdAt,updatedAt,url",
	}
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		local ok, issue = pcall(vim.json.decode, result)
		if not ok then
			callback(false, nil, "Failed to parse JSON response")
			return
		end

		callback(true, issue, nil)
	end)
end

--- Update issue title
---@param number integer Issue number
---@param title string New title
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, error: string|nil)
function M.update_title(number, title, repo, callback)
	local args = { "issue", "edit", tostring(number), "--title", title }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, _, error)
		callback(success, error)
	end)
end

--- Update issue body
---@param number integer Issue number
---@param body string New body
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, error: string|nil)
function M.update_body(number, body, repo, callback)
	local args = { "issue", "edit", tostring(number), "--body", body }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, _, error)
		callback(success, error)
	end)
end

--- Get repository labels
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, labels: table[]|nil, error: string|nil)
function M.list_labels(repo, callback)
	local args = { "label", "list", "--json", "name,description", "--limit", "1000" }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		local ok, labels = pcall(vim.json.decode, result)
		if not ok then
			callback(false, nil, "Failed to parse JSON response")
			return
		end

		callback(true, labels, nil)
	end)
end

--- Get repository milestones
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, milestones: table[]|nil, error: string|nil)
function M.list_milestones(repo, callback)
	local args = { "api", "repos/{owner}/{repo}/milestones", "--jq", ".[].title" }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		-- Parse line-separated milestone titles
		local milestones = {}
		for line in result:gmatch("[^\r\n]+") do
			if line ~= "" then
				table.insert(milestones, { title = line })
			end
		end

		callback(true, milestones, nil)
	end)
end

--- Get repository projects
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, projects: table[]|nil, error: string|nil)
function M.list_projects(repo, callback)
	-- Note: Projects v2 uses a different API structure
	local args = { "project", "list", "--owner", "{owner}", "--format", "json" }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		local ok, projects = pcall(vim.json.decode, result)
		if not ok then
			callback(false, nil, "Failed to parse JSON response")
			return
		end

		callback(true, projects.projects or {}, nil)
	end)
end

--- Get repository contributors (for assignee autocomplete)
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, contributors: table[]|nil, error: string|nil)
function M.list_contributors(repo, callback)
	local args = { "api", "repos/{owner}/{repo}/contributors", "--jq", ".[].login", "--paginate" }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		-- Parse line-separated usernames
		local contributors = {}
		for line in result:gmatch("[^\r\n]+") do
			if line ~= "" then
				table.insert(contributors, { login = line })
			end
		end

		callback(true, contributors, nil)
	end)
end

--- Get issue templates from repository
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, templates: table[]|nil, error: string|nil)
function M.list_issue_templates(repo, callback)
	-- Helper function to check local templates
	local function check_local_templates()
		local template_dir = vim.fn.getcwd() .. "/.github/ISSUE_TEMPLATE"
		local templates = {}

		-- Check if directory exists
		if vim.fn.isdirectory(template_dir) == 1 then
			local files = vim.fn.glob(template_dir .. "/*.md", false, true)
			for _, file in ipairs(files) do
				local name = vim.fn.fnamemodify(file, ":t")
				local path = ".github/ISSUE_TEMPLATE/" .. name
				table.insert(templates, { name = name, path = path })
			end
		end

		return templates
	end

	-- Try to list templates from .github/ISSUE_TEMPLATE/
	local args = {
		"api",
		"repos/{owner}/{repo}/contents/.github/ISSUE_TEMPLATE",
		"--jq",
		'.[] | select(.type == "file") | {name: .name, path: .path}',
	}
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, _error)
		if not success then
			-- Try fallback to org .github repo
			if repo then
				local owner = repo:match("^([^/]+)/")
				if owner then
					M.list_issue_templates(owner .. "/.github", callback)
					return
				end
			end

			-- API failed, try local templates as fallback
			local local_templates = check_local_templates()
			if #local_templates > 0 then
				callback(true, local_templates, nil)
				return
			end

			callback(true, {}, nil) -- No templates found
			return
		end

		local templates = {}
		-- Parse JSON objects line by line
		for line in result:gmatch("[^\r\n]+") do
			if line ~= "" then
				local ok, template = pcall(vim.json.decode, line)
				if ok and template.name then
					table.insert(templates, template)
				end
			end
		end

		callback(true, templates, nil)
	end)
end

--- Get issue template content
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param template_path string Path to template file
---@param callback fun(success: boolean, content: string|nil, error: string|nil)
function M.get_issue_template(repo, template_path, callback)
	-- Helper function to read local template
	local function read_local_template()
		local local_path = vim.fn.getcwd() .. "/" .. template_path
		if vim.fn.filereadable(local_path) == 1 then
			local content = table.concat(vim.fn.readfile(local_path), "\n")
			return content
		end
		return nil
	end

	local args = { "api", "repos/{owner}/{repo}/contents/" .. template_path, "--jq", ".content" }
	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			-- Try local file as fallback
			local local_content = read_local_template()
			if local_content then
				callback(true, local_content, nil)
				return
			end

			callback(false, nil, error)
			return
		end

		-- Decode base64 content
		local content = vim.base64.decode(result:gsub("%s+", ""))
		callback(true, content, nil)
	end)
end

--- Create a new issue
---@param opts table Options: { title: string, body: string, assignees: string[], labels: string[],
---  milestone: string, project: string, repo: string|nil }
---@param callback fun(success: boolean, issue: table|nil, error: string|nil)
function M.create_issue(opts, callback)
	local args = { "issue", "create", "--title", opts.title }

	if opts.body then
		table.insert(args, "--body")
		table.insert(args, opts.body)
	end

	if opts.assignees and #opts.assignees > 0 then
		for _, assignee in ipairs(opts.assignees) do
			table.insert(args, "--assignee")
			table.insert(args, assignee)
		end
	end

	if opts.labels and #opts.labels > 0 then
		for _, label in ipairs(opts.labels) do
			table.insert(args, "--label")
			table.insert(args, label)
		end
	end

	if opts.milestone then
		table.insert(args, "--milestone")
		table.insert(args, opts.milestone)
	end

	if opts.project then
		table.insert(args, "--project")
		table.insert(args, opts.project)
	end

	if opts.repo then
		table.insert(args, "--repo")
		table.insert(args, opts.repo)
	end

	M.run(args, function(success, result, error)
		if not success then
			callback(false, nil, error)
			return
		end

		-- Parse the issue URL from output to get issue number
		local url = result:match("https://github.com/[^/]+/[^/]+/issues/(%d+)")
		if url then
			callback(true, { number = tonumber(url), url = result }, nil)
		else
			callback(true, { url = result }, nil)
		end
	end)
end

--- Delete an issue
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param issue_number number Issue number to delete
---@param callback fun(success: boolean, error: string|nil)
function M.delete_issue(repo, issue_number, callback)
	local args = { "issue", "delete", tostring(issue_number), "--yes" }

	if repo then
		table.insert(args, "--repo")
		table.insert(args, repo)
	end

	M.run(args, function(success, _result, error)
		if not success then
			callback(false, error)
			return
		end

		callback(true, nil)
	end)
end

return M
