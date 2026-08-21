<#
.SYNOPSIS
    Removes Terraform local working files (.terraform directories,
    lock/crash files) from the current directory tree, Terraform-workflow
    style: `plan` previews, `apply` confirms before deleting.

.DESCRIPTION
    Recursively finds .terraform directories, crash.log, and
    .terraform.tfstate.lock.info under -Path (default: current directory).

    plan  lists what would be removed and stops there, like `terraform plan`.
    apply lists the same items, then asks for a typed "yes" before deleting
    anything, like `terraform apply`.

.PARAMETER Action
    plan or apply.

.PARAMETER Path
    Root directory to search from. Defaults to the current directory.

.PARAMETER IncludeLockFile
    Also target .terraform.lock.hcl files (normally kept in version control,
    so this is off by default).

.EXAMPLE
    tfclean.ps1 plan

.EXAMPLE
    tfclean.ps1 apply -Path C:\infra -IncludeLockFile
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("plan", "apply")]
    [string]$Action,

    [string]$Path = ".",
    [switch]$IncludeLockFile
)

function Get-CleanupTargets {
    param([string]$Path, [bool]$IncludeLockFile)

    $targets = @()
    $targets += Get-ChildItem -Path $Path -Directory -Filter ".terraform" -Recurse -Force -ErrorAction SilentlyContinue
    $targets += Get-ChildItem -Path $Path -File -Filter "crash.log" -Recurse -Force -ErrorAction SilentlyContinue
    $targets += Get-ChildItem -Path $Path -File -Filter ".terraform.tfstate.lock.info" -Recurse -Force -ErrorAction SilentlyContinue
    if ($IncludeLockFile) {
        $targets += Get-ChildItem -Path $Path -File -Filter ".terraform.lock.hcl" -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $targets
}

if (-not $Action) {
    Write-Host "Usage: tfclean.ps1 plan|apply [-Path <path>] [-IncludeLockFile]"
    return
}

$targets = Get-CleanupTargets -Path $Path -IncludeLockFile:$IncludeLockFile.IsPresent

if (-not $targets) {
    Write-Host "Nothing to clean under '$Path'."
    return
}

Write-Host "The following items would be removed under '$Path':"
Write-Host ""
foreach ($item in $targets) {
    Write-Host "  - $($item.FullName)"
}

if ($Action -eq "plan") {
    Write-Host ""
    Write-Host "Run 'tfclean apply' to remove these items."
    return
}

$confirmation = Read-Host "`nDo you want to perform these deletions? Only 'yes' will be accepted"
if ($confirmation -ne "yes") {
    Write-Host "Apply cancelled."
    return
}

foreach ($item in $targets) {
    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed: $($item.FullName)"
}
