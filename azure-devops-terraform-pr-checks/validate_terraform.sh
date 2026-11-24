#!/usr/bin/env bash
#
# PR check: run `terraform fmt -check`, `terraform init -backend=false` and
# `terraform validate` on every Terraform stack folder a pull request touches.
# Fails the run (and so blocks the PR, when the branch policy is Required) if
# any stack fails. Run by terraform-validate.yml from the repo root.
#
# No cloud credentials needed: -backend=false never touches state, and
# validate never reads tfvars or calls a provider API. `init` still downloads
# providers and modules, so the agent needs to reach the Terraform registry
# (or your mirror) and any private module source.
#
# Environment:
#   SYSTEM_PULLREQUEST_TARGETBRANCH  required, e.g. refs/heads/main (set by the
#                                    pipeline from $(System.PullRequest.TargetBranch))
#   STACK_DEPTH                      optional, default 2: how many leading path
#                                    parts name a stack folder. With 2,
#                                    Application/my-app/modules/x/main.tf
#                                    validates Application/my-app. Use 0 to
#                                    validate each changed file's own folder.

set -uo pipefail

STACK_DEPTH="${STACK_DEPTH:-2}"

log_issue() {
  # Azure Pipelines error annotation, shown as the failure reason on the PR.
  echo "##vso[task.logissue type=error]${1//$'\n'/ | }"
}

fail() {
  echo "error: $1" >&2
  log_issue "$1"
  exit 1
}

[[ -n "${SYSTEM_PULLREQUEST_TARGETBRANCH:-}" ]] \
  || fail "SYSTEM_PULLREQUEST_TARGETBRANCH is not set (this script is meant to run on a PR build)"
[[ "${STACK_DEPTH}" =~ ^[0-9]+$ ]] || fail "STACK_DEPTH must be a whole number, got '${STACK_DEPTH}'"

target_branch="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"

# Added or modified files only: a PR that only deletes a stack has nothing to validate.
echo "+ git diff --name-only --diff-filter=AM origin/${target_branch}...HEAD"
changed="$(git diff --name-only --diff-filter=AM "origin/${target_branch}...HEAD")" \
  || fail "git diff against origin/${target_branch} failed (does the checkout use fetchDepth: 0?)"

stacks=()
while IFS= read -r path; do
  [[ -z "$path" || "$path" != *.tf ]] && continue
  if [[ "${STACK_DEPTH}" -eq 0 ]]; then
    stacks+=("$(dirname "$path")")
    continue
  fi
  IFS='/' read -r -a parts <<< "$path"
  # The file must sit inside a stack folder, not at or above it.
  (( ${#parts[@]} > STACK_DEPTH )) || continue
  stacks+=("$(IFS='/'; echo "${parts[*]:0:STACK_DEPTH}")")
done <<< "$changed"

if [[ "${#stacks[@]}" -eq 0 ]]; then
  echo "no Terraform stack folders touched, nothing to validate"
  exit 0
fi
mapfile -t stacks < <(printf '%s\n' "${stacks[@]}" | sort -u)
echo "stack folder(s) touched (${#stacks[@]}): ${stacks[*]}"

command -v terraform >/dev/null 2>&1 || fail "terraform not found on this agent"
echo "+ terraform version"
terraform version

errors=()
for stack in "${stacks[@]}"; do
  echo "##[section]${stack}"
  step=""
  if ! (cd "$stack" && echo "+ terraform fmt -check -recursive" && terraform fmt -check -recursive); then
    step="fmt"
  elif ! (cd "$stack" && echo "+ terraform init -backend=false -input=false" && terraform init -backend=false -input=false); then
    step="init"
  elif ! (cd "$stack" && echo "+ terraform validate" && terraform validate); then
    step="validate"
  fi
  if [[ -n "$step" ]]; then
    msg="${stack}: ${step} failed"
    [[ "$step" == fmt ]] && msg="${msg}, run 'terraform fmt -recursive' and commit the result"
    echo "  [BLOCKED] ${msg}"
    errors+=("${msg}")
  else
    echo "  [ok] ${stack}"
  fi
done

if [[ "${#errors[@]}" -gt 0 ]]; then
  fail "$(printf '%s\n' "${errors[@]}")"
fi
echo "all touched stacks passed fmt, init and validate"
