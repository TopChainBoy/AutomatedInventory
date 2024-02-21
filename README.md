# Automated Inventory - Network Scanner Script

This script is designed to make an inventory iutomatically with all devices on your network. It scans the network and get information about each device. It retrieves the IP address, MAC address, operating system, and hardware specifications of each device on the network.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

You need to have `bash`, `nmap`, `arp`, `sshpass`, `ssh`, and `ipcalc` installed on your system to run this script. If not installed, you can install them using the following commands:

```
sudo apt-get install bash
sudo apt-get install nmap
sudo apt-get install net-tools
sudo apt-get install sshpass
sudo apt-get install openssh-client
sudo apt-get install ipcalc
```

### Installing

Clone the repository to your local machine:

```
git clone https://github.com/TopChainBoy/AutomatedInventory.git
```

Navigate to the project directory:

```
cd AutomatedInventory
```
Make the script executable:

```
chmod +x automatedInventory.sh
```

### Usage

The script can be run with the following command:

```
./automatedInventory.sh
```

The script will scan the network and display information about each device. It will also create a temporary file `ip_addresses.txt` to store the IP addresses of the devices, which will be deleted after the script finishes running.

## Built With

- Bash: The GNU Project's shell
- nmap: Network exploration tool and security scanner
- arp: Address Resolution Protocol
- sshpass: Non-interactive ssh password provider
- ssh: OpenSSH SSH client
- ipcalc: Parameter calculator for IPv4 addresses

## Authors

* **TopChainBoy** - *Initial work* - [TopChainBoy](https://github.com/TopChainBoy)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgements

This script uses the Bash shell, nmap, arp, sshpass, ssh, and ipcalc. We would like to acknowledge and thank the creators of these tools.
