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
    $LogEntry = "[$TimeStamp] [$Type] $Message"
    $LogEntry | Out-File -FilePath $LogFile -Append
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
    
    $ServerName = Read-Host "> Enter Server Name"
    if ([string]::IsNullOrWhiteSpace($ServerName)) { $ServerName = "DefaultServerName_Enshrouded" }
    $Password = Read-Host "> Enter Server Password"

    while ($true) {
        $ServerIP = Read-Host "> Enter Server IP (Default: 0.0.0.0)"
        if ([string]::IsNullOrWhiteSpace($ServerIP)) { $ServerIP = "0.0.0.0"; break }
        if ($ServerIP -match "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$") { break }
        Write-Host "`n Invalid IP! Use IPv4 format (0.0.0.0 - 255.255.255.255). `n" -ForegroundColor Red
    }

    Function Get-ValidPort {
        Param ([string]$Prompt, $Default)
        while ($true) {
            $Input = Read-Host "> $Prompt (Default: $Default)"
            if ([string]::IsNullOrWhiteSpace($Input)) { return $Default }
            if ($Input -match "^\d+$" -and [int]$Input -ge 0 -and [int]$Input -le 65535) { return $Input }
            Write-Host "`n Invalid Port! Enter a number between 0 and 65535. `n" -ForegroundColor Red
        }
    }
    $GamePort  = Get-ValidPort "Enter Game Port" "15636"
    $QueryPort = Get-ValidPort "Enter Query Port" "15637"

    while ($true) {
        $SlotCount = Read-Host "> Enter Max Players (Range: 4 - 16, Default: 4)"
        if ([string]::IsNullOrWhiteSpace($SlotCount)) { $SlotCount = "4"; break }
        if ($SlotCount -match "^\d+$" -and [int]$SlotCount -ge 4 -and [int]$SlotCount -le 16) { break }
        Write-Host "`n Invalid input! Please enter a number between 4 and 16. `n" -ForegroundColor Red
    }

    while ($true) {
        $BackupTime = Read-Host "> Enter daily backup time (Format HH:mm, e.g., 03:00)"
        if ([string]::IsNullOrWhiteSpace($BackupTime)) { $BackupTime = "03:00"; break }
        if ($BackupTime -match "^([0-1][0-9]|2[0-3]):([0-5][0-9])$") { break }
        Write-Host "`n Invalid Format! Please use HH:mm (e.g., 04:30). `n" -ForegroundColor Red
    }

    $SteamCMDPath = "C:\SteamCMD"
    $ServerPath   = "C:\EnshroudedServer"
    $BackupPath   = "C:\EnshroudedBackups"

    Write-Host "`n--- Current Default Directories ---" -ForegroundColor Gray
    Write-Host " SteamCMD: $SteamCMDPath"
    Write-Host " Server:   $ServerPath"
    Write-Host " Backups:  $BackupPath"
    
    if ((Read-Host "`n> Do you want to change these Default Directories? (y / n)") -match "^(y|yes)$") {
        Write-Host "`n--- Custom Directory Configuration ---" -ForegroundColor Yellow
        $InputSteam = Read-Host "> Enter path for SteamCMD"
        $InputServer = Read-Host "> Enter path for Server Files"
        $InputBackup = Read-Host "> Enter path for Backups"
        if (![string]::IsNullOrWhiteSpace($InputSteam)) { $SteamCMDPath = $InputSteam }
        if (![string]::IsNullOrWhiteSpace($InputServer)) { $ServerPath = $InputServer }
        if (![string]::IsNullOrWhiteSpace($InputBackup)) { $BackupPath = $InputBackup }
    }

    $OSName = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($OSName -match "Windows Server|Windows 10|Windows 11") {
        Write-Log "System Check: $OSName detected." "SUCCESS"
    } else {
        Write-Log "System Check failed: $OSName is not supported." "ERROR"; exit
    }

    Write-Host "`n--- Installation Summary ---" -ForegroundColor Yellow
    Write-Host "Detected OS:    $OSName"
    Write-Host "Server Name:    $ServerName"
    Write-Host "Server PW:      $Password"
    Write-Host "Server IP:      $ServerIP"
    Write-Host "Game Port:      $GamePort (UDP)"
    Write-Host "Query Port:     $QueryPort (UDP)"
    Write-Host "Max Players:    $SlotCount"
    Write-Host "Backup Time:    $BackupTime"
    Write-Host "----------------------------"
    Write-Host "SteamCMD Path:  $SteamCMDPath"
    Write-Host "Server Path:    $ServerPath"
    Write-Host "Backup Path:    $BackupPath"
    Write-Host "----------------------------"

    if ((Read-Host "`nIs this information correct? Proceed with installation? (y / n)") -match "^(y|yes)$") {
        $GlobalConfirm = $true
        Write-Log "Configuration confirmed. Starting process..." "INFO"
    } else { Clear-Host }
} until ($GlobalConfirm)

