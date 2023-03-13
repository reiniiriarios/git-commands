#!/bin/bash

function git_cmd_err() {
  printf "\e[31merror: $@\e[0m\n" >&2
  false
}

# portable sed by using gnu-sed on macos
# sed -i -e ... - does not work on OS X as it creates -e backups
# sed -i'' -e ... - does not work on OS X 10.6 but works on 10.9+
# sed -i '' -e ... - not working on GNU
[[ "$(uname -s)" == "Darwin"* ]] && SED_PORTABLE="gsed" || SED_PORTABLE="sed"

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
  elif [[ "$check_branch" == "develop"* || "$check_branch" == "dev"* ]]; then
    git_cmd_err "this command doesn't work on a dev branch"
    return
  elif [[ "$check_branch" == "release"* ]]; then
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

# reset current branch to remote
function git_remote_reset() {
  if [ -z "$1" ]; then
    local branch=$(git branch --show-current)
  else
    local branch=$1
    if ! git rev-parse --quiet --verify $branch; then
      git_cmd_err "branch $branch not found"
      return
    fi
  fi

  if ! git_branch_has_remote $branch; then
    git_cmd_err "no remote found for $branch"
    return
  fi
  local remote=$(git config branch.$branch.remote)

  git fetch $remote $branch
  git reset --hard "$remote/$branch"
}
alias gremotereset='git_remote_reset'

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

# find branch name by search string
function git_find_branch() {
  if [ -z $1 ]; then
    git_cmd_err "missing search string, e.g. ISSUE-1234"
    return
  fi
  local branches=$(git branch --list "*$1*" --format '%(refname:short)')
  local result_source="local"
  if [ -z "$branches" ]; then
    local result_source="remote"
    # lstrip past the remote name
    local branches=$(git branch -r --list "*$1*" --format '%(refname:lstrip=3)')
    if [ -z "$branches" ]; then
      git_cmd_err "unable to find branch matching: $1"
      return
    fi
  fi
  local num_results=$(echo "$branches" | wc -l | tr -d ' ')
  if [ $num_results -gt 1 ]; then
    git_cmd_err "unable to narrow results, $num_results $result_source matches"
    if [ $num_results -lt 11 ]; then
      printf "\e[33m$(echo "$branches" | sed 's/^/  /g')\e[0m\n" >&2
    fi
    return
  fi
  echo $branches
}

# switch branch by search string, if found, e.g. gswf ISSUE-1234
function git_switch_branch_by_search() {
  local branch=$(git_find_branch $1)
  if [ -n "$branch" ]; then
    git switch $branch
  fi
}
alias gswf='git_switch_branch_by_search'

# checkout branch by search string, if found, e.g. gswf ISSUE-1234
function git_checkout_branch_by_search() {
  local branch=$(git_find_branch $1)
  if [ -n "$branch" ]; then
    git checkout $branch
  fi
}
alias gcof='git_checkout_branch_by_search'

# find parent branch of $1, or current branch if $1 is empty
# usage: git_find_parent_branch
#        git_find_parent_branch branch_name
#        git_find_parent_branch -a branch_name
# ------------------------------------------------------------
# in the following example, 'release-20' would be returned
#           E---F---G  current-branch
#          /
#         C---D  release-20, feat--something
#        /
#   A---B  main
function git_find_parent_branch() {
  # whether to search all branches or limit by regex (listed below)
  if [ "$1" = "-a" ] || [ "$1" = "--all" ]; then
    local search_all=1
    shift
  else
    local search_all=0
  fi

  # start searching at start_branch
  if [ -z "$1" ]; then
    local start_branch=$(git branch --show-current)
  else
    local start_branch=$1
    if ! git rev-parse --quiet --verify $start_branch >/dev/null; then
      git_cmd_err "branch $start_branch not found"
      return
    fi
  fi

  # check branch isn't main
  git_cmd_branch_protection_main $start_branch || return

  # get all branches that aren't the current
  local all_branches=( $(git rev-parse --symbolic --branches) )

  # only look at branches that match these regexes
  if [ $search_all -eq 0 ]; then
    local -a regexes=(
      "^$(git_main_branch)$" \
      "^dev.*$" \
      "^release.*$" 
    )

    # filter branches by regexes
    local -a candidate_branches=()
    local -A branches_found
    for branch in ${all_branches[@]}; do
      for regex in $regexes; do
        if [[ $branch != $start_branch && $branch =~ $regex && -z "${branches_found[$branch]}" ]]; then
          candidate_branches+=( "$branch" )
          # logging each in branches_found prevents duplicates
          branches_found[$branch]=1
        fi
      done
    done
  else
    local -a candidate_branches=( "${all_branches[@]}" )
  fi

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
      local map=(
        $(git show-branch --topo-order "${check_branches[@]}" "$start_branch" \
          | tail -n +$(($num_check_branches+3)) \
          | sed "s/ \[.*$//" \
          | sed "s/ /_/g" \
          | sed "s/*/+/g" \
          | egrep '^_*[^_].*[^_]$' \
          | head -n1 \
          | sed 's/\(.\)/\1\n/g'
        )
      )

      # given the following list of potential branches
      #   main release-20
      # and given the following result from `git show-branch`
      # ----------------------------------------
      # ! [main] main commit
      #  ! [release-20] release commit 2
      #   * [chore--current-branch] chore commit 2
      # ---
      # +   [main] main commit
      #  +  [release-20] release commit 2
      #   * [chore--current-branch] chore commit 2
      #   * [chore--current-branch^] chore commit
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
    printf "  ${candidate_branches[@]}\n" >&2
    return
  fi

  # we did it!
  echo "${candidate_branches[@]}"
}

