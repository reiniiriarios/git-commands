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
- on macOS, installs [gnu-sed](https://formulae.brew.sh/formula/gnu-sed) if not found

## Help

The `gcmd` command provides a help interface for these shortcuts. Most functions also have a `-h`
flag available to display help.

Command|Description
---|---
`gcmd -f`|Display help for common functions.
`gcmd -l`|Display help for helper functions.
`gcmd -a`|Display help for aliases.
`gcmd -h <alias_name>`|Display help for an alias.
`<function_name> -h`|Display help for a function.

## Highlights

Alias|Function|Description
---|---|---
-|`git_find_parent_branch [-a] [branch_name]`|find parent of current or specified branch with regex filtering; `-a` to find without regex filtering
-|`git_find_branch <search_string>`|useful for finding by issue id
-|`git_commits_out_of_date [parent_branch] [branch_name]`|get number of commits current or specified branch is behind parent or specified parent
-|`git_branch_has_remote <branch_name>`|whether specified branch has remote (boolean)
`gswf`|`git_switch_branch_by_search <search_string>`|`switch` via search string, e.g. `gswf 1234` if branch name has issue number
`grf`|`git_rebase_forward`|rebase current branch to be up to date with parent
`grom`|`git_rebase_on_main`|rebase current branch to be up to date with main
`grob`|`git_rebase_on_branch <search_string>`|rebase current branch on branch found via `git_find_branch`
`grbn`|`git_rebase_n_commits <n>`|`rebase -i HEAD~$1` _n_ commits
`gsquash`|`git_squash <n>`|squash _n_ commits via `rebase -i`
`grn`|`git_reset <n>`|`reset --soft HEAD~$1` _n_ commits and then `reset` to unstage
`gbrebase`|`git_rebase_branch`|`rebase -i` all commits on the current branch
`gbsquash`|`git_squash_branch`|squash all commits on current branch via `rebase -i`
`gbreset`|`git_reset_branch`|soft reset all commits and unstage changes on current branch
`gbdel`|`git_delete_branch_by_search`|delete branch by search string, e.g. `gswf 1234` if branch name has issue number
`gremotereset`|`git_remote_reset`|reset branch to remote
`gbcount`|`git_branch_num_commits`|display number of commits on current branch
`gfp`|`git_force_push`|`push --force-with-lease` with branch protection
`gmff`|`git_merge_ff`|`merge --ff-only` with some error checking
`gmffthis`|`git_merge_ff_this`|checkout parent and then `merge --ff-only` current branch
`gwip`|-|commit all currently tracked files with message "WIP"
`gunwip`|-|reset and unstage last commit if message is "WIP"
`gbdd`|`git_drop_drop_commits`|drop all commits in current branch with messages beginning with `drop: `
`gmt <tag>`|`git_move_tag`|move tag to current commit both locally and on origin, pushing the current branch first
`gtp <tag>`|`git_push_tag`|push the current branch, then push the tag to origin

## Example Workflow Comparison

```sh
git switch main
git pull
git switch ABC-123-jira-made-a-branch-name-just-for-me
git rebase main
# Count commits in branch, or copy a commit revision
git rebase -i HEAD~10
# Change `pick` to `drop` for any temporary commits, then
# swap `pick` with `squash` on every commit after the first
# Rewrite commit message
git push --force-with-lease
# Wait for CI
git switch main
git merge --ff-only ABC-123-jira-made-a-branch-name-just-for-me
git push
```

vs

```sh
gswf 123
grom
gbsquash
# Rewrite commit message
gfp
# Wait for CI
gmffthis
gp
```
