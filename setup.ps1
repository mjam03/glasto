# setup.ps1
Start-Transcript -Path "C:\setup_log.txt"

Write-Output "Starting setup script..."

try {
    # Create automation directory
    Write-Output "Creating automation directory..."
    New-Item -ItemType Directory -Force -Path "C:\automation" | Out-Null
    
    # Download Firefox using alternative method
    Write-Output "Downloading Firefox..."
    $firefoxUrl = "https://download-installer.cdn.mozilla.net/pub/firefox/releases/latest/win64/en-US/Firefox%20Setup.exe"
    $firefoxInstaller = "C:\automation\firefox-installer.exe"
    
    # Try multiple methods to download Firefox
    try {
        (New-Object System.Net.WebClient).DownloadFile($firefoxUrl, $firefoxInstaller)
    } catch {
        Write-Output "WebClient failed, trying alternative Firefox version..."
        # Try specific version instead of latest
        $fallbackUrl = "https://download-installer.cdn.mozilla.net/pub/firefox/releases/115.0/win64/en-US/Firefox%20Setup%20115.0.exe"
        Start-BitsTransfer -Source $fallbackUrl -Destination $firefoxInstaller
    }
    
    # Verify Firefox download
    if (!(Test-Path $firefoxInstaller)) {
        throw "Firefox installer not downloaded successfully"
    }
    
    Write-Output "Firefox downloaded successfully. File size: $((Get-Item $firefoxInstaller).length) bytes"
    
    # Install Firefox with timeout and error handling
    Write-Output "Installing Firefox..."
    $processStartTime = Get-Date
    $process = Start-Process -FilePath $firefoxInstaller -ArgumentList "/S" -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Output "Firefox installer completed with non-zero exit code: $($process.ExitCode)"
    } else {
        Write-Output "Firefox installed successfully"
    }
    
    # Verify Firefox installation
    $firefoxPath = "${env:ProgramFiles}\Mozilla Firefox\firefox.exe"
    if (!(Test-Path $firefoxPath)) {
        Write-Output "Firefox executable not found at expected location"
        $firefoxPath = "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        if (!(Test-Path $firefoxPath)) {
            throw "Firefox installation failed - executable not found"
        }
    }
    
    Write-Output "Firefox installation verified at: $firefoxPath"
    
    # Download Python
    Write-Output "Downloading Python..."
    $pythonUrl = "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe"
    $pythonInstaller = "C:\automation\python-installer.exe"
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
    
    # Install Python
    Write-Output "Installing Python..."
    $pythonInstallArgs = "/quiet InstallAllUsers=1 PrependPath=1"
    $process = Start-Process -FilePath $pythonInstaller -ArgumentList $pythonInstallArgs -Wait -PassThru
    Write-Output "Python installer completed with exit code: $($process.ExitCode)"
    
    # Install Python packages
    Write-Output "Installing Python packages..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    & "C:\Program Files\Python39\python.exe" -m pip install --upgrade pip
    & "C:\Program Files\Python39\python.exe" -m pip install selenium webdriver_manager
    
    # Create Python automation script
    Write-Output "Creating Python script..."
    $pythonScript = @'
from selenium import webdriver
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.firefox.options import Options
from webdriver_manager.firefox import GeckoDriverManager
import time
import logging

# Setup logging
logging.basicConfig(
    filename='C:\\automation\\selenium.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def setup_driver():
    logging.info("Setting up Firefox driver...")
    options = Options()
    options.set_preference("detach", True)
    
    service = Service(GeckoDriverManager().install())
    driver = webdriver.Firefox(service=service, options=options)
    return driver

def main():
    logging.info("Starting main automation script")
    try:
        driver = setup_driver()
        logging.info("Driver setup complete")
        
        logging.info("Navigating to website...")
        driver.get("https://glastonbury.seetickets.com/content/extras")
        logging.info("Navigation complete")
        
        while True:
            time.sleep(1)
            
    except Exception as e:
        logging.error(f"An error occurred: {e}", exc_info=True)
        if 'driver' in locals():
            driver.quit()

if __name__ == "__main__":
    main()
'@
    $pythonScript | Out-File -FilePath "C:\automation\script.py" -Encoding UTF8
    
    # Create startup script
    Write-Output "Creating startup script..."
    $startupScript = @'
Start-Transcript -Path "C:\automation\startup_log.txt" -Append
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
Start-Process -FilePath "C:\Program Files\Python39\python.exe" -ArgumentList "C:\automation\script.py" -WindowStyle Hidden
'@
    $startupScript | Out-File -FilePath "C:\automation\startup.ps1" -Encoding UTF8
    
    # Create scheduled task
    Write-Output "Creating scheduled task..."
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\automation\startup.ps1"
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "StartAutomation" -Action $action -Trigger $trigger -Principal $principal -Force
    
    Write-Output "Setup completed successfully!"

} catch {
    Write-Error "An error occurred during setup: $_"
    Write-Error $_.ScriptStackTrace
    throw
} finally {
    Stop-Transcript
}
