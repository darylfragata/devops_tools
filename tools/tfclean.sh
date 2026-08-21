#!/usr/bin/env bash
#
# tfclean.sh - Removes Terraform local working files (.terraform directories,
# lock/crash files) from the current directory tree, Terraform-workflow
# style: `plan` previews, `apply` confirms before deleting.
#
# Usage:
#   ./tfclean.sh plan  [-p PATH] [-l]
#   ./tfclean.sh apply [-p PATH] [-l]
#
#   plan      List what would be removed, like `terraform plan`.
#   apply     List what would be removed, then prompt for a typed "yes"
#             before deleting anything, like `terraform apply`.
#   -p PATH   Root directory to search from (default: current directory)
#   -l        Also target .terraform.lock.hcl files (normally kept in VCS)

set -euo pipefail

usage() {
    grep '^#' "$0" | sed -e 's/^#!.*//' -e 's/^# \{0,1\}//'
}

action=""
if [ $# -gt 0 ]; then
    case "$1" in
        plan) action="plan"; shift ;;
        apply) action="apply"; shift ;;
    esac
fi

path="."
include_lock=false

while getopts "p:lh" opt; do
    case "$opt" in
        p) path="$OPTARG" ;;
        l) include_lock=true ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

if [ -z "$action" ]; then
    usage
    exit 1
fi

names=(".terraform" "crash.log" ".terraform.tfstate.lock.info")
if [ "$include_lock" = true ]; then
    names+=(".terraform.lock.hcl")
fi

find_args=()
for i in "${!names[@]}"; do
    [ "$i" -gt 0 ] && find_args+=(-o)
    find_args+=(-name "${names[$i]}")
done

targets=()
while IFS= read -r -d '' item; do
    targets+=("$item")
done < <(find "$path" \( "${find_args[@]}" \) -print0)

if [ "${#targets[@]}" -eq 0 ]; then
    echo "Nothing to clean under '$path'."
    exit 0
fi

echo "The following items would be removed under '$path':"
echo
for t in "${targets[@]}"; do
    echo "  - $t"
done

if [ "$action" = "plan" ]; then
    echo
    echo "Run 'tfclean apply' to remove these items."
    exit 0
fi

echo
read -r -p "Do you want to perform these deletions? Only 'yes' will be accepted: " confirmation
if [ "$confirmation" != "yes" ]; then
    echo "Apply cancelled."
    exit 0
fi

for t in "${targets[@]}"; do
    rm -rf -- "$t"
    echo "Removed: $t"
done
