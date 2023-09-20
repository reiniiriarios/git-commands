#!/bin/bash

GIT_CMDS_FILE_LOCATION="$HOME/.git-commands.sh"

# portable sed by using gnu-sed on macos
# sed -i -e ... - does not work on OS X as it creates -e backups
# sed -i'' -e ... - does not work on OS X 10.6 but works on 10.9+
# sed -i '' -e ... - not working on GNU
[[ "$(uname -s)" == "Darwin"* ]] && SED_PORTABLE="gsed" || SED_PORTABLE="sed"

#---------------------------- internal ----------------------------

function git_cmd() {
  printf "\e[36m→ git \e[32m$(echo "$@" | sed 's/%/%%/g')\e[0m\n"
  git $*
}

function git_cmd_err() {
  printf "\e[31merror: $@\e[0m\n" >&2
  false
}

function git_cmd_confirm() {
  if [ -z "$1" ]; then
    git_cmd_err "no question to confirm"
    false
    return
  fi
  printf "\e[33m$@ [y/N]\e[0m "
  read confirm
  local conf=$(echo "$confirm" | awk '{print tolower($0)}')
  if [[ "$conf" == 'y' || "$conf" == 'yes' ]]; then
    return
  fi
  false
}

# git_cmd_branch_protection || return
# git_cmd_branch_protection <branch_name> || return
#   Error function to be called by other functions to prevent those
#   functions from being called on main, dev, or release branches.
function git_cmd_branch_protection() {
  git_cmd_help $1 && return

  if [ -z "$1" ]; then
    local check_branch=$(git branch --show-current)
  else
    local check_branch=$1
  fi
  if [ $check_branch = $(git_main_branch) ]; then
    git_cmd_err "this command doesn't work on main"
    return
  elif [[ "$check_branch" == "dev"* ]]; then
    git_cmd_err "this command doesn't work on a dev branch"
    return
  elif [[ "$check_branch" == "release"* ]]; then
    git_cmd_err "this command doesn't work on a release branch"
    return
  fi
}