# number of commits out of date from parent
function git_commits_out_of_date() {
  if [ -n "$2" ]; then
    local check_branch=$2
  else
    local check_branch=$(git branch --show-current)
  fi
  if [ -n "$1" ]; then
    local parent=$1
  else
    local parent=$(git_find_parent_branch $check_branch)
  fi

  if [[ "$check_branch" == "$parent" ]]; then
    git_cmd_err "comparing $check_branch to itself"
    return
  fi
  if [[ "$check_branch" == "$(git_main_branch)" ]]; then
    git_cmd_err "this command doesn't work on main"
    return
  fi

  local commits=$(git rev-list --left-only --count $parent...$check_branch)

  if [[ -n "$commits" && "$commits" > 0 ]]; then
    echo $commits
  fi
}

# force push to remote with branch protection
function git_force_push() {
  git_cmd_branch_protection_main || return

  local remote=$(git config branch.$current_branch.remote)
  git push $remote $current_branch --force-with-lease
}
alias gfp='git_force_push'
alias gpf='git_force_push'

# switch to parent branch
alias gswp='git switch $(git_find_parent_branch)'

# merge fast forward only
function git_merge_ff() {
  if [ -z "$1" ]; then
    git_cmd_err "missing argument for which branch to merge"
  fi
  local branch_to_merge=$1

  if [ $branch_to_merge ]; then
    local current=$(git branch --show-current)
    local commits=$(git_commits_out_of_date $current $branch_to_merge)

    if [[ -n "$commits" && "$commits" != 0 ]]; then
      git_cmd_err "unable to fast-forward merge, $branch_to_merge is out of date by $commits commit(s)"
      return
    fi

    git merge --ff-only $branch_to_merge
  fi
}
alias gmff='git_merge_ff'

# merge fast-forward only - current branch with git_find_parent_branch()
function git_merge_ff_this() {
  git_cmd_branch_protection_main || return

  local branch_to_merge=$(git branch --show-current)

  if [ $branch_to_merge ]; then
    local parent=$(git_find_parent_branch)
    local remote=$(git config branch.$parent.remote)
    git pull --rebase $remote $parent:$parent

    local commits=$(git_commits_out_of_date)
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      git_cmd_err "unable to fast-forward merge, out of date with $parent by $commits commit(s)"
      return
    fi

    git checkout $parent
    git merge --ff-only $branch_to_merge
  fi
}
alias gmffthis='git_merge_ff_this'

# rebase interactively n commits back
function git_rebase_n_commits() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits argument"
    return
  fi
  git rebase -i HEAD~$1
}
alias grbn='git_rebase_n_commits'

# show the number of commits on a branch based on git_find_parent_branch()
function git_branch_num_commits() {
  local current=$(git branch --show-current)
  local parent=$(git_find_parent_branch 2>/dev/null)
  if [ -z $parent ]; then
    local commits=$(git rev-list --count HEAD)
  else
    local commits=$(git rev-list --count HEAD ^$parent)
  fi
  printf "\e[33m$commits commit(s)\e[0m on \e[32m$current\e[0m\n"
}
alias gbcount='git_branch_num_commits'

