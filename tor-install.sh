#!/usr/bin/env bash

## temp file for reading input (self deleting at the end)
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15


######################################################################
#
#   Pre-flight tests
#

# Check if the script is run as root (to ensure proper permissions)
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Check distro
if [ -f /etc/os-release ]; then
  source /etc/os-release
  if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
    if [[ "$ID_LIKE" != "debian" && "$ID_LIKE" != "ubuntu" ]]; then
      echo "This script can run on Debian or Ubuntu and similars, not $ID"
      exit 1
    fi
  fi
fi

# Check for dialog package
if [[ $(which dialog) == '' ]]; then
  # dialog command not found, install it
  apt-get install dialog
fi


######################################################################
#
#   Start - Install
#

dialog --clear --backtitle "Tor Install Script" --title "Welcome" \
    --defaultno \
    --yesno "This script will set up a tor node on this machine.\n\nAre you ok to proceed?" 10 40
if [[ $? != 0 ]]; then
  clear
  exit 1
fi


# Update the package list
apt-get update | dialog --clear --backtitle "Tor Install Script" --title "Updatiting your system" \
  --ok-label "Continue" \
  --progressbox  20 100 
if [[  "$PIPESTATUS" != 0 ]]; then
  dialog --msgbox "An error occurred, could not update apt software repository" 10 40
  clear
  exit
fi


# Install dependencies
apt-get install -y unattended-upgrades apt-listchanges wget gpg apt-transport-https | dialog \
  --clear --backtitle "Tor Install Script" --title "Installing dependencies" \
  --ok-label "Continue" \
  --progressbox 20 100
if [[  "$PIPESTATUS" != 0 ]]; then
  dialog --msgbox "An error occurred, could not install dependencies" 10 40
  clear
  exit
fi


# Configuring auto updates
dialog --clear --backtitle "Tor Install Script" --title "Enable auto-updates?" \
    --yesno "Do you want to enable automatic updates?" 10 40
