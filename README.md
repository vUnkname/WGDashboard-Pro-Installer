# WGDashboard Universal Pro Installer 🚀

A highly stable, fully automated, and robust custom installation script for [WGDashboard](https://github.com/donaldzou/WGDashboard).

## 💡 Why this script?
The default installation script provided by the original WGDashboard repository often fails on modern Linux environments (like Ubuntu 22.04, 24.04, and 26.04) due to:
- **PEP-668 Restrictions:** The default script attempts to install global PIP packages, which is blocked in modern Ubuntu versions.
- **Systemd Boot Loops:** The original service architecture (`Type=simple`) conflicts with Gunicorn's daemonization, causing endless restart loops.
- **Network & PIP Issues:** Downloads often fail on restricted networks or specific datacenters.

**This Pro Installer fixes all of that.** It sets up a proper Python Virtual Environment (`venv`), configures a stable `Type=forking` Systemd service with PID tracking, and includes intelligent fallback mirrors for PIP packages.

## ✨ Features
- **Universal OS Support:** Auto-detects your Ubuntu version. Uses native Python 3.12 for Ubuntu 24.04/26.04+ and automatically adds the `deadsnakes PPA` for Ubuntu 22.04.
- **100% Isolated Environment:** Uses Python `venv` natively. No conflicts with your system's global packages.
- **Smart Mirror Fallback:** Automatically tests connection to official PyPI servers. If blocked, it switches to reliable fallback mirrors.
- **Rock-Solid Systemd Integration:** Fixes the infamous background crash/boot-loop bug by utilizing `PIDFile` and `forking` mode.
- **Interactive Menu:** Easily Install, Start, Stop, Restart, or cleanly Uninstall the dashboard from a beautiful CLI menu.

## 🛠️ Installation & Usage

Run the following command as `root` to download and execute the installer:

```bash
wget -O setup.sh https://raw.githubusercontent.com/vUnkname/WGDashboard-Pro-Installer/main/setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

### Post-Installation Steps:
1. Allow the dashboard web port in your firewall:
   ```bash
   sudo ufw allow 10086/tcp
   ```
2. Allow your WireGuard VPN port (e.g., if you set it to 54008 in the panel):
   ```bash
   sudo ufw allow 54008/udp
   ```
3. Access the panel via `http://YOUR_SERVER_IP:10086`
   - **Default Username:** `admin`
   - **Default Password:** `admin` *(Please change this immediately!)*

## ⚠️ Important Note for WireGuard Routing (Internet Access)
To ensure your VPN clients have internet access, when creating a configuration in the WGDashboard panel, fill the **Optional Settings** with the following IPtables rules:

**PostUp:**
```bash
iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
```
**PostDown:**
```bash
iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE
```
*(Note: Replace `ens3` with your actual public network interface name, which you can find by running `ip a`).*

## 📜 Credits
- Original WGDashboard Core by [Donald Zou](https://github.com/donaldzou/WGDashboard).
- Custom Installer & Architecture patches developed to provide a seamless SysAdmin experience.
