#!/bin/bash
# chmod +x ./update-env.sh

set -e

full_script_name=$0
environment_folder_name=".environment"
environment_ignored_subfolder_name='.ignored'

script_filename=$(basename "$0")
script_filename_no_ext=$(basename "$0" .sh)
lock_filename="${script_filename_no_ext}.lock"
ignore_filename="${script_filename_no_ext}.ignore"

echo -e "Setup started..." > "$lock_filename"

start_gitignore_section_line="# @start Managed by $script_filename"
env_gitignore_section_line="# @env ------------------------"
files_gitignore_section_line="# @files ----------------------"
end_gitignore_section_line="# @end Managed by $script_filename"

declare -a files_checked_and_added_to_git
declare -a files_checked_and_removed_from_git

pending_general_gitignore_lines=()

# This step is only needed for Expo React Native projects that use EAS Build.
# `is_expo_project` facilitates the manual sync between .easignore file and the contents of .gitignore file.
# Without manually updating .easignore, all files excluded from .gitignore would also be excluded from EAS Build.
expo_app_config_files=(".easignore" "app.json" "app.config.js" "app.config.ts")
is_expo_project=0
for file in "${expo_app_config_files[@]}"; do
  if [[ -e "$file" ]]; then
    is_expo_project=1
    break
  fi
done

declare -a pending_add_gitignore_lines
declare -a pending_remove_gitignore_lines
pending_remove_gitignore_lines+=("$start_gitignore_section_line")
pending_remove_gitignore_lines+=("$env_gitignore_section_line")
pending_remove_gitignore_lines+=("$files_gitignore_section_line")
pending_remove_gitignore_lines+=("$end_gitignore_section_line")

################################################################################
################################################################################
################################################################################
################################################################################
################################################################################

# @start - Logger
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_line() {
  echo -e "$1" >> "$lock_filename"
}
log_indent_line() {
  log_line "  > $1"
}
log_double_indent_line() {
  log_line "    > $1"
}
log_line_done() {
  log_indent_line "done"
}
log_line_skip() {
  log_indent_line "skip"
}
# @end - Logger

