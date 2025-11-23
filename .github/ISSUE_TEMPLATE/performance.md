---
name: Performance Issue
about: Report slow performance or resource usage problems
title: '[Performance] '
labels: performance
assignees: ''
---

## Performance Issue

Describe the performance problem you're experiencing.

## Symptoms

- [ ] Slow command execution
- [ ] High CPU usage
- [ ] High memory usage
- [ ] UI lag/freezing
- [ ] Slow buffer loading
- [ ] Other: _____

## Reproduction

### Steps to Reproduce

1. Open Neovim
2. Run command '...'
3. Observe slowness

### Timing Information

If possible, provide timing information:

```vim
" Use :profile to measure
:profile start profile.log
:profile func *
:profile file *
" Run the slow operation
:Gh issue list
:profile pause
:noautocmd qall!
```

Attach the profile.log or paste relevant sections.

## Expected Performance

What performance did you expect?

Example: "Command should complete in < 1 second"

## Actual Performance

What performance are you seeing?

Example: "Command takes 10+ seconds"

## Environment

- **Neovim version**: (output of `nvim --version`)
- **gh.nvim version**: (commit hash or tag)
- **Repository size**: (number of issues, PRs, etc.)
- **Network speed**: (if relevant)
- **Operating System**: 

## Configuration

```lua
-- Your gh.nvim configuration
vim.g.gh_opts = {
  -- paste your config here
}
```

## Additional Context

- Does this happen with all repositories or specific ones?
- Does it happen consistently or intermittently?
- Any other plugins that might be interfering?
