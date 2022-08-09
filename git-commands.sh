#!/bin/bash

function git_cmd_err() {
  echo "\033[31merror: $@\033[0m"
}

# merge fast forward only
alias gmff="git merge --ff-only"

# reset current branch to remote origin
alias remotereset='git fetch origin $(git rev-parse --abbrev-ref HEAD) && git reset --hard "origin/$(git rev-parse --abbrev-ref HEAD)"'

# these come from oh-my-zsh
if [ -z "$ZSH" ]; then

  # rename branch
  function grename() {
    if [[ -z "$1" || -z "$2" ]]; then
      git_cmd_err "usage: $0 old_branch new_branch"
      return 1
    fi

    # Rename branch locally
    git branch -m "$1" "$2"
    # Rename branch in origin remote
    if git push origin :"$1"; then
      git push --set-upstream origin "$2"
    fi
  }

  # get name of main branch
  function git_main_branch() {
    command git rev-parse --git-dir &>/dev/null || return
    local ref
    for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk}; do
      if command git show-ref -q --verify $ref; then
        echo ${ref:t}
        return
      fi
    done
    echo master
  }

  # get name of dev branch
  function git_develop_branch() {
    command git rev-parse --git-dir &>/dev/null || return
    local branch
    for branch in dev devel development; do
      if command git show-ref -q --verify refs/heads/$branch; then
        echo $branch
        return
      fi
    done
    echo develop
  }

fi

# number of commits ahead from remote
function git_commits_ahead() {
  if git rev-parse --git-dir &>/dev/null; then
    local commits="$(git rev-list --count @{upstream}..HEAD 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      return $commits
    fi
  fi
}

# number of commits behind remote
function git_commits_behind() {
  if git rev-parse --git-dir &>/dev/null; then
    local commits="$(git rev-list --count HEAD..@{upstream} 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      return $commits
    fi
  fi
}

# find parent branch
function gitparent() {
  git show-branch \
    | sed "s/[^a-zA-Z0-9_\-]*].*//" \
    | grep "\*" \
    | grep -v "$(git rev-parse --abbrev-ref HEAD)" \
    | head -n1 \
    | sed "s/^.*\[//"
}

# number of commits from parent branch
function commits_from_parent() {
  if [ $(git branch --show-current) = $(git_main_branch) ]; then
    git_cmd_err "this command doesn't work on main"
    return 1
  fi
  local parent=$(gitparent)
  local commits=$(git rev-list --count HEAD ^$parent)
  if [[ -n "$commits" && "$commits" != 0 ]]; then
    return $commits
  fi
}

# force push to origin with branch protection
function gitforcepush() {
  local current_branch=$(git branch --show-current)
  if [ $current_branch = $(git_main_branch) ]; then
    git_cmd_err "cannot force push to main"
    return 1
  fi
  git push origin $current_branch --force-with-lease
}
alias gfp=gitforcepush

# merge fast-forward only - current branch with main
function gmffthis() {
  local branch_to_merge=$(git branch --show-current)
  if [ $branch_to_merge ]; then
    git checkout $(git_main_branch)
    git merge --ff-only $branch_to_merge
  fi
}

# rebase interactively n commits back
function rebase-i() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits, e.g. $0 1"
    return 1
  fi
  git rebase -i HEAD~$1
}

# interactively rebase all commits on current branch
function rebase-branch() {
  if [ $(git branch --show-current) = $(git_main_branch) ]; then
    git_cmd_err "this command doesn't work on main"
    return 1
  fi
  local parent=$(gitparent)
  local commits=$(git rev-list --count HEAD ^$parent)
  git rebase -i HEAD~$commits
}

# rebase current branch onto parent branch (for keeping up-to-date)
#       A---B---C current-branch
#      /
# D---E---F---G parent
#         ==>>
#               A'--B'--C' current-branch
#              /
# D---E---F---G parent
function rebase-forward() {
  if [ $(git branch --show-current) = $(git_main_branch) ]; then
    git_cmd_err "this command doesn't work on main"
    return 1
  fi
  local parent=$(gitparent)
  git pull origin $parent
  git rebase origin/$parent
}

# rebase shortcuts
alias rebase-c="git rebase --continue"
alias rebase-a="git rebase --abort"

# reset n commits back
function gitreset() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits, e.g. $0 1"
    return 1
  fi
  # go back
  git reset --soft HEAD~$1
  # and then unstage
  git reset
}

# --- Aliases from oh-my-zsh (not comprehensive) ---

