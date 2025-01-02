#!/bin/bash

# Podman Cleanup Script
# Completely removes all containers, volumes, images, networks, and storage.

echo -e "\e[93m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\e[0m"  # Bright yellow
echo -e "\e[38;5;208mIM GOING TO DELETE EVERYTHING\e[0m"  # Orange
echo ""
echo -e "\e[91mI HOPE YOU KNOW WHAT YOU ARE DOING\e[0m"  # Bright red
echo ""
echo -e "\e[38;5;196mLAST CHANCE TO CTRL-C OUT OF THIS\e[0m"  # Deep red
echo ""
read -p $'\e[91mType DELETE IT ALL: \e[0m' deletion_imminent  # Bright red prompt
if [ "$deletion_imminent" != "DELETE IT ALL" ]; then
    echo -e "\e[93mAlrighty - come back when you grow a spine\e[0m"  # Yellow
    exit 0
fi

# Function to display error and exit
error_exit() {
    echo "Error: $1"
    exit 1
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root. Use sudo or run as root."
fi

echo "Stopping and removing all containers..."
podman stop --all || error_exit "Failed to stop containers."
podman rm --all || error_exit "Failed to remove containers."

echo "Removing all volumes..."
podman volume prune --force || error_exit "Failed to remove volumes."

echo "Removing all images..."
podman image prune --all --force || error_exit "Failed to remove images."

echo "Removing all pods..."
podman pod rm --all --force || error_exit "Failed to remove pods."

echo "Removing all networks..."
podman network prune --force || error_exit "Failed to remove networks."

echo "Deleting Podman storage..."
rm -rf /var/lib/containers/ || error_exit "Failed to delete /var/lib/containers."
rm -rf ~/.local/share/containers/ || error_exit "Failed to delete ~/.local/share/containers."

echo "Deleting systemd container units"
rm -rf /etc/containers/containers* || error_exit "Failed to delete /etc/containers/containers*."
rm -rf /etc/containers/systemd/containers* || error_exit "Failed to delete /etc/containers/systemd/containers*."
rm -rf /etc/systemd/system/containers* || error_exit "Failed to delete /etc/systemd/system/containers*."

echo "Verifying cleanup..."
podman ps -a || error_exit "Podman containers check failed."
podman images || error_exit "Podman images check failed."
podman volume ls || error_exit "Podman volumes check failed."

echo "Podman cleanup completed successfully."

