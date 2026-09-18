#!/bin/bash
set -euo pipefail
# =============================================================================
# samba-ad-stack.sh — Samba Active Directory DC + Keycloak + Winbind
# =============================================================================
#
# ============================== HOW TO JOIN WINDOWS VM =========================
# 1. In Windows VM Settings -> Network, set DNS Server to this Linux Host IP.
# 2. Open Administrator PowerShell and run:
#    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses <HOST_IP>
# 3. (Windows 11 Home ONLY) Upgrade to Pro using generic KMS key:
#    Settings -> System -> Activation -> Change product key:
#    VK7JG-NPHTM-C97JM-9MPGT-3V66T
#    (Disconnect internet before applying, then reconnect after reboot).
# 4. Join the Domain via Settings GUI or run in Admin PowerShell:
#    $secpasswd = ConvertTo-SecureString "AwcatorAdmin123!" -AsPlainText -Force
#    $cred = New-Object System.Management.Automation.PSCredential ("AWCATOR\Administrator", $secpasswd)
#    Add-Computer -DomainName "AWCATOR.LOCAL" -Credential $cred -Restart
# 5. After reboot, click "Other user" at Lock Screen and login:
#    User: it-eng
#    Pass: Eng123!aw
# 6. Test Kerberos SSO by opening File Explorer to: \\<HOST_IP>\shared
# =============================================================================

# ============================== CONFIG =======================================
AD_REALM="AWCATOR.LOCAL"
AD_DOMAIN="AWCATOR"
AD_ADMIN_PASS="AwcatorAdmin123!"
AD_BASE_DN="DC=awcator,DC=local"

KC_DB="keycloak"
KC_DB_USER="keycloak_user"
KC_DB_PASS="StrongKeycloakPass123"
KC_ADMIN="admin"
KC_ADMIN_PASS="Admin123!"
KC_URL="http://localhost:8080"
KC_HEALTH_URL="http://localhost:9000"
KC_REALM="awcator"

