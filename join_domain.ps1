# Get the active network adapter
$adapter = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1

# Set the DNS server to the Arch Linux Host IP so it can resolve AWCATOR.LOCAL
Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "192.168.29.113"
Write-Output "Set DNS on $($adapter.Name) to 192.168.29.113"

# Check if the domain is reachable
$ping = Test-Connection -ComputerName "AWCATOR.LOCAL" -Count 1 -Quiet
if ($ping) {
    Write-Output "Domain AWCATOR.LOCAL is reachable!"
} else {
    Write-Output "ERROR: Cannot reach domain AWCATOR.LOCAL. Proceeding anyway..."
}

# Create the credential object for the domain admin
$secpasswd = ConvertTo-SecureString "AwcatorAdmin123!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("AWCATOR\Administrator", $secpasswd)

# Join the domain
Write-Output "Attempting to join domain AWCATOR.LOCAL..."
Add-Computer -DomainName "AWCATOR.LOCAL" -Credential $cred -Force
Write-Output "Domain join command executed."

# Wait a second before forcing reboot
Start-Sleep -Seconds 2
Restart-Computer -Force
