MTProto Proxy Manager
A user-friendly web-based interface for managing MTProto proxy services (Official, Python, and Golang implementations) without requiring terminal commands. This tool allows users to install, configure, start, stop, restart, and uninstall MTProto proxies through a modern, intuitive UI built with React and Tailwind CSS, backed by a Node.js server.
Features

Dashboard: View all installed proxies with their status, ports, and connection links.
Installation: Install Official, Python, or Golang MTProto proxies with customizable settings (port, secrets, AD tag, workers, TLS domain, NAT, etc.).
Management: Start, stop, restart, or uninstall proxy services with a single click.
Configuration: Manage secrets, AD tags, workers, NAT settings, and secure modes via forms.
Firewall Support: Generate and apply firewall rules for CentOS, Ubuntu, or Debian.
Non-Terminal Experience: No command-line knowledge required, making it accessible for non-programmers.
Random Port Selection: The web server runs on a random, unused port for security and flexibility.

Prerequisites

A server running Ubuntu, Debian, or CentOS.
Root access (required for proxy installation and management).
Node.js and npm installed.
Dependencies: lsof, curl, python3, pip, and jq for script execution.
Internet access for downloading dependencies and proxy configurations.

Installation
Follow these steps to set up the MTProto Proxy Manager on your server:

Install System Dependencies

For Ubuntu/Debian:sudo apt-get update
sudo apt-get install -y nodejs npm lsof curl python3 python3-pip jq


For CentOS:sudo yum install -y epel-release
sudo yum install -y nodejs npm lsof curl python3 python3-pip jq




Clone the Repository
git clone https://github.com/YOUR_USERNAME/mtproto-proxy-manager.git /opt/mtproxy-manager
cd /opt/mtproxy-manager

Replace YOUR_USERNAME with your GitHub username.

Install Node.js Dependencies
npm install express


Set Up File Structure

Ensure the following files are in /opt/mtproxy-manager:
index.html (React UI)
server.js (Node.js backend)
MTProtoProxyOfficialInstall.sh (Official proxy script)
MTProtoProxyInstall.sh (Python proxy script)
MTGInstall.sh (Golang proxy script)


Create a public directory and move index.html:mkdir -p public
mv index.html public/


Make scripts executable:chmod +x *.sh




Run the Server
node server.js


The server will start on a random port (e.g., http://localhost:54321).
Note the URL displayed in the terminal.


Access the Web UI

Open the URL (e.g., http://localhost:54321) in a web browser.
If accessing remotely, ensure the server’s firewall allows the random port (check with ufw or firewall-cmd).



Usage

Dashboard: View installed proxies, their statuses, ports, and Telegram connection links.
Install a Proxy:
Click "Install Official Proxy," "Install Python Proxy," or "Install Golang Proxy."
Fill in the form (port, secrets, AD tag, workers, TLS domain, NAT settings, etc.).
Submit to install the proxy.


Manage Proxies:
Use buttons to start, stop, restart, or uninstall proxies.
Configure settings like secrets or AD tags via the "Configure" button.


Firewall Rules:
During installation, firewall rules for the proxy port are displayed and can be applied.


Connection Links:
Copy tg://proxy links from the dashboard to configure Telegram clients.



Notes

Security: The server must run as root to manage system services. For production, consider adding authentication to the web UI.
Erlang Proxy: Support for the Erlang proxy (mtp_install.sh) is not included but can be added by extending the backend.
Dependencies: Ensure all dependencies are installed, especially jq for parsing JSON in the Python proxy script.
Port Conflicts: The server automatically selects a random port to avoid conflicts. Check firewall settings if the UI is inaccessible.
Updates: To update proxy configurations (e.g., secrets or TLS domains), use the "Configure" option in the UI.

Contributing
Contributions are welcome! Please submit a pull request or open an issue on GitHub for bugs, features, or improvements.
License
This project is licensed under the MIT License. See the LICENSE file for details.
Credits

Original proxy scripts by Hirbod Behnam.
Built with React, Tailwind CSS, and Node.js.
