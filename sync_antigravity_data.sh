#!/bin/bash

# Exit on error
set -e

# Default values
SOURCE_PATH="$HOME/.config/Antigravity"
DESTINATION_PATH="$HOME/.config/Antigravity IDE"
DRY_RUN=false

# Helper for print usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -s, --source <path>       Source config directory (default: $HOME/.config/Antigravity)"
    echo "  -d, --destination <path>  Destination config directory (default: $HOME/.config/Antigravity IDE)"
    echo "  -n, --dry-run             Perform a dry run (no files modified)"
    echo "  -h, --help                Show this help message"
    exit 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--source) SOURCE_PATH="$2"; shift ;;
        -d|--destination) DESTINATION_PATH="$2"; shift ;;
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

echo "=================================================="
echo "   Antigravity IDE Data & Logs Sync Script (Linux)"
echo "=================================================="
echo "Source:      $SOURCE_PATH"
echo "Destination: $DESTINATION_PATH"
if [ "$DRY_RUN" = true ]; then
    echo "MODE:        [DRY RUN] (No files will be modified)"
else
    echo "MODE:        [LIVE SYNC]"
fi
echo "=================================================="

# 1. Validate Source Path
if [ ! -d "$SOURCE_PATH" ]; then
    echo "Error: Source directory '$SOURCE_PATH' does not exist. Migration cannot continue." >&2
    exit 1
fi

# 2. Check for running processes
echo "Checking for running Antigravity processes..."
running_processes=$(pgrep -f -i "Antigravity" | grep -v "$$" || true)

if [ -n "$running_processes" ]; then
    echo "Warning: Active Antigravity processes were found (PIDs: $running_processes)."
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would prompt user to close running processes."
    else
        read -p "Do you want to close these processes automatically? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo "Stopping processes..."
            pkill -f -i "Antigravity" || true
            sleep 2
        else
            echo "Warning: Please close the IDE manually and re-run the script."
            exit 1
        fi
    fi
else
    echo "No active Antigravity processes found. Proceeding."
fi

# 3. Create Backup of Destination if it exists
backup_created=false
new_destination_created=false
backup_path=""

if [ -d "$DESTINATION_PATH" ]; then
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_path="${DESTINATION_PATH}_backup_${timestamp}"
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would backup existing destination folder to: $backup_path"
    else
        echo "Creating a backup of existing destination to: $backup_path"
        cp -R "$DESTINATION_PATH" "$backup_path"
        backup_created=true
        echo "Backup created successfully."
    fi
else
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Destination directory does not exist. Would create: $DESTINATION_PATH"
    else
        echo "Destination directory does not exist. Creating: $DESTINATION_PATH"
        mkdir -p "$DESTINATION_PATH"
        new_destination_created=true
    fi
fi

# Cleanup/Rollback handler on failure
cleanup() {
    exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        echo "An error occurred during synchronization (exit code $exit_code). Rolling back changes..." >&2
        if [ "$backup_created" = true ]; then
            if [ -d "$DESTINATION_PATH" ]; then
                rm -rf "$DESTINATION_PATH"
            fi
            mv "$backup_path" "$DESTINATION_PATH"
            echo "Rollback completed. Restored destination from backup: $DESTINATION_PATH"
        elif [ "$new_destination_created" = true ]; then
            if [ -d "$DESTINATION_PATH" ]; then
                rm -rf "$DESTINATION_PATH"
            fi
            echo "Rollback completed. Cleaned up destination folder: $DESTINATION_PATH"
        fi
    fi
}
trap cleanup EXIT

# 4. Copy User Configuration Files
src_user_dir="$SOURCE_PATH/User"
dst_user_dir="$DESTINATION_PATH/User"

config_files=("settings.json" "keybindings.json" "tasks.json")

if [ -d "$src_user_dir" ]; then
    if [ "$DRY_RUN" = false ] && [ ! -d "$dst_user_dir" ]; then
        mkdir -p "$dst_user_dir"
    fi

    for file in "${config_files[@]}"; do
        file_path="$src_user_dir/$file"
        if [ -f "$file_path" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "[Dry-Run] Would copy file: $file"
                echo "  -> User/$file"
            else
                echo "Copying configuration file: $file..."
                cp "$file_path" "$dst_user_dir/"
            fi
        fi
    done

    # 5. Copy User Configuration Directories
    config_dirs=("snippets" "History" "workspaceStorage")
    for dir in "${config_dirs[@]}"; do
        dir_path="$src_user_dir/$dir"
        if [ -d "$dir_path" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "[Dry-Run] Would copy directory: $dir"
                find "$dir_path" -type f 2>/dev/null | while IFS= read -r f; do
                    rel_path="${f#$src_user_dir/}"
                    echo "  -> User/$rel_path"
                done
            else
                echo "Copying directory recursively: $dir..."
                target_dir="$dst_user_dir/$dir"
                mkdir -p "$target_dir"
                cp -R "$dir_path/." "$target_dir/"
            fi
        fi
    done

    # 6. Copy globalStorage Contents
    global_storage_src="$src_user_dir/globalStorage"
    if [ -d "$global_storage_src" ]; then
        global_storage_dst="$dst_user_dir/globalStorage"
        if [ "$DRY_RUN" = true ]; then
            echo "[Dry-Run] Would copy globalStorage contents"
            find "$global_storage_src" -type f 2>/dev/null | while IFS= read -r f; do
                rel_path="${f#$src_user_dir/}"
                echo "  -> User/$rel_path"
            done
        else
            echo "Copying globalStorage contents recursively..."
            mkdir -p "$global_storage_dst"
            cp -R "$global_storage_src/." "$global_storage_dst/"
        fi
    fi
else
    echo "Warning: Source User folder '$src_user_dir' not found."
fi

# 7. Copy logs Folder Contents
logs_src="$SOURCE_PATH/logs"
if [ -d "$logs_src" ]; then
    logs_dst="$DESTINATION_PATH/logs"
    if [ "$DRY_RUN" = true ]; then
        echo "[Dry-Run] Would copy logs folder contents"
        find "$logs_src" -type f 2>/dev/null | while IFS= read -r f; do
            rel_path="${f#$SOURCE_PATH/}"
            echo "  -> $rel_path"
        done
    else
        echo "Copying logs recursively..."
        mkdir -p "$logs_dst"
        cp -R "$logs_src/." "$logs_dst/"
    fi
else
    echo "Warning: Source logs folder '$logs_src' not found."
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "Dry run completed. Run without -n or --dry-run to perform the actual sync."
else
    echo "Duplication Successful!"
fi
echo "=================================================="
