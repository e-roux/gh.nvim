--- Frontmatter parsing utilities for GitHub issue templates
local M = {}

--- Parse YAML frontmatter from markdown content
---@param content string Markdown content with optional frontmatter
---@return table|nil frontmatter Parsed frontmatter or nil if none found
---@return string body Content without frontmatter
function M.parse(content)
	-- Check if content starts with ---
	if not content:match("^%-%-%-\n") then
		return nil, content
	end

	-- Find the closing ---
	local frontmatter_end = content:find("\n%-%-%-\n", 4)
	if not frontmatter_end then
		-- Invalid frontmatter, return as-is
		return nil, content
	end

	-- Extract frontmatter and body
	local frontmatter_text = content:sub(5, frontmatter_end - 1)
	local body = content:sub(frontmatter_end + 5)

	-- Parse YAML frontmatter (simple key: value parser)
	local frontmatter = M.parse_yaml(frontmatter_text)

	return frontmatter, body
end

--- Simple YAML parser for frontmatter (supports basic key: value pairs)
---@param yaml_text string YAML text
---@return table Parsed YAML as table
function M.parse_yaml(yaml_text)
	local result = {}

	for line in yaml_text:gmatch("[^\r\n]+") do
		-- Skip empty lines and comments
		if line:match("%S") and not line:match("^%s*#") then
			-- Match key: value pattern
			local key, value = line:match("^([%w_]+):%s*(.*)$")
			if key and value then
				-- Trim whitespace
				key = key:match("^%s*(.-)%s*$")
				value = value:match("^%s*(.-)%s*$")

				-- Remove outer double quotes only (preserve single quotes as they may be part of the value)
				if value:match('^".*"$') then
					value = value:sub(2, -2)
				end

				-- Handle empty values
				if value == "" or value == "''" or value == '""' then
					value = nil
				end

				result[key] = value
			end
		end
	end

	return result
end

--- Validate frontmatter fields
---@param frontmatter table Frontmatter to validate
---@return boolean valid Whether frontmatter is valid
---@return string|nil error Error message if invalid
function M.validate(frontmatter)
	if not frontmatter then
		return true, nil
	end

	-- Check for valid field names
	local valid_fields = {
		name = true,
		about = true,
		title = true,
		labels = true,
		assignees = true,
		projects = true,
		milestone = true,
	}

	for key, _ in pairs(frontmatter) do
		if not valid_fields[key] then
			return false, "Invalid frontmatter field: " .. key
		end
	end

	return true, nil
end

--- Extract metadata from frontmatter for issue creation
---@param frontmatter table|nil Parsed frontmatter
---@return table metadata Metadata for issue creation { title: string, labels: string[], assignees: string[] }
function M.extract_metadata(frontmatter)
	local metadata = {
		title = nil,
		labels = {},
		assignees = {},
	}

	if not frontmatter then
		return metadata
	end

	-- Extract title prefix and remove surrounding single quotes if present
	if frontmatter.title then
		local title = frontmatter.title
		-- Remove single quotes if they wrap the entire value
		if title:match("^'.*'$") then
			title = title:sub(2, -2)
		end
		metadata.title = title
	end

	-- Extract labels (comma-separated or single value)
	if frontmatter.labels then
		if type(frontmatter.labels) == "string" then
			-- Split by comma
			for label in frontmatter.labels:gmatch("[^,]+") do
				label = label:match("^%s*(.-)%s*$") -- trim
				if label ~= "" then
					table.insert(metadata.labels, label)
				end
			end
		end
	end

	-- Extract assignees (comma-separated or single value)
	if frontmatter.assignees then
		if type(frontmatter.assignees) == "string" and frontmatter.assignees ~= "" then
			-- Split by comma
			for assignee in frontmatter.assignees:gmatch("[^,]+") do
				assignee = assignee:match("^%s*(.-)%s*$") -- trim
				if assignee ~= "" then
					table.insert(metadata.assignees, assignee)
				end
			end
		end
	end

	return metadata
end

--- Apply frontmatter metadata to buffer
---@param bufnr integer Buffer number
---@param metadata table Metadata from frontmatter
function M.apply_to_buffer(bufnr, metadata)
	-- Store metadata in buffer variable for later use when creating issue
	vim.api.nvim_buf_set_var(bufnr, "gh_issue_metadata", metadata)

	-- If title prefix exists, add it to the first line if buffer is empty or has placeholder
	if metadata.title then
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
		if #lines == 0 or lines[1] == "" or lines[1]:match("^#%s*$") then
			-- Set title prefix
			vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "# " .. metadata.title })
		end
	end
end

--- Get metadata from buffer variable
---@param bufnr integer Buffer number
---@return table|nil metadata Stored metadata or nil
function M.get_buffer_metadata(bufnr)
	local ok, metadata = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issue_metadata")
	if ok then
		return metadata
	end
	return nil
end

return M