# interactively rebase all commits on current branch
function git_rebase_branch() {
  git_cmd_branch_protection || return
  
  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)
  if [ "$commits" -lt "1" ]; then
    git_cmd_err "no commits to rebase"
    return
  fi
  if [ "$commits" -gt "40" ] && [ "$1" != "-y" ]; then
    printf "\e[33mAre you sure you want to rebase $commits commits? [y/N] \e[0m"
    read confirm
    if [[ "$confirm" != 'y' && "$confirm" != 'Y' && "$confirm" != 'yes' ]]; then
      return
    fi
  fi

  git rebase -i HEAD~$commits
}
alias gbrebase='git_rebase_branch'

# squash branch (automatically) via interactive rebase
function git_squash_branch() {
  git_cmd_branch_protection || return

  # count commits in branch
  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)
  if [ "$commits" -lt "2" ]; then
    git_cmd_err "no commits to squash"
    return
  fi

  # drop 'drop:' conventional commits first
  local commits_to_drop=$(git log -n $commits --pretty=format:%s | grep -c '^drop: ')
  if [ "$commits_to_drop" -gt "0" ]; then
    if [ "$1" != "-y" ]; then
      printf "\e[33mDrop $commits_to_drop commit(s) in current branch? [y/N] \e[0m"
      read confirm
    fi
    if [[ "$1" == "-y" || "$confirm" == 'y' || "$confirm" == 'Y' || "$confirm" == 'yes' ]]; then
      GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i '/ drop: / s/pick /drop /g'" git rebase -i HEAD~$commits

      # recount commits in branch after drop
      local commits=$(git rev-list --count HEAD ^$parent)
      if [ "$commits" -lt "2" ]; then
        git_cmd_err "no commits to squash after drop"
        return
      fi
    fi
  fi

  if [ "$1" != "-y" ]; then
    printf "\e[33mSquash $commits commits? [y/N] \e[0m"
    read confirm
    if [[ "$confirm" != 'y' && "$confirm" != 'Y' && "$confirm" != 'yes' ]]; then
      return
    fi
  fi

  GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i 's/pick/squash/g;0,/^squash /s//pick /'" git rebase -i HEAD~$commits
}
alias gbsquash='git_squash_branch'

# drop all commits in current branch with messages beginning with 'drop: '
function git_drop_drop_commits() {
  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)
  if [ "$commits" -lt "1" ]; then
    git_cmd_err "no commits to rebase"
    return
  fi

  local commits_to_drop=$(git log -n $commits --pretty=format:%s | grep -c '^drop: ')
  if [ "$commits_to_drop" -lt "1" ]; then
    git_cmd_err "no commits to drop"
    return
  fi

  if [ "$1" != "-y" ]; then
    printf "\e[33mDrop $commits_to_drop commit(s) in current branch? [y/N] \e[0m"
    read confirm
    if [[ "$confirm" != 'y' && "$confirm" != 'Y' && "$confirm" != 'yes' ]]; then
      return
    fi
  fi

  GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i '/ drop: / s/pick /drop /g'" git rebase -i HEAD~$commits
}
alias gbdd='git_drop_drop_commits'

# reset all commits on branch
function git_reset_branch() {
  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  local commits=$(git rev-list --count HEAD ^$parent)

  if [ "$commits" -lt "1" ]; then
    git_cmd_err "no commits to reset"
    return
  fi
  if [ "$commits" -gt "30" ] && [ "$1" != "-y" ]; then
    printf "\e[33mAre you sure you want to reset $commits commits? [y/N] \e[0m"
    read confirm
    printf "\n"
    if [[ "$confirm" != 'y' && "$confirm" != 'Y' && "$confirm" != 'yes' ]]; then
      return
    fi
  fi

  # go back
  git reset --soft HEAD~$commits
  # and then unstage
  git reset
}
alias gbreset='git_reset_branch'

