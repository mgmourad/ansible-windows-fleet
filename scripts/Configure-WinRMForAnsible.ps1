<#
.SYNOPSIS
    Configures WinRM for Ansible communication over HTTPS (port 5986).
    Run this on EACH Windows VM before Ansible can manage it.

.DESCRIPTION
    This script:
    1. Enables WinRM service
    2. Creates a self-signed certificate (for lab use)
    3. Creates an HTTPS listener on port 5986
    4. Configures firewall rule to allow WinRM HTTPS
    5. Sets WinRM authentication and service settings
    6. Validates the configuration

.NOTES
    Run as Administrator on each target Windows VM.
    For production, use CA-issued certificates instead of self-signed.

.EXAMPLE
    # Run locally on the Windows VM:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\Configure-WinRMForAnsible.ps1
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [int]$Port = 5986,
    [int]$CertValidityDays = 1095  # 3 years
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  WinRM HTTPS Configuration for Ansible  " -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Enable and configure WinRM service
Write-Host "[1/6] Enabling WinRM service..." -ForegroundColor Yellow
Set-Service -Name WinRM -StartupType Automatic
Start-Service WinRM

# Step 2: Create self-signed certificate
Write-Host "[2/6] Creating self-signed certificate..." -ForegroundColor Yellow
$hostname = $env:COMPUTERNAME
$cert = New-SelfSignedCertificate `
    -DnsName $hostname `
    -CertStoreLocation Cert:\LocalMachine\My `
    -NotAfter (Get-Date).AddDays($CertValidityDays) `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256

Write-Host "  Certificate thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

# Step 3: Remove existing HTTPS listener (if any) and create new one
Write-Host "[3/6] Configuring HTTPS listener on port $Port..." -ForegroundColor Yellow
$existingListener = Get-ChildItem WSMan:\localhost\Listener\ | Where-Object {
    $_.Keys -contains "Transport=HTTPS"
}
if ($existingListener) {
    Remove-Item -Path "WSMan:\localhost\Listener\$($existingListener.Name)" -Recurse -Force
    Write-Host "  Removed existing HTTPS listener" -ForegroundColor DarkYellow
}

New-Item -Path WSMan:\localhost\Listener\ `
    -Transport HTTPS `
    -Address * `
    -CertificateThumbPrint $cert.Thumbprint `
    -Port $Port `
    -Force | Out-Null

Write-Host "  HTTPS listener created on port $Port" -ForegroundColor Green

# Step 4: Configure firewall rule
Write-Host "[4/6] Configuring firewall rule..." -ForegroundColor Yellow
$ruleName = "WinRM-HTTPS-Ansible"
$existingRule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Remove-NetFirewallRule -Name $ruleName
}

New-NetFirewallRule `
    -Name $ruleName `
    -DisplayName "WinRM HTTPS (Ansible)" `
    -Description "Allow inbound WinRM over HTTPS for Ansible management" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort $Port `
    -Action Allow `
    -Profile Domain,Private | Out-Null

Write-Host "  Firewall rule '$ruleName' created" -ForegroundColor Green

# Step 5: Configure WinRM settings
Write-Host "[5/6] Configuring WinRM settings..." -ForegroundColor Yellow
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
Set-Item -Path WSMan:\localhost\Service\MaxMemoryPerShellMB -Value 1024
Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 1024

Write-Host "  WinRM authentication and limits configured" -ForegroundColor Green

# Step 6: Validate
Write-Host "[6/6] Validating configuration..." -ForegroundColor Yellow
$listener = Get-ChildItem WSMan:\localhost\Listener\ | Where-Object {
    $_.Keys -contains "Transport=HTTPS"
}
$service = Get-Service WinRM

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Hostname:     $hostname"
Write-Host "  Port:         $Port"
Write-Host "  Transport:    HTTPS"
Write-Host "  Certificate:  $($cert.Thumbprint)"
Write-Host "  Cert Expires: $($cert.NotAfter.ToString('yyyy-MM-dd'))"
Write-Host "  WinRM Status: $($service.Status)"
Write-Host "  Listener:     $($listener.Name)"
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Test from Ansible control node:" -ForegroundColor Yellow
Write-Host "  ansible windows -m win_ping --ask-vault-pass" -ForegroundColor White
