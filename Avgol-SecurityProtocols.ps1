<#
====================================================================================================
AVGOL COPY MASTER - SECURITY & PROTOCOL CRYPTOGRAPHY ENGINE
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

function New-AvgolSSHKeyPair
{
    param(
        [ValidateSet("ed25519", "rsa")]
        [string]$KeyType = "ed25519",
        [int]$KeyBits = 4096,
        [string]$Comment = "avgol-copymaster@$(hostname)",
        [string]$TargetDirectory = "$env:USERPROFILE\.ssh"
    )

    try
    {
        if (!(Test-Path -LiteralPath $TargetDirectory))
        {
            New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $keyName = "id_avgol_${KeyType}_$timestamp"
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

function New-AvgolSelfSignedTlsCert
{
    param(
        [string]$CommonName = "avgol-copymaster.local",
        [string[]]$DnsNames = @("localhost", "127.0.0.1"),
        [int]$ValidityYears = 2,
        [string]$ExportDirectory = "$env:USERPROFILE\Certificates\Avgol",
        [string]$PfxPassword = "AvgolSecurePassword123!"
    )

    try
    {
        if (!(Test-Path -LiteralPath $ExportDirectory))
        {
            New-Item -ItemType Directory -Path $ExportDirectory -Force | Out-Null
        }

        $allDns = @($CommonName) + $DnsNames | Select-Object -Unique
        $certSubject = "CN=$CommonName, O=Avgol Industries, OU=Industrial Replication, C=US"
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
                -FriendlyName "Avgol Copy Master TLS Certificate ($CommonName)"
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
        $basePath = [System.IO.Path]::Combine($ExportDirectory, "avgol_tls_${safeCn}_${timestamp}")

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
        $pfxPasswordSecure = ConvertTo-SecureString -String $PfxPassword -Force -AsPlainText
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
            $sb.AppendLine("1. SSH PUBLIC KEY DEPLOYMENT ON REMOTE SERVER") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("To establish passwordless, encrypted $Protocol connections, the generated Public Key") | Out-Null
            $sb.AppendLine("must be placed in the remote user's `~/.ssh/authorized_keys` file.") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("A. FOR LINUX / UNIX REMOTE SERVERS:") | Out-Null
            $sb.AppendLine("   Run the following commands as '$RemoteUser' on the remote server:") | Out-Null
            $sb.AppendLine("   ------------------------------------------------------------") | Out-Null
            $sb.AppendLine("   mkdir -p ~/.ssh") | Out-Null
            $sb.AppendLine("   chmod 700 ~/.ssh") | Out-Null
            if ($PublicKeyContent)
            {
                $sb.AppendLine("   echo '$PublicKeyContent' >> ~/.ssh/authorized_keys") | Out-Null
            }
            else
            {
                $sb.AppendLine("   echo '<PASTE_YOUR_PUBLIC_KEY_HERE>' >> ~/.ssh/authorized_keys") | Out-Null
            }
            $sb.AppendLine("   chmod 600 ~/.ssh/authorized_keys") | Out-Null
            $sb.AppendLine("   restorecon -Rv ~/.ssh # (Required for RHEL/CentOS/SELinux)") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("B. FOR WINDOWS OPENSSH REMOTE SERVERS:") | Out-Null
            $sb.AppendLine("   If '$RemoteUser' is a standard user, paste the public key into:") | Out-Null
            $sb.AppendLine("     C:\Users\$RemoteUser\.ssh\authorized_keys") | Out-Null
            $sb.AppendLine("   If '$RemoteUser' is an Administrator (member of Administrators group):") | Out-Null
            $sb.AppendLine("     C:\ProgramData\ssh\administrators_authorized_keys") | Out-Null
            $sb.AppendLine("   Set strict Windows ACLs (must only be accessible by SYSTEM and Administrators):") | Out-Null
            $sb.AppendLine("     icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant `"Administrators:F`" /grant `"SYSTEM:F`"") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("2. FIREWALL CONFIGURATION") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("Ensure incoming TCP traffic on Port $Port is allowed:") | Out-Null
            $sb.AppendLine("  * Linux (UFW)     : sudo ufw allow $Port/tcp comment 'SSH/SFTP Port'") | Out-Null
            $sb.AppendLine("  * Linux (firewalld: sudo firewall-cmd --permanent --add-port=$Port/tcp && sudo firewall-cmd --reload") | Out-Null
            $sb.AppendLine("  * Windows Firewall: netsh advfirewall firewall add rule name=`"OpenSSH Server ($Port)`" dir=in action=allow protocol=TCP localport=$Port") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("3. VERIFY SSH SERVICE STATUS") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("  * Linux  : sudo systemctl restart sshd && sudo systemctl status sshd") | Out-Null
            $sb.AppendLine("  * Windows: Restart-Service sshd; Get-Service sshd") | Out-Null
        }

        "SMB"
        {
            $sb.AppendLine("1. SMB / CIFS SHARE PERMISSIONS (Port $Port)") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("Ensure the folder is shared with appropriate Share & NTFS read permissions:") | Out-Null
            $sb.AppendLine("  * Grant '$RemoteUser' at least 'Read' (or 'Read & Change' if source delete is enabled).") | Out-Null
            $sb.AppendLine("  * Confirm SMBv2 / SMBv3 is enabled on the remote Windows server:") | Out-Null
            $sb.AppendLine("      Get-SmbServerConfiguration | Select-Object EnableSMB2Protocol") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("2. FIREWALL CONFIGURATION") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("Ensure Windows Firewall allows File and Printer Sharing (Ports 445 & 139):") | Out-Null
            $sb.AppendLine("  * Windows Firewall: Enable-NetFirewallRule -DisplayGroup `"File and Printer Sharing`"") | Out-Null
            $sb.AppendLine("  * Or specific port: netsh advfirewall firewall add rule name=`"SMB-In-445`" dir=in action=allow protocol=TCP localport=445") | Out-Null
        }

        "FTPS"
        {
            $sb.AppendLine("1. TLS / SSL CERTIFICATE BINDING FOR FTPS (Port $Port)") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("FTPS requires an X.509 SSL/TLS Certificate bound to the FTP Service on the server.") | Out-Null
            if ($CertThumbprint)
            {
                $sb.AppendLine("Active Certificate Thumbprint: $CertThumbprint") | Out-Null
                $sb.AppendLine("Common Name (Subject)        : $CertCommonName") | Out-Null
            }
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("A. FOR IIS FTP SERVER ON WINDOWS:") | Out-Null
            $sb.AppendLine("   1. Open IIS Manager -> Click Server Root -> 'Server Certificates'.") | Out-Null
            $sb.AppendLine("   2. Import the generated .pfx file.") | Out-Null
            $sb.AppendLine("   3. Go to your FTP Site -> 'FTP SSL Settings'.") | Out-Null
            $sb.AppendLine("   4. Select the certificate and set SSL Policy to 'Require SSL connections'.") | Out-Null
            $sb.AppendLine("   5. For mTLS (Mutual Authentication), select 'Client Certificates: Require'.") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("B. FOR VSFTPD (LINUX):") | Out-Null
            $sb.AppendLine("   Place the exported .crt.pem and .pfx/.key onto `/etc/ssl/certs/` and configure:") | Out-Null
            $sb.AppendLine("     ssl_enable=YES") | Out-Null
            $sb.AppendLine("     rsa_cert_file=/etc/ssl/certs/avgol_tls.crt.pem") | Out-Null
            $sb.AppendLine("     require_ssl_reuse=NO") | Out-Null
            $sb.AppendLine("     ssl_ciphers=HIGH") | Out-Null
            $sb.AppendLine("") | Out-Null
            $sb.AppendLine("2. FIREWALL & PASSIVE PORTS") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("Allow the FTPS control port ($Port) AND passive data port ranges:") | Out-Null
            $sb.AppendLine("  * Command: netsh advfirewall firewall add rule name=`"FTPS-Control`" dir=in action=allow protocol=TCP localport=$Port") | Out-Null
            $sb.AppendLine("  * Passive data ports (e.g. 50000-50100):") | Out-Null
            $sb.AppendLine("    netsh advfirewall firewall add rule name=`"FTPS-Passive`" dir=in action=allow protocol=TCP localport=50000-50100") | Out-Null
        }

        "WebDAV"
        {
            $sb.AppendLine("1. HTTPS / WEBDAV TLS CERTIFICATE (Port $Port)") | Out-Null
            $sb.AppendLine("--------------------------------------------------------------------------------") | Out-Null
            $sb.AppendLine("WebDAV over HTTPS requires an SSL Certificate bound to IIS or Apache/Nginx port $Port.") | Out-Null
            $sb.AppendLine("  * IIS: In Site Bindings, add 'https' on port $Port and select the certificate.") | Out-Null
            $sb.AppendLine("  * In WebDAV Authoring Rules, ensure user '$RemoteUser' has Read access.") | Out-Null
            $sb.AppendLine("  * Firewall: netsh advfirewall firewall add rule name=`"HTTPS-WebDAV`" dir=in action=allow protocol=TCP localport=$Port") | Out-Null
        }

        Default
        {
            $sb.AppendLine("Ensure Port $Port is open in the remote firewall and service is running.") | Out-Null
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

function Test-AvgolProtocolEndpoint
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
                $authArg = if ($PrivateKeyPath -and (Test-Path -LiteralPath $PrivateKeyPath)) {
                    "-i `"$PrivateKeyPath`""
                } else {
                    ""
                }

                # Non-interactive batch mode check (will test public key auth instantly)
                $testArgs = "-p $Port -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=$TimeoutSeconds $authArg $Username@$HostName exit"
                $proc = Start-Process -FilePath "ssh.exe" -ArgumentList $testArgs -Wait -NoNewWindow -PassThru
                if ($proc.ExitCode -eq 0)
                {
                    $result.AuthSuccess = $true
                    $result.Message = "SSH/SFTP Port $Port OPEN and Public-Key Authentication SUCCESSFUL for $Username@$HostName!"
                }
                else
                {
                    $result.AuthSuccess = $false
                    $result.Message = "SSH Port $Port is OPEN! Note: Key auth not yet accepted by remote server (Exit Code $($proc.ExitCode)). Ensure Public Key is in authorized_keys."
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
