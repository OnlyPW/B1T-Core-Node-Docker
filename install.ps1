# B1T Core Node Auto-Setup Script for Windows
# Requires: Windows 10/11, PowerShell 5.1+
# Author: B1T Core Team
# License: MIT

#Requires -RunAsAdministrator

param(
    [switch]$Help,
    [switch]$Version,
    [switch]$Check,
    [switch]$Force
)

# Configuration
$B1T_HOME = "C:\B1T-Core"
$B1T_DATA = "C:\B1T-Core\data"
$B1T_LOGS = "C:\B1T-Core\logs"
$DOCKER_DESKTOP_URL = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$NODE_VERSION = "18"
$NODE_URL = "https://nodejs.org/dist/latest-v18.x/node-v18.19.0-x64.msi"

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Cyan"
    White = "White"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { $Colors.Blue }
        "Success" { $Colors.Green }
        "Warning" { $Colors.Yellow }
        "Error" { $Colors.Red }
        default { $Colors.White }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    if ($version.Major -lt 10) {
        Write-Log "Windows 10 or later is required. Current version: $($version.Major).$($version.Minor)" "Error"
        return $false
    }
    Write-Log "Windows version check passed: $($version.Major).$($version.Minor)" "Success"
    return $true
}

function Test-PowerShellVersion {
    $version = $PSVersionTable.PSVersion
    if ($version.Major -lt 5) {
        Write-Log "PowerShell 5.1 or later is required. Current version: $version" "Error"
        return $false
    }
    Write-Log "PowerShell version check passed: $version" "Success"
    return $true
}

function Test-HyperV {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
    if ($hyperv.State -ne "Enabled") {
        Write-Log "Hyper-V is not enabled. Docker Desktop requires Hyper-V." "Warning"
        Write-Log "Attempting to enable Hyper-V..." "Info"
        
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
            Write-Log "Hyper-V enabled. A restart may be required." "Success"
            return $true
        }
        catch {
            Write-Log "Failed to enable Hyper-V: $($_.Exception.Message)" "Error"
            return $false
        }
    }
    Write-Log "Hyper-V is already enabled" "Success"
    return $true
}

function Test-WSL2 {
    try {
        $wslVersion = wsl --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL2 is available" "Success"
            return $true
        }
    }
    catch {
        # WSL not available
    }
    
    Write-Log "WSL2 is not available. Installing..." "Info"
    try {
        wsl --install --no-distribution
        Write-Log "WSL2 installed. A restart may be required." "Success"
        return $true
    }
    catch {
        Write-Log "Failed to install WSL2: $($_.Exception.Message)" "Warning"
        return $false
    }
}

function Test-Docker {
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker is installed: $dockerVersion" "Success"
            return $true
        }
    }
    catch {
        # Docker not available
    }
    
    Write-Log "Docker is not installed" "Info"
    return $false
}

function Install-Docker {
    if (Test-Docker) {
        Write-Log "Docker is already installed" "Success"
        return $true
    }
    
    Write-Log "Installing Docker Desktop..." "Info"
    
    $tempFile = "$env:TEMP\DockerDesktopInstaller.exe"
    
    try {
        Write-Log "Downloading Docker Desktop installer..." "Info"
        Invoke-WebRequest -Uri $DOCKER_DESKTOP_URL -OutFile $tempFile -UseBasicParsing
        
        Write-Log "Running Docker Desktop installer..." "Info"
        Start-Process -FilePath $tempFile -ArgumentList "install", "--quiet", "--accept-license" -Wait
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        Write-Log "Docker Desktop installation completed" "Success"
        Write-Log "Please start Docker Desktop manually and complete the setup" "Info"
        
        return $true
    }
    catch {
        Write-Log "Failed to install Docker Desktop: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-DockerCompose {
    try {
        $composeVersion = docker-compose --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker Compose is available: $composeVersion" "Success"
            return $true
        }
    }
    catch {
        # Docker Compose not available
    }
    
    # Check for docker compose (newer syntax)
    try {
        $composeVersion = docker compose version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker Compose is available: $composeVersion" "Success"
            return $true
        }
    }
    catch {
        # Docker Compose not available
    }
    
    Write-Log "Docker Compose is not available" "Warning"
    return $false
}