# ============================== HELPERS ======================================
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail(){ echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
section(){ echo; echo "══════════════════════════════════════════════"; echo "  $1"; echo "══════════════════════════════════════════════"; }
check_cmd(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi; }

# ============================== 0. PRE-FLIGHT ================================
section "0. PRE-FLIGHT CHECKS"
if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi
for pkg in samba postgresql keycloak; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then ok "package $pkg installed"; else fail "package $pkg missing"; exit 1; fi
done

# ============================== 1. WIPE ======================================
section "1. WIPING OLD DATA"
systemctl stop smb nmb winbind samba keycloak slapd nslcd 2>/dev/null || true
pkill -f "kc.sh start-dev" 2>/dev/null || true

rm -rf /var/lib/samba/private/* /var/lib/samba/*.tdb /var/lib/samba/*.ldb /var/cache/samba/* 2>/dev/null || true
rm -f /etc/samba/smb.conf
echo "  Wiped Samba state"

sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${KC_DB}';" 2>&1 | tail -1
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${KC_DB};" 2>&1 | tail -1
sudo -u postgres psql -c "DROP ROLE IF EXISTS ${KC_DB_USER};" 2>&1 | tail -1
sudo -u postgres psql -c "CREATE USER ${KC_DB_USER} WITH PASSWORD '${KC_DB_PASS}';" 2>&1 | tail -1
sudo -u postgres psql -c "CREATE DATABASE ${KC_DB} OWNER ${KC_DB_USER};" 2>&1 | tail -1
echo "  Dropped & recreated Keycloak PostgreSQL DB"
ok "All old data wiped"

# ============================== 2. PROVISION AD DC ============================
section "2. PROVISIONING SAMBA ACTIVE DIRECTORY DC"

cat > /etc/krb5.conf <<KRB
[libdefaults]
	default_realm = ${AD_REALM}
	dns_lookup_realm = false
	dns_lookup_kdc = false

[realms]
	${AD_REALM} = {
		kdc = 127.0.0.1
		admin_server = 127.0.0.1
	}

[domain_realm]
	.awcator.local = ${AD_REALM}
	awcator.local = ${AD_REALM}
KRB

samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --option="dns forwarder = 8.8.8.8" \
  --dns-backend=SAMBA_INTERNAL \
  --realm="${AD_REALM}" \
  --domain="${AD_DOMAIN}" \
  --adminpass="${AD_ADMIN_PASS}" 2>&1 | tail -2

mkdir -p /srv/samba/shared
chmod 777 /srv/samba/shared
chown root:root /srv/samba/shared

cat >> /etc/samba/smb.conf <<SMB

[global]
  ldap server require strong auth = no

[shared]
  comment = Awcator Shared
  path = /srv/samba/shared
  browseable = yes
  read only = no
  create mask = 0660
  directory mask = 0770
SMB

systemctl mask smb nmb winbind >/dev/null 2>&1 || true
systemctl unmask samba >/dev/null 2>&1 || true
systemctl restart samba
sleep 3
check_cmd "Samba AD DC running" systemctl is-active --quiet samba

# ============================== 3. ORG HIERARCHY (OUs) =======================
section "3. ORG HIERARCHY — OUs"
samba-tool ou create "OU=People,${AD_BASE_DN}" >/dev/null
samba-tool ou create "OU=Groups,${AD_BASE_DN}" >/dev/null
samba-tool ou create "OU=Departments,OU=Groups,${AD_BASE_DN}" >/dev/null
samba-tool ou create "OU=Levels,OU=Groups,${AD_BASE_DN}" >/dev/null
samba-tool ou create "OU=Roles,OU=Groups,${AD_BASE_DN}" >/dev/null
ok "Created Base OUs"

# ============================== 4. GROUPS ====================================
section "4. GROUPS"
samba-tool group add lvl1 --groupou="OU=Levels,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4011 >/dev/null
samba-tool group add lvl2 --groupou="OU=Levels,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4012 >/dev/null
samba-tool group add lvl3 --groupou="OU=Levels,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4013 >/dev/null
samba-tool group add lvl4 --groupou="OU=Levels,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4014 >/dev/null
samba-tool group add it --groupou="OU=Departments,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4001 >/dev/null
samba-tool group add hr --groupou="OU=Departments,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4002 >/dev/null
samba-tool group add sales --groupou="OU=Departments,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4003 >/dev/null
samba-tool group add hods --groupou="OU=Roles,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4021 >/dev/null
samba-tool group add managers --groupou="OU=Roles,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4022 >/dev/null
samba-tool group add endusers --groupou="OU=Roles,OU=Groups" --nis-domain="${AD_DOMAIN}" --gid-number=4023 >/dev/null
ok "Created all Groups with POSIX GIDs"

# ============================== 5. USERS =====================================
section "5. USERS"
USERS=(
  "it-hod|IT|Hod|it|hods|lvl4|1001|4001|Hod123!aw"
  "it-mgr|IT|Manager|it|managers|lvl4|1002|4001|Mgr123!aw"
  "it-eng|IT|Engineer|it|endusers|lvl4|1003|4001|Eng123!aw"
  "it-support|IT|Support|it|endusers|lvl3|1004|4001|Sup123!aw"
  "it-staff|IT|Staff|it|endusers|lvl2|1005|4001|Staff123!aw"
  "hr-hod|HR|Hod|hr|hods|lvl3|1006|4002|Hrhod123!aw"
  "hr-mgr|HR|Manager|hr|managers|lvl3|1007|4002|Hrmgr123!aw"
  "hr-staff1|HR|StaffOne|hr|endusers|lvl2|1008|4002|Hr123!aw"
  "hr-staff2|HR|StaffTwo|hr|endusers|lvl1|1009|4002|Hr456!aw"
  "sales-hod|Sales|Hod|sales|hods|lvl3|1010|4003|Shod123!aw"
  "sales-mgr|Sales|Manager|sales|managers|lvl2|1011|4003|Smgr123!aw"
  "sales-rep1|Sales|RepOne|sales|endusers|lvl1|1012|4003|Sr1123!aw"
  "sales-rep2|Sales|RepTwo|sales|endusers|lvl1|1013|4003|Sr2123!aw"
  "ops-cc1|CallCenter|One|it|endusers|lvl1|1014|4001|Cc1123!aw"
  "ops-cc2|CallCenter|Two|it|endusers|lvl1|1015|4001|Cc2123!aw"
)

for u in "${USERS[@]}"; do
  IFS='|' read -r uid gn sn dept role level uidnum gidnum pass <<< "$u"
  samba-tool user create "${uid}" "${pass}" \
    --use-username-as-cn --given-name="${gn}" --surname="${sn}" \
    --userou="OU=People" \
    --nis-domain="${AD_DOMAIN}" --uid-number="${uidnum}" --gid-number="${gidnum}" \
    --login-shell="/bin/bash" --unix-home="/home/${uid}" >/dev/null
  samba-tool group addmembers "${dept}" "${uid}" >/dev/null
  samba-tool group addmembers "${role}" "${uid}" >/dev/null
  samba-tool group addmembers "${level}" "${uid}" >/dev/null
done
ok "Created 15 Users and assigned to Groups"

# ============================== 6. WINBIND (NSS) =============================
section "6. WINBIND (Linux Login)"
cat > /etc/samba/smb.conf.winbind <<WB
# Applied dynamically by our script
  winbind enum users = yes
  winbind enum groups = yes
  winbind use default domain = yes
  template shell = /bin/bash
  template homedir = /home/%U
WB
sed -i '/\[global\]/r /etc/samba/smb.conf.winbind' /etc/samba/smb.conf
systemctl restart samba
sleep 3

if grep -q 'passwd.*winbind' /etc/nsswitch.conf 2>/dev/null; then
  ok "nsswitch already has winbind"
else
  sed -i 's/^passwd:.*/passwd: files systemd winbind/' /etc/nsswitch.conf
  sed -i 's/^group:.*/group: files systemd winbind/' /etc/nsswitch.conf
  ok "nsswitch configured for winbind"
fi

if ! grep -q 'pam_mkhomedir' /etc/pam.d/system-auth 2>/dev/null; then
  sed -i '0,/^session.*required.*pam_unix.so/s//session required pam_mkhomedir.so skel=\/etc\/skel\/ umask=007\n&/' /etc/pam.d/system-auth 2>/dev/null || true
fi

# ============================== 7. KEYCLOAK ==================================
section "7. KEYCLOAK"
cat > /etc/keycloak/keycloak.conf <<KCCONF
db=postgres
db-username=${KC_DB_USER}
db-password=${KC_DB_PASS}
db-url=jdbc:postgresql://localhost/${KC_DB}
http-enabled=true
http-port=8080
hostname-strict=false
hostname-strict-backchannel=false
health-enabled=true
metrics-enabled=true
KCCONF
chown keycloak:keycloak /etc/keycloak/keycloak.conf

mkdir -p /etc/systemd/system/keycloak.service.d
cat > /etc/systemd/system/keycloak.service.d/override.conf <<OVERRIDE
[Service]
Environment=KC_BOOTSTRAP_ADMIN_USERNAME=${KC_ADMIN}
Environment=KC_BOOTSTRAP_ADMIN_PASSWORD=${KC_ADMIN_PASS}
OVERRIDE
systemctl daemon-reload

systemctl restart keycloak
KC_READY=false
for i in $(seq 1 60); do
  if curl -sf "${KC_HEALTH_URL}/health/ready" >/dev/null 2>&1; then
    ok "Keycloak healthy"
    KC_READY=true
    break
  fi
  sleep 2
done
if [[ "$KC_READY" != "true" ]]; then fail "Keycloak not healthy"; exit 1; fi

sleep 3
check_cmd "Keycloak admin token test" curl -sf -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" -d "grant_type=password" -d "client_id=admin-cli" -d "username=${KC_ADMIN}" -d "password=${KC_ADMIN_PASS}"

# ============================== 8. KEYCLOAK AD FEDERATION ====================
section "8. KEYCLOAK AD FEDERATION"
KC_TOKEN=$(curl -sf -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN}" -d "password=${KC_ADMIN_PASS}" \
  | grep -o '"access_token":"[^"]*' | grep -o '[^"]*$')

curl -sf -X POST "${KC_URL}/admin/realms" \
  -H "Authorization: Bearer ${KC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"realm\":\"${KC_REALM}\",\"enabled\":true}" >/dev/null 2>&1 || true
check_cmd "Realm awcator created" curl -sf -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${KC_REALM}"

curl -sf -X POST "${KC_URL}/admin/realms/${KC_REALM}/components" \
  -H "Authorization: Bearer ${KC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"ad-ldap\",
    \"providerId\": \"ldap\",
    \"providerType\": \"org.keycloak.storage.UserStorageProvider\",
    \"config\": {
      \"enabled\": [\"true\"],
      \"editMode\": [\"READ_ONLY\"],
      \"vendor\": [\"ad\"],
      \"usernameLDAPAttribute\": [\"sAMAccountName\"],
      \"rdnLDAPAttribute\": [\"cn\"],
      \"uuidLDAPAttribute\": [\"objectGUID\"],
      \"userObjectClasses\": [\"person, organizationalPerson, user\"],
      \"connectionUrl\": [\"ldap://localhost:389\"],
      \"usersDn\": [\"OU=People,${AD_BASE_DN}\"],
      \"authType\": [\"simple\"],
      \"bindDn\": [\"CN=Administrator,CN=Users,${AD_BASE_DN}\"],
      \"bindCredential\": [\"${AD_ADMIN_PASS}\"],
      \"searchScope\": [\"1\"],
      \"useTruststoreSpi\": [\"never\"],
      \"pagination\": [\"true\"]
    }
  }" >/dev/null 2>&1 || true

