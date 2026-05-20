<#
.SYNOPSIS
    Syncs configuration files, snippets, history, workspaceStorage, globalStorage, and logs from the old Antigravity IDE folder to the new Antigravity IDE.
.DESCRIPTION
    This script automates the migration and synchronization of user settings and logs from the old Antigravity IDE to the new one.
    It backs up the destination folder before any changes, checks if the IDE is running, and copies all specified directories recursively.
.PARAMETER SourcePath
    The source AppData Roaming directory for Antigravity. Defaults to $env:APPDATA\Antigravity
.PARAMETER DestinationPath
    The destination AppData Roaming directory for Antigravity IDE. Defaults to $env:APPDATA\Antigravity IDE
.PARAMETER DryRun
    If set, prints the operations that would be performed without writing or copying files.
#>
param (
    [string]$SourcePath = "$env:APPDATA\Antigravity",
    [string]$DestinationPath = "$env:APPDATA\Antigravity IDE",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Antigravity IDE Data & Logs Sync Script" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Source:      $SourcePath" -ForegroundColor White
Write-Host "Destination: $DestinationPath" -ForegroundColor White
if ($DryRun) {
    Write-Host "MODE:        [DRY RUN] (No files will be modified)" -ForegroundColor Yellow
} else {
    Write-Host "MODE:        [LIVE SYNC]" -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Validate Source path
if (-not (Test-Path $SourcePath)) {
    Write-Error "Source directory '$SourcePath' does not exist. Migration cannot continue."
    exit 1
}

# 2. Check for running processes
Write-Host "Checking for running Antigravity processes..." -ForegroundColor Cyan
$processes = Get-Process | Where-Object { $_.Name -like "*Antigravity*" -or $_.Path -like "*Antigravity*" }
if ($processes) {
    Write-Host "Warning: The following Antigravity processes are running:" -ForegroundColor Yellow
    $processes | Format-Table Id, Name, Path
    
    if ($DryRun) {
        Write-Host "[Dry-Run] Would prompt user to close running processes." -ForegroundColor Yellow
    } else {
        $choice = Read-Host "Do you want to close these processes automatically? (Y/N)"
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Host "Stopping processes..." -ForegroundColor Yellow
            $processes | Stop-Process -Force
            Start-Sleep -Seconds 2
        } else {
            Write-Warning "Please close the IDE manually and re-run the script."
            exit 1
        }
    }
} else {
    Write-Host "No active Antigravity processes found. Proceeding." -ForegroundColor Green
}

# 3. Create Backup of Destination if it exists
$backupCreated = $false
$newDestinationCreated = $false
$backupPath = $null

if (Test-Path $DestinationPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "${DestinationPath}_backup_$timestamp"
    if ($DryRun) {
        Write-Host "[Dry-Run] Would backup existing destination folder to: $backupPath" -ForegroundColor Yellow
    } else {
        Write-Host "Creating a backup of existing destination to: $backupPath" -ForegroundColor Cyan
        Copy-Item -Path $DestinationPath -Destination $backupPath -Recurse -Force
        $backupCreated = $true
        Write-Host "Backup created successfully." -ForegroundColor Green
    }
} else {
    if ($DryRun) {
        Write-Host "[Dry-Run] Destination directory does not exist. Would create: $DestinationPath" -ForegroundColor Yellow
    } else {
        Write-Host "Destination directory does not exist. Creating: $DestinationPath" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        $newDestinationCreated = $true
    }
}

try {
    # 4. Copy User Configuration Files
    $srcUserDir = Join-Path $SourcePath "User"
    $dstUserDir = Join-Path $DestinationPath "User"
    
    $configFiles = @("settings.json", "keybindings.json", "tasks.json")
    
    if (Test-Path $srcUserDir) {
        if (-not $DryRun -and -not (Test-Path $dstUserDir)) {
            New-Item -ItemType Directory -Path $dstUserDir -Force | Out-Null
        }
        
        foreach ($file in $configFiles) {
            $filePath = Join-Path $srcUserDir $file
            if (Test-Path $filePath) {
                if ($DryRun) {
                    Write-Host "[Dry-Run] Would copy file: $file" -ForegroundColor Yellow
                } else {
                    Write-Host "Copying configuration file: $file..." -ForegroundColor Cyan
                    Copy-Item -Path $filePath -Destination $dstUserDir -Force
                }
            }
        }
    
        # 5. Copy User Configuration Directories
        $configDirs = @("snippets", "History", "workspaceStorage")
        foreach ($dir in $configDirs) {
            $dirPath = Join-Path $srcUserDir $dir
            if (Test-Path $dirPath) {
                if ($DryRun) {
                    Write-Host "[Dry-Run] Would copy directory: $dir" -ForegroundColor Yellow
                } else {
                    Write-Host "Copying directory recursively: $dir..." -ForegroundColor Cyan
                    $targetDir = Join-Path $dstUserDir $dir
                    if (-not (Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }
                    Copy-Item -Path "$dirPath\*" -Destination $targetDir -Recurse -Force
                }
            }
        }
    
        # 6. Copy globalStorage Contents
        $globalStorageSrc = Join-Path $srcUserDir "globalStorage"
        if (Test-Path $globalStorageSrc) {
            $globalStorageDst = Join-Path $dstUserDir "globalStorage"
            if ($DryRun) {
                Write-Host "[Dry-Run] Would copy globalStorage contents" -ForegroundColor Yellow
            } else {
                Write-Host "Copying globalStorage contents recursively..." -ForegroundColor Cyan
                if (-not (Test-Path $globalStorageDst)) {
                    New-Item -ItemType Directory -Path $globalStorageDst -Force | Out-Null
                }
                Copy-Item -Path "$globalStorageSrc\*" -Destination $globalStorageDst -Recurse -Force
            }
        }
    } else {
        Write-Warning "Source User folder '$srcUserDir' not found."
    }
    
    # 7. Copy logs Folder Contents
    $logsSrc = Join-Path $SourcePath "logs"
    if (Test-Path $logsSrc) {
        $logsDst = Join-Path $DestinationPath "logs"
        if ($DryRun) {
            Write-Host "[Dry-Run] Would copy logs folder contents" -ForegroundColor Yellow
        } else {
            Write-Host "Copying logs recursively..." -ForegroundColor Cyan
            if (-not (Test-Path $logsDst)) {
                New-Item -ItemType Directory -Path $logsDst -Force | Out-Null
            }
            Copy-Item -Path "$logsSrc\*" -Destination $logsDst -Recurse -Force
        }
    } else {
        Write-Warning "Source logs folder '$logsSrc' not found."
    }
}
catch {
    Write-Host "An error occurred during synchronization: $_" -ForegroundColor Red
    if (-not $DryRun) {
        Write-Host "Rolling back changes..." -ForegroundColor Yellow
        if ($backupCreated) {
            if (Test-Path $DestinationPath) {
                Remove-Item -Path $DestinationPath -Recurse -Force
            }
            Move-Item -Path $backupPath -Destination $DestinationPath -Force
            Write-Host "Rollback completed. Restored destination from backup: $DestinationPath" -ForegroundColor Green
        } elseif ($newDestinationCreated) {
            if (Test-Path $DestinationPath) {
                Remove-Item -Path $DestinationPath -Recurse -Force
            }
            Write-Host "Rollback completed. Cleaned up destination folder: $DestinationPath" -ForegroundColor Green
        }
    }
    throw $_
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run completed. Run without -DryRun to perform the actual sync." -ForegroundColor Yellow
} else {
    Write-Host "Duplication Successful!" -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Cyan