function Test-NodeJS {
    try {
        $nodeVersion = node --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $versionNumber = $nodeVersion -replace 'v', ''
            $majorVersion = [int]($versionNumber.Split('.')[0])
            
            if ($majorVersion -ge $NODE_VERSION) {
                Write-Log "Node.js is installed: $nodeVersion" "Success"
                return $true
            }
            else {
                Write-Log "Node.js version $nodeVersion is too old. Required: v$NODE_VERSION+" "Warning"
                return $false
            }
        }
    }
    catch {
        # Node.js not available
    }
    
    Write-Log "Node.js is not installed" "Info"
    return $false
}

function Install-NodeJS {
    if (Test-NodeJS) {
        Write-Log "Node.js is already installed" "Success"
        return $true
    }
    
    Write-Log "Installing Node.js..." "Info"
    
    $tempFile = "$env:TEMP\nodejs-installer.msi"
    
    try {
        Write-Log "Downloading Node.js installer..." "Info"
        Invoke-WebRequest -Uri $NODE_URL -OutFile $tempFile -UseBasicParsing
        
        Write-Log "Running Node.js installer..." "Info"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $tempFile, "/quiet", "/norestart" -Wait
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        Write-Log "Node.js installation completed" "Success"
        return $true
    }
    catch {
        Write-Log "Failed to install Node.js: $($_.Exception.Message)" "Error"
        return $false
    }
}

function New-Directories {
    Write-Log "Creating directories..." "Info"
    
    $directories = @($B1T_HOME, $B1T_DATA, $B1T_LOGS, "$B1T_HOME\backups")
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "Created directory: $dir" "Info"
        }
        else {
            Write-Log "Directory already exists: $dir" "Info"
        }
    }
    
    Write-Log "Directories created successfully" "Success"
}

function Copy-ProjectFiles {
    Write-Log "Setting up project files..." "Info"
    
    $projectDir = "$B1T_HOME\B1T-Core-Node"
    
    if (Test-Path $projectDir) {
        if (!$Force) {
            $response = Read-Host "Project directory already exists. Remove and recreate? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Log "Using existing project directory" "Info"
                return $true
            }
        }
        Remove-Item $projectDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    
    # Check if we're running from the project directory
    $currentDir = Get-Location
    $sourceFiles = @(
        "Dockerfile",
        "docker-compose.yml",
        ".env.example",
        "package.json",
        "Makefile",
        "README.md",
        "LICENSE"
    )
    
    $sourceDir = $null
    foreach ($file in $sourceFiles) {
        if (Test-Path "$currentDir\$file") {
            $sourceDir = $currentDir
            break
        }
        elseif (Test-Path "$PSScriptRoot\$file") {
            $sourceDir = $PSScriptRoot
            break
        }
    }
    
    if ($sourceDir) {
        Write-Log "Copying project files from $sourceDir..." "Info"
        
        # Copy all files and directories
        Get-ChildItem -Path $sourceDir -Exclude "install.ps1", "install.sh", ".git" | 
            Copy-Item -Destination $projectDir -Recurse -Force
        
        Write-Log "Project files copied successfully" "Success"
    }
    else {
        Write-Log "Project files not found. Please manually copy files to $projectDir" "Warning"
        Write-Log "Required files: $($sourceFiles -join ', ')" "Info"
    }
    
    return $true
}

