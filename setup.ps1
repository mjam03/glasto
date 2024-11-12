# setup.ps1
# Download and install Python
$pythonUrl = "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe"
$pythonInstaller = "C:\python-installer.exe"
Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
Remove-Item $pythonInstaller

# Download and install Firefox
$firefoxUrl = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
$firefoxInstaller = "C:\firefox-installer.exe"
Invoke-WebRequest -Uri $firefoxUrl -OutFile $firefoxInstaller
Start-Process -FilePath $firefoxInstaller -ArgumentList "/S" -Wait
Remove-Item $firefoxInstaller

# Install Selenium and create automation script
Start-Process -FilePath "C:\Program Files\Python39\python.exe" -ArgumentList "-m pip install selenium webdriver_manager" -Wait

# Create the Python script
$pythonScript = @'
from selenium import webdriver
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.firefox.options import Options
from webdriver_manager.firefox import GeckoDriverManager
import time

def setup_driver():
    options = Options()
    # options.add_argument("--headless")  # Uncomment if you don't need to see the browser
    options.set_preference("detach", True)
    
    service = Service(GeckoDriverManager().install())
    driver = webdriver.Firefox(service=service, options=options)
    return driver

def main():
    driver = setup_driver()
    try:
        # Navigate to the website
        driver.get("https://glastonbury.seetickets.com/content/extras")
        
        # Keep the browser open
        while True:
            time.sleep(1)
            
    except Exception as e:
        print(f"An error occurred: {e}")
        driver.quit()

if __name__ == "__main__":
    main()
'@

$pythonScript | Out-File -FilePath "C:\automation\script.py" -Encoding UTF8

# Create startup script
$startupScript = @'
Start-Process -FilePath "C:\Program Files\Python39\python.exe" -ArgumentList "C:\automation\script.py" -WindowStyle Hidden
'@

$startupScript | Out-File -FilePath "C:\automation\startup.ps1" -Encoding UTF8

# Create scheduled task to run at startup
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\automation\startup.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "StartAutomation" -Action $action -Trigger $trigger -Principal $principal -Force
