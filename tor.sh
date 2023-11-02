#!/bin/bash

# Check if the script is run as root (to ensure proper permissions)
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use 'su' before run."
  exit 1
fi

# Update the package list
apt-get update

# Install the desired packages
apt-get install -y unattended-upgrades apt-listchanges wget gpg apt-transport-https

# Check the exit status of the installation
if [ $? -eq 0 ]; then
  echo "Installation completed successfully."
else
  echo "Installation failed. can't install packages."
fi

# Define the lines for 50unattended-upgrades
lines_50unattended_upgrades=$(cat <<EOL
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=\${codename},label=Debian-Security";
    "origin=TorProject";
};

Unattended-Upgrade::Package-Blacklist {
};
EOL
)

# Check if the lines are already in the file 50unattended-upgrades
if grep -q "Unattended-Upgrade::Origins-Pattern" /etc/apt/apt.conf.d/50unattended-upgrades; then
  echo "The lines are already in the file 50unattended-upgrades."
else
  # Append the lines to the configuration file 50unattended-upgrades
  echo "$lines_50unattended_upgrades" | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
  echo "Lines added to /etc/apt/apt.conf.d/50unattended-upgrades."
fi

# Define the lines for 20auto-upgrades
lines_20auto_upgrades=$(cat <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL
)

# Check if the lines are already in the file 20auto-upgrades
if grep -q "APT::Periodic::Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades; then
  echo "The lines are already in the file 20auto-upgrades."
else
  # Append the lines to the configuration file 20auto-upgrades
  echo "$lines_20auto_upgrades" | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
  echo "Lines added to /etc/apt/apt.conf.d/20auto-upgrades."
fi

# Define the lines to add to the tor.list file
lines_to_add=$(cat <<EOL
deb     [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org <DISTRIBUTION> main
deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org <DISTRIBUTION> main
EOL
)

# Prompt the user for the distribution name
read -p "Enter your Debian distribution (e.g., buster, bullseye or bookworm): " distribution
lines_to_add="${lines_to_add//<DISTRIBUTION>/$distribution}"

# Check if the lines are already in the file
if grep -q "deb     \[signed-by=/usr/share/keyrings/tor-archive-keyring.gpg\] https://deb.torproject.org/torproject.org $distribution main" /etc/apt/sources.list.d/tor.list; then
  echo "The lines are already in the tor.list file."
  exit 0
fi

# Append the lines to the tor.list file
echo "$lines_to_add" | tee -a /etc/apt/sources.list.d/tor.list

echo "Lines added to /etc/apt/sources.list.d/tor.list."

# Add a comment for clarity
echo "Adding the Tor Project repository and installing Tor..."

# Download of PGP key and installation 
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
apt update
apt install -y tor deb.torproject.org-keyring

# Check the exit status of the installation
if [ $? -eq 0 ]; then
  echo "Tor installed successfully."
else
  echo "Tor installation failed. Please check for errors."
fi

# Ask the user to select a Tor node type
read -p "Select Tor node type:
1) Tor middle relay
2) Tor exit relay (Dangerous)
Enter your choice (1/2): " tor_node_type

if [ "$tor_node_type" -eq 1 ]; then
  # Middle relay configuration
  echo "You selected Tor middle relay."

  # Prompt for Nickname and ContactInfo
  read -p "Enter the Nickname for your middle relay: " nickname
  read -p "Enter the ContactInfo (your email, ATTENTION it will be published on tor.metrics): " contact_info

  # Define the Tor middle relay configuration
  torrc_configuration=$(cat <<EOL
Nickname $nickname
ContactInfo $contact_info
ORPort 443
ExitRelay 0
SocksPort 0
EOL
  )
