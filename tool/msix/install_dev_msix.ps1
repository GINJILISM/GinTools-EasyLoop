param(
  [string]$MsixPath,
  [string]$CerPath,
  [switch]$RemoveOld
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

if ([string]::IsNullOrWhiteSpace($MsixPath)) {
  $MsixPath = Join-Path $projectRoot 'build\windows\x64\runner\Release\EasyLoop.msix'
} elseif (-not [System.IO.Path]::IsPathRooted($MsixPath)) {
  $MsixPath = Join-Path $projectRoot $MsixPath
}

if ([string]::IsNullOrWhiteSpace($CerPath)) {
  $CerPath = Join-Path $projectRoot 'tool\msix\certs\EasyLoopDev.cer'
} elseif (-not [System.IO.Path]::IsPathRooted($CerPath)) {
  $CerPath = Join-Path $projectRoot $CerPath
}

function Assert-Admin {
  $current = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($current)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run PowerShell as Administrator and retry.'
  }
}

Assert-Admin

if (-not (Test-Path -LiteralPath $MsixPath)) {
  throw "MSIX file not found: $MsixPath"
}

if (-not (Test-Path -LiteralPath $CerPath)) {
  throw "Certificate file not found: $CerPath"
}

$msix = (Resolve-Path -LiteralPath $MsixPath).Path
$cer = (Resolve-Path -LiteralPath $CerPath).Path

Write-Host 'Importing certificate to LocalMachine Root/TrustedPeople...'
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null

if ($RemoveOld) {
  Write-Host 'Removing previous package if installed...'
  Get-AppxPackage | Where-Object { $_.Name -eq 'com.gintools.loopvideoeditor' } | ForEach-Object {
    Remove-AppxPackage -Package $_.PackageFullName
  }
}

Write-Host "Installing MSIX: $msix"
Add-AppxPackage -Path $msix -ForceApplicationShutdown

Write-Host 'Done: EasyLoop installed successfully.'
