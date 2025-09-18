#!/bin/sh

# --- Configuration ---
CONFIG_FILE=".docker_stacks_git_push.env"

# --- Functions ---

# Function to send a notification to NTFY
send_notification() {
    # Check if notifications are globally enabled
    if [ "$NTFY_ENABLED" != "yes" ]; then
        return
    fi
    title="$1"
    message="$2"
    priority="$3"
    server="${NTFY_SERVER:-https://ntfy.sh}"
    cmd="curl -s -H \"Title: $title\" -H \"Priority: $priority\""
    if [ -n "$NTFY_TOKEN" ]; then
        cmd="$cmd -H \"Authorization: Bearer $NTFY_TOKEN\""
    fi
    cmd="$cmd -d \"$message\" \"$server/$NTFY_TOPIC\""
    eval "$cmd"
}

# Function to display error messages, notify, and exit
error_exit() {
    error_message="$1"
    echo "Error: $error_message" >&2
    send_notification "❌ Git Push Failed" "$error_message" "high"
    exit 1
}

# Function to create the configuration file with explanations
create_config() {
    echo "--- Configuration File Setup ---"
    echo "This script needs some information to get started."
    echo "\n[1/9] Git Repository URL..."
    printf "Enter the Git repository URL: "
    read -r git_repo_url < /dev/tty
    echo "\n[2/9] Docker Stacks Directory Path..."
    printf "Enter the absolute local path to your Docker stacks directory: "
    read -r docker_stacks_path < /dev/tty
    echo "\n[3/9] Default Git Commit Message..."
    printf "Enter the default Git commit message (press Enter for 'Automated commit'): "
    read -r git_commit_message < /dev/tty
    echo "\n[4/9] Enable NTFY Notifications..."
    printf "Enable NTFY notifications? (yes/no): "
    read -r ntfy_enabled < /dev/tty
    if [ "$ntfy_enabled" = "yes" ]; then
        echo "\n[5/9] NTFY Topic..."
        printf "Enter your NTFY topic: "
        read -r ntfy_topic < /dev/tty
        echo "\n[6/9] NTFY Server URL..."
        printf "Enter your NTFY server URL: "
        read -r ntfy_server < /dev/tty
        echo "\n[7/9] NTFY Access Token..."
        printf "Enter your NTFY Access Token (optional): "
        read -r ntfy_token < /dev/tty
        echo "\n[8/9] Notify on Success..."
        printf "Notify on successful push? (yes/no): "
        read -r notify_on_success < /dev/tty
        echo "\n[9/9] Notify on No Changes..."
        printf "Notify when there are no changes? (yes/no): "
        read -r notify_on_no_changes < /dev/tty
    fi
    echo "\n---"
    echo "Creating configuration file: $CONFIG_FILE"
    echo "GIT_REPO_URL=\"$git_repo_url\"" > "$CONFIG_FILE"
    echo "DOCKER_STACKS_PATH=\"$docker_stacks_path\"" >> "$CONFIG_FILE"
    echo "GIT_COMMIT_MESSAGE=\"${git_commit_message:-'Automated commit'}\"" >> "$CONFIG_FILE"
    echo "# --- ntfy Notification Configuration ---" >> "$CONFIG_FILE"
    echo "NTFY_ENABLED=\"${ntfy_enabled:-no}\"" >> "$CONFIG_FILE"
    echo "NTFY_TOPIC=\"$ntfy_topic\"" >> "$CONFIG_FILE"
    echo "NTFY_SERVER=\"$ntfy_server\"" >> "$CONFIG_FILE"
    echo "NTFY_TOKEN=\"$ntfy_token\"" >> "$CONFIG_FILE"
    echo "# --- Notification Toggles (Set to \"yes\" or \"no\") ---" >> "$CONFIG_FILE"
    echo "NOTIFY_ON_SUCCESS=\"${notify_on_success:-yes}\"" >> "$CONFIG_FILE"
    echo "NOTIFY_ON_NO_CHANGES=\"${notify_on_no_changes:-no}\"" >> "$CONFIG_FILE"
    echo "Configuration file created successfully."
}

# --- NEW: Function to Setup Cron Job ---
setup_cron() {
    if ! command -v crontab >/dev/null 2>&1; then
        error_exit "crontab command not found. Please install cron."
    fi

    # Get the absolute path to this script
    SCRIPT_PATH=$(readlink -f "$0")
    
    echo "--- Cron Job Setup ---"
    echo "Select how often you want the script to run:"
    echo "  1) Every 15 minutes"
    echo "  2) Every 30 minutes"
    echo "  3) Every hour"
    echo "  4) Every 3 hours"
    echo "  5) Every 6 hours"
    echo "  6) Every 12 hours"
    echo "  7) Every 24 hours (at midnight)"
    printf "Enter your choice (1