if [ -z "$ZSH" ]; then
  alias g='git'

  alias ga='git add'
  alias gaa='git add --all'
  alias gapa='git add --patch'
  alias gau='git add --update'
  alias gav='git add --verbose'

  alias gap='git apply'
  alias gapt='git apply --3way'

  alias gcb='git checkout -b'
  alias gcm='git checkout $(git_main_branch)'
  alias gco='git checkout'

  alias gb='git branch'
  alias gba='git branch -a'
  alias gbd='git branch -d'
  alias gbD='git branch -D'
  alias gbl='git blame -b -w'
  alias gbnm='git branch --no-merged'
  alias gbr='git branch --remote'

  alias gbs='git bisect'
  alias gbsb='git bisect bad'
  alias gbsg='git bisect good'
  alias gbsr='git bisect reset'
  alias gbss='git bisect start'

  alias gc='git commit -v'
  alias gc!='git commit -v --amend'
  alias gcn!='git commit -v --no-edit --amend'
  alias gca='git commit -v -a'
  alias gca!='git commit -v -a --amend'
  alias gcan!='git commit -v -a --no-edit --amend'
  alias gcans!='git commit -v -a -s --no-edit --amend'
  alias gcam='git commit -a -m'
  alias gcsm='git commit -s -m'
  alias gcas='git commit -a -s'
  alias gcasm='git commit -a -s -m'
  alias gcmsg='git commit -m'
  alias gcs='git commit -S'
  alias gcss='git commit -S -s'
  alias gcssm='git commit -S -s -m'

  alias gcf='git config --list'

  alias gcl='git clone --recurse-submodules'
  alias gclean='git clean -id'
  alias gpristine='git reset --hard && git clean -dffx'

  alias gcount='git shortlog -sn'

  alias gcp='git cherry-pick'
  alias gcpa='git cherry-pick --abort'
  alias gcpc='git cherry-pick --continue'

  alias gf='git fetch'
  alias gfo='git fetch origin'

  alias gfg='git ls-files | grep'

  alias ggpur='ggu'
  alias ggpull='git pull origin "$(git branch --show-current)"'
  alias ggpush='git push origin "$(git branch --show-current)"'

  alias ggsup='git branch --set-upstream-to=origin/$(git branch --show-current)'
  alias gpsup='git push --set-upstream origin $(git branch --show-current)'

  alias ghh='git help'

  alias gignore='git update-index --assume-unchanged'
  alias gignored='git ls-files -v | grep "^[[:lower:]]"'

  alias gl='git pull'

  alias gd='git diff'
  alias gdca='git diff --cached'
  alias gdcw='git diff --cached --word-diff'
  alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'
  alias gds='git diff --staged'
  alias gdt='git diff-tree --no-commit-id --name-only -r'
  alias gdup='git diff @{upstream}'
  alias gdw='git diff --word-diff'

  alias glg='git log --stat'
  alias glgp='git log --stat -p'
  alias glgg='git log --graph'
  alias glgga='git log --graph --decorate --all'
  alias glgm='git log --graph --max-count=10'
  alias glo='git log --oneline --decorate'
  alias glog='git log --oneline --decorate --graph'
  alias gloga='git log --oneline --decorate --graph --all'
  alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
  alias glols="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat"
  alias glola="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all"
  alias glod="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'"
  alias glods="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --date=short"

  alias gm='git merge'
  alias gmom='git merge origin/$(git_main_branch)'
  alias gmtl='git mergetool --no-prompt'
  alias gmtlvim='git mergetool --no-prompt --tool=vimdiff'
  alias gmum='git merge upstream/$(git_main_branch)'
  alias gma='git merge --abort'

  alias gp='git push'
  alias gpd='git push --dry-run'
  alias gpf='git push --force-with-lease'
  alias gpf!='git push --force'
  alias gpoat='git push origin --all && git push origin --tags'
  alias gpr='git pull --rebase'
  alias gpu='git push upstream'
  alias gpv='git push -v'

  alias gr='git remote'
  alias gra='git remote add'
  alias grmv='git remote rename'
  alias grrm='git remote remove'
  alias grset='git remote set-url'
  alias grup='git remote update'
  alias grv='git remote -v'

  alias grb='git rebase'
  alias grba='git rebase --abort'
  alias grbc='git rebase --continue'
  alias grbd='git rebase $(git_develop_branch)'
  alias grbi='git rebase -i'
  alias grbm='git rebase $(git_main_branch)'
  alias grbom='git rebase origin/$(git_main_branch)'
  alias grbo='git rebase --onto'
  alias grbs='git rebase --skip'

  alias grev='git revert'

  alias grh='git reset'
  alias grhh='git reset --hard'
  alias groh='git reset origin/$(git_current_branch) --hard'
  alias gru='git reset --'

  alias grm='git rm'
  alias grmc='git rm --cached'

  alias grs='git restore'
  alias grss='git restore --source'
  alias grst='git restore --staged'

  alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'

  alias gsb='git status -sb'
  alias gss='git status -s'
  alias gst='git status'

  alias gsh='git show'
  alias gsps='git show --pretty=short --show-signature'

  alias gsi='git submodule init'
  alias gsu='git submodule update'

  alias gsta='git stash push'
  alias gstu='gsta --include-untracked'
  alias gstaa='git stash apply'
  alias gstc='git stash clear'
  alias gstd='git stash drop'
  alias gstl='git stash list'
  alias gstp='git stash pop'
  alias gsts='git stash show --text'
  alias gstall='git stash --all'

  alias gsw='git switch'
  alias gswc='git switch -c'
  alias gswm='git switch $(git_main_branch)'

  alias gts='git tag -s'
  alias gtv='git tag | sort -V'
  alias gtl='gtl(){ git tag --sort=-v:refname -n -l "${1}*" }; noglob gtl'

  alias gunignore='git update-index --no-assume-unchanged'

  alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'

  alias gup='git pull --rebase'
  alias gupv='git pull --rebase -v'
  alias gupa='git pull --rebase --autostash'
  alias gupav='git pull --rebase --autostash -v'
  alias gupom='git pull --rebase origin $(git_main_branch)'
  alias gupomi='git pull --rebase=interactive origin $(git_main_branch)'
  alias glum='git pull upstream $(git_main_branch)'

  alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'

  alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign -m "--wip-- [skip ci]"'

  alias gam='git am'
  alias gamc='git am --continue'
  alias gams='git am --skip'
  alias gama='git am --abort'
  alias gamscp='git am --show-current-patch'

fi
