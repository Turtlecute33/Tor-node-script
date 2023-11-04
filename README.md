# Tor Node Setup Script 🧅

![Tor Logo](https://turtlecute33.github.io/Turtlecute.org/images/tor.png)

## Description
This script is designed to simplify the process of setting up a Tor node on your Linux system. Whether you want to run a Tor middle relay or a Tor exit relay, this script will guide you through the configuration steps.

## Prerequisites
- You should run this script as a superuser (root) to ensure proper permissions.
- Debian or ubuntu.
  
## Usage
1. Clone the repository or download the script to your Linux system.
2. Make the script executable:
   ```bash
   chmod +x tor.sh
3. Execute
   ```bash
   ./tor.sh

# What the script does

The script will perform the following steps:

1. Check if the script is run as root to ensure proper permissions.
2. Update the package list on your system.
3. Install required dependencies, including unattended-upgrades, apt-listchanges, wget, gpg, and apt-transport-https.
4. Configure automatic updates for your operating system based on Debian or Ubuntu.
5. Add the Tor Project repository to your system's sources list.
6. Download the PGP key and install Tor.
7. Prompt you to select the type of Tor node: Tor middle relay or Tor exit relay (caution: Tor exit relay can have legal implications).
8. Configure the selected Tor node type with a nickname, contact information, and bandwidth limits.
9. Update the Tor configuration in the /etc/tor/torrc file.
10. Restart the Tor service to apply the changes.

## Note
For check if your node is running without issues use:
```bash
journalact -xeu tor@default
```
For Tor exit relays, the script includes a restricted ExitPolicy that should reduce abuse mails by vps providers/ISPs but allows certain outgoing connections. Be aware of the legal implications and potential misuse associated with running a Tor exit relay.

# Donations

If you find this script helpful, please consider making a Bitcoin donation to support the author's work at [https://salviamotor.vado.li](https://salviamotor.vado.li).

# Disclaimer

Running a Tor exit relay can expose you to legal issues, and it's essential to understand the responsibilities and potential risks associated with operating such a relay.

Happy Tor'ing! 🌐