# @start - Git
git_pending_add_to_ignored() {
  local line="$1"
  local found=0
  for item in "${pending_add_gitignore_lines[@]}"; do
    if [[ "$item" == "$line" ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    pending_add_gitignore_lines+=("$line")
  fi
}
git_pending_remove_from_ignored() {
  local line="$1"
  local found=0
  for item in "${pending_remove_gitignore_lines[@]}"; do
    if [[ "$item" == "$line" ]]; then
      found=1
    fi
  done
  if [[ $found -eq 0 ]]; then
    pending_remove_gitignore_lines+=("$line")
  fi
}
git_utils_remove_line_from_gitignore() {
  local line="$1"

  # Escape special characters in the line to avoid issues with sed
  escaped_line=$(printf '%s\n' "$line" | sed 's/[&/\]/\\&/g')

  # For patterns like .env*.local, we need to escape * as well
  escaped_line=$(printf '%s\n' "$escaped_line" | sed 's/\*/\\*/g')

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses -i '' for in-place editing without a backup
    sed -i '' "/^$escaped_line$/d" .gitignore
  else
    # Linux and other Unix-like systems use -i directly
    sed -i "/^$escaped_line$/d" .gitignore
  fi
}
git_add_file() {
  if ! git ls-files --error-unmatch "$1" > /dev/null 2>&1; then
    log_line ".git add $1..."
    git add "$1"
    log_line_done
  fi
  files_checked_and_added_to_git+=("$1")
  git_pending_remove_from_ignored "$1"
}
git_remove_file() {
  if git ls-files --error-unmatch "$1" > /dev/null 2>&1; then
    log_line ".git remove $1..."
    git rm -q -r --cached "$1"
    log_line_done
  fi
  files_checked_and_removed_from_git+=("$1")
  git_pending_add_to_ignored "$1"
}
# @end - Git

# @start - .gitignore
update_gitignore() {
  if [ ! -f ".gitignore" ]; then
    log_line "Create .gitignore file..."
    touch ".gitignore"
    log_line_done
  fi
  git_add_file ".gitignore"

  log_line ".gitignore update..."
  for line in "${pending_remove_gitignore_lines[@]}"; do
    git_utils_remove_line_from_gitignore "$line"
  done
  for line in "${pending_general_gitignore_lines[@]}"; do
    git_utils_remove_line_from_gitignore "$line"
  done
  for line in "$@"; do
    git_utils_remove_line_from_gitignore "$line"
    git_utils_remove_line_from_gitignore "!$line"
  done

  for line in "${pending_add_gitignore_lines[@]}"; do
    git_utils_remove_line_from_gitignore "$line"
  done
  if [ ${#pending_add_gitignore_lines[@]} -gt 0 ]; then
    log_indent_line "$start_gitignore_section_line"
    echo -e "\n\n$start_gitignore_section_line" >> .gitignore
    for line in "${pending_general_gitignore_lines[@]}"; do
      echo "$line" >> .gitignore
      log_indent_line "$line"
    done
    echo -e "$env_gitignore_section_line" >> .gitignore
    log_indent_line "$env_gitignore_section_line"
    for line in "${pending_add_gitignore_lines[@]}"; do
      echo "$line" >> .gitignore
      log_indent_line "$line"
    done
    echo -e "$files_gitignore_section_line" >> .gitignore
    log_indent_line "$files_gitignore_section_line"
    for line in "$@"; do
      echo "$line" >> .gitignore
      log_indent_line "$line"
    done
    echo -e "$end_gitignore_section_line\n" >> .gitignore
    log_indent_line "$end_gitignore_section_line"
  fi

  log_indent_line "clean up whitespaces"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Use -i '' and handle empty lines
    sed -i '' '/^$/N;/^\n$/D' .gitignore
  else
    # Linux: Use -i and handle empty lines
    sed -i '/^$/N;/^\n$/D' .gitignore
  fi
  log_line_done
}
# @end - .gitignore

# @start - .easignore
easignore_utils_remove_line_from_easignore() {
  local line="$1"

  # Escape special characters in the line to avoid issues with sed
  escaped_line=$(printf '%s\n' "$line" | sed 's/[&/\]/\\&/g')

  # For patterns like .env*.local, we need to escape * as well
  escaped_line=$(printf '%s\n' "$escaped_line" | sed 's/\*/\\*/g')

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses -i '' for in-place editing without a backup
    sed -i '' "/^$escaped_line$/d" .easignore
  else
    # Linux and other Unix-like systems use -i directly
    sed -i "/^$escaped_line$/d" .easignore
  fi
}
update_easignore_if_necessary() {
  if [[ is_expo_project -eq 1 ]]; then
    if [ ! -f ".easignore" ]; then
      log_line "Create .easignore file..."
      touch ".easignore"
      log_line_done
    fi
    git_add_file ".easignore"

    log_line ".easignore update..."
    gitignore_lines=()
    while IFS= read -r line; do
      gitignore_lines+=("$line")
    done < .gitignore
    for line in "${gitignore_lines[@]}"; do
      easignore_utils_remove_line_from_easignore "$line"
      easignore_utils_remove_line_from_easignore "!$line"
    done

    log_indent_line "copy over all .gitignore entries except for environment files"
    log_indent_line "force include environment files in EAS Build..."
    echo "" >> .easignore
    for line in "${gitignore_lines[@]}"; do
      temp_line="$line"
      for env_file in "$@"; do
        if [[ "$temp_line" == "$env_file" ]]; then
          temp_line="!$temp_line"
          break
        fi
      done
      echo "$temp_line" >> .easignore
      if [[ ! "$temp_line" == "$line" ]]; then
        log_double_indent_line "$temp_line"
      fi
    done
    log_indent_line "clean up whitespaces"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS: Use -i '' and handle empty lines
      sed -i '' '/^$/N;/^\n$/D' .easignore
    else
      # Linux: Use -i and handle empty lines
      sed -i '/^$/N;/^\n$/D' .easignore
    fi
    log_line_done
  fi
}
# @end - .easignore

# @start - Add dynamically ignored files
add_dynamically_ignored_files() {
  if [[ -f "$ignore_filename" && -r "$ignore_filename" ]]; then
    local did_find_lines=0
    local already_showed_first_line=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      did_find_lines=1
      if [[ did_find_lines -eq 1 && already_showed_first_line -eq 0 ]]; then
        already_showed_first_line=1
        log_line "Reading $ignore_filename..."
      fi
      # log_indent_line "$line"
      pending_general_gitignore_lines+=("$line")
    done < "$ignore_filename"
    git_add_file "$ignore_filename"
    if [[ did_find_lines -eq 1 ]]; then
      log_line_done
    fi
  fi
}
# @end - Add dynamically ignored files

# @start - Errors
check_environment_is_provided() {
  if [ "$1" == "$environment_ignored_subfolder_name" ]; then
    log_line "[ERROR] $environment_folder_name/$environment_ignored_subfolder_name cannot be used as an environment name"
    printf "\nFor more details, check the "
    printf "${YELLOW}%s${NC}" "$lock_filename"
    printf " file.\n\n"
    printf "${RED}%s${NC}" "ERROR"
    printf " Please use a different name for the environment.\n\n"
    printf "%s/%s " "$environment_folder_name" "$environment_ignored_subfolder_name"
    printf "${RED}%s${NC}" "is meant to always be ignored by"
    printf " %s\n\n" "$full_script_name"
    exit 1
  fi
  if [ -z "$1" ]; then
    log_line "[ERROR] Invalid environment name provided"
    printf "For more details, check the "
    printf "${YELLOW}%s${NC}" "$lock_filename"
    printf " file.\n"
    printf '\n'
    printf "${RED}%s${NC}" "ERROR"
    printf " Please provide an environment name:\n"
    printf "\t%s " "$full_script_name"
    printf "${RED}%s${NC}" "<environment>"
    printf '\n\n'
    exit 1
  fi
  if [ ! -d "$environment_folder_name" ]; then
    log_line "[ERROR] $environment_folder_name directory needs to exist and contain an environment subfolder containing the environment files"
    printf "\nFor more details, check the "
    printf "${YELLOW}%s${NC}" "$lock_filename"
    printf " file.\n\n"
    printf "${RED}%s${NC}" "ERROR"
    printf " Please make sure "
    printf "${RED}%s${NC}" "$environment_folder_name"
    printf " exists and is a directory\n\n"
    exit 1
  fi
  path_to_new_env_folder="$environment_folder_name/$1"
  if [ ! -d "$path_to_new_env_folder" ]; then
    log_line "[ERROR] Invalid environment name provided. Subfolder should exist and containing the environment files."
    printf "For more details, check the "
    printf "${YELLOW}%s${NC}" "$lock_filename"
    printf " file.\n"
    printf '\n'
    printf "${RED}%s${NC}" "ERROR"
    printf " Please make sure "
    printf "${RED}%s${NC}" "$path_to_new_env_folder"
    printf " exists and is a directory."
    printf '\n\n'
    exit 1
  fi
}
# @end - Errors

################################################################################
################################################################################
################################################################################
################################################################################
################################################################################

log_line "Check $script_filename files..."
add_dynamically_ignored_files
git_add_file "$lock_filename"
git_add_file "$script_filename"

git_remove_file "$environment_folder_name"

log_line "Check environment files and folders..."
check_environment_is_provided "$1"

log_line "Copy environment files to project..."
cd "$path_to_new_env_folder"
env_subfolders=()
while IFS= read -r -d '' subfolder; do
  temp_subfolder=${subfolder#./}
  env_subfolders+=("$temp_subfolder")
done < <(find . -type d ! -name ".*" -print0)
env_files=()
while IFS= read -r -d '' file; do
  temp_file=${file#./}
  env_files+=("$temp_file")
done < <(find . -type f ! -name ".*" -print0)
cd ../..

for folder in "${env_subfolders[@]}"; do
  log_indent_line "found /$folder"
  if [ ! -d "$folder" ]; then
    mkdir "$folder" || true
    log_indent_line "fix missing folder $folder"
  fi
done

for file in "${env_files[@]}"; do
  log_indent_line "found $file"
done
for file in "${env_files[@]}"; do
  if [ -f "$file" ]; then
    if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
      log_indent_line ".git remove $file..."
      git rm -q -r --cached "$file"
    fi
    rm -f "$file" || true
  fi
  cp "$path_to_new_env_folder/$file" "$file" || true
  log_indent_line "project now has $file"
done
log_line_done

update_gitignore "${env_files[@]}"

update_easignore_if_necessary "${env_files[@]}"

log_line "Files actively checked and added to git..."
for file in "${files_checked_and_added_to_git[@]}"; do
  log_indent_line "$file"
done
log_line_done

log_line "Files actively checked and removed from git..."
for file in "${files_checked_and_removed_from_git[@]}"; do
  log_indent_line "$file"
done
log_line_done

printf "Project environment is now ${GREEN}%s${NC}\n" "$1"
log_line "Environment was successfully changed" >> "$lock_filename"