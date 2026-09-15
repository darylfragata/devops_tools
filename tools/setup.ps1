<#
.SYNOPSIS
    Sets up this tools/ folder so scripts like tfclean can be run as a bare
    command (e.g. `tfclean plan`) from anywhere in PowerShell.

.DESCRIPTION
    PowerShell won't resolve a bare command name to a .ps1 file for security
    reasons, so this adds a small wrapper function per tool (currently just
    `tfclean`) to your PowerShell profile ($PROFILE), plus adds this folder
    to PATH for consistency with future tools. Safe to re-run - it won't add
    duplicate entries if already set up.

.EXAMPLE
    ./setup.ps1
#>
[CmdletBinding()]
param()

$toolsPath = $PSScriptRoot
$marker = "# devops_tools tools"

if (-not (Test-Path -Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent.Contains($toolsPath)) {
    Write-Host "Already set up: '$toolsPath' is already referenced in $PROFILE"
    return
}

$block = @"

$marker
`$env:PATH += ";$toolsPath"
function tfclean { & "$toolsPath\tfclean.ps1" @args }
"@

Add-Content -Path $PROFILE -Value $block

# Activate in this session too.
$env:PATH += ";$toolsPath"
function global:tfclean { & "$toolsPath\tfclean.ps1" @args }

Write-Host "Set up '$toolsPath' in $PROFILE"
Write-Host "Restart PowerShell (or run '. `$PROFILE') to use it in new sessions."
Write-Host "It's also active in this session now - try: tfclean plan"