function Set-Environment {
    Write-Log "Configuring environment..." "Info"
    
    $projectDir = "$B1T_HOME\B1T-Core-Node"
    $envFile = "$projectDir\.env"
    $envExample = "$projectDir\.env.example"
    
    if (Test-Path $envExample) {
        if (!(Test-Path $envFile)) {
            Copy-Item $envExample $envFile
            Write-Log "Created .env file from template" "Info"
        }
        
        # Generate random password
        $rpcPassword = -join ((1..25) | ForEach-Object { Get-Random -InputObject ([char[]]([char]'a'..[char]'z') + [char[]]([char]'A'..[char]'Z') + [char[]]([char]'0'..[char]'9')) })
        
        # Update .env file
        $envContent = Get-Content $envFile
        $envContent = $envContent -replace 'RPC_PASSWORD=.*', "RPC_PASSWORD=$rpcPassword"
        $envContent = $envContent -replace 'DATA_DIR=.*', "DATA_DIR=$($B1T_DATA -replace '\\', '/')"
        $envContent = $envContent -replace 'LOG_DIR=.*', "LOG_DIR=$($B1T_LOGS -replace '\\', '/')"
        
        $envContent | Set-Content $envFile
        
        Write-Log "Environment configuration updated" "Success"
        Write-Log "Generated new RPC password" "Info"
    }
    else {
        Write-Log ".env.example not found, skipping environment setup" "Warning"
    }
}

