#!/bin/bash

remove_test_projects() {
  local sln_file="$1"
  local temp_file=$(mktemp)

  > "$temp_file"

  while IFS= read -r line; do
    if echo "$line" | grep -qi 'Test'; then
      skip_block=1
    fi
    
    if [[ -z $skip_block ]]; then
      echo "$line" >> "$temp_file"
    fi
    
    if echo "$line" | grep -q 'EndProject'; then
      skip_block=""
    fi
  done < "$sln_file"

  mv "$temp_file" "$sln_file"

  echo "Test projects removed from solution: $sln_file"
}

if [[ -z "$1" ]]; then
  echo "Usage: $0 <path_to_solution_file>"
  exit 1
fi

remove_test_projects "$1"
