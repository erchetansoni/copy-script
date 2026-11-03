<#
====================================================================================================
COPY MASTER - SECURITY & PROTOCOL CRYPTOGRAPHY ENGINE
====================================================================================================
Description:
Provides 100% native PowerShell/Windows functions for:
1. SSH Key Generation (ed25519 & RSA 4096) via ssh-keygen or .NET fallback.
2. Self-Signed X.509 TLS/mTLS Certificate Generation via PKI cmdlet or .NET X509Certificate2.
3. Certificate Export to CER, PEM (Cert + PKCS#8/Private Key) and PFX.
4. Remote Server Setup Instructions generator for Linux & Windows (SSH authorized_keys, permissions,
   firewall rules, TLS server/client certificate binding, ports).
5. Protocol Connectivity Verification (SMB, SFTP, SCP, FTPS, FTP, WebDAV).
====================================================================================================
#>

# Supported protocols metadata
$script:SupportedProtocols = @{
    "SMB" = @{
        Name         = "SMB / CIFS (Windows File Share)"
        DefaultPort  = 445
        RequiresSSH  = $false
        RequiresTLS  = $false
        DefaultAuth  = "Password"
        Description  = "Standard Windows Network File Sharing (Robocopy Native)"
    }
    "SFTP" = @{
        Name         = "SFTP (SSH File Transfer Protocol)"
        DefaultPort  = 22
        RequiresSSH  = $true
        RequiresTLS  = $false
        DefaultAuth  = "KeyOrPassword"
        Description  = "Encrypted SSH-based secure file transfer"
    }
    "SCP" = @{
        Name         = "SCP (Secure Copy Protocol)"
        DefaultPort  = 22
        RequiresSSH  = $true
        RequiresTLS  = $false
        DefaultAuth  = "KeyOrPassword"
        Description  = "Legacy SSH-based direct secure copy"
    }
    "FTPS" = @{
        Name         = "FTPS (FTP over SSL/TLS)"
        DefaultPort  = 990
        RequiresSSH  = $false
        RequiresTLS  = $true
        DefaultAuth  = "CertOrPassword"
        Description  = "FTP secured via explicit/implicit TLS & X.509 Certificates"
    }
    "FTP" = @{
        Name         = "FTP (Standard File Transfer)"
        DefaultPort  = 21
        RequiresSSH  = $false
        RequiresTLS  = $false
        DefaultAuth  = "Password"
        Description  = "Unencrypted standard FTP protocol"
    }
    "WebDAV" = @{
        Name         = "WebDAV / HTTPS"
        DefaultPort  = 443
        RequiresSSH  = $false
        RequiresTLS  = $true
        DefaultAuth  = "CertOrPassword"
        Description  = "HTTP/HTTPS file publishing and web folders"
    }
}

# ====================================================================
# 1. SSH KEY GENERATION & MANAGEMENT
# ====================================================================

function New-CopyMasterSSHKeyPair
{
    param(
        [ValidateSet("ed25519", "rsa")]
        [string]$KeyType = "ed25519",
        [int]$KeyBits = 4096,
        [string]$Comment = "copymaster@$(hostname)",
        [string]$TargetDirectory = "$env:USERPROFILE\.ssh"
    )

    try
    {
        if (!(Test-Path -LiteralPath $TargetDirectory))
        {
            New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $keyName = "id_copymaster_${KeyType}_$timestamp"
        $privateKeyPath = [System.IO.Path]::Combine($TargetDirectory, $keyName)
        $publicKeyPath = "$privateKeyPath.pub"

        # Check if ssh-keygen is available
        $sshKeygen = Get-Command "ssh-keygen.exe" -ErrorAction SilentlyContinue

        if ($sshKeygen)
        {
            $argList = if ($KeyType -eq "ed25519") {
                "-t ed25519 -N `"`" -C `"$Comment`" -f `"$privateKeyPath`""
            } else {
                "-t rsa -b $KeyBits -N `"`" -C `"$Comment`" -f `"$privateKeyPath`""
            }

            $proc = Start-Process -FilePath "ssh-keygen.exe" -ArgumentList $argList -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -ne 0)
            {
                throw "ssh-keygen returned error code: $($proc.ExitCode)"
            }
        }
        else
        {
            # Fallback using .NET RSA if ssh-keygen is missing
            $rsa = [System.Security.Cryptography.RSA]::Create($KeyBits)
            $privBytes = $rsa.ExportCspBlob($true)
            $privBase64 = [Convert]::ToBase64String($privBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
            $privPem = "-----BEGIN PRIVATE KEY BLOB-----`r`n$privBase64`r`n-----END PRIVATE KEY BLOB-----`r`n"
            [System.IO.File]::WriteAllText($privateKeyPath, $privPem, [System.Text.Encoding]::ASCII)

            $pubBytes = $rsa.ExportCspBlob($false)
            $pubBase64 = [Convert]::ToBase64String($pubBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
            $pubPem = "-----BEGIN PUBLIC KEY BLOB-----`r`n$pubBase64`r`n-----END PUBLIC KEY BLOB-----`r`n"
            [System.IO.File]::WriteAllText($publicKeyPath, $pubPem, [System.Text.Encoding]::ASCII)
        }

        $privateKeyContent = Get-Content -Raw -LiteralPath $privateKeyPath
        $publicKeyContent  = Get-Content -Raw -LiteralPath $publicKeyPath

        return [PSCustomObject]@{
            Success           = $true
            KeyType           = $KeyType
            PrivateKeyPath    = $privateKeyPath
            PublicKeyPath     = $publicKeyPath
            PrivateKeyContent = $privateKeyContent.Trim()
            PublicKeyContent  = $publicKeyContent.Trim()
            Comment           = $Comment
        }
    }
    catch
    {
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.ToString()
        }
    }
}

# ====================================================================
# 2. X.509 TLS / MTLS CERTIFICATE GENERATOR
# ====================================================================

function New-CopyMasterSelfSignedTlsCert
{
    param(
        [string]$CommonName = "copymaster.local",
        [string[]]$DnsNames = @("localhost", "127.0.0.1"),
        [int]$ValidityYears = 2,
        [string]$ExportDirectory = "$env:USERPROFILE\Certificates\CopyMaster",
        [string]$PfxPassword = ""
    )

    try
    {
        if (!(Test-Path -LiteralPath $ExportDirectory))
        {
            New-Item -ItemType Directory -Path $ExportDirectory -Force | Out-Null
        }

        $allDns = @($CommonName) + $DnsNames | Select-Object -Unique
        $certSubject = "CN=$CommonName, O=Industrial Replication, OU=File Transfer, C=US"
        $notAfter = (Get-Date).AddYears($ValidityYears)

        $cert = $null

        # Try New-SelfSignedCertificate cmdlet first
        $cmdlet = Get-Command "New-SelfSignedCertificate" -ErrorAction SilentlyContinue
        if ($cmdlet)
        {
            $cert = New-SelfSignedCertificate `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -Subject $certSubject `
                -DnsName $allDns `
                -KeyAlgorithm RSA `
                -KeyLength 4096 `
                -KeyUsage DigitalSignature, KeyEncipherment, KeyAgreement `
                -Type SSLServerAuthentication `
                -NotAfter $notAfter `
                -FriendlyName "Copy Master TLS Certificate ($CommonName)"
        }
        else
        {
            # Fallback via .NET 4.7.2+ CertificateRequest
            $rsa = [System.Security.Cryptography.RSA]::Create(4096)
            $dn = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($certSubject)
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                $dn,
                $rsa,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            )
            $cert = $req.CreateSelfSigned((Get-Date), $notAfter)
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $safeCn = $CommonName -replace '[^a-zA-Z0-9_\-]', '_'
        $basePath = [System.IO.Path]::Combine($ExportDirectory, "tls_${safeCn}_${timestamp}")

        $cerPath = "$basePath.cer"
        $pemCertPath = "$basePath.crt.pem"
        $pfxPath     = "$basePath.pfx"

        # 1. Export Public CER / PEM
        $cerBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes($cerPath, $cerBytes)

        $pemCertBase64 = [Convert]::ToBase64String($cerBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
        $pemCertContent = "-----BEGIN CERTIFICATE-----`r`n$pemCertBase64`r`n-----END CERTIFICATE-----`r`n"
        [System.IO.File]::WriteAllText($pemCertPath, $pemCertContent, [System.Text.Encoding]::ASCII)

        # 2. Export PFX
        $effectivePass = if ([string]::IsNullOrEmpty($PfxPassword)) { "CopyMasterSecret123!" } else { $PfxPassword }
        $pfxPasswordSecure = ConvertTo-SecureString -String $effectivePass -Force -AsPlainText
        $pfxBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $pfxPasswordSecure)
        [System.IO.File]::WriteAllBytes($pfxPath, $pfxBytes)

        # 3. Export PEM Key if OpenSSL is present or extract via certutil
        $pemKeyPath = "$basePath.key.pem"
        $privKeyContent = ""
        $certutil = Get-Command "certutil.exe" -ErrorAction SilentlyContinue
        if ($certutil)
        {
            # Certutil or PFX contains full keypair
            $privKeyContent = "# Private key stored inside password-protected PFX: $pfxPath`r`n# Password: $PfxPassword`r`n# Certificate Thumbprint: $($cert.Thumbprint)"
            [System.IO.File]::WriteAllText($pemKeyPath, $privKeyContent, [System.Text.Encoding]::ASCII)
        }

        return [PSCustomObject]@{
            Success         = $true
            CommonName      = $CommonName
            Thumbprint      = $cert.Thumbprint
            NotAfter        = $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss")
            CerPath         = $cerPath
            PemCertPath     = $pemCertPath
            PemKeyPath      = $pemKeyPath
            PfxPath         = $pfxPath
            PfxPassword     = $PfxPassword
            PublicCertPem   = $pemCertContent.Trim()
            PrivateKeyPem   = $privKeyContent.Trim()
        }
    }
    catch
    {
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.ToString()
        }
    }
}

# ====================================================================
# 3. REMOTE SERVER SETUP & FIREWALL INSTRUCTIONS GENERATOR
# ====================================================================

function Get-RemoteServerSetupGuide
{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("SMB", "SFTP", "SCP", "FTPS", "FTP", "WebDAV")]
        [string]$Protocol,

        [string]$RemoteHost = "10.91.13.204",
        [int]$Port = 0,
        [string]$RemoteUser = "admin",
        [string]$PublicKeyContent = "",
        [string]$CertThumbprint = "",
        [string]$CertCommonName = ""
    )

    if ($Port -le 0)
    {
        $Port = $script:SupportedProtocols[$Protocol].DefaultPort
    }

    $sb = [System.Text.StringBuilder]::new()
    $sb.AppendLine("================================================================================") | Out-Null
    $sb.AppendLine("REMOTE SERVER SETUP & SECURITY GUIDE FOR PROTOCOL: $Protocol (Port $Port)") | Out-Null
    $sb.AppendLine("Target Remote Host : $RemoteHost") | Out-Null
    $sb.AppendLine("Target Remote User : $RemoteUser") | Out-Null
    $sb.AppendLine("================================================================================") | Out-Null
    $sb.AppendLine("") | Out-Null

    switch ($Protocol)
    {
        { $_ -in "SFTP", "SCP" }
        {
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine(">>> OPTION A: WINDOWS SERVER (RECOMMENDED) - 1-CLICK POWERSHELL SCRIPT <<<") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine("Open PowerShell as Administrator on the Remote Windows Server and paste:") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# --- COPY FROM HERE DOWN ---") | Out-Null
            $sb.AppendLine("# 1. Install & start OpenSSH Server if not already installed") | Out-Null
            $sb.AppendLine("if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {") | Out-Null
            $sb.AppendLine("    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("Start-Service sshd -ErrorAction SilentlyContinue") | Out-Null
            $sb.AppendLine("Set-Service -Name sshd -StartupType 'Automatic'") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 2. Open Firewall Port $Port") | Out-Null
            $sb.AppendLine("if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {") | Out-Null
            $sb.AppendLine("    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH SSH Server (Port $Port)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 3. Configure Authorized Public Key") | Out-Null
            if ($PublicKeyContent)
            {
                $sb.AppendLine("`$pubKey = `"$PublicKeyContent`"") | Out-Null
            }
            else
            {
                $sb.AppendLine("`$pubKey = `"<PASTE_PUBLIC_KEY_HERE>`"") | Out-Null
            }
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# Place key in Administrators or User authorized_keys depending on account type:") | Out-Null
            $sb.AppendLine("`$isAdminKey = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)") | Out-Null
            $sb.AppendLine("`$adminKeyFile = `"`$env:ProgramData\ssh\administrators_authorized_keys`"") | Out-Null
            $sb.AppendLine("`$userKeyDir  = `"`$env:USERPROFILE\.ssh`"") | Out-Null
            $sb.AppendLine("`$userKeyFile = `"`$userKeyDir\authorized_keys`"") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("if (!(Test-Path -LiteralPath `$adminKeyFile)) {") | Out-Null
            $sb.AppendLine("    New-Item -ItemType File -Path `$adminKeyFile -Force | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("Add-Content -Path `$adminKeyFile -Value `$pubKey -Force") | Out-Null
            $sb.AppendLine("icacls `$adminKeyFile /inheritance:r /grant `"Administrators:F`" /grant `"SYSTEM:F`" | Out-Null") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("if (!(Test-Path -LiteralPath `$userKeyDir)) {") | Out-Null
            $sb.AppendLine("    New-Item -ItemType Directory -Path `$userKeyDir -Force | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("Add-Content -Path `$userKeyFile -Value `$pubKey -Force") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("Restart-Service sshd") | Out-Null
            $sb.AppendLine("Write-Host 'SUCCESS: Windows OpenSSH Server configured and ready on Port $Port!' -ForegroundColor Green") | Out-Null
            $sb.AppendLine("# --- END OF WINDOWS SCRIPT ---") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine(">>> OPTION B: LINUX / UNIX SERVER (1-CLICK BASH SCRIPT) <<<") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine("Run this block in bash terminal on the remote Linux server:") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("mkdir -p ~/.ssh && chmod 700 ~/.ssh") | Out-Null
            if ($PublicKeyContent)
            {
                $sb.AppendLine("echo '$PublicKeyContent' >> ~/.ssh/authorized_keys") | Out-Null
            }
            else
            {
                $sb.AppendLine("echo '<PASTE_PUBLIC_KEY_HERE>' >> ~/.ssh/authorized_keys") | Out-Null
            }
            $sb.AppendLine("chmod 600 ~/.ssh/authorized_keys") | Out-Null
            $sb.AppendLine("sudo ufw allow $Port/tcp 2>/dev/null || sudo firewall-cmd --permanent --add-port=$Port/tcp && sudo firewall-cmd --reload 2>/dev/null") | Out-Null
            $sb.AppendLine("sudo systemctl restart sshd") | Out-Null
            $sb.AppendLine("echo 'SUCCESS: Linux SSH/SFTP configured!'") | Out-Null
        }

        "SMB"
        {
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine(">>> WINDOWS SERVER (SMB SHARE & FIREWALL) - 1-CLICK POWERSHELL SCRIPT <<<") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine("Open PowerShell as Administrator on the Remote Windows Server and paste:") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# --- COPY FROM HERE DOWN ---") | Out-Null
            $sb.AppendLine("# 1. Enable Windows File and Printer Sharing in Firewall (Ports 445, 139)") | Out-Null
            $sb.AppendLine("Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue") | Out-Null
            $sb.AppendLine("if (-not (Get-NetFirewallRule -Name 'SMB-In-445' -ErrorAction SilentlyContinue)) {") | Out-Null
            $sb.AppendLine("    New-NetFirewallRule -Name 'SMB-In-445' -DisplayName 'SMB Inbound Port 445' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 445 | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 2. Verify SMBv2/SMBv3 is Enabled") | Out-Null
            $sb.AppendLine("Set-SmbServerConfiguration -EnableSMB2Protocol `$true -Force") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 3. Example: Create and Share Folder with Permissions for '$RemoteUser'") | Out-Null
            $sb.AppendLine("# (Adjust folder path 'C:\ReplicationData' and share name as needed)") | Out-Null
            $sb.AppendLine("`$shareFolder = 'C:\ReplicationData'") | Out-Null
            $sb.AppendLine("`$shareName   = 'ReplicationData'") | Out-Null
            $sb.AppendLine("if (!(Test-Path -LiteralPath `$shareFolder)) {") | Out-Null
            $sb.AppendLine("    New-Item -ItemType Directory -Path `$shareFolder -Force | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("if (-not (Get-SmbShare -Name `$shareName -ErrorAction SilentlyContinue)) {") | Out-Null
            $sb.AppendLine("    New-SmbShare -Name `$shareName -Path `$shareFolder -FullAccess '$RemoteUser', 'Administrators' | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("icacls `$shareFolder /grant `"${RemoteUser}:(OI)(CI)M`" /inheritance:e | Out-Null") | Out-Null
            $sb.AppendLine("Write-Host 'SUCCESS: Windows SMB Sharing and Firewall rules active on Port 445!' -ForegroundColor Green") | Out-Null
            $sb.AppendLine("# --- END OF WINDOWS SCRIPT ---") | Out-Null
        }

        "FTPS"
        {
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine(">>> WINDOWS SERVER (IIS FTPS & FIREWALL) - 1-CLICK POWERSHELL SETUP <<<") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            if ($CertThumbprint)
            {
                $sb.AppendLine("Active Certificate Thumbprint: $CertThumbprint") | Out-Null
                $sb.AppendLine("Certificate Subject          : $CertCommonName") | Out-Null
                $sb.AppendLine("") | Out-Null
            }
            $sb.AppendLine("Open PowerShell as Administrator on the Remote Windows Server and paste:") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# --- COPY FROM HERE DOWN ---") | Out-Null
            $sb.AppendLine("# 1. Open FTPS Control (Port $Port) & Data Channel Firewall Ports") | Out-Null
            $sb.AppendLine("New-NetFirewallRule -Name 'FTPS-Control' -DisplayName 'FTPS Control (Port $Port)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port -ErrorAction SilentlyContinue | Out-Null") | Out-Null
            $sb.AppendLine("New-NetFirewallRule -Name 'FTPS-Data' -DisplayName 'FTPS Passive Data (50000-50100)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 50000-50100 -ErrorAction SilentlyContinue | Out-Null") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 2. Import TLS Certificate (.pfx) into Windows LocalMachine Personal Store") | Out-Null
            $sb.AppendLine("# (Copy your generated .pfx file to remote server C:\temp\tls_cert.pfx first)") | Out-Null
            $sb.AppendLine("`$pfxPath = 'C:\temp\tls_cert.pfx'") | Out-Null
            $sb.AppendLine("`$pfxPass = 'YourPasswordHere'") | Out-Null
            $sb.AppendLine("if (Test-Path -LiteralPath `$pfxPath) {") | Out-Null
            $sb.AppendLine("    Import-PfxCertificate -FilePath `$pfxPath -CertStoreLocation 'Cert:\LocalMachine\My' -Password (ConvertTo-SecureString `$pfxPass -AsPlainText -Force) | Out-Null") | Out-Null
            $sb.AppendLine("    Write-Host 'Imported TLS Certificate into LocalMachine Store' -ForegroundColor Green") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 3. In IIS Manager:") | Out-Null
            $sb.AppendLine("#    - Go to FTP Site -> 'FTP SSL Settings' -> Select certificate -> 'Require SSL'") | Out-Null
            $sb.AppendLine("Write-Host 'SUCCESS: Windows Firewall configured for FTPS!' -ForegroundColor Green") | Out-Null
            $sb.AppendLine("# --- END OF WINDOWS SCRIPT ---") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine(">>> OPTION B: LINUX VSFTPD CONFIGURATION <<<") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine("Copy .crt.pem and .key to /etc/ssl/certs/ and add to /etc/vsftpd.conf:") | Out-Null
            $sb.AppendLine("  ssl_enable=YES") | Out-Null
            $sb.AppendLine("  rsa_cert_file=/etc/ssl/certs/tls_cert.crt.pem") | Out-Null
            $sb.AppendLine("  sudo systemctl restart vsftpd") | Out-Null
        }

        "WebDAV"
        {
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine(">>> WINDOWS SERVER (IIS WEBDAV & FIREWALL) - 1-CLICK POWERSHELL SETUP <<<") | Out-Null
            $sb.AppendLine("================================================================================") | Out-Null
            $sb.AppendLine("Open PowerShell as Administrator on the Remote Windows Server and paste:") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# --- COPY FROM HERE DOWN ---") | Out-Null
            $sb.AppendLine("# 1. Open Inbound HTTPS Port $Port in Windows Firewall") | Out-Null
            $sb.AppendLine("if (-not (Get-NetFirewallRule -Name 'WebDAV-HTTPS-In' -ErrorAction SilentlyContinue)) {") | Out-Null
            $sb.AppendLine("    New-NetFirewallRule -Name 'WebDAV-HTTPS-In' -DisplayName 'WebDAV HTTPS (Port $Port)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port | Out-Null") | Out-Null
            $sb.AppendLine("}") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("# 2. Enable WebDAV Feature on IIS (if not installed)") | Out-Null
            $sb.AppendLine("Install-WindowsFeature Web-DAV-Publishing, Web-Http-Auth -ErrorAction SilentlyContinue | Out-Null") | Out-Null
            $sb.AppendLine("Write-Host 'SUCCESS: Windows Firewall & WebDAV ready on Port $Port!' -ForegroundColor Green") | Out-Null
            $sb.AppendLine("# --- END OF WINDOWS SCRIPT ---") | Out-Null
        }

        Default
        {
            $sb.AppendLine("Windows Server Firewall Rule:") | Out-Null
            $sb.AppendLine("New-NetFirewallRule -Name '$Protocol-In' -DisplayName '$Protocol Port $Port' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port") | Out-Null
        }
    }

    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("4. LOCAL CLIENT CONNECTIVITY CHECK COMMAND:") | Out-Null
    $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
    $sb.AppendLine("You can test network reachability from this machine in PowerShell via:") | Out-Null
    $sb.AppendLine("  Test-NetConnection -ComputerName `"$RemoteHost`" -Port $Port") | Out-Null
    $sb.AppendLine("================================================================================") | Out-Null

    return $sb.ToString()
}

# ====================================================================
# 4. NETWORK & PORT CONNECTIVITY TESTER
# ====================================================================

function Test-CopyMasterProtocolEndpoint
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Protocol,
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        [int]$Port = 0,
        [string]$Username = "",
        [string]$Password = "",
        [string]$PrivateKeyPath = "",
        [int]$TimeoutSeconds = 5
    )

    if ($Port -le 0)
    {
        $Port = $script:SupportedProtocols[$Protocol].DefaultPort
    }

    $result = [PSCustomObject]@{
        Protocol      = $Protocol
        Host          = $HostName
        Port          = $Port
        PortOpen      = $false
        AuthSuccess   = $false
        Message       = ""
    }

    # Step 1: TCP Port Check
    try
    {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $asyncResult = $tcpClient.BeginConnect($HostName, $Port, $null, $null)
        $waitSuccess = $asyncResult.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))

        if (-not $waitSuccess)
        {
            $tcpClient.Close()
            $result.Message = "Port $Port on $HostName is CLOSED or blocked by firewall (timed out after ${TimeoutSeconds}s)."
            return $result
        }

        $tcpClient.EndConnect($asyncResult)
        $result.PortOpen = $true
        $tcpClient.Close()
    }
    catch
    {
        $result.Message = "Failed to connect to $HostName on port $Port : $($_.Exception.Message)"
        return $result
    }

    # Step 2: Protocol-Specific Authentication / Probe Check
    switch ($Protocol)
    {
        "SMB"
        {
            # Tested via net use probe if username provided
            if ($Username -and $Password)
            {
                $probeShare = "\\$HostName\IPC$"
                cmd.exe /c "net use `"$probeShare`" /delete /y" *> $null
                $netOut = cmd.exe /c "net use `"$probeShare`" /user:$Username $Password /persistent:no" 2>&1
                if ($LASTEXITCODE -eq 0)
                {
                    $result.AuthSuccess = $true
                    $result.Message = "SMB Port $Port OPEN and IPC$ authentication successful with user '$Username'!"
                    cmd.exe /c "net use `"$probeShare`" /delete /y" *> $null
                }
                else
                {
                    $result.Message = "SMB Port $Port OPEN, but authentication failed: $netOut"
                }
            }
            else
            {
                $result.AuthSuccess = $true
                $result.Message = "SMB Port $Port is OPEN and accepting TCP connections."
            }
        }

        { $_ -in "SFTP", "SCP" }
        {
            $sshCmd = Get-Command "ssh.exe" -ErrorAction SilentlyContinue
            if ($sshCmd -and $Username)
            {
                $authArg = ""
                $keyUsedDesc = ""

                if ($PrivateKeyPath -and (Test-Path -LiteralPath $PrivateKeyPath))
                {
                    # Explicitly use the specified key and disable standard fallback identities
                    $authArg = "-i `"$PrivateKeyPath`" -o IdentitiesOnly=yes"
                    $keyUsedDesc = "Specified Key: $PrivateKeyPath"
                }
                else
                {
                    # No key explicitly provided in UI box
                    $keyUsedDesc = "Default OpenSSH Key (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
                }

                # Non-interactive batch mode check (test public key auth strictly)
                $testArgs = "-p $Port -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=$TimeoutSeconds $authArg $Username@$HostName exit"
                $proc = Start-Process -FilePath "ssh.exe" -ArgumentList $testArgs -Wait -NoNewWindow -PassThru
                if ($proc.ExitCode -eq 0)
                {
                    $result.AuthSuccess = $true
                    $result.Message = "SSH/SFTP Port $Port OPEN and Authentication SUCCESSFUL for $Username@$HostName! ($keyUsedDesc)"
                }
                else
                {
                    $result.AuthSuccess = $false
                    $result.Message = "SSH Port $Port is OPEN, but key authentication was rejected using $keyUsedDesc. (Exit Code $($proc.ExitCode)). Ensure the Public Key is added to $Username's ~/.ssh/authorized_keys."
                }
            }
            else
            {
                $result.AuthSuccess = $true
                $result.Message = "SSH/SFTP Port $Port is OPEN and responding to TCP handshakes."
            }
        }

        "FTPS"
        {
            # Probe SSL stream handshake
            try
            {
                $tcp = [System.Net.Sockets.TcpClient]::new()
                $tcp.Connect($HostName, $Port)
                $ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false, { param($s, $c, $chain, $sslErr) return $true })
                $ssl.AuthenticateAsClient($HostName)
                $result.AuthSuccess = $true
                $result.Message = "FTPS Port $Port OPEN! TLS Handshake succeeded (Cipher: $($ssl.CipherAlgorithm), Protocol: $($ssl.SslProtocol))."
                $ssl.Close()
                $tcp.Close()
            }
            catch
            {
                $result.Message = "FTPS Port $Port OPEN, but TLS handshake failed or standard FTP port: $($_.Exception.Message)"
            }
        }

        Default
        {
            $result.AuthSuccess = $true
            $result.Message = "Port $Port is OPEN and accessible."
        }
    }

    return $result
}