function Install-Dependencies {
    Write-Log "Installing Node.js dependencies..." "Info"
    
    $projectDir = "$B1T_HOME\B1T-Core-Node"
    $packageJson = "$projectDir\package.json"
    
    if (Test-Path $packageJson) {
        Push-Location $projectDir
        try {
            npm install
            Write-Log "Dependencies installed successfully" "Success"
        }
        catch {
            Write-Log "Failed to install dependencies: $($_.Exception.Message)" "Error"
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Log "package.json not found, skipping npm install" "Warning"
    }
}

function New-WindowsService {
    Write-Log "Creating Windows service..." "Info"
    
    $serviceName = "B1TCoreNode"
    $serviceDisplayName = "B1T Core Node"
    $serviceDescription = "B1T Core Blockchain Node Service"
    $projectDir = "$B1T_HOME\B1T-Core-Node"
    
    # Check if service already exists
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Log "Service $serviceName already exists" "Info"
        return $true
    }
    
    # Create service wrapper script
    $serviceScript = "$B1T_HOME\service-wrapper.ps1"
    $serviceScriptContent = @"
# B1T Core Node Service Wrapper
param([string]`$Action)

`$projectDir = "$projectDir"
Set-Location `$projectDir

switch (`$Action) {
    "start" {
        docker-compose up -d
    }
    "stop" {
        docker-compose down
    }
    "restart" {
        docker-compose restart
    }
    default {
        Write-Host "Usage: service-wrapper.ps1 [start|stop|restart]"
    }
}
"@
    
    $serviceScriptContent | Set-Content $serviceScript
    
    try {
        # Note: Creating a proper Windows service for Docker Compose is complex
        # For now, we'll create a scheduled task that starts on boot
        
        $taskName = "B1T Core Node Startup"
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$serviceScript`" start"
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Force
        
        Write-Log "Scheduled task created for auto-start" "Success"
    }
    catch {
        Write-Log "Failed to create scheduled task: $($_.Exception.Message)" "Warning"
    }
}

function New-ManagementScripts {
    Write-Log "Creating management scripts..." "Info"
    
    $scriptsDir = "$B1T_HOME\scripts"
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    
    # B1T CLI script
    $cliScript = @"
# B1T Core CLI Wrapper
param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$Arguments)

`$projectDir = "$B1T_HOME\B1T-Core-Node"
Set-Location `$projectDir

if (`$Arguments) {
    docker-compose exec b1t-core b1t-cli @Arguments
} else {
    docker-compose exec b1t-core b1t-cli getinfo
}
"@
    $cliScript | Set-Content "$scriptsDir\b1t-cli.ps1"
    
    # Status script
    $statusScript = @"
# B1T Core Node Status
Write-Host "=== B1T Core Node Status ===" -ForegroundColor Green

`$projectDir = "$B1T_HOME\B1T-Core-Node"
Set-Location `$projectDir

Write-Host "\n=== Docker Containers ===" -ForegroundColor Blue
docker-compose ps

Write-Host "\n=== Node Info ===" -ForegroundColor Blue
try {
    docker-compose exec b1t-core b1t-cli getinfo
} catch {
    Write-Host "Node not responding" -ForegroundColor Red
}
"@
    $statusScript | Set-Content "$scriptsDir\b1t-status.ps1"
    
    # Logs script
    $logsScript = @"
# B1T Core Node Logs
param([string]`$Service = "")

`$projectDir = "$B1T_HOME\B1T-Core-Node"
Set-Location `$projectDir

if (`$Service) {
    docker-compose logs -f `$Service
} else {
    docker-compose logs -f
}
"@
    $logsScript | Set-Content "$scriptsDir\b1t-logs.ps1"
    
    Write-Log "Management scripts created in $scriptsDir" "Success"
}

function Start-InitialSetup {
    Write-Log "Running initial setup..." "Info"
    
    $projectDir = "$B1T_HOME\B1T-Core-Node"
    
    if (Test-Path "$projectDir\scripts\setup.js") {
        Push-Location $projectDir
        try {
            node scripts\setup.js --auto
            Write-Log "Setup script completed" "Success"
        }
        catch {
            Write-Log "Setup script failed: $($_.Exception.Message)" "Warning"
        }
        finally {
            Pop-Location
        }
    }
    
    # Build Docker images
    if (Test-Path "$projectDir\docker-compose.yml") {
        Push-Location $projectDir
        try {
            Write-Log "Building Docker images..." "Info"
            docker-compose build
            Write-Log "Docker images built successfully" "Success"
        }
        catch {
            Write-Log "Failed to build Docker images: $($_.Exception.Message)" "Error"
        }
        finally {
            Pop-Location
        }
    }
}

function Show-CompletionMessage {
    Write-Host "`n" -NoNewline
    Write-Host "=== B1T Core Node Installation Completed! ===" -ForegroundColor Green
    Write-Host "`n" -NoNewline
    
    Write-Host "=== Installation Summary ===" -ForegroundColor Green
    Write-Host "Installation Directory: " -NoNewline -ForegroundColor Blue
    Write-Host "$B1T_HOME\B1T-Core-Node"
    Write-Host "Data Directory: " -NoNewline -ForegroundColor Blue
    Write-Host "$B1T_DATA"
    Write-Host "Log Directory: " -NoNewline -ForegroundColor Blue
    Write-Host "$B1T_LOGS"
    
    Write-Host "`n=== Management Commands ===" -ForegroundColor Green
    Write-Host "Start node: " -NoNewline -ForegroundColor Blue
    Write-Host "cd '$B1T_HOME\B1T-Core-Node'; docker-compose up -d"
    Write-Host "Stop node: " -NoNewline -ForegroundColor Blue
    Write-Host "cd '$B1T_HOME\B1T-Core-Node'; docker-compose down"
    Write-Host "Check status: " -NoNewline -ForegroundColor Blue
    Write-Host "PowerShell '$B1T_HOME\scripts\b1t-status.ps1'"
    Write-Host "View logs: " -NoNewline -ForegroundColor Blue
    Write-Host "PowerShell '$B1T_HOME\scripts\b1t-logs.ps1'"
    Write-Host "CLI access: " -NoNewline -ForegroundColor Blue
    Write-Host "PowerShell '$B1T_HOME\scripts\b1t-cli.ps1 getinfo'"
    
    Write-Host "`n=== Next Steps ===" -ForegroundColor Green
    Write-Host "1. Review configuration: " -NoNewline -ForegroundColor Blue
    Write-Host "notepad '$B1T_HOME\B1T-Core-Node\.env'"
    Write-Host "2. Start Docker Desktop if not running"
    Write-Host "3. Start the node: " -NoNewline -ForegroundColor Blue
    Write-Host "cd '$B1T_HOME\B1T-Core-Node'; docker-compose up -d"
    Write-Host "4. Check status: " -NoNewline -ForegroundColor Blue
    Write-Host "PowerShell '$B1T_HOME\scripts\b1t-status.ps1'"
    
    Write-Host "`n=== Security Recommendations ===" -ForegroundColor Green
    Write-Host "1. Change default RPC password in .env file"
    Write-Host "2. Configure Windows Firewall rules"
    Write-Host "3. Set up regular backups"
    Write-Host "4. Monitor system resources and logs"
    Write-Host "`n" -NoNewline
}

function Invoke-SystemCheck {
    Write-Log "Checking system requirements..." "Info"
    
    $checks = @(
        @{ Name = "Administrator Rights"; Test = { Test-Administrator } },
        @{ Name = "Windows Version"; Test = { Test-WindowsVersion } },
        @{ Name = "PowerShell Version"; Test = { Test-PowerShellVersion } },
        @{ Name = "Hyper-V"; Test = { Test-HyperV } },
        @{ Name = "WSL2"; Test = { Test-WSL2 } },
        @{ Name = "Docker"; Test = { Test-Docker } },
        @{ Name = "Docker Compose"; Test = { Test-DockerCompose } },
        @{ Name = "Node.js"; Test = { Test-NodeJS } }
    )
    
    $results = @()
    foreach ($check in $checks) {
        try {
            $result = & $check.Test
            $results += @{ Name = $check.Name; Result = $result }
        }
        catch {
            $results += @{ Name = $check.Name; Result = $false; Error = $_.Exception.Message }
        }
    }
    
    Write-Host "`n=== System Check Results ===" -ForegroundColor Green
    foreach ($result in $results) {
        $status = if ($result.Result) { "✓ PASS" } else { "✗ FAIL" }
        $color = if ($result.Result) { "Green" } else { "Red" }
        
        Write-Host "$($result.Name): " -NoNewline
        Write-Host $status -ForegroundColor $color
        
        if ($result.Error) {
            Write-Host "  Error: $($result.Error)" -ForegroundColor Red
        }
    }
    
    return $results
}

function Invoke-MainInstallation {
    Write-Host "=== B1T Core Node Auto-Setup for Windows ===" -ForegroundColor Green
    Write-Host "Supported Systems: Windows 10/11 with Docker Desktop" -ForegroundColor Blue
    Write-Host "`n" -NoNewline
    
    if (!(Test-Administrator)) {
        Write-Log "This script must be run as Administrator" "Error"
        Write-Log "Please right-click PowerShell and select 'Run as Administrator'" "Info"
        exit 1
    }
    
    Write-Log "Starting installation process..." "Info"
    
    # System checks and installations
    if (!(Test-WindowsVersion)) { exit 1 }
    if (!(Test-PowerShellVersion)) { exit 1 }
    
    Test-HyperV
    Test-WSL2
    
    if (!(Install-Docker)) {
        Write-Log "Docker installation failed. Please install Docker Desktop manually." "Error"
        exit 1
    }
    
    if (!(Install-NodeJS)) {
        Write-Log "Node.js installation failed. Please install Node.js manually." "Error"
        exit 1
    }
    
    # Project setup
    New-Directories
    Copy-ProjectFiles
    Set-Environment
    Install-Dependencies
    New-WindowsService
    New-ManagementScripts
    Start-InitialSetup
    
    Show-CompletionMessage
}

# Handle script parameters
if ($Help) {
    Write-Host "B1T Core Node Auto-Setup Script for Windows"
    Write-Host "Usage: .\install.ps1 [options]"
    Write-Host "Options:"
    Write-Host "  -Help          Show this help message"
    Write-Host "  -Version       Show version information"
    Write-Host "  -Check         Check system requirements"
    Write-Host "  -Force         Force overwrite existing files"
    Write-Host "`nRequirements:"
    Write-Host "  - Windows 10/11"
    Write-Host "  - PowerShell 5.1+"
    Write-Host "  - Administrator privileges"
    Write-Host "  - Internet connection"
    exit 0
}

if ($Version) {
    Write-Host "B1T Core Node Auto-Setup for Windows v1.0.0"
    exit 0
}

if ($Check) {
    Invoke-SystemCheck
    exit 0
}

# Main installation
Invoke-MainInstallation