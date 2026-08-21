# Tools

Personal scripts for everyday DevOps workflows. Each tool ships as both a
PowerShell (`.ps1`) and Bash (`.sh`) version, and defaults to operating on
the current directory (wherever you run it from) unless `-Path`/`-p` is given.

## Setup

Run the setup script once so tools can be called as a bare command (e.g.
`tfclean plan`) from anywhere, regardless of where you cloned this repo:

```powershell
./setup.ps1
```

```bash
./setup.sh
```

Both are safe to re-run and only touch your shell profile / rc file
(`$PROFILE` for PowerShell, `~/.bashrc` / `~/.zshrc` for bash/zsh) - adding
this `tools/` folder to `PATH` plus a small wrapper so bare command names
work in both shells. See each script's comments for exactly what it does.

## tfclean

Follows the same `plan`/`apply` shape as Terraform itself:

- **plan** - scans the target directory tree and lists every `.terraform/`
  directory, `crash.log`, and `.terraform.tfstate.lock.info` it finds.
  Nothing is deleted.
- **apply** - shows the same list, then asks you to type `yes` before
  deleting anything.

`.terraform.lock.hcl` is skipped by default since it's normally committed to
version control; pass `-IncludeLockFile` / `-l` to include it too.

Invocation is identical across both shells once [Setup](#setup) has run —
only the flag prefix differs (`-Path`/`-IncludeLockFile` vs `-p`/`-l`):

```powershell
tfclean plan                    # preview from the current directory
tfclean apply                   # preview + confirm + delete
tfclean apply -Path C:\infra    # target a specific directory
tfclean apply -IncludeLockFile  # also remove .terraform.lock.hcl
```

```bash
tfclean plan                # preview from the current directory
tfclean apply                # preview + confirm + delete
tfclean apply -p ~/infra     # target a specific directory
tfclean apply -l             # also remove .terraform.lock.hcl
```

Without running setup, call the scripts directly instead (`./tfclean.ps1
plan`, `./tfclean.sh plan`, etc.) - the "Run 'tfclean apply' ..." hint they
print assumes setup has run. Either way, it operates on whatever directory
you're in when you run it, not the script's own location.
