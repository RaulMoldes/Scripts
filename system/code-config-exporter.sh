#!/bin/bash

# VSCode configuration export script
# Exports complete VSCode configuration to backup files

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Message display functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect operating system and set paths
detect_vscode_path() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        VSCODE_CONFIG_DIR="$HOME/.config/Code/User"
        VSCODE_EXTENSIONS_DIR="$HOME/.vscode/extensions"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
        VSCODE_EXTENSIONS_DIR="$HOME/.vscode/extensions"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        VSCODE_CONFIG_DIR="$APPDATA/Code/User"
        VSCODE_EXTENSIONS_DIR="$HOME/.vscode/extensions"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Create backup directory function
create_backup_dir() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="vscode_backup_$timestamp"

    if [[ -d "$BACKUP_DIR" ]]; then
        log_warning "Directory $BACKUP_DIR already exists"
        read -p "Do you want to continue and overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        rm -rf "$BACKUP_DIR"
    fi

    mkdir -p "$BACKUP_DIR"
    log_success "Backup directory created: $BACKUP_DIR"
}

# Export VSCode settings function
export_settings() {
    log_info "Exporting VSCode configuration..."

    # Check if configuration directory exists
    if [[ ! -d "$VSCODE_CONFIG_DIR" ]]; then
        log_error "VSCode configuration directory not found: $VSCODE_CONFIG_DIR"
        return 1
    fi

    # Copy main configuration files
    local config_files=("settings.json" "keybindings.json" "tasks.json" "launch.json")
    local config_copied=false

    for file in "${config_files[@]}"; do
        if [[ -f "$VSCODE_CONFIG_DIR/$file" ]]; then
            cp "$VSCODE_CONFIG_DIR/$file" "$BACKUP_DIR/"
            log_success "Exported: $file"
            config_copied=true
        else
            log_warning "Not found: $file"
        fi
    done

    # Copy snippets if they exist
    if [[ -d "$VSCODE_CONFIG_DIR/snippets" ]]; then
        cp -r "$VSCODE_CONFIG_DIR/snippets" "$BACKUP_DIR/"
        log_success "Exported: snippets"
        config_copied=true
    else
        log_warning "Snippets directory not found"
    fi

    if [[ "$config_copied" == false ]]; then
        log_error "No configuration files found"
        return 1
    fi
}

# Export extensions list function
export_extensions() {
    log_info "Exporting extensions list..."

    # Check if VSCode is available in PATH
    if ! command -v code &> /dev/null; then
        log_warning "Command 'code' not available. Trying alternative methods..."

        # Alternative method: read from extensions directory
        if [[ -d "$VSCODE_EXTENSIONS_DIR" ]]; then
            log_info "Listing extensions from extensions directory..."
            ls "$VSCODE_EXTENSIONS_DIR" | grep -E "^[^.]+\." | cut -d'-' -f1-2 > "$BACKUP_DIR/extensions_list.txt"
            log_success "Extensions list exported to extensions_list.txt (alternative method)"
        else
            log_warning "Could not export extensions list"
            return 1
        fi
    else
        # Preferred method using code command
        code --list-extensions > "$BACKUP_DIR/extensions_list.txt"
        log_success "Extensions list exported to extensions_list.txt"

        # Also create installation script
        echo "#!/bin/bash" > "$BACKUP_DIR/install_extensions.sh"
        echo "# Script to install VSCode extensions" >> "$BACKUP_DIR/install_extensions.sh"
        echo "" >> "$BACKUP_DIR/install_extensions.sh"
        while read -r extension; do
            echo "code --install-extension $extension" >> "$BACKUP_DIR/install_extensions.sh"
        done < "$BACKUP_DIR/extensions_list.txt"
        chmod +x "$BACKUP_DIR/install_extensions.sh"
        log_success "Installation script created: install_extensions.sh"
    fi
}

# Create README file function
create_readme() {
    log_info "Creating README file..."

    cat > "$BACKUP_DIR/README.md" << EOF
# VSCode Configuration Backup

Backup created on: $(date)
Operating system: $OSTYPE

## Backup contents

### Configuration files:
- \`settings.json\`: General VSCode settings
- \`keybindings.json\`: Custom keyboard shortcuts
- \`tasks.json\`: Configured tasks
- \`launch.json\`: Debug configurations
- \`snippets/\`: Custom snippets

### Extensions:
- \`extensions_list.txt\`: List of installed extensions
- \`install_extensions.sh\`: Script to reinstall all extensions

## How to restore configuration

### 1. Restore configuration files:
Copy configuration files to your VSCode directory:

**Linux:**
\`\`\`bash
cp settings.json ~/.config/Code/User/
cp keybindings.json ~/.config/Code/User/
cp -r snippets ~/.config/Code/User/
\`\`\`

**macOS:**
\`\`\`bash
cp settings.json ~/Library/Application\ Support/Code/User/
cp keybindings.json ~/Library/Application\ Support/Code/User/
cp -r snippets ~/Library/Application\ Support/Code/User/
\`\`\`

**Windows (Git Bash/WSL):**
\`\`\`bash
cp settings.json \$APPDATA/Code/User/
cp keybindings.json \$APPDATA/Code/User/
cp -r snippets \$APPDATA/Code/User/
\`\`\`

### 2. Reinstall extensions:
\`\`\`bash
chmod +x install_extensions.sh
./install_extensions.sh
\`\`\`

Or manually:
\`\`\`bash
while read extension; do code --install-extension \$extension; done < extensions_list.txt
\`\`\`

## Notes
- Make sure VSCode is installed before restoring
- Restart VSCode after restoring configuration
- Some extensions may require additional configuration
EOF

    log_success "README.md file created"
}

# Create compressed archive function
create_archive() {
    read -p "Do you want to create a compressed archive of the backup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v tar &> /dev/null; then
            tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
            log_success "Compressed archive created: ${BACKUP_DIR}.tar.gz"
        elif command -v zip &> /dev/null; then
            zip -r "${BACKUP_DIR}.zip" "$BACKUP_DIR"
            log_success "Compressed archive created: ${BACKUP_DIR}.zip"
        else
            log_warning "No compression tools found (tar or zip)"
        fi
    fi
}

# Main function
main() {
    log_info "Starting VSCode configuration backup..."

    detect_vscode_path
    log_info "Configuration detected at: $VSCODE_CONFIG_DIR"

    create_backup_dir

    export_settings
    export_extensions
    create_readme

    log_success "Backup completed in directory: $BACKUP_DIR"

    create_archive

    log_info "Process completed successfully!"
    log_info "To restore your configuration, check the README.md file in the backup directory"
}

# Execute main function
main "$@"