# Extract the ID of the provider we just created (index 1 if default exists)
AD_PROVIDER_ID=$(curl -sf -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${KC_REALM}/components?type=org.keycloak.storage.UserStorageProvider" | jq -r '.[1].id // .[0].id')

if [[ -n "$AD_PROVIDER_ID" && "$AD_PROVIDER_ID" != "null" ]]; then
  curl -sf -X POST "${KC_URL}/admin/realms/${KC_REALM}/components" \
    -H "Authorization: Bearer ${KC_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"group-mapper\",
      \"providerId\": \"group-ldap-mapper\",
      \"providerType\": \"org.keycloak.storage.ldap.mappers.LDAPStorageMapper\",
      \"parentId\": \"${AD_PROVIDER_ID}\",
      \"config\": {
        \"mode\": [\"READ_ONLY\"],
        \"groups.dn\": [\"OU=Groups,${AD_BASE_DN}\"],
        \"group.name.ldap.attribute\": [\"cn\"],
        \"group.object.classes\": [\"group\"],
        \"preserve.group.inheritance\": [\"true\"],
        \"membership.ldap.attribute\": [\"member\"],
        \"membership.attribute.type\": [\"DN\"],
        \"memberof.ldap.attribute\": [\"memberOf\"]
      }
    }" >/dev/null 2>&1 || true

  curl -sf -X POST "${KC_URL}/admin/realms/${KC_REALM}/user-storage/${AD_PROVIDER_ID}/sync?action=triggerFullSync" -H "Authorization: Bearer ${KC_TOKEN}" >/dev/null 2>&1 || true
  sleep 5
