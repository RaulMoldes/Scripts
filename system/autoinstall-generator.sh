#!/bin/bash

# Enhanced Ubuntu Autoinstall YAML Generator
# This script generates a comprehensive autoinstall.yaml file based on your current Ubuntu configuration
# It captures system settings, packages, users, and services for complete system restoration

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be executed as root (use sudo)"
    exit 1
fi

# Configuration
OUTPUT_FILE="autoinstall.yaml"
BACKUP_DIR="autoinstall_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/autoinstall_generator.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting autoinstall.yaml generation based on current system configuration"

# Function to get current locale safely
get_locale() {
    local locale
    locale=$(localectl status 2>/dev/null | grep "System Locale" | cut -d= -f2 | cut -d. -f1 || echo "en_US")
    echo "${locale:-en_US}"
}

# Function to get keyboard layout safely
get_keyboard_layout() {
    local layout
    layout=$(localectl status 2>/dev/null | grep "X11 Layout" | awk '{print $3}' || echo "us")
    echo "${layout:-us}"
}

# Function to detect if interface uses DHCP
is_dhcp_interface() {
    local interface="$1"
    # Check if NetworkManager is managing the interface
    if command -v nmcli >/dev/null 2>&1; then
        nmcli -t -f DEVICE,METHOD dev show "$interface" 2>/dev/null | grep -q "METHOD:auto" && return 0
    fi
    # Check dhclient processes
    pgrep -f "dhclient.*$interface" >/dev/null 2>&1 && return 0
    # Check systemd-networkd
    [[ -f "/run/systemd/netif/state" ]] && grep -q "$interface.*dhcp" /run/systemd/netif/state 2>/dev/null && return 0
    return 1
}

# Function to get all network interfaces (excluding loopback and virtual)
get_physical_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|ens|enp|wl)' | head -5
}

# Function to get installed packages more intelligently
get_essential_packages() {
    {
        # Get manually installed packages
        apt-mark showmanual 2>/dev/null | sort

        # Add snap packages if snapd is installed
        if command -v snap >/dev/null 2>&1; then
            echo "# Snap packages (install manually after system setup):"
            snap list 2>/dev/null | tail -n +2 | awk '{print "# snap install " $1}' || true
        fi

        # Add flatpak packages if flatpak is installed
        if command -v flatpak >/dev/null 2>&1; then
            echo "# Flatpak packages (install manually after system setup):"
            flatpak list --app 2>/dev/null | awk '{print "# flatpak install " $1}' || true
        fi
    } | head -100  # Limit to prevent oversized configs
}

# Function to get current users (excluding system users)
get_regular_users() {
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd
}

# Function to get systemd services that are enabled
get_enabled_services() {
    systemctl list-unit-files --type=service --state=enabled 2>/dev/null | awk '$2=="enabled" {print $1}' | grep -v '@\|systemd\|dbus\|network' | head -20 || true
}

# Function to backup important config files
backup_configs() {
    log "Backing up important configuration files to $BACKUP_DIR"

    # List of important config files to backup
    local config_files=(
        "/etc/fstab"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/timezone"
        "/etc/default/grub"
        "/etc/ssh/sshd_config"
        "/etc/sudoers"
        "/etc/crontab"
    )

    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done

    # Backup user home directories structure
    for user in $(get_regular_users); do
        if [[ -d "/home/$user" ]]; then
            mkdir -p "$BACKUP_DIR/home_$user"
            # Copy dotfiles and important configs
            cp "/home/$user"/.??* "$BACKUP_DIR/home_$user/" 2>/dev/null || true
        fi
    done
}

# Start generating the YAML file
log "Generating $OUTPUT_FILE"

cat > "$OUTPUT_FILE" << EOF
#cloud-config
# Generated on $(date) by Ubuntu Autoinstall Generator
# System: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Ubuntu")
# Hostname: $(hostname)

autoinstall:
  version: 1

  # Regional settings
  locale: $(get_locale)
  keyboard:
    layout: $(get_keyboard_layout)
    variant: ""
    toggle: null

  # Network configuration
  network:
    version: 2
EOF

# Network configuration
log "Configuring network settings"
echo "    ethernets:" >> "$OUTPUT_FILE"

