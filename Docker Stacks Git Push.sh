#!/bin/sh

# --- Configuration ---
# The script will look for this file in the directory it is run from.
CONFIG_FILE=".docker_stacks_git_push.env"

# --- Functions ---

# Function to send a notification to NTFY (Safer version without eval)
send_notification() {
    if [ "$NTFY_ENABLED" != "yes" ]; then return; fi
    title="$1"
    message="$2"
    priority="$3"
    server="${NTFY_SERVER:-https://ntfy.sh}"

    # Build curl command arguments safely
    if [ -n "$NTFY_TOKEN" ]; then
        curl -s -H "Title: $title" -H "Priority: $priority" -H "Authorization: Bearer $NTFY_TOKEN" -d "$message" "$server/$NTFY_TOPIC"
    else
        curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "$server/$NTFY_TOPIC"
    fi
}

# Function to display error messages, notify, and exit
error_exit() {
    error_message="$1"
    echo "Error: $error_message" >&2
    send_notification "❌ Git Push Failed" "$error_message" "high"
    exit 1
}

# Function to create the configuration file
create_config() {
    echo "--- Configuration File Setup ---"
    # ... (prompts remain the same)
    echo "\n[1/9] Git Repository URL..."
    printf "Enter the Git repository URL: "; read -r git_repo_url < /dev/tty
    echo "\n[2/9] Docker Stacks Directory Path..."
    printf "Enter the absolute local path to your Docker stacks directory: "; read -r docker_stacks_path < /dev/tty
    echo "\n[3/9] Default Git Commit Message..."
    printf "Enter the default Git commit message (press Enter for 'Automated commit'): "; read -r git_commit_message < /dev/tty
    echo "\n[4/9] Enable NTFY Notifications..."
    printf "Enable NTFY notifications? (yes/no): "; read -r ntfy_enabled < /dev/tty
    if [ "$ntfy_enabled" = "yes" ]; then
        echo "\n[5/9] NTFY Topic..."
        printf "Enter your NTFY topic: "; read -r ntfy_topic < /dev/tty
        echo "\n[6/9] NTFY Server URL..."
        printf "Enter your NTFY server URL: "; read -r ntfy_server < /dev/tty