if [[ $? == 0 ]]; then
    if [[ "$ID" == "debian" || "$ID_LIKE" == "debian" ]]; then
        unattended_upgrades_content="Unattended-Upgrade::Origins-Pattern {
        \"origin=Debian,codename=${VERSION_CODENAME},label=Debian-Security\";
        \"origin=TorProject\";
    };
    Unattended-Upgrade::Package-Blacklist {
    };
    Unattended-Upgrade::Automatic-Reboot "true";
    "
    fi

    if [[ "$ID" == "ubuntu" || "$ID_LIKE" == "ubuntu" ]]; then
        unattended_upgrades_content="Unattended-Upgrade::Allowed-Origins {
        \"${ID}:${VERSION_CODENAME}-security\";
        \"TorProject:${VERSION_CODENAME}\";
    };
    Unattended-Upgrade::Package-Blacklist {
    };
    Unattended-Upgrade::Automatic-Reboot "true";
    "
    fi

    # Define the unattended-upgrades file
    unattended_upgrades_file="/etc/apt/apt.conf.d/50unattended-upgrades"
    echo "$unattended_upgrades_content" | tee "$unattended_upgrades_file" >/dev/null

    dialog --backtitle "Tor Install Script" --title "Unattended Upgrades done" \
     --msgbox "Unattended Upgrades have been configured" 20 100

    # Define the lines for 20auto-upgrades
    lines_20auto_upgrades=$(cat <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL
)

    MISSING=$(grep -q "APT::Periodic::Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades)
    if [[ $MISSING == 1 ]]; then
      echo "$lines_20auto_upgrades" | tee -a /etc/apt/apt.conf.d/20auto-upgrades
    fi

    dialog --backtitle "Tor Install Script" --title "Auto Upgrades done" \
     --msgbox "Auto Upgrades have been configured" 20 100
fi


# Add Tor repository to APT sources
dialog --clear --backtitle "Tor Install Script" --title "Add Tor repository?" \
    --yesno "Do you want configure Tor software repository?" 10 40
if [[ $? == 0 ]]; then

  ## Download Tor PGP keyring first
  wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null 
  if [[  "$PIPESTATUS" != 0 ]]; then
    dialog --msgbox "An error occurred, could not download tor project keyring" 10 40
    clear
    exit 1
  fi

  # Add Tor repo
  # Get the codenamen for Debian, Ubuntu or distros deriving from Ubuntu
  oscodename=${UBUNTU_CODENAME:-VERSION_CODENAME}
  # Define the tor.list content
  tor_list_content="deb     [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $oscodename main
deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $oscodename main"
  tor_list_file="/etc/apt/sources.list.d/tor.list"
  # Add or replace the tor.list file
  echo -e "$tor_list_content" | tee "$tor_list_file" >/dev/null

  # Update the again
  apt-get update | dialog --clear --backtitle "Tor Install Script" --title "Updatiting your system" \
    --ok-label "Continue" \
    --progressbox  20 100 
  if [[  "$PIPESTATUS" != 0 ]]; then
    dialog --msgbox "An error occurred, could not update apt software repository" 10 40
    clear
    exit
  fi

  # Install Tor Packages
  apt-get install -y tor deb.torproject.org-keyring | dialog --clear --backtitle "Tor Install Script" --title "Installing Tor packages" \
    --ok-label "Continue" \
    --progressbox  20 100 
  if [[  "$PIPESTATUS" != 0 ]]; then
    dialog --msgbox "An error occurred, could not update apt software repository" 10 40
    clear
    exit
  fi


fi


######################################################################
#
#   TOR Node configuration
#

#Get node Nickname
dialog --clear --backtitle "Tor Install Script" --title "Setting node name" \
       --inputbox "Give a nickname to your node.\n\n\
Enter the nickname below:" 16 51 2> $tempfile
retval=$?
nickname=`cat $tempfile`
if [[ "$retval" != 0 ]]; then
  dialog --ok-label "Goodbye" --msgbox "Choice not allowed" 10 40
  clear
  exit 1
fi

#Get Contact-info
dialog --clear --backtitle "Tor Install Script" --title "Setting contact info" \
       --inputbox "Enter the Contact email. \n\nWARNING: it will be published on tor.metrics!\n\n\
Enter contact info below:" 16 51 2> $tempfile
retval=$?
contact_info=`cat $tempfile`
if [[ "$retval" != 0 ]]; then
  dialog --ok-label "Goodbye" --msgbox "Choice not allowed" 10 40
  clear
  exit 1
fi

# Get Bandwidth limit
pattern="^[0-9]+ (MB|GB|TB)$"
bandwidth='_'
while [[ ! $bandwidth =~ $pattern ]]; do
  dialog --clear --backtitle "Tor Install Script" --title "Setting traffic limit" \
        --inputbox "State the maximum weekly bandwidth that the node can use.\n\
(Ex: '100 MB', '300 GB', '1 TB'... numbers & capital letters)\n\n
Check on your VPS provider contract and limitations.\n\n\
Enter limit below:" 16 51 2> $tempfile
  retval=$?
  bandwidth=`cat $tempfile`
  if [[ "$retval" != 0 ]]; then
    dialog --ok-label "Goodbye" --msgbox "Choice not allowed" 10 40
    clear
    exit 1
  fi
done


# Initial tor.rc configuration (common to both nodes types)
cat > /etc/tor/torrc << EOF
Nickname $nickname
ContactInfo $contact_info
AccountingRule sum
AccountingStart week 1 10:00
AccountingMax $bandwidth
ORPort 443
ExitRelay 0
SocksPort 0
EOF



#Get node type
dialog --clear --backtitle "Tor Install Script" \
	--title "Select note type" \
  --radiolist "Select which type of Tor node you want to run:" 20 61 5 \
        "middle"  "Tor middle relay " on \
        "exit"    "Tor exit node (dangerous)" off 2> $tempfile
retval=$?
choice=`cat $tempfile`
if [[ "$?" != 0 ]]; then
  dialog --msgbox "Choice not allowed" 10 40
  clear
  exit 1
fi

if [[ "$choince" == "exit" ]]; then
  cat > /etc/tor/torrc << EOF
DirPort 80
DirPortFrontPage /etc/tor/tor-exit-notice.html
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
ExitPolicy accept *:8332-8333 # Bitcoin
ExitPolicy accept *:8443      # PCsync HTTPS
ExitPolicy accept *:8888      # HTTP Proxies, NewsEDGE
ExitPolicy accept *:9418      # git
ExitPolicy accept *:9999      # distinct
ExitPolicy accept *:10000     # Network Data Management Protocol
ExitPolicy accept *:11371     # OpenPGP hkp (http keyserver protocol)
ExitPolicy accept *:19294     # Google Voice TCP
ExitPolicy accept *:19638     # Ensim control panel
ExitPolicy accept *:50001-50002     # Electrum Bitcoin SSL
ExitPolicy accept *:64738     # Mumble
ExitPolicy reject *:*
EOF
fi


dialog --backtitle "Tor Install Script" --title "Tor configuration done" \
  --msgbox "Tor configuration updated in /etc/tor/torrc."


# Update the package list
systemctl restart tor@default | dialog --clear --backtitle "Tor Install Script" --title "Restarting tor..." \
  --ok-label "Continue" \
  --progressbox  20 100 
if [[ "$PIPESTATUS" != 0 ]]; then
  dialog --msgbox "Failed to restart the Tor service. Please check for errors." 10 40
  clear
  exit
fi


# Happy ending!
dialog --backtitle "Tor Install Script" --title "Auto Upgrades done" \
  --msgbox "Thank you for using Tor Install script! If it was helpful to you, please consider visiting https://salviamotor.vado.li and making a Bitcoin donation." 30 100

clear