for interface in $(get_physical_interfaces); do
    if ip addr show "$interface" 2>/dev/null | grep -q "inet "; then
        log "Processing interface: $interface"

        echo "      $interface:" >> "$OUTPUT_FILE"

        if is_dhcp_interface "$interface"; then
            echo "        dhcp4: true" >> "$OUTPUT_FILE"
            echo "        dhcp6: false" >> "$OUTPUT_FILE"
        else
            # Static IP configuration
            ip_info=$(ip addr show "$interface" | grep "inet " | head -1 | awk '{print $2}')
            gateway=$(ip route | grep default | grep "$interface" | head -1 | awk '{print $3}')

            echo "        dhcp4: false" >> "$OUTPUT_FILE"
            echo "        dhcp6: false" >> "$OUTPUT_FILE"

            if [[ -n "$ip_info" ]]; then
                echo "        addresses:" >> "$OUTPUT_FILE"
                echo "          - $ip_info" >> "$OUTPUT_FILE"
            fi

            if [[ -n "$gateway" ]]; then
                echo "        routes:" >> "$OUTPUT_FILE"
                echo "          - to: default" >> "$OUTPUT_FILE"
                echo "            via: $gateway" >> "$OUTPUT_FILE"
            fi

            # DNS configuration
            dns_servers=$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -3 | tr '\n' ',' | sed 's/,$//' || echo "8.8.8.8,8.8.4.4")
            if [[ -n "$dns_servers" ]]; then
                echo "        nameservers:" >> "$OUTPUT_FILE"
                echo "          addresses: [$dns_servers]" >> "$OUTPUT_FILE"
            fi
        fi
    fi
done

# Storage configuration
log "Configuring storage settings"
current_swap=$(swapon --show=SIZE --noheadings --bytes 2>/dev/null | head -1 || echo "0")
swap_gb=$((current_swap / 1024 / 1024 / 1024))

cat >> "$OUTPUT_FILE" << EOF

  # Storage configuration
  storage:
    layout:
      name: lvm
    swap:
      size: ${swap_gb}G

  # Current partition information (for reference):
EOF

# Add current partition info as comments
lsblk -f 2>/dev/null | sed 's/^/  # /' >> "$OUTPUT_FILE" || true

# User configuration
log "Configuring user accounts"
primary_user=$(get_regular_users | head -1)
primary_user_real=$(getent passwd "$primary_user" 2>/dev/null | cut -d: -f5 | cut -d, -f1 || echo "User")

cat >> "$OUTPUT_FILE" << EOF

  # User configuration
  identity:
    hostname: $(hostname)
    username: $primary_user
    password: '\$6\$rounds=4096\$CHANGE_THIS_SALT\$CHANGE_THIS_HASH'  # Generate with: openssl passwd -6
    realname: "$primary_user_real"

  # SSH configuration
  ssh:
    install-server: true
    allow-pw: $(if systemctl is-active ssh >/dev/null 2>&1; then echo "true"; else echo "false"; fi)
    authorized-keys: []
    # Add your SSH public keys here:
    # - "ssh-rsa AAAAB3NzaC1yc2EAAAA... your-key-here"

EOF

# Package installation
log "Gathering package information"
echo "  # Package installation" >> "$OUTPUT_FILE"
echo "  packages:" >> "$OUTPUT_FILE"

# Get essential packages
get_essential_packages | while IFS= read -r package; do
    if [[ "$package" =~ ^# ]]; then
        echo "  $package" >> "$OUTPUT_FILE"
    else
        echo "    - $package" >> "$OUTPUT_FILE"
    fi
done

# Post-installation commands
log "Configuring post-installation commands"
cat >> "$OUTPUT_FILE" << EOF

  # Post-installation commands
  late-commands:
    - echo 'Autoinstall completed on \$(date)' > /target/var/log/autoinstall.log
    - chmod 644 /target/var/log/autoinstall.log

    # Copy timezone configuration
    - cp /etc/timezone /target/etc/timezone

    # Restore important services
EOF

# Add enabled services
for service in $(get_enabled_services); do
    echo "    - systemctl enable $service" >> "$OUTPUT_FILE"
done

cat >> "$OUTPUT_FILE" << EOF

  # Additional system configuration
  user-data:
    disable_root: false
    package_update: true
    package_upgrade: true
    timezone: $(cat /etc/timezone 2>/dev/null || echo "UTC")

    # Preserve important files
    write_files:
      - path: /etc/hostname
        content: $(hostname)

      - path: /etc/hosts
        content: |
$(cat /etc/hosts | sed 's/^/          /')

    # System services configuration
    runcmd:
      - systemctl daemon-reload
      - echo "System restoration completed" >> /var/log/autoinstall.log

EOF

# Create backup of configurations
backup_configs

# Set proper permissions
chmod 600 "$OUTPUT_FILE"

log "Autoinstall configuration generated successfully!"
log "Output file: $PWD/$OUTPUT_FILE"
log "Backup directory: $PWD/$BACKUP_DIR"
log "Log file: $LOG_FILE"

echo ""
echo "=== IMPORTANT NOTES ==="
echo "1. Edit the password hash in the YAML file before use:"
echo "   openssl passwd -6 'your-password'"
echo ""
echo "2. Add your SSH public keys to the authorized-keys section"
echo ""
echo "3. Review and adjust package lists as needed"
echo ""
echo "4. Test the configuration in a VM before production use"
echo ""
echo "5. Backup files are stored in: $BACKUP_DIR"
echo ""
echo "6. Storage configuration uses LVM - adjust if needed"
echo ""

log "Script completed successfully"
