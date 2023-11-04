
Description
This script is designed to simplify the process of setting up a Tor node on your Linux system. Whether you want to run a Tor middle relay or a Tor exit relay, this script will guide you through the configuration steps.

Author
This script is maintained by Turtlecute.

Prerequisites
You should run this script as a superuser (root) to ensure proper permissions.
Usage
Clone the repository or download the script to your Linux system.
Make the script executable:
bash
Copy code
chmod +x setup-tor-node.sh
Run the script:
bash
Copy code
./setup-tor-node.sh
Installation Steps
The script will perform the following steps:

Check if the script is run as root to ensure proper permissions.
Update the package list on your system.
Install required dependencies, including unattended-upgrades, apt-listchanges, wget, gpg, and apt-transport-https.
Configure automatic updates for your operating system based on Debian or Ubuntu.
Add the Tor Project repository to your system's sources list.
Download the PGP key and install Tor.
Prompt you to select the type of Tor node: Tor middle relay or Tor exit relay (caution: Tor exit relay can have legal implications).
Configure the selected Tor node type with a nickname, contact information, and bandwidth limits.
Update the Tor configuration in the /etc/tor/torrc file.
Restart the Tor service to apply the changes.
Note
For Tor exit relays, the script includes a default ExitPolicy that allows certain outgoing connections. Be aware of the legal implications and potential misuse associated with running a Tor exit relay.
Donations
If you find this script helpful, please consider making a Bitcoin donation to support the author's work at https://salviamotor.vado.li.

Disclaimer
Running a Tor exit relay can expose you to legal issues, and it's essential to understand the responsibilities and potential risks associated with operating such a relay. Make sure to comply with your local laws and regulations.

Happy Tor'ing! 🌐



