#!/usr/bin/env bash

input=$(cat)

model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name')

dir_name=$(basename "$current_dir")

git_info=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null)
  if [[ -n "$branch" ]]; then
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
      git_info="(git:$branch*)"
    else
      git_info="(git:$branch)"
    fi
  fi
fi

parts=("$dir_name")
[[ -n "$git_info" ]] && parts+=("$git_info")
parts+=("[$model_name]")
if [[ "$output_style" != "default" && "$output_style" != "null" ]]; then
  parts+=("{$output_style}")
fi

printf "%s" "${parts[*]}"