# --- EXECUTION PHASE ---

Write-Log "Creating directories..." "INFO"
New-Item -ItemType Directory -Force -Path $SteamCMDPath, $ServerPath, $BackupPath | Out-Null

# SteamCMD Setup
Write-Log "Downloading & Extracting SteamCMD..." "INFO"
try {
    Invoke-WebRequest -Uri "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -OutFile "$SteamCMDPath\steamcmd.zip" -ErrorAction Stop
    Expand-Archive -Path "$SteamCMDPath\steamcmd.zip" -DestinationPath $SteamCMDPath -Force -ErrorAction Stop
} catch {
    Write-Log "Critical Error during SteamCMD setup: $_" "ERROR"; exit
}

# START STEAMCMD WARM-UP
Write-Log "Starting SteamCMD for initial update and self-check..." "INFO"
& "$SteamCMDPath\steamcmd.exe" +quit
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 7) { 
    # Note: Exit code 7 is often just a notification of a finished update process
    Write-Log "SteamCMD warm-up finished with Code: $LASTEXITCODE" "INFO"
}

# INSTALL ENSHROUDED
Write-Log "Installing Enshrouded Server... This may take a while." "INFO"
& "$SteamCMDPath\steamcmd.exe" +@sSteamCmdForcePlatformType windows +force_install_dir "$ServerPath" +login anonymous +app_update 2278520 validate +quit

# Smart Validation
$ExePath = Join-Path -Path $ServerPath -ChildPath "enshrouded_server.exe"
if (Test-Path $ExePath) {
    Write-Log "Validation SUCCESS: enshrouded_server.exe found." "SUCCESS"
} else {
    Write-Log "Validation FAILED: enshrouded_server.exe NOT found!" "ERROR"; exit
}

# CONFIG & TASKS
Write-Log "Generating configuration..." "INFO"
$ConfigObject = @{
    name          = $ServerName
    password      = $Password
    saveDirectory = "./savegame"
    logDirectory  = "./logs"
    ip            = $ServerIP
    gamePort      = [int]$GamePort
    queryPort     = [int]$QueryPort
    slotCount     = [int]$SlotCount
}

$ConfigJson = $ConfigObject | ConvertTo-Json
try {
    [System.IO.File]::WriteAllText("$ServerPath\enshrouded_server.json", $ConfigJson)
    Write-Log "Configuration file saved successfully." "SUCCESS"
} catch {
    Write-Log "Failed to save configuration: $_" "ERROR"
}

# Scheduled Task
try {
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Compress-Archive -Path '$ServerPath\savegame' -DestinationPath '$BackupPath\Backup_$(Get-Date -Format 'yyyyMMdd_HHmm').zip' -Force`""
    $Trigger = New-ScheduledTaskTrigger -Daily -At $BackupTime
    Register-ScheduledTask -TaskName "EnshroudedBackupTask" -Action $Action -Trigger $Trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount) -Force -ErrorAction Stop
    Write-Log "Backup task created successfully." "SUCCESS"
} catch {
    Write-Log "Failed to create backup task." "WARN"
}

Write-Log "Installation Process Finished Successfully." "SUCCESS"
Write-Host "`nFull Log available at: $LogPath" -ForegroundColor Gray

Exit 0
