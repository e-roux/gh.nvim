--- Issues module
--- Mirrors gh issue commands
local M = {}

-- Load submodules (mirrors gh issue commands)
local list = require("gh.issues.list") -- gh issue list
local view = require("gh.issues.view") -- gh issue view
local create = require("gh.issues.create") -- gh issue create
local delete = require("gh.issues.delete") -- gh issue delete
local close = require("gh.issues.close") -- gh issue close/reopen

-- Export list functions (gh issue list)
M.open_issue_list = list.open_issue_list

-- Export view functions (gh issue view)
M.open_issue_detail = view.open_issue_detail

-- Export create functions (gh issue create)
M.create_issue_buffer = create.create_issue_buffer
M.get_assignee_completions = create.get_assignee_completions
M.get_label_completions = create.get_label_completions
M.get_milestone_completions = create.get_milestone_completions
M.get_project_completions = create.get_project_completions
M.get_template_completions = create.get_template_completions

-- Export delete functions (gh issue delete)
M.delete_issue_at_cursor = delete.delete_issue_at_cursor

-- Export close/reopen functions
M.close_issue = close.close_issue
M.reopen_issue = close.reopen_issue
M.get_issue_completions = close.get_issue_completions

-- Setup autocmds
M.setup_autocmds = list.setup_autocmds

-- Export for testing
M._test_parse_issue_list_changes = list._test_parse_issue_list_changes

return M
