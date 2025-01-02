#!/bin/bash

# podman-installer.sh
# Generalized installer script for containers using Quadlet.

# Variables
SYSTEMD_OUTPUT_DIR="/etc/systemd/system/"
SETTINGS_FILE="$1"
DRY_RUN=false
ENABLE_NOW=false

# Error handling
error_exit() {
    echo "Error: $1"
    exit 1
}

# Parse arguments
while [[ "$1" != "" ]]; do
    case $1 in
        --dry-run ) DRY_RUN=true
                    ;;
        --now )     ENABLE_NOW=true
                    ;;
        * )         SETTINGS_FILE=$1
                    ;;
    esac
    shift
done

# Validate input
if [ -z "$SETTINGS_FILE" ]; then
    error_exit "Usage: $0 [--dry-run] [--now] <settings-file>"
fi

# Load settings
if [ ! -f "$SETTINGS_FILE" ]; then
    error_exit "Settings file not found: $SETTINGS_FILE"
fi
source "$SETTINGS_FILE" || error_exit "Failed to load settings from $SETTINGS_FILE"

# Show variables being used
echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Variables detected:"
echo -e "  \033[1;32mCONTAINER_NAME:\033[0m $CONTAINER_NAME"
echo -e "  \033[1;32mIMAGE_NAME:\033[0m $IMAGE_NAME"
echo -e "  \033[1;32mTIMEZONE:\033[0m $TIMEZONE"
echo -e "  \033[1;32mVOLUMES:\033[0m ${VOLUMES[*]}"
echo -e "  \033[1;32mPORTS:\033[0m ${PORTS[*]}"
echo -e "  \033[1;32mCAPABILITIES:\033[0m ${CAPABILITIES[*]}"
echo -e "  \033[1;32mREQUIRES_WEBPASSWORD:\033[0m $REQUIRES_WEBPASSWORD"

# Dry-run mode
if [ "$DRY_RUN" == "true" ]; then
    echo
    echo -e "\033[1;32mDry-run mode enabled.\033[0m\n"
    echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m The following steps would be executed:"
    echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Create Quadlet configuration file in $QUADLET_DIR"
    echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Firewall rules for ports: ${PORTS[*]}"
    echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Generate systemd service files in $SYSTEMD_OUTPUT_DIR"
    if [ "$ENABLE_NOW" == "true" ]; then
        echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Enable and start service immediately."
    fi
    exit 0
fi

# Prompt for WEBPASSWORD if required
if [[ "$REQUIRES_WEBPASSWORD" == "true" ]]; then
    read -sp "Enter WEBPASSWORD: " WEBPASSWORD
    echo
    ENVIRONMENT+=("WEBPASSWORD=$WEBPASSWORD")
fi

# Create Quadlet configuration file
echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Creating Quadlet configuration file..."
mkdir -p "$QUADLET_DIR" || error_exit "Failed to create $QUADLET_DIR"

cat << EOF > "$QUADLET_DIR/$CONTAINER_NAME"
[Container]
Image=$IMAGE_NAME
Environment=TZ=$TIMEZONE
EOF

for ENV in "${ENVIRONMENT[@]}"; do
    echo "Environment=$ENV" >> "$QUADLET_DIR/$CONTAINER_NAME"
done

for PORT in "${PORTS[@]}"; do
    echo "PublishPort=$PORT" >> "$QUADLET_DIR/$CONTAINER_NAME"
done

for VOLUME in "${VOLUMES[@]}"; do
    echo "Volume=$VOLUME" >> "$QUADLET_DIR/$CONTAINER_NAME"
done

if [ -n "$CAPABILITY" ]; then
    echo "AddCapability=$CAPABILITY" >> "$QUADLET_DIR/$CONTAINER_NAME"
fi

if [ -n "$NETWORK" ]; then
    echo "Network=$NETWORK" >> "$QUADLET_DIR/$CONTAINER_NAME"
fi

# Firewall command section
echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Configuring firewall rules..."
for PORT in "${PORTS[@]}"; do
    IFS=':' read -r HOST_PORT REST <<< "$PORT"
    IFS='/' read -r CONTAINER_PORT PROTOCOL <<< "$REST"
    [[ -z "$PROTOCOL" ]] && PROTOCOL="tcp"
    firewall-cmd --permanent --add-port=${HOST_PORT}/${PROTOCOL} || error_exit "Failed to open port $HOST_PORT/$PROTOCOL."
done

firewall-cmd --reload || error_exit "Failed to reload firewall rules."

# Process Quadlet output and split into files
echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Generating systemd service files..."
/usr/lib/podman/quadlet -dryrun -v | awk '
/^---/ {
  out="'$SYSTEMD_OUTPUT_DIR'" substr($0,4); 
  gsub("---", "", out); 
  print "Writing to: " out;
}
{ if (out) print > out }' || error_exit "Failed to split and generate systemd service files."

# Reload systemd units
echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Reloading systemd daemon..."
systemctl daemon-reload || error_exit "Failed to reload systemd daemon."


if [ "$ENABLE_NOW" == "true" ]; then
    echo -e "\033[0;35m[\033[1;33mStatus\033[0;35m]\033[0m Enabling and starting service..."
    SERVICE_NAME="$(echo $CONTAINER_NAME | cut -d'.' -f1).service"
    systemctl enable "$SERVICE_NAME" || error_exit "Failed to enable $SERVICE_NAME."
    systemctl start "$SERVICE_NAME" || error_exit "Failed to start $SERVICE_NAME."
    timeout 30 tmux new-session \; split-window -v \; send-keys 'watch podman ps; echo WILL END IN 30 SECONDS' C-m \; select-pane -t 0 \; send-keys "journalctl -fu $SERVICE_NAME" C-m \; send-keys C-b D

fi

