# setup.ps1
Start-Transcript -Path "C:\setup_log.txt"

Write-Output "Starting setup script..."

try {
    # Create automation directory
    Write-Output "Creating automation directory..."
    New-Item -ItemType Directory -Force -Path "C:\automation" | Out-Null
    
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
    
    # Download Firefox
    Write-Output "Downloading Firefox..."
    $firefoxUrl = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
    $firefoxInstaller = "C:\automation\firefox-installer.exe"
    Invoke-WebRequest -Uri $firefoxUrl -OutFile $firefoxInstaller
    
    # Install Firefox
    Write-Output "Installing Firefox..."
    $process = Start-Process -FilePath $firefoxInstaller -ArgumentList "/S" -Wait -PassThru
    Write-Output "Firefox installer completed with exit code: $($process.ExitCode)"
    
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
