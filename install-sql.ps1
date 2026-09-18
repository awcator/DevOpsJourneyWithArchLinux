# Download SQL Server 2022 Developer Edition downloader
Write-Output "Downloading SQL Server installer..."
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?linkid=2215158&clcid=0x409&culture=en-us&country=us" -OutFile "C:\SQL2022-SSEI-Dev.exe"

# We must download the ISO/CAB files first using the downloader, then run unattended install.
# The stub installer requires GUI. We will download the Express edition installer which supports quiet install natively.
Write-Output "Downloading SQL Server 2022 Express Edition..."
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us" -OutFile "C:\SQL2022-SSEI-Expr.exe"

Write-Output "Downloading SQL Server full setup (this takes a moment)..."
Start-Process -FilePath "C:\SQL2022-SSEI-Expr.exe" -ArgumentList "/Q /ACTION=Download /MEDIAPATH=C:\SQLSetup" -Wait

Write-Output "Installing SQL Server 2022..."
# We grant 'AWCATOR\it-eng' sysadmin privileges during unattended install
Start-Process -FilePath "C:\SQLSetup\SQLEXPR_x64_ENU\SETUP.EXE" -ArgumentList '/Q /ACTION=Install /FEATURES=SQL /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /SQLSYSADMINACCOUNTS="AWCATOR\it-eng" /AGTSVCACCOUNT="NT AUTHORITY\Network Service" /IACCEPTSQLSERVERLICENSETERMS' -Wait

Write-Output "Downloading SQL Server Management Studio (SSMS)..."
Invoke-WebRequest -Uri "https://aka.ms/ssmsfullsetup" -OutFile "C:\SSMS-Setup.exe"

Write-Output "Installing SSMS..."
Start-Process -FilePath "C:\SSMS-Setup.exe" -ArgumentList "/Passive" -Wait

Write-Output "SQL Server and SSMS installation complete! 'AWCATOR\it-eng' has sysadmin access."
