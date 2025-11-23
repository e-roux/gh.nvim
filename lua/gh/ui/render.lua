--- Rendering utilities for GitHub issue/PR metadata
--- Implements Snacks.nvim-style virtual text rendering for metadata
local M = {}

--- Namespace for virtual text
local ns = vim.api.nvim_create_namespace("gh_render")

--- Helper to create colored badge segments with rounded corners
---@param text string Badge text
---@param hl string|{bg: string, fg: string} Highlight group or color spec
---@return table[] Array of highlight segments
local function badge(text, hl)
	local bg, fg
	if type(hl) == "table" then
		bg = hl.bg
		fg = hl.fg
	else
		bg = hl
		fg = nil
	end

	-- Rounded separators (powerline characters)
	local left_sep, right_sep = "", ""

	if type(hl) == "table" and hl.bg and hl.fg then
		-- For custom colors, we need to create temporary highlight groups
		local hl_name = "GhBadge_" .. text:gsub("%W", "_")
		local hl_inv = hl_name .. "Inv"
		vim.api.nvim_set_hl(0, hl_name, { bg = bg, fg = fg })
		vim.api.nvim_set_hl(0, hl_inv, { fg = bg })

		return {
			{ left_sep, hl_inv },
			{ text, hl_name },
			{ right_sep, hl_inv },
		}
	else
		-- Use existing highlight group
		-- Get the background color from the highlight group
		local hl_id = vim.fn.hlID(bg)
		local bg_color = vim.fn.synIDattr(vim.fn.synIDtrans(hl_id), "bg#")
		local fg_color = vim.fn.synIDattr(vim.fn.synIDtrans(hl_id), "fg#")

		if bg_color == "" then
			bg_color = nil
		end
		if fg_color == "" then
			fg_color = nil
		end

		-- Create highlight groups for this badge
		local hl_name = "GhBadge_" .. bg
		local hl_inv = hl_name .. "Inv"

		vim.api.nvim_set_hl(0, hl_name, { bg = bg_color, fg = fg_color })
		if bg_color then
			vim.api.nvim_set_hl(0, hl_inv, { fg = bg_color })
		end

		return {
			{ left_sep, bg_color and hl_inv or "Normal" },
			{ text, hl_name },
			{ right_sep, bg_color and hl_inv or "Normal" },
		}
	end
end

--- Convert hex color to RGB
---@param hex string Hex color like "#ff0000"
---@return number, number, number RGB values
local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

--- Calculate perceived brightness of a color
---@param hex string Hex color like "#ff0000"
---@return number Brightness value 0-255
local function get_brightness(hex)
	local r, g, b = hex_to_rgb(hex)
	-- Using the perceived brightness formula
	return (r * 299 + g * 587 + b * 114) / 1000
end

--- Get appropriate text color (black or white) for a background color
---@param bg_hex string Background color hex
---@return string Foreground color hex
local function get_contrast_color(bg_hex)
	local brightness = get_brightness(bg_hex)
	return brightness > 128 and "#000000" or "#ffffff"
end

--- Format relative time (similar to Snacks.nvim)
---@param iso_time string ISO 8601 timestamp
---@return string Relative time string
local function reltime(iso_time)
	if not iso_time then
		return ""
	end

	-- Parse ISO 8601 timestamp: 2024-01-15T10:30:00Z
	local year, month, day, hour, min, sec = iso_time:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not year then
		-- Fallback: just show the date
		return iso_time:match("^%d%d%d%d%-%d%d%-%d%d") or iso_time
	end

	local time_parts = { year = year, month = month, day = day, hour = hour, min = min, sec = sec }
	local timestamp = os.time(time_parts)
	local now = os.time()
	local diff = now - timestamp

	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		local minutes = math.floor(diff / 60)
		return minutes .. "m ago"
	elseif diff < 86400 then
		local hours = math.floor(diff / 3600)
		return hours .. "h ago"
	elseif diff < 604800 then
		local days = math.floor(diff / 86400)
		return days .. "d ago"
	elseif diff < 2592000 then
		local weeks = math.floor(diff / 604800)
		return weeks .. "w ago"
	elseif diff < 31536000 then
		local months = math.floor(diff / 2592000)
		return months .. "mo ago"
	else
		local years = math.floor(diff / 31536000)
		return years .. "y ago"
	end
