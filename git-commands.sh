#!/bin/bash

function git_cmd_err() {
  printf "\e[31merror: $@\e[0m\n" >&2
  false
}

# err function to protect these branches, to be called by other functions
function git_cmd_branch_protection() {
  if [ -z "$1" ]; then
    local check_branch=$(git branch --show-current)
  else
    local check_branch=$1
  fi
  if [ $check_branch = $(git_main_branch) ]; then
    git_cmd_err "this command doesn't work on main"
    return
  elif [[ "$check_branch" == *"develop"* ]]; then
    git_cmd_err "this command doesn't work on a dev branch"
    return
  elif [[ "$check_branch" == *"release"* ]]; then
    git_cmd_err "this command doesn't work on a release branch"
    return
  fi
}

# err function to protect main, to be called by other functions
function git_cmd_branch_protection_main() {
  if [ -z "$1" ]; then
    local check_branch=$(git branch --show-current)
  else
    local check_branch=$1
  fi
  if [ $check_branch = $(git_main_branch) ]; then
    git_cmd_err "this command doesn't work on main"
    return
  fi
}

# merge fast forward only
alias gmff="git merge --ff-only"

# reset current branch to remote origin
alias remotereset='git fetch origin $(git rev-parse --abbrev-ref HEAD) && git reset --hard "origin/$(git rev-parse --abbrev-ref HEAD)"'

# number of commits ahead from remote
function git_commits_ahead() {
  if git rev-parse --git-dir &>/dev/null; then
    local commits="$(git rev-list --count @{upstream}..HEAD 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      echo $commits
    fi
  fi
}

# number of commits behind remote
function git_commits_behind() {
  if git rev-parse --git-dir &>/dev/null; then
    local commits="$(git rev-list --count HEAD..@{upstream} 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      echo $commits
    fi
  fi
}

