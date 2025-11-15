-- TODO: See GitHub issues #25 and #22 — quickfix parsing / gh integration. Add tests and harden gh output handling.

-- Check for plenary dependency
local ok, Job = pcall(require, "plenary.job")
if not ok then
  vim.notify("gh.nvim: Plenary not found", vim.log.levels.WARN)
  return
end

-- Load gh module
local gh_module_ok, gh = pcall(require, "gh")
if not gh_module_ok then
  vim.notify("gh.nvim: Failed to load gh module: " .. tostring(gh), vim.log.levels.ERROR)
  return
end

local GH = "gh"

--- Run the gh command asynchronously and populate the quickfix list
--- @param opts table
local function gh_command(opts)
  Job:new({
    command = GH,
    args = opts.fargs,
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        vim.schedule(function()
          vim.notify("gh command failed", vim.log.levels.ERROR)
        end)
        return
      end
      local result = table.concat(j:result(), "\n")
      local items = gh.toqflist(result)
      vim.schedule(function()
        vim.fn.setqflist({}, " ", { title = "gh", items = items })
        if #items > 0 then
          print(#items .. " items found!")
        else
          print("No items found.")
        end
      end)
    end,
  }):start()
end

vim.api.nvim_create_user_command("Gh", gh_command, { nargs = "*", bang = true })