end

--- Property definitions for metadata rendering
---@param item table Issue or PR data
---@return table[] Array of {name: string, segments: table[]}
local function get_properties(item)
	local props = {}

	-- Status
	if item.state then
		local state_upper = item.state:upper()
		local icon = state_upper == "OPEN" and "●" or state_upper == "CLOSED" and "✓" or "○"
		local hl_group = state_upper == "OPEN" and "DiagnosticInfo" or "DiagnosticHint"

		local segments = {}
		vim.list_extend(segments, badge(icon .. " " .. state_upper, hl_group))

		table.insert(props, {
			name = "Status",
			segments = segments,
		})
	end

	-- Author
	if item.author and item.author.login then
		local segments = {}
		vim.list_extend(segments, badge("  " .. item.author.login, "Identifier"))

		table.insert(props, {
			name = "Author",
			segments = segments,
		})
	end

	-- Created
	if item.createdAt then
		table.insert(props, {
			name = "Created",
			segments = { { reltime(item.createdAt), "Comment" } },
		})
	end

	-- Updated
	if item.updatedAt then
		table.insert(props, {
			name = "Updated",
			segments = { { reltime(item.updatedAt), "Comment" } },
		})
	end

	-- Closed
	if item.closedAt then
		table.insert(props, {
			name = "Closed",
			segments = { { reltime(item.closedAt), "Comment" } },
		})
	end

	-- Labels
	if item.labels and #item.labels > 0 then
		local segments = {}
		for _, label in ipairs(item.labels) do
			local color = "#" .. (label.color or "888888")
			local fg = get_contrast_color(color)
			vim.list_extend(segments, badge(label.name, { bg = color, fg = fg }))
			-- Add space between badges
			table.insert(segments, { " ", "Normal" })
		end

		table.insert(props, {
			name = "Labels",
			segments = segments,
		})
	end

	-- Assignees
	if item.assignees and #item.assignees > 0 then
		local segments = {}
		for _, assignee in ipairs(item.assignees) do
			vim.list_extend(segments, badge(assignee.login, "Special"))
			-- Add space between badges
			table.insert(segments, { " ", "Normal" })
		end

		table.insert(props, {
			name = "Assignees",
			segments = segments,
		})
	end

	-- Milestone
	if item.milestone and item.milestone.title then
		local segments = {}
		vim.list_extend(segments, badge(item.milestone.title, "Title"))

		table.insert(props, {
			name = "Milestone",
			segments = segments,
		})
	end

	-- URL
	if item.url then
		table.insert(props, {
			name = "URL",
			segments = { { item.url, "Underlined" } },
		})
	end

	return props
end

--- Render metadata as virtual text lines
---@param bufnr integer Buffer number
---@param item table Issue or PR data
function M.render_metadata(bufnr, item)
	-- Clear existing virtual text
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	-- Define bold highlight group for labels
	-- Get the Comment highlight colors and make them bold
	local comment_fg = vim.fn.synIDattr(vim.fn.hlID("Comment"), "fg")
	local comment_bg = vim.fn.synIDattr(vim.fn.hlID("Comment"), "bg")
	vim.api.nvim_set_hl(0, "GhMetadataLabel", {
		fg = comment_fg ~= "" and comment_fg or nil,
		bg = comment_bg ~= "" and comment_bg or nil,
		bold = true,
		default = true,
	})

	local props = get_properties(item)

	if #props == 0 then
		return
	end

	local virt_lines = {}

	-- Build virtual text lines for each property
	for _, prop in ipairs(props) do
		local line = {}

		-- Add label with bold font
		table.insert(line, { prop.name, "GhMetadataLabel" })
		table.insert(line, { ": ", "GhMetadataLabel" })

		-- Add value segments
		for _, segment in ipairs(prop.segments) do
			table.insert(line, segment)
		end

		table.insert(virt_lines, line)
	end

	-- Add blank line for spacing
	table.insert(virt_lines, { { " ", "Normal" } })

	-- Add virtual text after line 1 (the title line)
	vim.api.nvim_buf_set_extmark(bufnr, ns, 1, 0, {
		virt_lines = virt_lines,
		virt_lines_above = false,
	})
end

--- Clear metadata rendering
---@param bufnr integer Buffer number
function M.clear_metadata(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

return M