fi

# ============================== 9. TEST SCRIPTS ==============================
section "9. GENERATING DEV SCRIPTS TO SAMBA SHARE"

# 9.1: SQL Installer Script
cat > /srv/samba/shared/install-sql.ps1 <<'SQLPS1'
Write-Output "Downloading Full SQL Server 2022 Express Installer..."
Invoke-WebRequest -Uri "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe" -OutFile "C:\SQLEXPR_x64_ENU.exe"

Write-Output "Extracting installer safely to C:\SQLSetup_Final..."
Start-Process -FilePath "C:\SQLEXPR_x64_ENU.exe" -ArgumentList "/q /x:C:\SQLSetup_Final" -Wait

Write-Output "Installing SQL Server and applying Sysadmin rights to AWCATOR\it-eng..."
Start-Process -FilePath "C:\SQLSetup_Final\SETUP.EXE" -ArgumentList '/Q /ACTION=Install /FEATURES=SQL /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /SQLSYSADMINACCOUNTS="AWCATOR\it-eng" "AWCATOR\Administrator" /AGTSVCACCOUNT="NT AUTHORITY\Network Service" /IACCEPTSQLSERVERLICENSETERMS' -Wait

Write-Output "Downloading SQL Server Management Studio (SSMS)..."
Invoke-WebRequest -Uri "https://aka.ms/ssmsfullsetup" -OutFile "C:\SSMS-Setup.exe"

