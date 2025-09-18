#!/bin/sh

# --- Configuration ---
CONFIG_FILE=".docker_stacks_git_push.env"

# --- Functions ---

# Function to send a notification to NTFY
send_notification() {
    # Exit if NTFY_TOPIC is not set
    if [ -z "$NTFY_TOPIC" ]; then
        return
    fi
    
    title="$1"
    message="$2"
    priority="$3"
    
    curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "https://ntfy.sh/$NTFY_TOPIC"
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
    echo "Configuration file not found. Let's create one."
    
    # Prompt for Git repository URL, reading from the terminal
    printf "Enter the Git repository URL: "
    read -r git_repo_url < /dev/tty # <-- THE TRICK IS HERE
    while [ -z "$git_repo_url" ]; do
        printf "Git repository URL cannot be empty. Please enter it: "
        read -r git_repo_url < /dev/tty # <-- THE TRICK IS HERE
    done

    # Prompt for Docker stacks path, reading from the terminal
    printf "Enter the absolute local path to your Docker stacks directory: "
    read -r docker_stacks_path < /dev/tty # <-- THE TRICK IS HERE
    while [ -z "$docker_stacks_path" ]; do
        printf "Path cannot be empty. Please enter the path: "
        read -r docker_stacks_path < /dev/tty # <-- THE TRICK IS HERE
    done
    
    # Prompt for Git commit message, reading from the terminal
    printf "Enter the default Git commit message (press Enter for 'Automated commit'): "
    read -r git_commit_message < /dev/tty # <-- THE TRICK IS HERE
    
    # Prompt for NTFY topic (optional), reading from the terminal
    printf "Enter your NTFY topic (optional, leave blank to disable notifications): "
    read -r ntfy_topic < /dev/tty # <-- THE TRICK IS HERE
    
    # Create the config file
    echo "Creating configuration file: $CONFIG_FILE"
    echo "GIT_REPO_URL=\"$git_repo_url\"" > "$CONFIG_FILE"
    echo "DOCKER_STACKS_PATH=\"$docker_stacks_path\"" >> "$CONFIG_FILE"
    # Set default commit message if empty
    if [ -z "$git_commit_message" ]; then
        git_commit_message="Automated commit"
    fi
    echo "GIT_COMMIT_MESSAGE=\"$git_commit_message\"" >> "$CONFIG_FILE"
    echo "NTFY_TOPIC=\"$ntfy_topic\"" >> "$CONFIG_FILE"
    
    echo "Configuration file created successfully."
}

# --- Script Start ---
# Change to the script's directory to ensure the .env file is managed locally
cd "$(dirname "$0")" || exit

# Check if config file exists, if not, create it
if ! [ -f "$CONFIG_FILE" ]; then
    create_config
fi

# Load the configuration using the POSIX-compliant dot command
. "./$CONFIG_FILE"

# --- Failsafes ---
if ! command -v git >/dev/null 2>&1; then
    error_exit "Git is not installed."
fi
if [ -n "$NTFY_TOPIC" ] && ! command -v curl >/dev/null 2>&1; then
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
    send_notification "ℹ️ No Changes to Commit" "Script ran successfully, but there were no new changes in $DOCKER_STACKS_PATH." "default"
    exit 0
fi
git add .
git commit -m "$GIT_COMMIT_MESSAGE"
git push -u origin main
if [ $? -eq 0 ]; then
    echo "Docker stacks pushed to git successfully!"
    send_notification "✅ Git Push Successful" "Your Docker stacks were successfully pushed from $(hostname)." "default"
else
    error_exit "The 'git push' command failed."
fi
