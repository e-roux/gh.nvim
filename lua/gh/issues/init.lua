--- Issues module
--- Handles issue listing, viewing, and creation
local M = {}

-- Load submodules
local list = require("gh.issues.list")
local create = require("gh.issues.create")

-- Export list functions
M.open_issue_list = list.open_issue_list
M.open_issue_detail = list.open_issue_detail
M.setup_autocmds = list.setup_autocmds

-- Export create functions
M.create_issue_buffer = create.create_issue_buffer
M.get_assignee_completions = create.get_assignee_completions
M.get_label_completions = create.get_label_completions
M.get_milestone_completions = create.get_milestone_completions
M.get_project_completions = create.get_project_completions
M.get_template_completions = create.get_template_completions

-- Export for testing
M._test_parse_issue_list_changes = list._test_parse_issue_list_changes

return M