Write-Output "Installing SSMS silently (takes a few minutes)..."
Start-Process -FilePath "C:\SSMS-Setup.exe" -ArgumentList "/Passive" -Wait

Write-Output "Installation complete! You can now log into SQL Server Management Studio as 'it-eng'."
SQLPS1

# 9.2: Python Test Script
cat > /srv/samba/shared/test_sql.py <<'SQLPY'
import pyodbc

conn_str = (
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=localhost\\SQLEXPRESS;"
    "Database=master;"
    "Trusted_Connection=yes;"
)

print("Connecting to SQL Server Express using Active Directory Kerberos Token...")
conn = pyodbc.connect(conn_str, autocommit=True)
cursor = conn.cursor()

cursor.execute("SELECT SUSER_SNAME()")
current_user = cursor.fetchone()[0]
print(f"✅ Successfully logged in as: {current_user}")

db_name = "DevOpsTestDB"
print(f"\nCreating Database: {db_name}...")
try:
    cursor.execute(f"CREATE DATABASE {db_name}")
    print("✅ Database created successfully.")
except Exception as e:
    print(f"⚠️ Database might already exist: {e}")

conn.close()
conn_str_db = conn_str.replace("Database=master;", f"Database={db_name};")
conn = pyodbc.connect(conn_str_db, autocommit=True)
cursor = conn.cursor()

print("\nCreating Table: Employees...")
cursor.execute("""
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Employees' and xtype='U')
    CREATE TABLE Employees (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(50),
        Department NVARCHAR(50),
        Role NVARCHAR(50)
    )
""")
print("✅ Table created.")

print("\nInserting data for AWCATOR personnel...")
cursor.execute("INSERT INTO Employees (Name, Department, Role) VALUES (?, ?, ?)", ("IT Engineer", "IT", "Sysadmin"))
cursor.execute("INSERT INTO Employees (Name, Department, Role) VALUES (?, ?, ?)", ("HR Manager", "HR", "Manager"))
cursor.execute("INSERT INTO Employees (Name, Department, Role) VALUES (?, ?, ?)", ("Sales Rep", "Sales", "Enduser"))
print("✅ Data inserted.")

print("\nFetching data from Employees table:")
print("-" * 40)
cursor.execute("SELECT * FROM Employees")
for row in cursor.fetchall():
    print(f"ID: {row.ID} | Name: {row.Name:<15} | Dept: {row.Department:<5} | Role: {row.Role}")
print("-" * 40)

print("\n🎉 Full database lifecycle completed successfully via AD Windows Authentication!")

cursor.close()
conn.close()
SQLPY

# 9.3: Create SQL Service Script
cat > /srv/samba/shared/Create-SqlService.ps1 <<'CREATESVC'
# Enable TCP/IP in SQL Server Express and Restart the SQL Service
Write-Output "Enabling TCP/IP for SQL Server Express to allow network/remote connections..."
$sqlProviderPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp"
if (Test-Path $sqlProviderPath) {
    Set-ItemProperty -Path $sqlProviderPath -Name "Enabled" -Value 1
    $sqlIpAllPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
    if (Test-Path $sqlIpAllPath) {
        Set-ItemProperty -Path $sqlIpAllPath -Name "TcpPort" -Value "1433"
        Set-ItemProperty -Path $sqlIpAllPath -Name "TcpDynamicPorts" -Value ""
    }
    Write-Output "Restarting SQL Server Service..."
    Restart-Service -Name "MSSQL`$SQLEXPRESS" -Force
} else {
    Write-Output "WARNING: Could not find SQL Registry path to enable TCP/IP. Skipping..."
}
# 1. Download NSSM
$nssmZip = "C:\Users\Public\nssm.zip"
$nssmExtracted = "C:\Users\Public\nssm"
Write-Output "Downloading NSSM..."
if (-not (Test-Path $nssmZip)) {
    Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip
    Expand-Archive -Path $nssmZip -DestinationPath $nssmExtracted -Force
}
$nssmExe = "$nssmExtracted\nssm-2.24\win64\nssm.exe"

