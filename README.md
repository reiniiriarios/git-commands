# git-commands

Commonly used aliases, functions, etc. ✌🏻

[→ Jump to `git-commands.sh` source](https://github.com/reiniiriarios/git-commands/blob/main/git-commands.sh)

## Install

Clone repo and...

```sh
./install.sh
```

- adds symbolic link from `$HOME/.git-commands.sh` to `git-commands.sh`
- adds `[ -s "$HOME/.git-commands.sh" ] && . "$HOME/.git-commands.sh"` to `.bashrc` or `.zshrc`

## Highlights

Alias|Function|Description
---|---|---
-|`git_find_parent_branch [-a] [branch_name]`|find parent of current or specified branch with regex filtering<br>`-a` find without regex filtering
-|`git_find_branch <search_string>`|useful for finding by issue id
`gswf`|`git_switch_branch_by_search <search_string>`|`git switch` via search string
`gcof`|`git_checkout_branch_by_search <search_string>`|`git checkout` via search string
`grf`|`git_rebase_forward`|rebase current branch to be up to date with parent
`grom`|`git_rebase_on_main`|rebase current branch to be up to date with main
`grbranch`|`git_rebase_branch`|`git rebase -i` all commits on the current branch
`gsqbranch`|`git_squash_branch`|auto-squash all commits on current branch via `rebase -i`
`grsbranch`|`git_reset_branch`|soft reset all commits and unstage changes on current branch
`gbcount`|`git_branch_num_commits`|display number of commits on current branch
`gp`|`git_push_with_set_upstream`|`git push` but if branch has no upstream, it's set to current branch name