# find parent branch of $1, or current branch if $1 is empty
#   in the following example, 'release-20' would be returned
#           E---F---G  current-branch
#          /
#         C---D  release-20, feat--something
#        /
#   A---B  main
function git_find_parent_branch() {
  # start searching at start_branch
  if [ -z "$1" ]; then
    local start_branch=$(git branch --show-current)
  else
    local start_branch=$1
  fi

  # check branch isn't main
  git_cmd_branch_protection_main $start_branch || return

  # get all branches that aren't the current
  local all_branches=( $(git rev-parse --symbolic --branches) )

  # only look at branches that match these regexes
  local -a regexes=(
    "^$(git_main_branch)$" \
    "^dev.*$" \
    "^release.*$" 
  )

  # filter branches by regexes
  local -a candidate_branches=()
  local -A branches_found
  for branch in $all_branches; do
    for regex in $regexes; do
      if [[ $branch != $start_branch && $branch =~ $regex && -z "${branches_found[$branch]}" ]]; then
        candidate_branches+=( "$branch" )
        # logging each in branches_found prevents duplicates
        branches_found[$branch]=1
      fi
    done
  done

  # `git show-branch` cannot show more than 29 branches and commits at a time
  local max_branches_returned=28
  local num_branches_left=${#candidate_branches[@]}
  local last_count

  # do while
  while : ; do
    local -a branches_to_check=( "${candidate_branches[@]}" )
    local -a branches_narrowed=()

    while [[ ${#branches_to_check[@]} -gt 0 ]]; do
      # slice remaining branches to check to the max we can check at once
      local -a check_branches=( "${branches_to_check[@]:0:$max_branches_returned}" )
      local num_check_branches=${#check_branches[@]}

      # create a map index of commits to branches
      #   the left column in `git show-branch` maps to the list of branches in the header, denoting
      #   whether the commit is on that branch by a '+' or '*'
      #   >> show branches we want to check in topographical order
      #   -> cut the header list out of the result
      #   -> remove everything after the symbols
      #   -> replace ' ' with '_'
      #   -> replace '*' with '+'
      #   -> limit to lines with '_' <= 1
      #   -> get the first line
      #   -> split each character to its own line
      local map=( $(git show-branch --topo-order "${check_branches[@]}" "$start_branch" \
                      | tail -n +$(($num_check_branches+3)) \
                      | sed "s/ \[.*$//" \
                      | sed "s/ /_/g" \
                      | sed "s/*/+/g" \
                      | egrep '^_*[^_].*[^_]$' \
                      | head -n1 \
                      | sed 's/\(.\)/\1\n/g'
                ) )

      # given the following list of potential branches
      #   main release-30
      # and given the following result from `git show-branch`
      # ----------------------------------------
      # ! [main] main commit
      #  ! [release-20] release commit 2
      #   * [chore--something] chore commit 2
      # ---
      # +   [main] main commit
      #  +  [release-20] release commit 2
      #   * [chore--something] chore commit 2
      #   * [chore--something^] chore commit
      #  +* [release-20^] release commit
      # ++* [main^] test
      # ----------------------------------------
      # the resulting map _++ is derived from the following line
      #  +* [release-20^] release commit
      # this maps to the header in the result, as
      #   _  0  main
      #   +  1  release-20
      #   +  1
      # narrowing main out of the candidate list

      # loop through the branches, narrowing the list by whether it is in the map
      local i=1
      for branch in "${check_branches[@]}"; do
        if [[ "${map[$i]}" == "+" ]]; then
          branches_narrowed+=( $branch )
        fi
        ((i=i+1))
      done

      # cut the branches we just checked out of the remaining list
      branches_to_check=( "${branches_to_check[@]:$max_branches_returned}" )
    done

    # set candidate branches to the list we've just narrowed
    last_count=$count
    candidate_branches=( "${branches_narrowed[@]}" )
    count=${#candidate_branches[@]}

    # if we have no more branches to check, we're done
    [[ $max_branches_returned -lt $num_branches_left && $num_branches_left -lt $last_count ]] || break
  done

  # check if we narrowed to a single result
  if [[ ${#candidate_branches[@]} -gt 1 ]]; then
    git_cmd_err "unable to narrow parent branch down from the following:"
    git_cmd_err "  ${candidate_branches[@]}"
    return
  fi

  # we did it!
  echo "${candidate_branches[@]}"
}

# number of commits from parent branch based on git_find_parent_branch()
function git_commits_from_parent() {
  git_cmd_branch_protection_main || return

  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)
  if [[ -n "$commits" && "$commits" != 0 ]]; then
    echo $commits
  fi
}

# force push to origin with branch protection
function git_force_push() {
  local current_branch=$(git branch --show-current)
  if [ $current_branch = $(git_main_branch) ]; then
    git_cmd_err "cannot force push to main"
    return
  fi
  git push origin $current_branch --force-with-lease
}
alias gfp='git_force_push'
alias gpf='git_force_push'

# merge fast-forward only - current branch with main
function git_merge_ff_this() {
  local branch_to_merge=$(git branch --show-current)
  if [ $branch_to_merge ]; then
    git checkout $(git_main_branch)
    git merge --ff-only $branch_to_merge
  fi
}
alias gmffthis='git_merge_ff_this'

# rebase interactively n commits back
function git_rebase_n_commits() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits, e.g. $0 1"
    return
  fi
  git rebase -i HEAD~$1
}
alias grbn='git_rebase_n_commits'

# show the number of commits on a branch based on git_find_parent_branch()
function git_branch_num_commits() {
  local current=$(git branch --show-current)
  local parent=$(git_find_parent_branch 2&>/dev/null)
  if [ -z $parent ]; then
    local commits=$(git rev-list --count HEAD)
  else
    local commits=$(git rev-list --count HEAD ^$parent)
  fi
  printf "\e[33m$commits commits\e[0m on \e[32m$current\e[0m\n"
}
alias gbcount='git_branch_num_commits'

# interactively rebase all commits on current branch
function git_rebase_branch() {
  git_cmd_branch_protection || return
  
  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)
  git rebase -i HEAD~$commits
}
alias grbranch='git_rebase_branch'
alias grbbranch='git_rebase_branch'

# reset all commits on branch
function git_reset_branch() {
  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)

  if [ "$commits" -lt "1" ]; then
    git_cmd_err "no commits to reset"
    return
  fi
  if [ "$commits" -gt "30" ]; then
    printf "\e[33mAre you... sure you want to reset $commits commits?\e[0m\n"
    printf "\e[33mRun the following if you are:\e[0m\n"
    printf "  git reset --soft HEAD~$commits\n"
    return
  fi

  # go back
  git reset --soft HEAD~$commits
  # and then unstage
  git reset
}
alias grsbranch='git_reset_branch'

# rebase current branch onto parent branch based on git_find_parent_branch()
#       A---B---C current-branch
#      /
# D---E---F---G parent
#         ==>>
#               A'--B'--C' current-branch
#              /
# D---E---F---G parent
# ---------------------------------------
#         A---B current-branch
#        /
#       C---D another-branch
#      /
# E---F---G main
#       ==>>
#             A---B current-branch
#            /
#       C---D another-branch
#      /
# E---F---G main
function git_rebase_forward() {
  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  git pull origin $parent
  git rebase origin/$parent
}
alias grf='git_rebase_forward'
alias grop='git_rebase_forward'

# rebase current branch onto main branch
#       A---B---C current-branch
#      /
# D---E---F---G main
#         ==>>
#               A'--B'--C' current-branch
#              /
# D---E---F---G main
# ---------------------------------------
#         A---B current-branch
#        /
#       C---D another-branch
#      /
# E---F---G main
#       ==>>
#           C---D another-branch
#          /
#        /  A'--B' current-branch
#      /   /
# E---F---G main
function git_rebase_on_main() {
  git_cmd_branch_protection_main || return

  git pull origin $(git_main_branch)
  git rebase origin/$(git_main_branch)
}
alias grom='git_rebase_on_main'

# reset n commits back
function git_reset() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits, e.g. $0 1"
    return
  fi
  # go back
  git reset --soft HEAD~$1
  # and then unstage
  git reset
}
alias grn='git_reset'

# add wip commit
alias gwip='git add -A; git commit --no-verify -m "WIP"'

# reset last commit if message contains 'WIP'
alias gunwip='git log -n 1 --pretty=format:%s | grep -q -c "WIP" && git_reset 1'

# whether a branch has a remote set
function git_branch_has_remote() {
  remote=$(git config branch.$1.remote)
  ! [ -z $remote ] && return
  false
}

# git push, but set upstream if no remote set for branch
function git_push_with_set_upstream() {
  if ! git_branch_has_remote $(git branch --show-current); then
    local remote=$(git config branch.$(git_main_branch).remote)
    local current_branch=$(git branch --show-current)
    git push --set-upstream $remote $current_branch $@
  else
    git push $@
  fi
}
alias gp='git_push_with_set_upstream'

# --- Functions and aliases from oh-my-zsh (not comprehensive) ---

if ! [ -d "$HOME/.oh-my-zsh" ]; then

  # rename branch
  function grename() {
    if [[ -z "$1" || -z "$2" ]]; then
      git_cmd_err "usage: $0 old_branch new_branch"
      return
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
        echo $ref | cut -d '/' -f3
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

  # git pull origin
  function ggl() {
    if ! [ -z "$1" ]; then
      git pull origin "$1"
    else
      git pull origin "$(git rev-parse --abbrev-ref HEAD)"
    fi
  }

  alias ga='git add'
  alias gaa='git add --all'
  alias gapa='git add --patch'
  alias gau='git add --update'
  alias gav='git add --verbose'

  alias gcb='git checkout -b'
  alias gcm='git checkout $(git_main_branch)'
  alias gco='git checkout'

  alias gb='git branch'
  alias gba='git branch -a'
  alias gbd='git branch -d'
  alias gbD='git branch -D'
  alias gbnm='git branch --no-merged'
  alias gbr='git branch --remote'

  alias gbl='git blame -b -w'

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

  alias gignore='git update-index --assume-unchanged'
  alias gunignore='git update-index --no-assume-unchanged'
  alias gignored='git ls-files -v | grep "^[[:lower:]]"'

  alias gl='git pull'

  alias gd='git diff'
  alias gdca='git diff --cached'
  alias gdcw='git diff --cached --word-diff'
  alias gds='git diff --staged'
  alias gdup='git diff @{upstream}'
  alias gdw='git diff --word-diff'

  alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'

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
  alias gmum='git merge upstream/$(git_main_branch)'
  alias gma='git merge --abort'

  alias gmtl='git mergetool --no-prompt'
  alias gmtlvim='git mergetool --no-prompt --tool=vimdiff'

  #alias gp='git push'
  alias gpd='git push --dry-run'
  # alias gpf='git push --force-with-lease'
  alias gpoat='git push origin --all && git push origin --tags'
  alias gpu='git push upstream'
  alias gpv='git push -v'

  alias grb='git rebase'
  alias grba='git rebase --abort'
  alias grbc='git rebase --continue'
  alias grbi='git rebase -i'
  alias grbo='git rebase --onto'
  alias grbs='git rebase --skip'

  alias grev='git revert'

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
  alias gstu='git stash push --include-untracked'
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

  alias gpr='git pull --rebase'
  alias gup='git pull --rebase'
  alias gupv='git pull --rebase -v'
  alias gupa='git pull --rebase --autostash'
  alias gupav='git pull --rebase --autostash -v'
  alias gupom='git pull --rebase origin $(git_main_branch)'
  alias gupomi='git pull --rebase=interactive origin $(git_main_branch)'
  alias glum='git pull upstream $(git_main_branch)'

  alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
fi
