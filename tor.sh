#!/usr/bin/env bash

# ==============================
#     Tor Node Setup Script
#        by Turtlecute
# ==============================

echo "$(tput setaf 2)
                ..
               ,:
              .::
             .:2.
              .:, 1L
               .v: Z, ..::,
                :k:N.Lv:
                 22ukL
                 JSYk.$(tput bold)$(tput setaf 7)
                ,B@B@i
               BO@@B@.
             :B@L@Bv:@7
           .PB@iBB@ .@Mi
         .P@B@iE@@r . 7B@i
       5@@B@:NB@1$(tput setaf 5) r ri:$(tput bold)$(tput setaf 7)7@M
     .@B@BG.OB@B$(tput setaf 5)  ,.. .i, $(tput bold)$(tput setaf 7)MB,
    @B@BO.B@@B$(tput setaf 5)  i7777,   $(tput bold)$(tput setaf 7)MB.
   PB@B@.OB@BE$(tput setaf 5)  LririL,.L. $(tput bold)$(tput setaf 7)@P
   B@B@5iB@B@i$(tput setaf 5)  :77r7L, L7 $(tput bold)$(tput setaf 7)O@
   @B1B27@B@B,$(tput setaf 5) . .:ii.  r7 $(tput bold)$(tput setaf 7)BB
   O@.@M:B@B@:$(tput setaf 5) v7:    ::.  $(tput bold)$(tput setaf 7)BM
   :Br7@L5B@BO$(tput setaf 5) irL: :v7L. $(tput bold)$(tput setaf 7)P@,
     7@,Y@UqB@B7$(tput setaf 5) ir ,L;r: $(tput bold)$(tput setaf 7)u@7
       r@LiBMBB@Bu$(tput setaf 5)   rr:.$(tput bold)$(tput setaf 7):B@i
          FNL1NB@@@@:  ;OBX
            rLu2ZB@B@@XqG7$(tput sgr0)$(tput setaf 2)
                . rJuv::
$(tput setaf 2)Tor node script
$(tput bold)$(tput setaf 5)by Turtlecute.$(tput sgr0)"

echo "$(tput setaf 6)This script will auto-setup a Tor node for you.$(tput sgr0)"
read -p "$(tput bold)$(tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"

# ===== Root Check =====
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use 'sudo' or 'su'."
  exit 1
fi

# ===== Update & Install Dependencies =====
echo "$(tput setaf 6)Updating your system...$(tput sgr0)"
apt-get update -y > /dev/null || { echo "Failed to update packages."; exit 1; }

echo "$(tput setaf 6)Installing dependencies...$(tput sgr0)"
apt-get install -y unattended-upgrades apt-listchanges wget gpg apt-transport-https nyx > /dev/null || { echo "Failed to install dependencies."; exit 1; }

# ===== Configure Auto Updates =====
echo "$(tput setaf 6)Configuring auto updates...$(tput sgr0)"
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  if [[ "$ID" == "debian" ]]; then
    unattended_upgrades_content="Unattended-Upgrade::Origins-Pattern {
      \"origin=Debian,codename=${VERSION_CODENAME},label=Debian-Security\";
      \"origin=TorProject\";
    };
    Unattended-Upgrade::Package-Blacklist {};
    Unattended-Upgrade::Automatic-Reboot \"true\";"
  elif [[ "$ID" == "ubuntu" ]]; then
    unattended_upgrades_content="Unattended-Upgrade::Allowed-Origins {
      \"${ID}:${VERSION_CODENAME}-security\";
      \"TorProject:${VERSION_CODENAME}\";
    };
    Unattended-Upgrade::Package-Blacklist {};
    Unattended-Upgrade::Automatic-Reboot \"true\";"
  else
    echo "Unsupported distribution: $ID"
    exit 1
  fi
  echo "$unattended_upgrades_content" | tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null
else
  echo "Unsupported distribution: /etc/os-release not found"
  exit 1
fi

cat <<EOL | tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL

# ===== Configure Tor Repository =====
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
    echo "$(tput setaf 6)Adding Tor repository...$(tput sgr0)"
    echo "deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $VERSION_CODENAME main
deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/tor.list > /dev/null
  else
    echo "Unsupported distribution: $ID"
    exit 1
  fi
else
  echo "Unsupported distribution: /etc/os-release not found"
  exit 1
fi

# ===== Install Tor =====
echo "$(tput setaf 6)Installing Tor...$(tput sgr0)"
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null
apt-get update -y > /dev/null
apt-get install -y tor deb.torproject.org-keyring > /dev/null || { echo "Tor installation failed."; exit 1; }

# ===== Nickname Validation Function =====
validate_nickname() {
  while true; do
    read -p "Enter the Nickname for your $1 relay (no spaces, only letters, numbers, '_' or '-'): " nickname
    if [[ "$nickname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      break
    else
      echo "Invalid nickname. Please avoid spaces or special characters."
    fi
  done
}

# ===== Node Type Selection =====
read -p "Select Tor node type:
1) Tor middle relay
2) Tor exit relay (Dangerous)
Enter your choice (1/2): " tor_node_type

