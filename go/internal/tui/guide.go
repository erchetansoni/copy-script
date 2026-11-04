package tui

import (
	"fmt"
	"strings"
)

// GenerateServerGuide produces exact setup, firewall, and authentication instructions for the chosen protocol.
func GenerateServerGuide(protocol, host string, port int, user, pubKey string) string {
	if port <= 0 {
		switch strings.ToUpper(protocol) {
		case "SFTP", "SCP":
			port = 22
		case "SMB":
			port = 445
		case "FTPS":
			port = 990
		case "FTP":
			port = 21
		case "WEBDAV":
			port = 443
		default:
			port = 22
		}
	}

	if host == "" {
		host = "<server-ip-or-hostname>"
	}
	if user == "" {
		user = "<remote-username>"
	}

	var sb strings.Builder
	sb.WriteString("================================================================================\n")
	sb.WriteString(fmt.Sprintf("REMOTE SERVER SETUP & SECURITY GUIDE: %s (Port %d)\n", strings.ToUpper(protocol), port))
	sb.WriteString(fmt.Sprintf("Target Host: %s | Target User: %s\n", host, user))
	sb.WriteString("================================================================================\n\n")

	switch strings.ToUpper(protocol) {
	case "SFTP", "SCP":
		sb.WriteString("--- [SECTION 1: LINUX SSH/SFTP SERVER SETUP] ---\n")
		sb.WriteString("1. Ensure SSH server is running:\n")
		sb.WriteString("   sudo systemctl enable --now sshd\n\n")
		sb.WriteString("2. Configure user's authorized_keys:\n")
		sb.WriteString(fmt.Sprintf("   mkdir -p /home/%s/.ssh\n", user))
		sb.WriteString(fmt.Sprintf("   chmod 700 /home/%s/.ssh\n", user))
		if pubKey != "" {
			sb.WriteString(fmt.Sprintf("   echo \"%s\" >> /home/%s/.ssh/authorized_keys\n", strings.TrimSpace(pubKey), user))
		} else {
			sb.WriteString(fmt.Sprintf("   echo \"<PASTE_PUBLIC_KEY_HERE>\" >> /home/%s/.ssh/authorized_keys\n", user))
		}
		sb.WriteString(fmt.Sprintf("   chmod 600 /home/%s/.ssh/authorized_keys\n", user))
		sb.WriteString(fmt.Sprintf("   chown -R %s:%s /home/%s/.ssh\n\n", user, user, user))
		sb.WriteString("3. Firewall Open Rule:\n")
		sb.WriteString(fmt.Sprintf("   UFW (Ubuntu/Debian): sudo ufw allow %d/tcp comment 'CopyMaster SSH'\n", port))
		sb.WriteString(fmt.Sprintf("   Firewalld (RHEL/Rocky): sudo firewall-cmd --permanent --add-port=%d/tcp && sudo firewall-cmd --reload\n\n", port))

		sb.WriteString("--- [SECTION 2: WINDOWS OPENSSH SERVER SETUP] ---\n")
		sb.WriteString("1. Install & Start OpenSSH Server (Run as Administrator in PowerShell):\n")
		sb.WriteString("   Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0\n")
		sb.WriteString("   Start-Service sshd; Set-Service -Name sshd -StartupType 'Automatic'\n\n")
		sb.WriteString("2. Configure authorized_keys:\n")
		sb.WriteString(fmt.Sprintf("   New-Item -ItemType Directory -Force -Path 'C:\\Users\\%s\\.ssh'\n", user))
		sb.WriteString(fmt.Sprintf("   Add-Content -Path 'C:\\Users\\%s\\.ssh\\authorized_keys' -Value '<PUBLIC_KEY>'\n", user))
		sb.WriteString("   icacls.exe \"$env:USERPROFILE\\.ssh\\authorized_keys\" /inheritance:r /grant \"$($env:USERNAME):(F)\"\n\n")
		sb.WriteString("3. Windows Defender Firewall Rule:\n")
		sb.WriteString(fmt.Sprintf("   New-NetFirewallRule -Name 'CopyMaster-SSH' -DisplayName 'CopyMaster SSH (Port %d)' -Protocol TCP -LocalPort %d -Action Allow -Direction Inbound\n", port, port))

	case "SMB":
		sb.WriteString("--- [SMB / WINDOWS SHARE CONFIGURATION] ---\n")
		sb.WriteString("1. Create Shared Directory (PowerShell Administrator):\n")
		sb.WriteString("   New-Item -ItemType Directory -Path 'C:\\ReplicationTarget' -Force\n")
		sb.WriteString(fmt.Sprintf("   New-SmbShare -Name 'ReplicationTarget' -Path 'C:\\ReplicationTarget' -FullAccess '%s'\n\n", user))
		sb.WriteString("2. Verify Firewall Inbound Port 445:\n")
		sb.WriteString("   Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing'\n\n")
		sb.WriteString("3. Connect using UNC path:\n")
		sb.WriteString(fmt.Sprintf("   \\\\%s\\ReplicationTarget\n", host))

	case "FTPS", "FTP":
		sb.WriteString("--- [FTPS / TLS SECURED FTP CONFIGURATION] ---\n")
		sb.WriteString(fmt.Sprintf("1. Inbound Port %d/tcp (Control Channel) & Passive Port Range (e.g. 50000-50100/tcp).\n", port))
		sb.WriteString("2. Require Explicit TLS (Auth TLS) to protect OT credentials.\n")
		sb.WriteString("3. Ensure passive external IP matches reachable IP in industrial network.\n")

	case "WEBDAV":
		sb.WriteString("--- [WEBDAV OVER HTTPS CONFIGURATION] ---\n")
		sb.WriteString(fmt.Sprintf("1. Open Port %d/tcp for HTTPS traffic.\n", port))
		sb.WriteString("2. Require TLS 1.2+ and Basic/Digest or Client Certificate authentication.\n")

	default:
		sb.WriteString(fmt.Sprintf("Ensure server on %s:%d is reachable and required firewall ports are permitted.\n", host, port))
	}

	sb.WriteString("\nTip: Test connection directly from Copy Master by pressing F4.")
	return sb.String()
}

