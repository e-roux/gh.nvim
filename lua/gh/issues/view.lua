--- Issue view module (gh issue view)
local M = {}

local buffer = require("gh.ui.buffer")
local cli = require("gh.cli")

--- Format issue detail for display
---@param issue table Issue data
---@return string[] Formatted lines
local function format_issue_detail(issue)
  local lines = {}

  -- Title
  table.insert(lines, "# " .. issue.title)
  table.insert(lines, "")

  -- Body
  if issue.body and issue.body ~= "" then
    for line in (issue.body .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "_No description provided._")
  end

  return lines
end

--- Parse issue detail from buffer lines
---@param lines string[] Buffer lines
---@return table Parsed issue { title: string, body: string }
local function parse_issue_detail(lines)
  local title = ""
  local body_lines = {}
  local in_body = false

  for _, line in ipairs(lines) do
    if line:match("^#%s+") and not in_body then
      -- Title line
      title = line:gsub("^#%s+", "")
    elseif line == "" and title ~= "" and not in_body then
      -- Empty line after title marks start of body
      in_body = true
    elseif in_body then
      table.insert(body_lines, line)
    end
  end

  return {
    title = title,
    body = table.concat(body_lines, "\n"),
  }
end

--- Add virtual text metadata to issue buffer
---@param bufnr integer Buffer number
local function add_issue_metadata_virtual_text(bufnr)
  local ok, issue = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_original_issue")
  if not ok or not issue then
    return
  end

  -- Use the render module which now uses components
  local render = require("gh.ui.render")
  render.render_metadata(bufnr, issue)
end

--- Open issue detail buffer for viewing/editing (gh issue view)
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo) or nil for current repo
function M.open_issue_detail(number, repo)
  cli.get_issue(number, repo, function(success, issue, error)
    if not success then
      vim.notify("Failed to fetch issue: " .. (error or "unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Create buffer
    local buf_name = repo and string.format("gh://issue/%s/%d", repo, number)
      or string.format("gh://issue/%d", number)
    local bufnr = buffer.create_scratch(buf_name)

    -- Format and display issue
    local lines = format_issue_detail(issue)
    buffer.set_lines(bufnr, lines)

    -- Store original issue
    vim.api.nvim_buf_set_var(bufnr, "gh_issue_number", number)
    vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
    vim.api.nvim_buf_set_var(bufnr, "gh_original_issue", issue)

    -- Add virtual text metadata
    add_issue_metadata_virtual_text(bufnr)

    -- Set up write handler
    buffer.on_write(bufnr, function(buf)
      local current_lines = buffer.get_lines(buf)
      local parsed = parse_issue_detail(current_lines)
      local issue_number = vim.api.nvim_buf_get_var(buf, "gh_issue_number")
      local target_repo = vim.api.nvim_buf_get_var(buf, "gh_repo")
      local original = vim.api.nvim_buf_get_var(buf, "gh_original_issue")

      if target_repo == "" then
        target_repo = nil
      end

      local pending = 0
      local errors = {}

      -- Update title if changed
      if parsed.title ~= original.title then
        pending = pending + 1
        cli.update_title(issue_number, parsed.title, target_repo, function(title_success, err)
          pending = pending - 1
          if not title_success then
            table.insert(errors, "title: " .. (err or "unknown"))
          end
        end)
      end

      -- Update body if changed
      if parsed.body ~= original.body then
        pending = pending + 1
        cli.update_body(issue_number, parsed.body, target_repo, function(body_success, err)
          pending = pending - 1
          if not body_success then
            table.insert(errors, "body: " .. (err or "unknown"))
          end
        end)
      end

      if pending == 0 then
        vim.notify("No changes detected", vim.log.levels.INFO)
        return true
      end

      -- Wait for operations to complete
      vim.wait(5000, function()
        return pending == 0
      end)

      if #errors > 0 then
        vim.notify("Errors saving changes:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
        return false
      end

      return true
    end)

    -- Set up keymaps
    buffer.set_keymaps(bufnr, {
      ["q"] = {
        callback = function()
          vim.cmd("close")
        end,
        desc = "Close issue detail",
      },
      ["gx"] = {
        callback = function()
          local ok, iss = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_original_issue")
          if ok and iss and iss.url then
            vim.ui.open(iss.url)
          end
        end,
        desc = "Open issue in browser",
      },
    })

    -- Open in split with config options
    local config = require("gh.config")
    buffer.open_smart(bufnr, {
      reuse_window = config.opts.issue_detail.reuse_window,
      split_direction = config.opts.issue_detail.split_direction,
    })

    -- Set filetype
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  end)
end

return M
