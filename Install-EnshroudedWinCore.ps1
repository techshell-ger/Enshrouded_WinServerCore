# =================================================================================
# Enshrouded Server - Windows Server Core Installer 
# Created by Techshell-Ger (https://github.com/techshell-ger)
# Assistant: Günther Gemini 
# Script inspired by TripodGG (https://github.com/TripodGG)
# =================================================================================

# --- LOGGING CONFIGURATION ---
$LogFile = "Install-EnshWinCore.log"
$LogPath = Join-Path -Path $PWD -ChildPath $LogFile

Function Write-Log {
    Param ([string]$Message, [string]$Type = "INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Full string for the log file
    $LogEntry = "[$TimeStamp] [$Type] $Message"
    $LogEntry | Out-File -FilePath $LogFile -Append
    
    # Clean message for the PowerShell console
    $Color = "White"
    if ($Type -eq "SUCCESS") { $Color = "Green" }
    if ($Type -eq "ERROR")   { $Color = "Red" }
    if ($Type -eq "WARN")    { $Color = "Yellow" }
    
    Write-Host $Message -ForegroundColor $Color
}

Clear-Host

Write-Log "Log File for Installation Progress created: $LogPath" "INFO"

# --- MAIN INPUT LOOP ---
$GlobalConfirm = $false
do {
    Write-Log "Waiting for user input..." "INFO"
    Write-Host "`n --- Enshrouded Server Setup Configuration --- `n" -ForegroundColor Yellow
    
    # 1. Basic Info
    $ServerName = Read-Host "> Enter Server Name"
    if ([string]::IsNullOrWhiteSpace($ServerName)) { $ServerName = "DefaultServerName_Enshrouded" }
    
    $Password = Read-Host "> Enter Server Password"

    # 2. IP Validation
    while ($true) {
        $ServerIP = Read-Host "> Enter Server IP (Default: 0.0.0.0)"
        if ([string]::IsNullOrWhiteSpace($ServerIP)) { $ServerIP = "0.0.0.0"; break }
        $IPRegex = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if ($ServerIP -match $IPRegex) { break }
        Write-Host "`n Invalid IP! Use IPv4 format (0.0.0.0 - 255.255.255.255). `n" -ForegroundColor Red
    }

    # 3. Port Validation Function
    Function Get-ValidPort {
        Param ([string]$Prompt, [string]$Default)
        while ($true) {
            $InputPort = Read-Host "> $Prompt (Default: $Default)"
            if ([string]::IsNullOrWhiteSpace($InputPort)) { return $Default }
            if ($InputPort -match "^\d+$" -and [int]$InputPort -ge 0 -and [int]$InputPort -le 65535) {
                return $InputPort
            }
            Write-Host "`n Invalid Port! Enter a number between 0 and 65535. `n" -ForegroundColor Red
        }
    }
    $GamePort  = Get-ValidPort "Enter Game Port" "15636"
    $QueryPort = Get-ValidPort "Enter Query Port" "15637"

    # 4. Slot Count Validation (Range: 4 - 16)
    while ($true) {
        $SlotCount = Read-Host "> Enter Max Players (Range: 4 - 16, Default: 4)"
        if ([string]::IsNullOrWhiteSpace($SlotCount)) { 
            $SlotCount = "4"
            break 
        }
        if ($SlotCount -match "^\d+$" -and [int]$SlotCount -ge 4 -and [int]$SlotCount -le 16) { 
            break 
        }
        Write-Host "`n Invalid input! Please enter a number between 4 and 16. `n" -ForegroundColor Red
    }

    # 5. Backup Time Validation
    while ($true) {
        $BackupTime = Read-Host "> Enter daily backup time (Format HH:mm, e.g., 03:00)"
        if ([string]::IsNullOrWhiteSpace($BackupTime)) { $BackupTime = "03:00"; break }
        if ($BackupTime -match "^([0-1][0-9]|2[0-3]):([0-5][0-9])$") { break }
        Write-Host "`n Invalid Format! Please use HH:mm (e.g., 04:30). `n" -ForegroundColor Red
    }

    # 6. Directory Configuration
    $SteamCMDPath = "C:\SteamCMD"
    $ServerPath   = "C:\EnshroudedServer"
    $BackupPath   = "C:\EnshroudedBackups"

    Write-Host "`n--- Current Default Directories ---" -ForegroundColor Gray
    Write-Host " SteamCMD: $SteamCMDPath"
    Write-Host " Server:   $ServerPath"
    Write-Host " Backups:  $BackupPath"
    
    $ValidDirInput = $false
    while (-not $ValidDirInput) {
        $EditDefaultDirectory = Read-Host "`n> Do you want to change these Default Directories? (y / n)"
        if ($EditDefaultDirectory -match "^(y|yes|n|no)$") {
            $ValidDirInput = $true
            if ($EditDefaultDirectory -match "^(y|yes)$") {
                Write-Host "`n--- Custom Directory Configuration --- `n" -ForegroundColor Yellow
                $InputSteam = Read-Host "> Enter path for SteamCMD (Enter to keep current)"
                $InputServer = Read-Host "> Enter path for Server Files (Enter to keep current)"
                $InputBackup = Read-Host "> Enter path for Backups (Enter to keep current)"
                if (![string]::IsNullOrWhiteSpace($InputSteam)) { $SteamCMDPath = $InputSteam }
                if (![string]::IsNullOrWhiteSpace($InputServer)) { $ServerPath = $InputServer }
                if (![string]::IsNullOrWhiteSpace($InputBackup)) { $BackupPath = $InputBackup }
            }
        } else { Write-Host "`n Invalid input! Please enter 'y' or 'n'. `n" -ForegroundColor Red }
    }

    # 7. System Validation
    $OSName = (Get-CimInstance Win32_OperatingSystem).Caption
    $AllowedOS = "Windows Server 2016|Windows Server 2019|Windows Server 2022|Windows Server 2025|Windows 10|Windows 11"
    if ($OSName -match $AllowedOS) {
        Write-Log "System Check: $OSName detected." "SUCCESS"
    } else {
        Write-Log "System Check failed: $OSName is not supported." "ERROR"
        exit
    }

    # 8. Final Summary & Confirmation
    Write-Host "`n--- Installation Summary ---" -ForegroundColor Yellow
    Write-Host "Detected OS:   $OSName"
    Write-Host "Server Name:   $ServerName"
    Write-Host "Server PW:     $Password"
    Write-Host "Server IP:     $ServerIP"
    Write-Host "Game Port:     $GamePort (UDP)"
    Write-Host "Query Port:    $QueryPort (UDP)"
    Write-Host "Max Players:   $SlotCount"
    Write-Host "Backup Time:   $BackupTime"
    Write-Host "----------------------------"
    Write-Host "SteamCMD Path: $SteamCMDPath"
    Write-Host "Server Path:   $ServerPath"
    Write-Host "Backup Path:   $BackupPath"
    Write-Host "----------------------------"

    $ValidConfirmInput = $false
    while (-not $ValidConfirmInput) {
        $Confirm = Read-Host "`nProceed with installation? (y / n)"
        if ($Confirm -match "^(y|yes|n|no)$") {
            $ValidConfirmInput = $true
            if ($Confirm -match "^(y|yes)$") {
                $GlobalConfirm = $true
                Write-Log "Installation confirmed. Starting process..." "INFO"
                
                # Extended Logging of chosen configuration
                Write-Log "--------------------------------------------------" "INFO"
                Write-Log "### Configuration Summary for this Installation ###" "INFO"
                Write-Log "OS: $OSName" "INFO"
                Write-Log "Server Name: $ServerName" "INFO"
                Write-Log "Server IP: $ServerIP" "INFO"
                Write-Log "Ports: Game $GamePort / Query $QueryPort" "INFO"
                Write-Log "Max Players: $SlotCount" "INFO"
                Write-Log "Backup Time: $BackupTime" "INFO"
                Write-Log "Paths: SteamCMD: $SteamCMDPath | Server: $ServerPath | Backup: $BackupPath" "INFO"
                Write-Log "--------------------------------------------------" "INFO"
                
            } else {
                Write-Log "User chose to re-enter information." "WARN"
                Clear-Host
                Write-Host "Restarting configuration wizard..." -ForegroundColor Cyan
            }
        } else { Write-Host "`n Invalid input! Please enter 'y' or 'n'. `n" -ForegroundColor Red }
    }
} until ($GlobalConfirm -eq $true)

<#
# --- START INSTALLATION ---
Write-Log "Creating directories..." "INFO"
New-Item -ItemType Directory -Force -Path $SteamCMDPath, $ServerPath, $BackupPath | Out-Null

# Download SteamCMD
Write-Log "Downloading SteamCMD..." "INFO"
try {
    Invoke-WebRequest -Uri "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -OutFile "$SteamCMDPath\steamcmd.zip" -ErrorAction Stop
    Write-Log "SteamCMD download successful." "SUCCESS"
} catch {
    Write-Log "Failed to download SteamCMD: $_" "ERROR"
    exit
}

# Extract SteamCMD
Write-Log "Extracting SteamCMD..." "INFO"
try {
    Expand-Archive -Path "$SteamCMDPath\steamcmd.zip" -DestinationPath $SteamCMDPath -Force -ErrorAction Stop
    Write-Log "SteamCMD extraction successful." "SUCCESS"
} catch {
    Write-Log "Failed to extract SteamCMD: $_" "ERROR"
}

# Install Enshrouded
Write-Log "Running SteamCMD to install Enshrouded... This may take a while." "INFO"
& "$SteamCMDPath\steamcmd.exe" +force_install_dir "$ServerPath" +login anonymous +app_update 2278520 validate +quit

if ($LASTEXITCODE -eq 0) {
    Write-Log "SteamCMD finished successfully (Exit Code 0)." "SUCCESS"
} else {
    Write-Log "SteamCMD finished with non-zero Exit Code: $LASTEXITCODE" "WARN"
}

# Validate Exe
$ExePath = Join-Path -Path $ServerPath -ChildPath "enshrouded_server.exe"
if (Test-Path -Path $ExePath) {
    Write-Log "Validation: enshrouded_server.exe found!" "SUCCESS"
} else {
    Write-Log "Validation FAILED: enshrouded_server.exe NOT found!" "ERROR"
}

# Create Config JSON
Write-Log "Generating enshrouded_server.json..." "INFO"
$ConfigPath = "$ServerPath\enshrouded_server.json"
$ConfigJson = @"
{
    "name": "$ServerName",
    "password": "$Password",
    "saveDirectory": "./savegame",
    "logDirectory": "./logs",
    "ip": "$ServerIP",
    "gamePort": $GamePort,
    "queryPort": $QueryPort,
    "slotCount": $SlotCount
}
"@
try {
    $ConfigJson | Out-File -FilePath $ConfigPath -Encoding utf8 -ErrorAction Stop
    Write-Log "Configuration file saved." "SUCCESS"
} catch {
    Write-Log "Failed to save configuration." "ERROR"
}

# Backup Task
Write-Log "Creating backup task for $BackupTime..." "INFO"
try {
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Compress-Archive -Path '$ServerPath\savegame' -DestinationPath '$BackupPath\Backup_$(Get-Date -Format 'yyyyMMdd_HHmm').zip' -Force`""
    $Trigger = New-ScheduledTaskTrigger -Daily -At $BackupTime
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
    Register-ScheduledTask -TaskName "EnshroudedBackupTask" -Action $Action -Trigger $Trigger -Principal $Principal -Force -ErrorAction Stop
    Write-Log "Backup task created successfully." "SUCCESS"
} catch {
    Write-Log "Failed to create backup task: $_" "ERROR"
}

Write-Log "Installation Process Finished." "SUCCESS"
Write-Host "`nFull Log available at: $LogPath" -ForegroundColor Gray
#>

Exit 0