# 2. Write a pure PowerShell service wrapper
$psScript = "C:\Users\Public\SqlServiceQuery.ps1"
$logFile = "C:\Users\Public\SqlService.log"

@"
`$logFile = "C:\Users\Public\SqlService.log"
function Log(`$msg) {
    `$time = Get-Date -Format "HH:mm:ss"
    Add-Content -Path `$logFile -Value "[`$time] `$msg"
}

Log "Starting background query service (Pure PowerShell)..."
try {
    `$connStr = "Server=localhost\SQLEXPRESS;Database=DevOpsTestDB;Integrated Security=True;TrustServerCertificate=True;"
    `$conn = New-Object System.Data.SqlClient.SqlConnection(`$connStr)
    
    Log "Connecting to SQL Server..."
    `$conn.Open()
    
    `$cmd = `$conn.CreateCommand()
    `$cmd.CommandText = "SELECT SUSER_SNAME()"
    `$currentUser = `$cmd.ExecuteScalar()
    Log "Authenticated to SQL Server as: `$currentUser"
    
    while (`$true) {
        `$cmd.CommandText = "SELECT COUNT(*) FROM Employees"
        `$count = `$cmd.ExecuteScalar()
        Log "Successfully queried database! Found `$count Employees in the table."
        Start-Sleep -Seconds 30
    }
} catch {
    Log "FATAL ERROR: `$_"
    Start-Sleep -Seconds 5
}
"@ | Out-File -FilePath $psScript -Encoding ascii

# 3. Configure the Windows Service
$serviceName = "Simple_SQL_Service"
& $nssmExe stop $serviceName 2>$null
& $nssmExe remove $serviceName confirm 2>$null
Start-Sleep -Seconds 2

$psExe = (Get-Command powershell.exe).Source
& $nssmExe install $serviceName "$psExe" "-ExecutionPolicy Bypass -NoProfile -NonInteractive -File $psScript"
& $nssmExe set $serviceName AppDirectory "C:\Users\Public\"

# 4. Pure PowerShell API to Grant "Log on as a Service" Right
$code = @"
using System;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Security.Principal;
using System.Text;

public class LsaWrapper
{
    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_OBJECT_ATTRIBUTES
    {
        public int Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public int Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct LSA_UNICODE_STRING
    {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }

    [DllImport("advapi32.dll", PreserveSig = true)]
    private static extern uint LsaOpenPolicy(ref LSA_UNICODE_STRING SystemName, ref LSA_OBJECT_ATTRIBUTES ObjectAttributes, int AccessMask, out IntPtr PolicyHandle);

    [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
    private static extern uint LsaAddAccountRights(IntPtr PolicyHandle, IntPtr AccountSid, LSA_UNICODE_STRING[] UserRights, int CountOfRights);

    [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
    private static extern uint LsaClose(IntPtr ObjectHandle);

    [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
    private static extern int LsaNtStatusToWinError(uint status);

    public static void AddPrivilege(string account, string privilege)
    {
        IntPtr policyHandle = IntPtr.Zero;
        uint status;
        
        NTAccount ntAccount = new NTAccount(account);
        SecurityIdentifier sid = (SecurityIdentifier)ntAccount.Translate(typeof(SecurityIdentifier));
        byte[] sidBytes = new byte[sid.BinaryLength];
        sid.GetBinaryForm(sidBytes, 0);
        IntPtr sidPtr = Marshal.AllocHGlobal(sidBytes.Length);
        Marshal.Copy(sidBytes, 0, sidPtr, sidBytes.Length);

        LSA_OBJECT_ATTRIBUTES objAttributes = new LSA_OBJECT_ATTRIBUTES();
        objAttributes.Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));

        LSA_UNICODE_STRING systemName = new LSA_UNICODE_STRING();

        status = LsaOpenPolicy(ref systemName, ref objAttributes, 0x00000800, out policyHandle);
        if (status != 0) throw new Win32Exception(LsaNtStatusToWinError(status));

        LSA_UNICODE_STRING[] privileges = new LSA_UNICODE_STRING[1];
        privileges[0] = new LSA_UNICODE_STRING();
        privileges[0].Buffer = Marshal.StringToHGlobalUni(privilege);
        privileges[0].Length = (ushort)(privilege.Length * 2);
        privileges[0].MaximumLength = (ushort)(privileges[0].Length + 2);

        status = LsaAddAccountRights(policyHandle, sidPtr, privileges, 1);
        
        Marshal.FreeHGlobal(sidPtr);
        Marshal.FreeHGlobal(privileges[0].Buffer);
        LsaClose(policyHandle);

        if (status != 0) throw new Win32Exception(LsaNtStatusToWinError(status));
    }
}
"@

try {
    Add-Type -TypeDefinition $code -ErrorAction Stop
} catch {
    # Type might already exist in this session
}

$user = "AWCATOR\it-eng"
$plainPass = "Eng123!aw"

try {
    [LsaWrapper]::AddPrivilege($user, "SeServiceLogonRight")
} catch {
}

Write-Output "Configuring NSSM ObjectName..."
& $nssmExe set $serviceName ObjectName $user $plainPass

Write-Output "Starting the service..."
Start-Service -Name $serviceName

if ((Get-Service $serviceName).Status -eq 'Running') {
    Write-Output "SUCCESS! Service is running."
} else {
    Write-Output "Service failed to start."
}
Write-Output "Check C:\Users\Public\SqlService.log"
CREATESVC

# 9.4: Delete SQL Service Script
cat > /srv/samba/shared/Delete-SqlService.ps1 <<'DELETESVC'
$nssmExe = "C:\Users\Public\nssm\nssm-2.24\win64\nssm.exe"
$serviceName = "Simple_SQL_Service"

Write-Output "Stopping $serviceName..."
& $nssmExe stop $serviceName 2>$null

Write-Output "Removing $serviceName..."
& $nssmExe remove $serviceName confirm 2>$null

Write-Output "Cleaning up files..."
Remove-Item -Path "C:\Users\Public\SqlServiceQuery.ps1" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Users\Public\SqlService.log" -Force -ErrorAction SilentlyContinue

Write-Output "Done! Service deleted and logs cleaned up."
DELETESVC

chmod 777 /srv/samba/shared/*
ok "Generated all Windows test scripts to /srv/samba/shared/"

# ============================== 10. TESTS ====================================
section "10. INTEGRATION TESTS"

check_cmd "AD DC Resolves users" samba-tool user list
check_cmd "SMB Share accessible via AD User (Kerberos)" bash -c "smbclient -L localhost -U \"it-eng%Eng123!aw\""
check_cmd "Keycloak Auth works via AD" curl -sf -X POST "${KC_URL}/realms/${KC_REALM}/protocol/openid-connect/token" -d "grant_type=password" -d "client_id=admin-cli" -d "username=it-eng" -d "password=Eng123!aw"

# ============================== SUMMARY ======================================
echo
echo "╔═════════════════════════════════════════════════════════╗"
echo "║      SAMBA ACTIVE DIRECTORY STACK — SETUP COMPLETE      ║"
echo "╠═════════════════════════════════════════════════════════╣"
printf "║  Tests passed: %-3d    Tests failed: %-3d               ║\n" "$PASS" "$FAIL"
echo "╠═════════════════════════════════════════════════════════╣"
echo "║  Domain:     ${AD_REALM} (${AD_DOMAIN})                        ║"
echo "║  Admin:      Administrator / ${AD_ADMIN_PASS}                 ║"
echo "║  Keycloak:   ${KC_URL}                                 ║"
echo "║  Fileshare:  \\\\<IP_ADDRESS>\shared                     ║"
echo "║  Scripts:    Available in the shared folder!            ║"
echo "╚═════════════════════════════════════════════════════════╝"