# squash n commits
function git_squash() {
  git_cmd_branch_protection || return

  local confirm=0
  if [[ "$1" == "-y" ]]; then
    local confirm=1
    shift
  fi

  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits argument"
    return
  fi

  if [ "$1" -gt "10" ] || [ "$confirm" -eq 1 ]; then
    printf "\e[33mAre you sure you want to squash $1 commits? [y/N] \e[0m"
    read confirm
    printf "\n"
    if [[ "$confirm" != 'y' && "$confirm" != 'Y' && "$confirm" != 'yes' ]]; then
      return
    fi
  fi

  GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i 's/pick/squash/g;0,/^squash /s//pick /'" git rebase -i HEAD~$1
}
alias gsquash='git_squash'

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
#       C---D release-7
#      /
# E---F---G main
#       ==>>
#             A'---B' current-branch
#            /
#       C---D release-7
#      /
# E---F---G main
function git_rebase_forward() {
  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  local remote=$(git config branch.$parent.remote)
  git pull --rebase $remote $parent:$parent
  git rebase $remote/$parent
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
#        /  C'--A'--B' current-branch
#      /   /
# E---F---G main
function git_rebase_on_main() {
  git_cmd_branch_protection_main || return

  local remote=$(git config branch.$(git_main_branch).remote)
  git pull --rebase $remote $(git_main_branch):$(git_main_branch)
  git rebase $(git_main_branch)
}
alias grom='git_rebase_on_main'

# rebase current branch onto another branch by search string
function get_rebase_on_branch() {
  git_cmd_branch_protection || return

  local branch=$(git_find_branch $1)
  if [ -n "$branch" ]; then
    local remote=$(git config branch.$(branch).remote)
    git pull --rebase $remote $branch:$branch
    git rebase $branch
  fi
}
alias grob='git_rebase_on_branch'

# reset n commits back
function git_reset() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits argument"
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
  local remote=$(git config branch.$1.remote)
  ! [ -z $remote ] && return
  false
}

function git_short_stat_no_images() {
  local -a extensions=(
    'png' \
    'jpg' \
    'gif' \
    'svg' \
    'ttf' \
    'woff' \
    'woff2' \
    'eot' \
    'pdf'
  )
  extensions=$(printf "':!*.%s' " "${extensions[@]}")
  eval "git --no-pager diff --shortstat $@ -- $extensions"
}
alias gshortstatnoimg='git_short_stat_no_images'
alias gshortstat='git --no-pager diff --shortstat'

function gdroplast() {
  git_cmd_branch_protection || return
  git reset --hard HEAD^
}

alias gt='git tag'

# because otherwise i forget to push first, then ci runs wonky if i'm not on a branch
function git_tag_push() {
  if [ -z "$1" ]; then
    git_cmd_err "missing argument for tag to push"
    return
  fi

  git push
  git push origin $1
}
alias gtp='git_tag_push'

# move a tag from one commit to another, both locally and on origin
function git_move_tag() {
  if [ -z "$1" ]; then
    git_cmd_err "missing argument for tag to move"
    return
  fi

  local num_tags=$(git tag -l "$1" | wc -l)
  if [ $num_tags -eq 0 ]; then
    git_cmd_err "tag not found"
    return
  elif [ $num_tags -gt 1 ]; then
    git_cmd_err "multiple tags found"
    return
  fi

  local tag_name=$(git tag -l "$1" | head -n 1)
  git tag -d $tag_name
  git push origin :refs/tags/$tag_name
  git tag $tag_name
  git push
  git push origin $tag_name
}
alias gmt='git_move_tag'

alias gl='git pull --rebase'

# -------------------- Functions and aliases from oh-my-zsh (not comprehensive) --------------------

if [ -d "$HOME/.oh-my-zsh" ]; then
  return
fi

# rename branch
function grename() {
  if [[ -z "$1" || -z "$2" ]]; then
    git_cmd_err "usage: grename old_branch new_branch"
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
      echo $ref | cut -d '/' -f 3
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
    git pull --rebase origin "$1"
  else
    git pull --rebase origin "$(git rev-parse --abbrev-ref HEAD)"
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
alias gfa='git fetch --all'
alias gfprune='git fetch --prune'

alias gfg='git ls-files | grep'

alias ggpur='ggu'
alias ggpull='git pull origin "$(git branch --show-current)"'
alias ggpush='git push origin "$(git branch --show-current)"'

alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'

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

alias gp='git push'
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

# alias gpr='git pull --rebase'
# alias gup='git pull --rebase'
alias gupv='git pull --rebase -v'
alias gupa='git pull --rebase --autostash'
alias gupav='git pull --rebase --autostash -v'
alias gupom='git pull --rebase origin $(git_main_branch)'
alias gupomi='git pull --rebase=interactive origin $(git_main_branch)'
alias glum='git pull upstream $(git_main_branch)'

alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
