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

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if required commands are installed
REQUIRED_COMMANDS=("nmap" "arp" "sshpass" "ssh" "ipcalc" "ping")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command_exists $cmd; then
    echo "The command '$cmd' is not installed. Install it by running 'sudo apt install $cmd'."
    exit 1
  fi
done

# Get the SSH credentials
SSH_USERNAME=${SSH_USERNAME:-$(read -p "Enter SSH username: ")}
SSH_PASSWORD=${SSH_PASSWORD:-$(read -s -p "Enter SSH password: ")}

# Get the IP address and subnet mask of the active network interface
ip_info=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')

# Use ipcalc to get the network range
network=$(ipcalc -n $ip_info | awk -F= '/Network/ {print $2}')

# Use nmap to scan the network
nmap -sn $network | awk '/Nmap scan report for/ {print $5}' > $BASE_DIR/ip_addresses.txt

# Create a log file
log_file=$BASE_DIR/network_scan.log
echo "Network Scan Log - $(date)" > $log_file

# Loop through each IP address
while read -r ip; do
  # Check if the IP address is reachable
  if ping -c 1 $ip &> /dev/null; then
    echo "IP Address: $ip" | tee -a $log_file

    # Get the MAC address
    mac=$(arp -n $ip | awk '/ether/ {print $3}')
    echo "MAC Address: $mac" | tee -a $log_file

    # Get the device type and operating system using nmap
    os=$(nmap -O $ip | awk '/Running:/ {print substr($0, index($0, $2))}')
    echo "Operating System: $os" | tee -a $log_file

    # Get hardware specifications using ssh and dmidecode
    specs=$(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no $SSH_USERNAME@$ip 'sudo dmidecode -t system; sudo dmidecode -t processor')
    echo "Hardware Specifications: $specs" | tee -a $log_file

    echo "-----------------------------------" | tee -a $log_file
  else
    echo "IP Address: $ip is not reachable" | tee -a $log_file
  fi
done < $BASE_DIR/ip_addresses.txt

# Remove the temporary file
rm $BASE_DIR/ip_addresses.txt