# git_cmd_branch_protection_main || return
# git_cmd_branch_protection_main <branch_name> || return
#   Error function to be called by other functions to prevent those
#   functions from being called on the main branch.
function git_cmd_branch_protection_main() {
  git_cmd_help $1 && return

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

#---------------------------- help ----------------------------

# print comment prefix for calling function if $1 is a help flag
function git_cmd_help() {
  if [[ "$1" != "-h" && "$1" != "--help" ]]; then
    return 1
  fi
  # find calling function, bash || zsh
  [[ -n $BASH_VERSION ]] && local fn_name="${FUNCNAME[1]}" || local fn_name="${funcstack[@]:1:1}"
  # find line number of calling fn
  local n=$(grep -n "function $fn_name()" "$GIT_CMDS_FILE_LOCATION" | cut -d : -f 1)

  local help=""
  while : ; do
    n=$(( n - 1 ))
    local line=$(sed -n $n'p' "$GIT_CMDS_FILE_LOCATION")
    if [[ "$line" = "#"* ]]; then
      # prettify each comment line
      local line=$(printf "$line" | sed 's/^# //')
      if [[ "$line" != "  "* ]]; then
        line=$(printf "$line" | sed 's/\(<.*>\)/\\e[35m\1\\e[36m/g' | sed 's/\(\[.*\]\)/\\e[33m\1\\e[36m/g')
        line="\e[36m$line\e[0m"
      else
        line=$(printf "$line" | sed 's/`\(.*\)`/\\e[33m\1\\e[0m/g')
      fi
      help="$line\n$help"
    else
      # if we run out of comment lines, we're done
      break
    fi
  done

  printf "$help"
}

# display help for an alias
function git_cmd_help_alias() {
  if [[ -z "$1" ]]; then
    git_cmd_err "alias not specified"
    return
  fi
  # find line number of alias
  local n=$(grep -n "alias $1=" "$GIT_CMDS_FILE_LOCATION" | cut -d : -f 1)
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    git_cmd_err "alias not found"
    return
  fi

  local help=""
  while : ; do
    n=$(( n - 1 ))
    local line=$(sed -n $n'p' "$GIT_CMDS_FILE_LOCATION")
    if [[ "$line" = "#"* ]]; then
      local line=$(printf "$line" | sed 's/^# /  /')
      help="$line\n$help"
    else
      # if we run out of comment lines, we're done
      break
    fi
  done

  if [ -z "$help" ]; then
    git_cmd_err "no documentation found"
    return
  fi

  printf "\e[36m$1\e[0m\n"
  printf "$help"
}

# help function
function git_cmd_info() {
  if [[ "$1" == "-f" || "$1" == "--functions" ]]; then
    git_cmd_help_functions
  elif [[ "$1" == "-l" || "$1" == "--helpers" ]]; then
    git_cmd_help_helpers
  elif [[ "$1" == "-a" || "$1" == "--all" ]]; then
    git_cmd_help_aliases
  elif [[ "$1" == "-h" || "$1" == "--help" || "$1" == "--alias" ]]; then
    git_cmd_help_alias $2
  else
    printf "\e[30mGIT BASH SHORTCUTS\e[0m\n"
    printf "\e[36mgcmd \e[33m-f\e[0m                Display help for common functions.\n"
    printf "\e[36mgcmd \e[33m-l\e[0m                Display help for helper functions.\n"
    printf "\e[36mgcmd \e[33m-a\e[0m                Display help for aliases.\n"
    printf "\e[36mgcmd \e[33m-h \e[37m<alias_name>\e[0m   Display help for an alias.\n"
    printf "\e[37m<function_name> \e[33m-h\e[0m     Display help for a function.\n"
  fi
}
alias gcmd='git_cmd_info'
alias gcmds='git_cmd_info'

# info on common functions
function git_cmd_help_functions() {
  local -a functions=( \
    "git_force_push" \
    "git_switch_branch_by_search" \
    "git_checkout_branch_by_search" \
    "git_rebase_n_commits" \
    "git_rebase_branch" \
    "git_rebase_forward" \
    "git_rebase_on_main" \
    "git_rebase_on_branch" \
    "git_squash" \
    "git_squash_branch" \
    "git_drop_drop_commits" \
    "git_merge_ff" \
    "git_merge_ff_this" \
    "git_reset" \
    "git_reset_branch" \
    "git_drop_last" \
    "git_remote_reset" \
    "git_wip" \
    "git_wip_undo" \
    "git_rename_branch" \
    "git_backup_branch" \
    "git_tag_push" \
    "git_move_tag" \
    "git_branch_num_commits" \
  )

  local help=""
  for function in "${functions[@]}"; do
    help="$help$($function -h)\n\n"
  done
  help="\e[30mCOMMON FUNCTIONS\e[0m\n\n$help"

  if [[ "$1" == "-e" ]]; then
    printf "$help"
  else
    printf "$help" | less -R
  fi
}

# info on helper functions
function git_cmd_help_helpers() {
  local -a functions=( \
    "git_find_branch" \
    "git_find_parent_branch" \
    "git_commits_out_of_date" \
    "git_commits_ahead" \
    "git_commits_behind" \
    "git_main_branch" \
    "git_develop_branch" \
  )

  local help=""
  for function in "${functions[@]}"; do
    help="$help$($function -h)\n\n"
  done
  help="\e[30mHELPER FUNCTIONS\e[0m\n\n$help"

  if [[ "$1" == "-e" ]]; then
    printf "$help"
  else
    printf "$help" | less -R
  fi
}

# info on aliases
function git_cmd_help_aliases() {
  local -a aliases=( \
    "gp" \
    "ga" \
    "gaa" \
    "gcm" \
    "gcd" \
    "gcpb" \
    "gco" \
    "gcb" \
    "gsw" \
    "gswc" \
    "gswm" \
    "gswd" \
    "gswp" \
    "gb" \
    "gba" \
    "gbd" \
    "gbnm" \
    "gbr" \
    "gbl" \
    "gf" \
    "gfo" \
    "gfa" \
    "gfprune" \
    "gl" \
    "gc" \
    "gca" \
    "gcam" \
    "gcmsg" \
    "gcf" \
    "gcount" \
    "grb" \
    "grbi" \
    "grba" \
    "grbc" \
    "grbs" \
    "gcp" \
    "gcpa" \
    "gcpc" \
    "gbs" \
    "gbsb" \
    "gbsg" \
    "gbsr" \
    "gbss" \
    "gfg" \
    "gd" \
    "gdw" \
    "gsb" \
    "gss" \
    "gst" \
    "grt" \
    "gcl" \
    "gsi" \
    "gsu" \
    "glo" \
    "glog" \
    "gloga" \
    "glol" \
    "glols" \
    "glola" \
    "glod" \
    "glods" \
    "gt" \
  )

  local help=""
  for alias in "${aliases[@]}"; do
    help="$help$(git_cmd_help_alias $alias)\n"
  done
  help="\e[30mALIASES\e[0m\n\n$help"

  if [[ "$1" == "-e" ]]; then
    printf "$help"
  else
    printf "$help" | less -R
  fi
}

#---------------------------- functions ----------------------------

# gremotereset
# git_remote_reset
#   Reset current branch to remote.
function git_remote_reset() {
  git_cmd_help $1 && return

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

  git_cmd fetch $remote $branch
  git_cmd reset --hard "$remote/$branch"
}
alias gremotereset='git_remote_reset'

# git_commits_ahead
#   Return number of commits current branch is ahead of remote.
function git_commits_ahead() {
  git_cmd_help $1 && return

  if git rev-parse --git-dir &>/dev/null; then
    local commits="$(git rev-list --count @{upstream}..HEAD 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      echo $commits
    fi
  fi
}

# git_commits_behind
#   Return number of commits current branch is behind remote.
function git_commits_behind() {
  git_cmd_help $1 && return

  if git rev-parse --git-dir &>/dev/null; then
    local commits="$(git rev-list --count HEAD..@{upstream} 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]; then
      echo $commits
    fi
  fi
}

# git_find_branch <search_string>
#   Find branch name by search string.
function git_find_branch() {
  git_cmd_help $1 && return

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

# git_find_local_branch <search_string>
#   Find branch name by search string.
function git_find_local_branch() {
  git_cmd_help $1 && return

  if [ -z $1 ]; then
    git_cmd_err "missing search string, e.g. ISSUE-1234"
    return
  fi
  local branches=$(git branch --list "*$1*" --format '%(refname:short)')
  if [ -z "$branches" ]; then
    git_cmd_err "unable to find branch matching: $1"
    return
  fi
  local num_results=$(echo "$branches" | wc -l | tr -d ' ')
  if [ $num_results -gt 1 ]; then
    git_cmd_err "unable to narrow results, $num_results matches"
    if [ $num_results -lt 11 ]; then
      printf "\e[33m$(echo "$branches" | sed 's/^/  /g')\e[0m\n" >&2
    fi
    return
  fi
  echo $branches
}

# git_find_remote_branch <search_string>
#   Find branch name by search string.
function git_find_remote_branch() {
  git_cmd_help $1 && return

  if [ -z $1 ]; then
    git_cmd_err "missing search string, e.g. ISSUE-1234"
    return
  fi
  # lstrip past the remote name
  local branches=$(git branch -r --list "*$1*" --format '%(refname:lstrip=3)')
  if [ -z "$branches" ]; then
    git_cmd_err "unable to find branch matching: $1"
    return
  fi
  local num_results=$(echo "$branches" | wc -l | tr -d ' ')
  if [ $num_results -gt 1 ]; then
    git_cmd_err "unable to narrow results, $num_results matches"
    if [ $num_results -lt 11 ]; then
      printf "\e[33m$(echo "$branches" | sed 's/^/  /g')\e[0m\n" >&2
    fi
    return
  fi
  echo $branches
}

# gswf <search_string>
# git_switch_branch_by_search <search_string>
#   Switch branch by search string, if found.
function git_switch_branch_by_search() {
  git_cmd_help $1 && return

  local branch=$(git_find_branch $1)
  if [ -n "$branch" ]; then
    git_cmd switch $branch

    # git has info printed for this, but this makes it more obvious
    local behind=$(git_commits_behind)
    if [ -n "$behind" ]; then
      printf "\e[33m$behind commits behind remote\e[0m\n"
    else
      local ahead=$(git_commits_ahead)
      if [ -n "$ahead" ]; then
        printf "\e[33m$ahead commits ahead of remote\e[0m\n"
      fi
    fi
  fi
}
alias gswf='git_switch_branch_by_search'

# gcof <search_string>
# git_checkout_branch_by_search <search_string>
#   Checkout branch by search string, if found.
function git_checkout_branch_by_search() {
  git_cmd_help $1 && return

  local branch=$(git_find_branch $1)
  if [ -n "$branch" ]; then
    git_cmd checkout $branch
  fi
}
alias gcof='git_checkout_branch_by_search'

# gbdel <search_string>
# git_delete_branch_by_search <search_string>
#   Switch branch by search string, if found.
function git_delete_branch_by_search() {
  git_cmd_help $1 && return

  git_cmd_branch_protection $1 || return

  # local branch?
  local branch=$(git_find_local_branch $1)
  if [ -n "$branch" ]; then
    git_cmd_confirm "Are you sure you want to delete branch $branch?" || return
    local remote=$(git config branch.$branch.remote)
    git_cmd branch -D $branch
    # has remote?
    if [ -n "$remote" ] && git ls-remote $remote --exit-code --heads $branch; then
      git_cmd_confirm "Do you also want to delete $branch on $remote?" || return
      git_cmd push $remote --delete $branch
    fi
  else
    # remote branch?
    local branch=$(git_find_remote_branch $1)
    if [ -n "$branch" ]; then
      local remote=$(git config branch.$branch.remote)
      git_cmd_confirm "Are you sure you want to delete branch $branch on $remote?" || return
      git_cmd push $remote --delete $branch
    fi
  fi
}
alias gbdel='git_delete_branch_by_search'

# git_find_parent_branch
# git_find_parent_branch [-a] <branch_name>
#   Find parent branch. Default behavior filters branches
#   by regex, searching for main, dev, or release branches.
#   
#   `-a`  Search all branches instead of limiting by regex.
#   
#   In the following example, 'release-20' would be returned:
#   
#             E---F---G  current-branch
#            /
#           C---D  release-20, feat--something
#          /
#     A---B  main
function git_find_parent_branch() {
  git_cmd_help $1 && return

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
          | sed "s/-/+/g" \
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
    local -a candidates_without_main=()

    # if more than one result, filter out main
    for branch in "${candidate_branches[@]}"; do
      if [[ "$branch" != "$(git_main_branch)" ]]; then
        candidates_without_main+=( $branch )
      fi
    done
    candidate_branches=( "${candidates_without_main[@]}" )

    # if still more than one result, give up
    if [[ ${#candidate_branches[@]} -gt 1 ]]; then
      git_cmd_err "unable to narrow parent branch down from the following:"
      for branch in "${candidate_branches[@]}"; do
        printf "  $branch\n" >&2
      done
      return
    fi
  fi

  # we did it!
  echo "${candidate_branches[@]}"
}

# git_commits_out_of_date
# git_commits_out_of_date <parent_branch>
# git_commits_out_of_date <parent_branch> <branch_name>
#   Return number of commits branch is out of date from parent.
function git_commits_out_of_date() {
  git_cmd_help $1 && return

  if [ -n "$2" ]; then
    local check_branch=$2
  else
    local check_branch=$(git branch --show-current)
  fi
  if [ -n "$1" ]; then
    local parent=$1
  else
    local parent=$(git_find_parent_branch $check_branch)
    if [ -z $parent ]; then
      false
      return
    fi
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

# gfp
# gfp [..]
# git_force_push [..]
#   Force push with lease to remote with branch protection.
function git_force_push() {
  git_cmd_help $1 && return

  git_cmd_branch_protection_main || return
  git_cmd push --force-with-lease $*
}
alias gfp='git_force_push'
alias gpf='git_force_push'

# gmff <branch_name>
# git_merge_ff <branch_name>
#   Merge current branch with given branch, fast forward only.
function git_merge_ff() {
  git_cmd_help $1 && return

  if [ -z "$1" ]; then
    git_cmd_err "missing argument for which branch to merge"
  fi
  local branch_to_merge=$1
  [[ -z "$branch_to_merge" ]] && return

  git update-index --refresh >/dev/null
  if ! git diff-index --quiet HEAD --; then
    git_cmd_err "unable to fast-forward merge, you have unstaged changes"
    return
  fi

  local current=$(git branch --show-current)
  local commits=$(git_commits_out_of_date $current $branch_to_merge)

  if [[ -n "$commits" && "$commits" != 0 ]]; then
    git_cmd_err "unable to fast-forward merge, $branch_to_merge is out of date by $commits commit(s)"
    return
  fi

  git_cmd merge --ff-only $branch_to_merge
}
alias gmff='git_merge_ff'

# gmffthis
# git_merge_ff_this
#   Merge current branch with parent branch, fast forward only.
function git_merge_ff_this() {
  git_cmd_help $1 && return

  git_cmd_branch_protection_main || return

  local branch_to_merge=$(git branch --show-current)
  [[ -z "$branch_to_merge" ]] && return

  git update-index --refresh >/dev/null
  if ! git diff-index --quiet HEAD --; then
    git_cmd_err "unable to fast-forward merge, you have unstaged changes"
    return
  fi

  local parent=$(git_find_parent_branch)
  if [ -z $parent ]; then
    false
    return
  fi
  local remote=$(git config branch.$parent.remote)
  git_cmd fetch $remote $parent:$parent || return

  local commits=$(git_commits_out_of_date)
  if [[ -n "$commits" && "$commits" != 0 ]]; then
    git_cmd_err "unable to fast-forward merge, out of date with $parent by $commits commit(s)"
    return
  fi

  git_cmd switch $parent
  git_cmd merge --ff-only $branch_to_merge
}
alias gmffthis='git_merge_ff_this'

# grbn <n>
# git_rebase_n_commits <n>
#   Rebase interactively `n` commits back from HEAD.
function git_rebase_n_commits() {
  git_cmd_help $1 && return

  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits argument"
    return
  fi
  git_cmd rebase -i HEAD~$1
}
alias grbn='git_rebase_n_commits'

# gbcount
# git_branch_num_commits
#   Count number of commits on current branch,
#   based on search for parent branch.
function git_branch_num_commits() {
  git_cmd_help $1 && return

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

# gbrebase
# git_rebase_branch
#   Interactively rebase all commits on current branch,
#   based on search for parent branch.
function git_rebase_branch() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return
  
  local parent=$(git_find_parent_branch)
  if [ -z $parent ]; then
    false
    return
  fi
  local commits=$(git rev-list --count HEAD ^$parent)
  if [ "$commits" -lt "1" ]; then
    git_cmd_err "no commits to rebase"
    return
  fi
  if [ "$commits" -gt "40" ] && [ "$1" != "-y" ]; then
    git_cmd_confirm "Are you sure you want to rebase $commits commits?" || return
  fi

  git_cmd rebase -i HEAD~$commits
}
alias gbrebase='git_rebase_branch'

# gbsquash
# git_squash_branch
#   Squash branch (automatically) via interactive rebase.
#   If commits beginning with 'drop: ' are found, the
#   option to automatically drop them is given.
function git_squash_branch() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return

  # count commits in branch
  local parent=$(git_find_parent_branch)
  if [ -z $parent ]; then
    false
    return
  fi
  local commits=$(git rev-list --count HEAD ^$parent)
  if [ "$commits" -lt "2" ]; then
    git_cmd_err "no commits to squash"
    return
  fi

  # drop 'drop:' conventional commits first
  local commits_to_drop=$(git log -n $commits --pretty=format:%s | grep -c '^drop: ')
  if [ "$commits_to_drop" -gt "0" ]; then
    if [ "$1" == "-y" || git_cmd_confirm "Drop $commits_to_drop commit(s) in current branch?" ]; then
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
    git_cmd_confirm "Squash $commits commits?" || return
  fi

  GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i 's/pick/squash/g;0,/^squash /s//pick /'" git rebase -i HEAD~$commits
}
alias gbsquash='git_squash_branch'

# gbdd
# git_drop_drop_commits
#   Drop all commits in current branch with commit
#   messages beginning with 'drop: '.
function git_drop_drop_commits() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  if [ -z $parent ]; then
    false
    return
  fi
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
    git_cmd_confirm "Drop $commits_to_drop commit(s) in current branch?" || return
  fi

  GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i '/ drop: / s/pick /drop /g'" git rebase -i HEAD~$commits
}
alias gbdd='git_drop_drop_commits'

# gbreset
# git_reset_branch
#   Soft reset and unstage all commits on current branch.
function git_reset_branch() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  if [ -z $parent ]; then
    false
    return
  fi
  local commits=$(git rev-list --count HEAD ^$parent)

  if [ "$commits" -lt "1" ]; then
    git_cmd_err "no commits to reset"
    return
  fi
  if [ "$commits" -gt "30" ] && [ "$1" != "-y" ]; then
    git_cmd_confirm "Are you sure you want to reset $commits commits?" || return
  fi

  # go back
  git_cmd reset --soft HEAD~$commits
  # and then unstage
  git_cmd reset
}
alias gbreset='git_reset_branch'

# gsquash <n>
# git_squash <n>
#   Automatically squash `n` commits via interactive rebase.
function git_squash() {
  git_cmd_help $1 && return

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
    git_cmd_confirm "Are you sure you want to squash $1 commits?" || return
  fi

  GIT_SEQUENCE_EDITOR="$SED_PORTABLE -i 's/pick/squash/g;0,/^squash /s//pick /'" git rebase -i HEAD~$1
}
alias gsquash='git_squash'

# grf
# grop
# git_rebase_forward
#   Rebase current branch onto parent branch based
#   on search for parent branch.
#  
#         A---B---C current-branch
#        /
#   D---E---F---G parent
#           ==>
#                 A'--B'--C' current-branch
#                /
#   D---E---F---G parent
#   _______________________________________
#  
#           A---B current-branch
#          /
#         C---D release-7
#        /
#   E---F---G main
#         ==>
#               A'---B' current-branch
#              /
#         C---D release-7
#        /
#   E---F---G main
function git_rebase_forward() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return

  local parent=$(git_find_parent_branch)
  if [ -z $parent ]; then
    false
    return
  fi
  local remote=$(git config branch.$parent.remote)
  git_cmd pull --rebase $remote $parent:$parent
  git_cmd rebase $remote/$parent
}
alias grf='git_rebase_forward'
alias grop='git_rebase_forward'

# grom
# git_rebase_on_main
#   Rebase current branch onto main branch.
#   
#         A---B---C current-branch
#        /
#   D---E---F---G main
#           ==>
#                 A'--B'--C' current-branch
#                /
#   D---E---F---G main
#   _______________________________________
#   
#           A---B current-branch
#          /
#         C---D another-branch
#        /
#   E---F---G main
#         ==>
#           C---D another-branch
#          /
#         /   C'--A'--B' current-branch
#        /   /
#   E---F---G main
function git_rebase_on_main() {
  git_cmd_help $1 && return

  git_cmd_branch_protection_main || return

  local remote=$(git config branch.$(git_main_branch).remote)
  git_cmd pull --rebase $remote $(git_main_branch):$(git_main_branch)
  git_cmd rebase $(git_main_branch)
}
alias grom='git_rebase_on_main'

# grob <search_string>
# git_rebase_on_branch <search_string>
#   Rebase current branch onto another branch by search string.
function git_rebase_on_branch() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return

  local branch=$(git_find_branch $1)
  if [ -n "$branch" ]; then
    local remote=$(git config branch.$(branch).remote)
    git_cmd pull --rebase $remote $branch:$branch
    git_cmd rebase $branch
  fi
}
alias grob='git_rebase_on_branch'

# grn <n>
# git_reset <n>
#   Soft reset and unstage `n` commits back from HEAD.
function git_reset() {
  git_cmd_help $1 && return

  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    git_cmd_err "missing number of commits argument"
    return
  fi
  # go back
  git_cmd reset --soft HEAD~$1
  # and then unstage
  git_cmd reset
}
alias grn='git_reset'

# gwip
# git_wip
#   Commit all current changes to WIP commit.
function git_wip() {
  git_cmd_help $1 && return

  git_cmd add -A
  git_cmd commit --no-verify -m "WIP"
}
alias gwip='git_wip'

# gunwip
# git_wip_undo
#   Reset last commit if message contains 'WIP'.
function git_wip_undo() {
  git_cmd_help $1 && return

  git log -n 1 --pretty=format:%s | grep -q -c "WIP" && git_reset 1
}
alias gunwip='git_wip_undo'

# git_branch_has_remote <branch_name>
#   Return whether a branch has a remote set.
function git_branch_has_remote() {
  git_cmd_help $1 && return

  local remote=$(git config branch.$1.remote)
  ! [ -z $remote ] && return
  false
}

# gshortstatnoimg <commit_sha> <another_commit_sha>
# git_short_stat_no_images <commit_sha> <another_commit_sha>
#   Return a short stat diff, filtering out common image filetypes.
function git_short_stat_no_images() {
  git_cmd_help $1 && return

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
alias gshortstat='git_cmd --no-pager diff --shortstat'

# gdroplast
# git_drop_last
#   Drop (hard reset) the last commit back from HEAD.
function git_drop_last() {
  git_cmd_help $1 && return

  git_cmd_branch_protection || return
  git_cmd reset --hard HEAD^
}
alias gdroplast='git_drop_last'

# gtp <tag_name>
# git_tag_push <tag_name>
#   Push current branch, then push tag.
function git_tag_push() {
  git_cmd_help $1 && return

  if [ -z "$1" ]; then
    git_cmd_err "missing argument for tag to push"
    return
  fi

  git_cmd push
  git_cmd push origin $1
}
alias gtp='git_tag_push'

# gmt <tag_name>
# git_move_tag <tag_name>
#   Move a tag from one commit to another, both
#   locally and on origin.
function git_move_tag() {
  git_cmd_help $1 && return

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
  git_cmd tag -d $tag_name
  git_cmd push origin :refs/tags/$tag_name
  git_cmd tag $tag_name
  git_cmd push
  git_cmd push origin $tag_name
}
alias gmt='git_move_tag'

# git_develop_branch
#   Get the name of the first develop branch found.
function git_develop_branch() {
  git_cmd_help $1 && return

  local branches=( $(git rev-parse --symbolic --branches | grep ^dev) )
  if [[ ${#branches[@]} -gt 1 ]]; then
    git_cmd_err "multiple dev branches found"
    if [ ${#branches[@]} -lt 11 ]; then
      printf "\e[33m$(echo "$branches" | sed 's/^/  /g')\e[0m\n" >&2
    fi
    return
  elif [[ ${#branches[@]} -lt 1 ]]; then
    git_cmd_err "no dev branch found"
    return
  fi

  echo ${branches[1]}
}

# grename <new_branch_name>
# grename <branch_name> <new_branch_name>
# git_rename_branch <branch_name> <new_branch_name>
#   Rename a branch both locally and on origin.
function git_rename_branch() {
  git_cmd_help $1 && return

  local old=''
  local new=''
  if [[ -n "$1" && -n "$2" ]]; then
    old=$1
    new=$2
    if ! git show-ref --verify --quiet refs/heads/$old; then
      git_cmd_err "branch \"$old\" not found"
      return
    fi
  elif [[ -n "$1" && -z "$2" ]]; then
    old=$(git branch --show-current)
    new=$1
  else
    git_cmd_err "usage: grename old_branch new_branch || grename new_branch"
    return
  fi

  # rename branch locally
  git_cmd branch -m "$old" "$new"

  # rename branch in all remotes
  local remotes=( $(git remote) )
  for remote in "${remotes[@]}"; do
    if git ls-remote --exit-code --heads $remote "$old" >/dev/null; then
      if git_cmd push origin :"$old"; then
        git_cmd push --set-upstream $remote "$new"
      fi
    fi
  done
}
alias grename='git_rename_branch'

# git_main_branch
#   Get the name of the main branch.
function git_main_branch() {
  git_cmd_help $1 && return

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

# git_backup_branch <backup_name>
# gbb <backup_name>
#   Backup current branch.
function git_backup_branch() {
  if [[ -z "$1" ]]; then
    git_cmd_err "must supply backup name"
  fi

  local current=$(git branch --show-current)

  git_cmd checkout -b $1
  git_cmd switch $current
}
alias gbb='git_backup_branch'

#---------------------------- aliases ----------------------------

# most of these are from oh-my-zsh

# git tag
alias gt='git tag'
# git pull --rebase
alias gl='git_cmd pull --rebase'

# git add
alias ga='git_cmd add'
# git add --all
alias gaa='git_cmd add --all'
# git add --patch
alias gapa='git_cmd add --patch'
# git add --patupdatech
alias gau='git_cmd add --update'
# git add --verbose
alias gav='git_cmd add --verbose'

# git checkout -b
alias gcb='git_cmd checkout -b'
# git checkout (main branch)
alias gcm='git_cmd checkout $(git_main_branch)'
# git checkout
alias gco='git_cmd checkout'
# git checkout (dev branch)
alias gcd='git_cmd checkout $(git_develop_branch)'
# git checkout (parent branch)
alias gcpb='git_cmd switch $(git_find_parent_branch)'

# git branch
alias gb='git_cmd branch'
# git branch -a
alias gba='git_cmd branch -a'
# git branch -d
alias gbd='git_cmd branch -d'
# git branch -D
alias gbD='git_cmd branch -D'
# git branch --no-merged
alias gbnm='git_cmd branch --no-merged'
# git branch --remote
alias gbr='git_cmd branch --remote'

# git blame -b -w
alias gbl='git_cmd blame -b -w'

# git bisect
alias gbs='git_cmd bisect'
# git bisect bad
alias gbsb='git_cmd bisect bad'
# git bisect good
alias gbsg='git_cmd bisect good'
# git bisect reset
alias gbsr='git_cmd bisect reset'
# git bisect start
alias gbss='git_cmd bisect start'

# git commit -v
alias gc='git_cmd commit -v'
# git commit -v -a
alias gca='git_cmd commit -v -a'
# git commit --amend
alias gcam='git_cmd commit --amend'
# git commit -m
alias gcmsg='git_cmd commit -m'

# git config --list
alias gcf='git_cmd config --list'

# git clone --recurse-submodules
alias gcl='git_cmd clone --recurse-submodules'

# git shortlog -sn
alias gcount='git_cmd shortlog -sn'

# git cherry-pick
alias gcp='git_cmd cherry-pick'
# git cherry-pick --abord
alias gcpa='git_cmd cherry-pick --abort'
# git cherry-pick --continue
alias gcpc='git_cmd cherry-pick --continue'

# git fetch
alias gf='git_cmd fetch'
# git fetch origin
alias gfo='git_cmd fetch origin'
# git fetch --all
alias gfa='git_cmd fetch --all'
# git fetch --prune
alias gfprune='git_cmd fetch --prune'

# git ls-files | grep [..]
alias gfg='git ls-files | grep'

alias gignore='git_cmd update-index --assume-unchanged'
alias gunignore='git_cmd update-index --no-assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'

# git diff
alias gd='git_cmd diff'
# git diff --cached
alias gdca='git_cmd diff --cached'
# git diff --cached --word-diff
alias gdcw='git_cmd diff --cached --word-diff'
# git diff --staged
alias gds='git_cmd diff --staged'
# git diff @{upstream}
alias gdup='git_cmd diff @{upstream}'
# git diff --word-diff
alias gdw='git_cmd diff --word-diff'

alias gdct='git_cmd describe --tags $(git rev-list --tags --max-count=1)'

# git log --stat
alias glg='git_cmd log --stat'
# git log --stat -p
alias glgp='git_cmd log --stat -p'
# git log --graph
alias glgg='git_cmd log --graph'
# git log --graph --decorate --all
alias glgga='git_cmd log --graph --decorate --all'
# git log --graph --max-count=10
alias glgm='git_cmd log --graph --max-count=10'
# git log --oneline --decorate
alias glo='git_cmd log --oneline --decorate'
# git log --oneline --decorate --graph
alias glog='git_cmd log --oneline --decorate --graph'
# git log --oneline --decorate --graph --all
alias gloga='git_cmd log --oneline --decorate --graph --all'
# git log --graph (--pretty)
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
# git log --graph (--pretty) --stat
alias glols="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat"
# git log --graph (--pretty) --all
alias glola="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all"
# git log --graph (--pretty)
alias glod="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'"
# git log --graph (--pretty) --date=short
alias glods="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --date=short"

# git merge
alias gm='git_cmd merge'
# git merge origin/(main branch)
alias gmom='git_cmd merge origin/$(git_main_branch)'
# git merge upstream/(main branch)
alias gmum='git_cmd merge upstream/$(git_main_branch)'
# git merge --abort
alias gma='git_cmd merge --abort'

alias gmtl='git_cmd mergetool --no-prompt'
alias gmtlvim='git_cmd mergetool --no-prompt --tool=vimdiff'

# git push
alias gp='git_cmd push'
# git push --dry-run
alias gpd='git_cmd push --dry-run'
# git push upstream
alias gpu='git_cmd push upstream'

# git rebase
alias grb='git_cmd rebase'
# git rebase -i
alias grbi='git_cmd rebase -i'
# git rebase --abort
alias grba='git_cmd rebase --abort'
# git rebase --continue
alias grbc='git_cmd rebase --continue'
# git rebase --skip
alias grbs='git_cmd rebase --skip'

# cd to top level of current git repo
alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'

# git status -sb
alias gsb='git_cmd status -sb'
# git status -s
alias gss='git_cmd status -s'
# git status
alias gst='git_cmd status'

# git show
alias gsh='git_cmd show'
# git show --pretty=short --show-signature
alias gsps='git_cmd show --pretty=short --show-signature'

# git submodule init
alias gsi='git_cmd submodule init'
# git submodule update
alias gsu='git_cmd submodule update'

# git switch
alias gsw='git_cmd switch'
# git switch -c
alias gswc='git_cmd switch -c'
# git switch (main branch)
alias gswm='git_cmd switch $(git_main_branch)'
# git switch (main branch)
alias gswd='git_cmd switch $(git_develop_branch)'
# git switch (parent branch)
alias gswp='git_cmd switch $(git_find_parent_branch)'

# git tag -s
alias gts='git_cmd tag -s'
alias gtv='git_cmd tag | sort -V'
alias gtl='gtl(){ git tag --sort=-v:refname -n -l "${1}*" }; noglob gtl'

alias gupv='git_cmd pull --rebase -v'
alias gupom='git_cmd pull --rebase origin $(git_main_branch)'
alias gupomi='git_cmd pull --rebase=interactive origin $(git_main_branch)'
alias glum='git_cmd pull upstream $(git_main_branch)'

alias gwch='git_cmd whatchanged -p --abbrev-commit --pretty=medium'
