# uBlock Origin Auto-Updater Script
# Downloads the latest uBlock Origin release for Chromium browsers

param(
    [string]$DownloadPath = (Join-Path $env:USERPROFILE "Downloads\uBlock-Origin"),
    [string]$ExtractPath = (Join-Path $env:USERPROFILE "Desktop\uBlock-Origin"),
    [switch]$Verbose
)

# Set error handling
$ErrorActionPreference = "Stop"

# Function to write verbose output
function Write-VerboseOutput {
    param([string]$Message)
    if ($Verbose) {
        Write-Host $Message -ForegroundColor Green
    }
}

try {
    Write-Host "Starting uBlock Origin update process..." -ForegroundColor Cyan
    
    # Check if we have a current version installed
    $versionFile = Join-Path $ExtractPath "current_version.txt"
    $currentVersion = ""
    
    if (Test-Path $versionFile) {
        $currentVersion = Get-Content $versionFile -Raw
        $currentVersion = $currentVersion.Trim()
        Write-Host "Current installed version: $currentVersion" -ForegroundColor Yellow
    } else {
        Write-Host "No previous version found" -ForegroundColor Yellow
    }
    
    # GitHub API URL for releases
    $apiUrl = "https://api.github.com/repos/gorhill/uBlock/releases/latest"
    
    Write-VerboseOutput "Fetching latest release information from GitHub API..."
    
    # Get the latest release information
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    
    if (-not $response) {
        throw "Failed to fetch release information from GitHub API"
    }
    
    $latestVersion = $response.tag_name
    $releaseDate = $response.published_at
    
    Write-Host "Latest available version: $latestVersion (Published: $releaseDate)" -ForegroundColor Yellow
    
    # Compare versions
    if ($currentVersion -eq $latestVersion) {
        Write-Host ""
        Write-Host "Already up to date! Current version ($currentVersion) matches latest version." -ForegroundColor Green
        Write-Host "No download needed." -ForegroundColor Green
        
        # Show usage examples and exit
        Write-Host ""
        Write-Host "=== Usage Examples ===" -ForegroundColor Cyan
        Write-Host "Default usage:     .\ublock-updater.ps1"
        Write-Host "Custom paths:      .\ublock-updater.ps1 -DownloadPath 'C:\CustomDownload' -ExtractPath 'C:\CustomExtract'"
        Write-Host "Verbose output:    .\ublock-updater.ps1 -Verbose"
        exit 0
    }
    
    if ($currentVersion) {
        Write-Host ""
        Write-Host "Update available: $currentVersion to $latestVersion" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "Installing uBlock Origin version: $latestVersion" -ForegroundColor Cyan
    }
    
    # Find the Chromium ZIP asset
    $chromiumAsset = $response.assets | Where-Object { $_.name -like "*chromium*.zip" }
    
    if (-not $chromiumAsset) {
        throw "Chromium ZIP file not found in the latest release assets"
    }
    
    $downloadUrl = $chromiumAsset.browser_download_url
    $fileName = $chromiumAsset.name
    
    Write-VerboseOutput "Found Chromium asset: $fileName"
    Write-VerboseOutput "Download URL: $downloadUrl"
    
    # Create download directory if it doesn't exist
    if (-not (Test-Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        Write-VerboseOutput "Created download directory: $DownloadPath"
    }
    
    # Create extract directory if it doesn't exist
    if (-not (Test-Path $ExtractPath)) {
        New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
        Write-VerboseOutput "Created extract directory: $ExtractPath"
    }
    
    # Full paths
    $zipPath = Join-Path $DownloadPath $fileName
    $tempExtractPath = Join-Path $ExtractPath "temp-extract"
    $finalExtractPath = Join-Path $ExtractPath "uBlock-Origin"
    
    Write-Host "Downloading $fileName..." -ForegroundColor Cyan
    
    # Download the file with progress
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $zipPath)
    
    Write-Host "Download completed successfully" -ForegroundColor Green
    
    # Remove existing extracted folder if it exists
    if (Test-Path $finalExtractPath) {
        Write-VerboseOutput "Removing existing folder: $finalExtractPath"
        Remove-Item -Path $finalExtractPath -Recurse -Force
    }
    
    # Remove temp extract folder if it exists
    if (Test-Path $tempExtractPath) {
        Write-VerboseOutput "Removing existing temp folder: $tempExtractPath"
        Remove-Item -Path $tempExtractPath -Recurse -Force
    }
    
    Write-Host "Extracting ZIP file..." -ForegroundColor Cyan
    
    # Extract the ZIP file to temp location first
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtractPath)
    
    # Find the uBlock0.chromium folder inside the extracted content
    $chromiumFolder = Get-ChildItem -Path $tempExtractPath -Directory | Where-Object { $_.Name -like "*chromium*" } | Select-Object -First 1
    
    if ($chromiumFolder) {
        Write-VerboseOutput "Found Chromium folder: $($chromiumFolder.Name)"
        # Move the chromium folder contents to the final location
        Move-Item -Path $chromiumFolder.FullName -Destination $finalExtractPath
        Write-VerboseOutput "Moved contents to: $finalExtractPath"
    } else {
        throw "Could not find Chromium folder in extracted content"
    }
    
    # Clean up temp extraction folder
    Remove-Item -Path $tempExtractPath -Recurse -Force
    
    Write-Host "Extraction completed successfully" -ForegroundColor Green
    
    # Save the current version to file for future comparison
    $latestVersion | Out-File -FilePath $versionFile -Encoding UTF8
    Write-VerboseOutput "Saved version $latestVersion to $versionFile"
    
    # Clean up the ZIP file
    Write-VerboseOutput "Cleaning up downloaded ZIP file..."
    Remove-Item -Path $zipPath -Force
    
    # Display completion information
    Write-Host ""
    Write-Host "=== Update Complete ===" -ForegroundColor Cyan
    Write-Host "Updated from: $currentVersion to $latestVersion" -ForegroundColor White
    Write-Host "Downloaded to: $DownloadPath" -ForegroundColor White
    Write-Host "Extracted to: $finalExtractPath" -ForegroundColor White
    
    Write-Host ""
    Write-Host "uBlock Origin has been successfully updated!" -ForegroundColor Green
    
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Example usage information
Write-Host ""
Write-Host "=== Usage Examples ===" -ForegroundColor Cyan
Write-Host "Default usage:     .\ublock-updater.ps1"
Write-Host "Custom paths:      .\ublock-updater.ps1 -DownloadPath 'C:\CustomDownload' -ExtractPath 'C:\CustomExtract'"
Write-Host "Verbose output:    .\ublock-updater.ps1 -Verbose"
