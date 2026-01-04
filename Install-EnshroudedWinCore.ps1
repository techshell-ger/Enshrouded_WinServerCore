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
        Write-Host "`n Invalid IP! Use IPv4 format. `n" -ForegroundColor Red
    }

    Function Get-ValidPort {
        Param ([string]$Prompt, $Default)
        while ($true) {
            $Input = Read-Host "> $Prompt (Default: $Default)"
            if ([string]::IsNullOrWhiteSpace($Input)) { return $Default }
            if ($Input -match "^\d+$" -and [int]$Input -ge 0 -and [int]$Input -le 65535) { return $Input }
            Write-Host "`n Invalid Port! `n" -ForegroundColor Red
        }
    }
    $GamePort  = Get-ValidPort "Enter Game Port" "15636"
    $QueryPort = Get-ValidPort "Enter Query Port" "15637"

    while ($true) {
        $SlotCount = Read-Host "> Enter Max Players (4-16)"
        if ([string]::IsNullOrWhiteSpace($SlotCount)) { $SlotCount = "4"; break }
        if ($SlotCount -match "^\d+$" -and [int]$SlotCount -ge 4 -and [int]$SlotCount -le 16) { break }
        Write-Host "`n Invalid input! (4-16). `n" -ForegroundColor Red
    }

    while ($true) {
        $BackupTime = Read-Host "> Enter backup time (HH:mm)"
        if ([string]::IsNullOrWhiteSpace($BackupTime)) { $BackupTime = "03:00"; break }
        if ($BackupTime -match "^([0-1][0-9]|2[0-3]):([0-5][0-9])$") { break }
        Write-Host "`n Invalid Format! `n" -ForegroundColor Red
    }

    $SteamCMDPath = "C:\SteamCMD"
    $ServerPath   = "C:\EnshroudedServer"
    $BackupPath   = "C:\EnshroudedBackups"

    # Summary and Confirmation
    Write-Host "`n--- Installation Summary ---" -ForegroundColor Yellow
    Write-Host "Server Name:    $ServerName"
    Write-Host "Game Port:      $GamePort (UDP)"
    Write-Host "Query Port:     $QueryPort (UDP)"
    Write-Host "Backup Time:    $BackupTime"
    Write-Host "----------------------------"
    Write-Host "Server Path:    $ServerPath"
    Write-Host "----------------------------"

    if ((Read-Host "`nProceed with installation? (y / n)") -match "^(y|yes)$") {
        $GlobalConfirm = $true
    } else { Clear-Host }
} until ($GlobalConfirm)

# --- EXECUTION PHASE ---

Write-Log "Creating directories..." "INFO"
New-Item -ItemType Directory -Force -Path $SteamCMDPath, $ServerPath, $BackupPath | Out-Null

Write-Log "Downloading & Extracting SteamCMD..." "INFO"
try {
    Invoke-WebRequest -Uri "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -OutFile "$SteamCMDPath\steamcmd.zip" -ErrorAction Stop
    Expand-Archive -Path "$SteamCMDPath\steamcmd.zip" -DestinationPath $SteamCMDPath -Force -ErrorAction Stop
} catch {
    Write-Log "Critical Error during SteamCMD setup: $_" "ERROR"; exit
}

# INSTALL ENSHROUDED (Enhanced Logic)
Write-Log "Starting SteamCMD initialization and download..." "INFO"

# Step 1: Force Platform and Login (First Run)
& "$SteamCMDPath\steamcmd.exe" +@sSteamCmdForcePlatformType windows +login anonymous +quit

# Step 2: Set Path and Download (Separate Step to ensure 'Missing Configuration' error is avoided)
Write-Log "Installing Enshrouded App 2278520... This may take a while." "INFO"
& "$SteamCMDPath\steamcmd.exe" +@sSteamCmdForcePlatformType windows +force_install_dir "$ServerPath" +login anonymous +app_update 2278520 validate +quit

# Validation
$ExePath = Join-Path -Path $ServerPath -ChildPath "enshrouded_server.exe"
if (Test-Path $ExePath) {
    Write-Log "Validation SUCCESS: Server files found." "SUCCESS"
} else {
    Write-Log "Validation FAILED: enshrouded_server.exe NOT found!" "ERROR"; exit
}

# CONFIG GENERATION
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
    Write-Log "Configuration file saved." "SUCCESS"
} catch {
    Write-Log "Failed to save configuration." "ERROR"
}

# Backup Task
try {
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Compress-Archive -Path '$ServerPath\savegame' -DestinationPath '$BackupPath\Backup_$(Get-Date -Format 'yyyyMMdd_HHmm').zip' -Force`""
    $Trigger = New-ScheduledTaskTrigger -Daily -At $BackupTime
    Register-ScheduledTask -TaskName "EnshroudedBackupTask" -Action $Action -Trigger $Trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount) -Force -ErrorAction Stop
    Write-Log "Backup task created." "SUCCESS"
} catch {
    Write-Log "Failed to create backup task." "WARN"
}

Write-Log "Installation Process Finished Successfully." "SUCCESS"
Write-Host "`nFull Log available at: $LogPath" -ForegroundColor Gray

Exit 0
