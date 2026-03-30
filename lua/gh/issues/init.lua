--- Issues module
--- Mirrors gh issue commands
local M = {}

-- Lazy submodule accessors — each submodule is loaded only when first needed
local function get_list()
  return require("gh.issues.list")
end
local function get_view()
  return require("gh.issues.view")
end
local function get_create()
  return require("gh.issues.create")
end
local function get_delete()
  return require("gh.issues.delete")
end
local function get_close()
  return require("gh.issues.close")
end

-- List (gh issue list)
function M.open_issue_list(...)
  return get_list().open_issue_list(...)
end

-- View (gh issue view)
function M.open_issue_detail(...)
  return get_view().open_issue_detail(...)
end

-- Create (gh issue create)
function M.create_issue_buffer(...)
  return get_create().create_issue_buffer(...)
end
function M.get_assignee_completions(...)
  return get_create().get_assignee_completions(...)
end
function M.get_label_completions(...)
  return get_create().get_label_completions(...)
end
function M.get_milestone_completions(...)
  return get_create().get_milestone_completions(...)
end
function M.get_project_completions(...)
  return get_create().get_project_completions(...)
end
function M.get_template_completions(...)
  return get_create().get_template_completions(...)
end

-- Delete (gh issue delete)
function M.delete_issue_at_cursor(...)
  return get_delete().delete_issue_at_cursor(...)
end

-- Close / reopen (gh issue close / reopen)
function M.close_issue(...)
  return get_close().close_issue(...)
end
function M.reopen_issue(...)
  return get_close().reopen_issue(...)
end
function M.get_issue_completions(...)
  return get_close().get_issue_completions(...)
end

-- Setup autocmds (called from gh.setup())
function M.setup_autocmds()
  get_list().setup_autocmds()
end

-- Export for testing
function M._test_parse_issue_list_changes(...)
  return get_list()._test_parse_issue_list_changes(...)
end

return M