else
  # Exit relay configuration
  echo "You selected Tor exit relay (Dangerous)."

  # Prompt for Nickname and ContactInfo
  read -p "Enter the Nickname for your exit relay: " nickname
  read -p "Enter the ContactInfo (your email, ATTENTION it will be published): " contact_info

  # Define the Tor exit relay configuration
  torrc_configuration=$(cat <<EOL
Nickname $nickname
ContactInfo $contact_info
ORPort 443
ExitRelay 1
SocksPort 0
DirPort 80
DirPortFrontPage /etc/tor/tor-exit-notice.html
ExitPolicy accept *:20-21     # FTP
ExitPolicy accept *:22        # SSH
ExitPolicy accept *:23        # Telnet
ExitPolicy accept *:43        # WHOIS
ExitPolicy accept *:53        # DNS
ExitPolicy accept *:79        # finger
ExitPolicy accept *:80-81     # HTTP
ExitPolicy accept *:88        # kerberos
ExitPolicy accept *:110       # POP3
ExitPolicy accept *:143       # IMAP
ExitPolicy accept *:194       # IRC
ExitPolicy accept *:220       # IMAP3
ExitPolicy accept *:389       # LDAP
ExitPolicy accept *:443       # HTTPS
ExitPolicy accept *:464       # kpasswd
ExitPolicy accept *:465       # URD for SSM (more often: an alternative SUBMISSION port, see 587)
ExitPolicy accept *:531       # IRC/AIM
ExitPolicy accept *:543-544   # Kerberos
ExitPolicy accept *:554       # RTSP
ExitPolicy accept *:563       # NNTP over SSL
ExitPolicy accept *:587       # SUBMISSION (authenticated clients [MUA's like Thunderbird] send mail over STARTTLS SMTP here)
ExitPolicy accept *:636       # LDAP over SSL
ExitPolicy accept *:706       # SILC
ExitPolicy accept *:749       # kerberos
ExitPolicy accept *:853       # DNS over TLS
ExitPolicy accept *:873       # rsync
ExitPolicy accept *:902-904   # VMware
ExitPolicy accept *:981       # Remote HTTPS management for firewall
ExitPolicy accept *:989-990   # FTP over SSL
ExitPolicy accept *:991       # Netnews Administration System
ExitPolicy accept *:992       # TELNETS
ExitPolicy accept *:993       # IMAP over SSL
ExitPolicy accept *:994       # IRCS
ExitPolicy accept *:995       # POP3 over SSL
ExitPolicy accept *:1194      # OpenVPN
ExitPolicy accept *:1220      # QT Server Admin
ExitPolicy accept *:1293      # PKT-KRB-IPSec
ExitPolicy accept *:1500      # VLSI License Manager
ExitPolicy accept *:1533      # Sametime
ExitPolicy accept *:1677      # GroupWise
ExitPolicy accept *:1723      # PPTP
ExitPolicy accept *:1755      # RTSP
ExitPolicy accept *:1863      # MSNP
ExitPolicy accept *:2082      # Infowave Mobility Server
ExitPolicy accept *:2083      # Secure Radius Service (radsec)
ExitPolicy accept *:2086-2087 # GNUnet, ELI
ExitPolicy accept *:2095-2096 # NBX
ExitPolicy accept *:2102-2104 # Zephyr
ExitPolicy accept *:3128      # SQUID
ExitPolicy accept *:3389      # MS WBT
ExitPolicy accept *:3690      # SVN
ExitPolicy accept *:4321      # RWHOIS
ExitPolicy accept *:4643      # Virtuozzo
ExitPolicy accept *:5050      # MMCC
ExitPolicy accept *:5190      # ICQ
ExitPolicy accept *:5222-5223 # XMPP, XMPP over SSL
ExitPolicy accept *:5228      # Android Market
ExitPolicy accept *:5900      # VNC
ExitPolicy accept *:6660-6669 # IRC
ExitPolicy accept *:6679      # IRC SSL
ExitPolicy accept *:6697      # IRC SSL
ExitPolicy accept *:8000      # iRDMI
ExitPolicy accept *:8008      # HTTP alternate
ExitPolicy accept *:8074      # Gadu-Gadu
ExitPolicy accept *:8080      # HTTP Proxies
ExitPolicy accept *:8082      # HTTPS Electrum Bitcoin port
ExitPolicy accept *:8087-8088 # Simplify Media SPP Protocol, Radan HTTP
ExitPolicy accept *:8232-8233 # Zcash
ExitPolicy accept *:8332-8333 # Bitcoin
ExitPolicy accept *:8443      # PCsync HTTPS
ExitPolicy accept *:8888      # HTTP Proxies, NewsEDGE
ExitPolicy accept *:9418      # git
ExitPolicy accept *:9999      # distinct
ExitPolicy accept *:10000     # Network Data Management Protocol
ExitPolicy accept *:11371     # OpenPGP hkp (http keyserver protocol)
ExitPolicy accept *:19294     # Google Voice TCP
ExitPolicy accept *:19638     # Ensim control panel
ExitPolicy accept *:50002     # Electrum Bitcoin SSL
ExitPolicy accept *:64738     # Mumble
ExitPolicy reject *:*
EOL
  )
fi

# Update the Tor configuration in /etc/tor/torrc
echo "$torrc_configuration" | sudo tee /etc/tor/torrc > /dev/null

echo "Tor configuration updated in /etc/tor/torrc."

# Add a comment for clarity
echo "Restarting the Tor service..."

# Restart the Tor service
sudo systemctl restart tor@default

# Check the exit status of the service restart
if [ $? -eq 0 ]; then
  echo "Tor service restarted successfully."
else
  echo "Failed to restart the Tor service. Please check for errors."
fi

# Happy ending!
echo ""Thank you for using my script! If it has been helpful to you, please consider visiting https://salviamotor.vado.li and making a Bitcoin donation.""