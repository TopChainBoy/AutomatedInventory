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

# Function to validate email address
validate_email() {
  if [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    return 0
  else
    echo "Invalid email address"
    exit 1
  fi
}

# Function to check if the email service is running
check_email_service() {
  if systemctl is-active --quiet postfix; then
    return 0
  else
    echo "Email service is not running. Start it by running 'sudo systemctl start postfix'."
    exit 1
  fi
}

# Check if the email service is running
check_email_service

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
REQUIRED_COMMANDS=("nmap" "arp" "sshpass" "ssh" "ipcalc" "ping" "mail")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command_exists $cmd; then
    echo "The command '$cmd' is not installed. Install it by running 'sudo apt install $cmd'."
    exit 1
  fi
done

# Get the SSH credentials
SSH_USERNAME=${SSH_USERNAME:-$(read -p "Enter SSH username: ")}
SSH_PASSWORD=${SSH_PASSWORD:-$(read -s -p "Enter SSH password: ")}

# Get the email address for notifications
EMAIL_ADDRESS=${EMAIL_ADDRESS:-$(read -p "Enter email address for notifications: ")}

# Validate the email address
validate_email $EMAIL_ADDRESS

# Get the IP address and subnet mask of the active network interface
ip_info=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')

# Use ipcalc to get the network range
network=$(ipcalc -n $ip_info | awk -F= '/Network/ {print $2}')

# Use nmap to scan the network
nmap -sn $network | awk '/Nmap scan report for/ {print $5}' > $BASE_DIR/ip_addresses.txt

# Create a log file
log_file=$BASE_DIR/network_scan.log
unknown_device_log=$BASE_DIR/unknown_devices.log
echo "Network Scan Log - $(date)" > $log_file
echo "Unknown Devices Log - $(date)" > $unknown_device_log

# Known MAC addresses
known_mac_addresses=$(cat $BASE_DIR/known_mac_addresses.txt)

# Loop through each IP address
while read -r ip; do
  # Get the MAC address
  mac=$(arp -n $ip | awk '/ether/ {print $3}')

  # Check if the device is known before attempting to ping or SSH
  if grep -q "$mac" <<< "$known_mac_addresses"; then
    # Check if the IP address is reachable
    if ping -c 1 $ip &> /dev/null; then
      echo "IP Address: $ip" | tee -a $log_file
      echo "MAC Address: $mac" | tee -a $log_file
      echo "Known device detected: $mac" | tee -a $log_file

      # Get the device type and operating system using nmap
      os=$(nmap -O $ip | awk '/Running:/ {print substr($0, index($0, $2))}')
      echo "Operating System: $os" | tee -a $log_file

      # Check if the device is online before attempting SSH
      if ping -c 1 $ip &> /dev/null; then
        # Check if SSH connection is successful
        if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $SSH_USERNAME@$ip exit &> /dev/null; then
          # Get hardware specifications using ssh and dmidecode
          specs=$(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no $SSH_USERNAME@$ip 'sudo dmidecode -t system; sudo dmidecode -t processor')
          echo "Hardware Specifications: $specs" | tee -a $log_file
        else
          echo "SSH connection failed" | tee -a $log_file
        fi
      else
        echo "Device is not online. Skipping SSH attempt." | tee -a $log_file
      fi
    else
      echo "IP Address: $ip is not reachable" | tee -a $log_file
    fi
  else
    echo "Unknown device detected: $mac" | tee -a $unknown_device_log
    echo "Unknown device detected: $mac. IP Address: $ip" | mail -s "Unknown Device Detected" $EMAIL_ADDRESS
    if [ $? -eq 0 ]; then
      echo "Email sent successfully" | tee -a $log_file
    else
      echo "Failed to send email. Retrying..." | tee -a $log_file
      retry_count=0
      while [ $retry_count -lt 3 ]; do
        echo "Unknown device detected: $mac. IP Address: $ip" | mail -s "Unknown Device Detected" $EMAIL_ADDRESS
        if [ $? -eq 0 ]; then
          echo "Email sent successfully" | tee -a $log_file
          break
        else
          ((retry_count++))
          echo "Retry $retry_count failed. Retrying..." | tee -a $log_file
        fi
      done
      if [ $retry_count -eq 3 ]; then
        echo "Failed to send email after 3 attempts" | tee -a $log_file
      fi
    fi
  fi

  echo "Last seen online: $(date)" | tee -a $log_file
  echo "-----------------------------------" | tee -a $log_file
done < $BASE_DIR/ip_addresses.txt

# Remove the temporary file
rm $BASE_DIR/ip_addresses.txt