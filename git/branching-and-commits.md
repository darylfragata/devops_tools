# Git Branch & Commit Guidelines

> Cheat sheet for when you forget what to name a branch or how to write a commit. Look it up until it's muscle memory.

## Step 1: What am I doing? → Branch name

Pick the row that matches, copy the format.

| I am... | Branch prefix | Example |
|---|---|---|
| Adding something new | `feature/` | `feature/vpc-module` |
| Fixing a bug | `fix/` | `fix/iam-policy` |
| Writing/updating docs | `docs/` | `docs/update-architecture` |
| Changing CI/CD | `ci/` | `ci/add-terraform-plan` |
| Cleaning up code (no behavior change) | `refactor/` | `refactor/terraform-modules` |
| Changing config/settings | `config/` | `config/update-tags` |
| Preparing a release | `release/YYYY.MM` | `release/2026.08` |

```bash
git checkout -b feature/vpc-module
```

## Step 2: What did I just do? → Commit message

```text
<type>(<scope>): <description>
```

`<scope>` = the module/area you touched (e.g. `vpc`, `iam`). `<description>` = short, lowercase, present tense ("add", not "added").

| Same as branch prefix | Commit type | Example |
|---|---|---|
| `feature/` | `feat` | `feat(vpc): add private subnets` |
| `fix/` | `fix` | `fix(iam): correct lambda policy` |
| `docs/` | `docs` | `docs(terraform): update module guide` |
| `ci/` | `ci` | `ci(terraform): add plan validation` |
| `refactor/` | `refactor` | `refactor(vpc): simplify subnet configuration` |
| `config/` | `chore` | `chore(terraform): update provider` |
| — | `test` | `test(vpc): add subnet validation` |
| — | `revert` | `revert(vpc): revert subnet change` |

**Rule of thumb:** the branch prefix and commit type almost always match. If your branch is `feature/x`, your commits should say `feat(x): ...`.

```bash
git commit -m "feat(vpc): add private subnets"
```

### Scenario: creating/updating a module

Scope = the module name. Type = what you actually did to it.

```bash
# brand new module → feature/ + feat
git checkout -b feature/rds-module
git commit -m "feat(rds): add module scaffold"

# change to an existing module → type matches the change, scope stays the module name
git commit -m "feat(rds): add read replica support"
git commit -m "fix(rds): correct backup retention default"
git commit -m "refactor(rds): simplify variable names"
```

## Everyday flow (copy-paste)

```bash
# 1. start work
git checkout release/2026.08
git pull
git checkout -b feature/vpc-module

# 2. work + commit as you go
git add .
git commit -m "feat(vpc): add private subnets"

# 3. push and open a PR into the release branch
git push -u origin feature/vpc-module
```

PR title = same format as your commit message: `feat(vpc): add private subnets`.

## How branches connect

```text
main                        (always stable)
  └─ release/2026.08         (this month's work)
       └─ feature/vpc-module (your task)
```

1. Branch off the current `release/YYYY.MM` for your work.
2. PR your branch → the release branch.
3. When the release is ready, PR the release branch → `main`.
4. Delete branches once merged.

## If you forget everything else, remember this

```text
new thing        → feat
broken thing     → fix
docs             → docs
pipeline/CI      → ci
cleanup          → refactor
config/deps      → chore
tests            → test
undo             → revert
```

---

## Optional / once it's habit

Skip this section for now — come back once branch + commit naming feels automatic.

**Commit body** (only if the "why" isn't obvious from the description):

```text
feat(vpc): add private subnets

Needed so RDS isn't reachable from the public internet.

Closes #42
```

**Tagging a release** after merging to `main`:

```bash
git tag -a v2026.08.0 -m "release 2026.08"
```