if [[ "$tor_node_type" -eq 1 ]]; then
  echo "You selected Tor middle relay."
  validate_nickname "middle"
  read -p "Enter your ContactInfo (your email, will be public): " contact_info
  echo "Enter your maximum WEEKLY bandwidth (ex: '200 GB', '1 TB') or '0' for unlimited:"
  while true; do
    read bandwidth1
    if [[ "$bandwidth1" =~ ^[0-9]+[[:space:]]?(MB|GB|TB)?$ ]]; then
      break
    else
      echo "Invalid input. Format example: '200 GB' or '0'."
    fi
  done
  torrc_configuration="Nickname $nickname
ContactInfo $contact_info
ORPort 443
ExitRelay 0
SocksPort 0"
  if [[ "$bandwidth1" != "0" ]]; then
    torrc_configuration+="
AccountingRule sum
AccountingStart week 1 10:00
AccountingMax $bandwidth1"
  fi
elif [[ "$tor_node_type" -eq 2 ]]; then
  echo "You selected Tor exit relay (Dangerous)."
  validate_nickname "exit"
  read -p "Enter your ContactInfo (your email, will be public): " contact_info
  echo "Enter your maximum WEEKLY bandwidth (ex: '200 GB', '1 TB') or '0' for unlimited:"
  while true; do
    read bandwidth2
    if [[ "$bandwidth2" =~ ^[0-9]+[[:space:]]?(MB|GB|TB)?$ ]]; then
      break
    else
      echo "Invalid input. Format example: '200 GB' or '0'."
    fi
  done
  torrc_configuration="Nickname $nickname
ContactInfo $contact_info
ORPort 443
ExitRelay 1
SocksPort 0
DirPort 80
DirPortFrontPage /etc/tor/tor-exit-notice.html
ExitPolicy accept *:22
ExitPolicy accept *:23
ExitPolicy accept *:43
ExitPolicy accept *:53
ExitPolicy accept *:79
ExitPolicy accept *:80-81
ExitPolicy accept *:88
ExitPolicy accept *:110
ExitPolicy accept *:143
ExitPolicy accept *:194
ExitPolicy accept *:220
ExitPolicy accept *:389
ExitPolicy accept *:443
ExitPolicy accept *:464
ExitPolicy accept *:465
ExitPolicy accept *:531
ExitPolicy accept *:543-544
ExitPolicy accept *:554
ExitPolicy accept *:563
ExitPolicy accept *:587
ExitPolicy accept *:636
ExitPolicy accept *:706
ExitPolicy accept *:749
ExitPolicy accept *:853
ExitPolicy accept *:873
ExitPolicy accept *:902-904
ExitPolicy accept *:981
ExitPolicy accept *:989-990
ExitPolicy accept *:991
ExitPolicy accept *:992
ExitPolicy accept *:993
ExitPolicy accept *:994
ExitPolicy accept *:995
ExitPolicy accept *:1194
ExitPolicy accept *:1220
ExitPolicy accept *:1293
ExitPolicy accept *:1500
ExitPolicy accept *:1533
ExitPolicy accept *:1677
ExitPolicy accept *:1723
ExitPolicy accept *:1755
ExitPolicy accept *:1863
ExitPolicy accept *:2082
ExitPolicy accept *:2083
ExitPolicy accept *:2086-2087
ExitPolicy accept *:2095-2096
ExitPolicy accept *:2102-2104
ExitPolicy accept *:3128
ExitPolicy accept *:3389
ExitPolicy accept *:3690
ExitPolicy accept *:4321
ExitPolicy accept *:4643
ExitPolicy accept *:5050
ExitPolicy accept *:5190
ExitPolicy accept *:5222-5223
ExitPolicy accept *:5228
ExitPolicy accept *:5900
ExitPolicy accept *:6660-6669
ExitPolicy accept *:6679
ExitPolicy accept *:6697
ExitPolicy accept *:8000
ExitPolicy accept *:8008
ExitPolicy accept *:8074
ExitPolicy accept *:8080
ExitPolicy accept *:8082
ExitPolicy accept *:8087-8088
ExitPolicy accept *:8332-8333
ExitPolicy accept *:8443
ExitPolicy accept *:8888
ExitPolicy accept *:9418
ExitPolicy accept *:9999
ExitPolicy accept *:10000
ExitPolicy accept *:11371
ExitPolicy accept *:19294
ExitPolicy accept *:19638
ExitPolicy accept *:50001-50002
ExitPolicy accept *:64738
ExitPolicy reject *:*"
  if [[ "$bandwidth2" != "0" ]]; then
    torrc_configuration+="
AccountingRule sum
AccountingStart week 1 10:00
AccountingMax $bandwidth2"
  fi
else
  echo "Invalid Tor node type."
  exit 1
fi

# ===== Write Tor Configuration =====
echo "$torrc_configuration" | tee /etc/tor/torrc > /dev/null
echo "Tor configuration updated in /etc/tor/torrc."

# ===== Restart & Enable Tor Service =====
echo "Restarting the Tor service..."
systemctl restart tor 2>/dev/null || systemctl restart tor@default
if [ $? -ne 0 ]; then
  echo "Failed to restart Tor service."
  exit 1
fi

systemctl enable tor 2>/dev/null || systemctl enable tor@default
echo "Tor service enabled at boot."

# ===== Done =====
echo "$(tput bold)$(tput setaf 2)✅ Tor node configured and running!$(tput sgr0)"
echo "If this script was useful, visit https://salviamotor.vado.li and consider a Bitcoin donation."
