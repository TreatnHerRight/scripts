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
    
    # Use NTFY_SERVER if set, otherwise use the public server
    server="${NTFY_SERVER:-https://ntfy.sh}"
    
    # Prepare curl command with optional token
    cmd="curl -s -H \"Title: $title\" -H \"Priority: $priority\""
    if [ -n "$NTFY_TOKEN" ]; then
        cmd="$cmd -H \"Authorization: Bearer $NTFY_TOKEN\""
    fi
    cmd="$cmd -d \"$message\" \"$server/$NTFY_TOPIC\""
    
    # Execute the command
    eval "$cmd"
}

# Function to display error messages, notify, and exit
error_exit() {
    error_message="$1"
    echo "Error: $error_message" >&2
    # Failure notifications are always sent if NTFY is enabled
    send_notification "❌ Git Push Failed" "$error_message" "high"
    exit 1
}

# Function to create the configuration file with explanations
create_config() {
    echo "--- Configuration File Setup ---"
    echo "This script needs some information to get started."
    
    # --- Git Repository URL ---
    echo "\n[1/9] Git Repository URL"
    echo "This is the full HTTPS or SSH address of the remote repository."
    echo "Example: https://github.com/YourUsername/YourRepoName.git"
    printf "Enter the Git repository URL: "
    read -r git_repo_url < /dev/tty
    
    # --- Docker Stacks Path ---
    echo "\n[2/9] Docker Stacks Directory Path"
    echo "This is the full path on this machine to the folder containing your Docker files."
    echo "Tip: Navigate to the folder in another terminal and use the 'pwd' command to get the exact path."
    echo "Example: /opt/stacks/dockge"
    printf "Enter the absolute local path to your Docker stacks directory: "
    read -r docker_stacks_path < /dev/tty
    
    # --- Git Commit Message ---
    echo "\n[3/9] Default Git Commit Message"
    echo "This is the default message that will be used for each automated commit."
    printf "Enter the default Git commit message (press Enter for 'Automated commit'): "
    read -r git_commit_message < /dev/tty
    
    # --- Enable NTFY ---
    echo "\n[4/9] Enable NTFY Notifications"
    echo "NTFY is a push notification service. Answer 'yes' to configure notifications."
    printf "Enable NTFY notifications? (yes/no): "
    read -r ntfy_enabled < /dev/tty

    if [ "$ntfy_enabled" = "yes" ]; then
        # --- NTFY Topic ---
        echo "\n[5/9] NTFY Topic"
        echo "This is the name of your NTFY topic (e.g., 'docker-backups')."
        echo "Notifications will be sent to YOUR_SERVER/YOUR_TOPIC."
        printf "Enter your NTFY topic: "
        read -r ntfy_topic < /dev/tty
        
        # --- NTFY Server ---
        echo "\n[6/9] NTFY Server URL"
        echo "Enter the address of your self-hosted or public NTFY server."
        echo "Example: http://192.168.1.100:8080 or https://ntfy.sh"
        printf "Enter your NTFY server URL: "
        read -r ntfy_server < /dev/tty
        
        # --- NTFY Token ---
        echo "\n[7/9] NTFY Access Token"
        echo "If your NTFY topic is private, enter your access token here. Otherwise, leave blank."
        printf "Enter your NTFY Access Token (optional): "
        read -r ntfy_token < /dev/tty
        
        # --- Notify on Success ---
        echo "\n[8/9] Notify on Success"
        echo "Select 'yes' to receive a notification every time the script successfully pushes an update."
        printf "Notify on successful push? (yes/no): "
        read -r notify_on_success < /dev/tty
        
        # --- Notify on No Changes ---
        echo "\n[9/9] Notify on No Changes"
        echo "Select 'yes' to receive a 'heartbeat' notification even when there are no changes to commit."
        printf "Notify when there are no changes? (yes/no): "
        read -r notify_on_no_changes < /dev/tty
    fi
    
    # --- Create the config file ---
    echo "\n---"
    echo "Creating configuration file: $CONFIG_FILE"
    echo "GIT_REPO_URL=\"$git_repo_url\"" > "$CONFIG_FILE"
    echo "DOCKER_STACKS_PATH=\"$docker_stacks_path\"" >> "$CONFIG_FILE"
    echo "GIT_COMMIT_MESSAGE=\"${git_commit_message:-'Automated commit'}\"" >> "$CONFIG_FILE"
    
    # --- Save New NTFY Settings ---
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

# --- Script Start ---
# Change to the script's directory to ensure the .env file is managed locally
cd "$(dirname "$0")" || exit

if ! [ -f "$CONFIG_FILE" ]; then
    create_config
fi

. "./$CONFIG_FILE"

# --- Failsafes ---
if ! command -v git >/dev/null 2>&1; then
    error_exit "Git is not installed."
fi
if [ "$NTFY_ENABLED" = "yes" ] && ! command -v curl >/dev/null 2>&1; then
    error_exit "Curl is not installed, but is required for NTFY notifications."
fi
if ! [ -d "$DOCKER_STACKS_PATH" ]; then
    error_exit "The specified Docker stacks path does not exist: $DOCKER_STACKS_PATH"
fi

# --- Main Logic ---
cd "$DOCKER_STACKS_PATH" || error_exit "Could not navigate to the Docker stacks directory."

if ! [ -d ".git" ]; then
    git init && git remote add origin "$GIT_REPO_URL"
fi

if git diff-index --quiet HEAD --; then
    echo "No changes to commit."
    if [ "$NOTIFY_ON_NO_CHANGES" = "yes" ]; then
        send_notification "ℹ️ No Changes to Commit" "Script ran successfully, but there were no new changes." "default"
    fi
    exit 0
fi

git add .
git commit -m "$GIT_COMMIT_MESSAGE"
git push -u origin main

if [ $? -eq 0 ]; then
    echo "Docker stacks pushed to git successfully!"
    if [ "$NOTIFY_ON_SUCCESS" = "yes" ]; then
        send_notification "✅ Git Push Successful" "Your Docker stacks were successfully pushed from $(hostname)." "default"
    fi
else
    error_exit "The 'git push' command failed."
fi

