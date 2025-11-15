--- Minimal init for testing
-- Add plugin to runtime path
vim.opt.rtp:append(".")

-- Add plenary to runtime path
vim.opt.rtp:append("test/runtime/plenary.nvim")

-- Load plenary
vim.cmd("runtime! plugin/plenary.vim")
