# Azure DevOps: Terraform PR validation checklist

A setup checklist for making every pull request in an Azure Repos Terraform repo run `terraform fmt -check`, `terraform init -backend=false` and `terraform validate` on the stacks it touches, and block the merge if they fail.

Derived from a setup I built and ran in my own homelab Azure DevOps organization (onboarding generator + application Terraform repo, with release branches and per-environment plans). The two starter files here are a cut-down, org-neutral copy of that pipeline: the script was tested locally against a scratch git repo (docs-only, valid, bad fmt, validate error), **not yet run as an Azure Pipelines job in this form**. Fire-test it (step 6) before relying on it.

## Files

| File | What it is |
| --- | --- |
| [`terraform-validate.yml`](terraform-validate.yml) | The pipeline: checks out the repo with full history, installs Terraform if missing, runs the script. |
| [`validate_terraform.sh`](validate_terraform.sh) | Diffs the PR against its target branch, maps changed `.tf` files to stack folders, runs fmt / init / validate per stack, fails with a reason per stack. |

## How it works

- A **Build Validation branch policy** on the target branch is what queues the pipeline on every PR. For Azure Repos, the YAML `pr:` trigger is ignored, so the YAML sets `pr: none` and relies on the policy.
- It runs on **every** PR into that branch, whoever opened it: a person, a bot or a generator pipeline.
- No cloud credentials: `-backend=false` never touches state, and `validate` never reads tfvars or calls a provider API.
- Only stacks with an added or modified `.tf` file are checked. A file under a stack's `modules/` folder counts as that stack.

## Checklist

### 1. Decide before copying

- [ ] **Repo layout.** One folder per stack, and how deep? `STACK_DEPTH=2` fits `<Account|Application>/<stack>/...`; `1` fits `<stack>/...`; `0` validates each changed file's own folder (use only if every folder with `.tf` files can be initialised on its own).
- [ ] **Target branches.** Just `main`, or also `release/*` (or similar)? Every branch PRs merge into needs the policy.
- [ ] **Agents.** Microsoft-hosted, or a self-hosted pool? Self-hosted agents behind a proxy must reach `apt.releases.hashicorp.com` (or have Terraform pre-installed) and `registry.terraform.io` (or your provider mirror), because `init` still downloads providers.
- [ ] **Terraform version.** Pinned in your team? If so, pin it in the install step instead of taking the latest.
- [ ] **Module sources.** Modules in private Azure Repos need git auth during `init`: set `persistCredentials: true` on the checkout, or configure an extraheader with `$(System.AccessToken)`.

### 2. Add the files

- [ ] Copy `terraform-validate.yml` and `validate_terraform.sh` into the Terraform repo (for example under `pipelines/`).
- [ ] Fix the script path in the YAML's last step if it isn't `pipelines/validate_terraform.sh`.
- [ ] Set `STACK_DEPTH` and the `pool`.
- [ ] Commit through a PR like any other change.

### 3. Register the pipeline

- [ ] Pipelines → New pipeline → Azure Repos Git → the repo → Existing Azure Pipelines YAML file → pick `terraform-validate.yml` → Save (no need to run).
- [ ] Rename it to something readable, e.g. `<repo>-terraform-validate`. That's the name the policy and PR show.

### 4. Add the branch policy

- [ ] Repos → Branches → target branch → … → Branch policies → **Build Validation** → **+**.
  - Build pipeline: the one from step 3
  - Trigger: **Automatic**
  - Policy requirement: **Required**
  - Build expiration: **Immediately when the target branch is updated**
  - Display name: e.g. `Terraform validate`
  - Path filter (optional): include everything, then exclude what shouldn't queue it, e.g. `/*; !/docs/*; !/pipelines/*; !/README.md`. Start with `/*` and begin every path with `/` (this is the form my homelab policy uses).
- [ ] For a branch pattern such as `release/*`: Project settings → Repositories → Policies → **Add branch protection** → pattern `release/*`, then the same Build Validation settings. This covers branches that don't exist yet.
- [ ] Make sure a **minimum reviewers** (or other required) policy exists too. A required policy is also what makes a direct `git push` to the branch get rejected.

### 5. Decide who can override it

- [ ] Grant **"Bypass policies when completing pull requests"** to a small group only (e.g. DevOps leads): Project settings → Repositories → the repo → Security.
  - Use: PR → Complete → **Override branch policies and enable merge** → enter a reason (kept on the PR).
  - It overrides **every** policy on the branch, required reviewers included.
  - Meant for when the *check* is the problem (agent outage, a change it shouldn't apply to), not for merging Terraform that doesn't validate: that fails again at deploy time.
- [ ] Grant **"Bypass policies when pushing"** to nobody. It skips the PR, the check, the review and the reason.

### 6. Fire-test

Use throwaway branches and abandon the PRs afterwards.

- [ ] **Valid change** to one stack: the check runs, `[ok] <stack>`, the PR can complete.
- [ ] **Unformatted `.tf`** (e.g. remove an indent): blocked with `fmt failed, run 'terraform fmt -recursive' and commit the result`.
- [ ] **Validate error** (e.g. reference an undeclared `var.missing`): blocked with `validate failed`.
- [ ] **Docs-only PR:** skipped by the path filter, or passes with `no Terraform stack folders touched`.
- [ ] **Two stacks in one PR:** both listed, each checked.
- [ ] **Bypass** once on a throwaway PR, to see what the override and its reason look like.

## What this does not check

- **tfvars values.** `validate` checks the code, not values: a wrong type, a missing required variable or a bad value only shows up in a `terraform plan` with that environment's tfvars. If tfvars live in a separate repo or store, changes there need their own check (syntax, keys against `variables.tf`, or a plan).
- **What the change will do.** That's `terraform plan` against real state, which needs read-only cloud credentials per environment. A sensible next step once validate is stable: a plan pipeline queued after validate passes, posting the plan as a PR comment.
- **Anything at deploy time:** permissions, quotas, naming conflicts.

## Later, if needed

- **Plans on PRs.** A read-only plan role per account, credentials in a variable group, the Build Service allowed to queue the plan pipeline, and a map from target branch to the environments a PR may plan.
- **A central pipelines repo.** Move pipelines out of the Terraform repo once you have long-lived release branches: with the YAML in the same repo, a PR runs its own branch's copy, so every pipeline change has to land on every live branch. Trade-off: one pipeline for all branches, plus repository resources and a one-time Permit per pipeline.
- **A skip keyword** (e.g. `Skip validation: <reason>` in the PR description). Not built into Azure DevOps; would need the script to read the PR through the REST API, require a reason, allow only a named group, and show who skipped and why in the PR. The built-in bypass (step 5) is usually enough.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `git diff against origin/<branch> failed` | The checkout is shallow. Keep `fetchDepth: 0`. |
| `terraform not found on this agent` | The install step was removed or failed; on self-hosted agents, check the agent can reach HashiCorp's apt repo, or pre-install Terraform. |
| `init` fails on a module source | Private module repo without auth (see step 1), or the agent can't reach the registry. |
| The check doesn't appear on a PR | No policy on that target branch (a new release branch without a pattern policy), or the path filter excluded every changed file. |
| The check passes but nothing was validated | No `.tf` file changed, or `STACK_DEPTH` is deeper than your layout (files sit at or above the stack level and are skipped). |
