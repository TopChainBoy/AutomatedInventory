#!/bin/bash

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Function to display usage information
usage() {
  echo "Usage: $0 [-h|--help]"
  echo "Scan the network and get information about each device."
  echo "Options:"
  echo "  -h, --help    Show this help message and exit."
}

# Check if help option is given
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

# Check if required commands are installed
REQUIRED_COMMANDS=("nmap" "arp" "sshpass" "ssh" "ipcalc")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command_exists $cmd; then
    echo "The command '$cmd' is not installed. Install it by running 'sudo apt install $cmd'."
    exit 1
  fi
done

# Get the IP address and subnet mask of the active network interface
ip_info=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')

# Define the network range MANUAL METHOD
#network="192.168.1.0/24"

# Use ipcalc to get the network range
network=$(ipcalc -n $ip_info | awk -F= '/Network/ {print $2}')

# Use nmap to scan the network
nmap -sn $network | awk '/Nmap scan report for/ {print $5}' > $BASE_DIR/ip_addresses.txt

# Loop through each IP address
while read -r ip; do
  echo "IP Address: $ip"

  # Get the MAC address
  mac=$(arp -n $ip | awk '/ether/ {print $3}')
  echo "MAC Address: $mac"

  # Get the device type and operating system using nmap
  os=$(nmap -O $ip | awk '/Running:/ {print substr($0, index($0, $2))}')
  echo "Operating System: $os"

  # Get hardware specifications using ssh and dmidecode (requires ssh access)
  # Replace 'username' and 'password' with actual SSH credentials
  specs=$(sshpass -p 'password' ssh -o StrictHostKeyChecking=no username@$ip 'sudo dmidecode -t system; sudo dmidecode -t processor')
  echo "Hardware Specifications: $specs"

  echo "-----------------------------------"

done < $BASE_DIR/ip_addresses.txt

# Remove the temporary file
rm $BASE_DIR/ip_addresses.txt
