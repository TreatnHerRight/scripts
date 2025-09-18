#!/bin/bash

# --- Configuration ---
CONFIG_FILE=".docker_stacks_git_push.env"

# --- Functions ---

# Function to send a notification to NTFY
send_notification() {
    # Exit if NTFY_TOPIC is not set
    if [ -z "$NTFY_TOPIC" ]; then
        return
    fi
    
    local title="$1"
    local message="$2"
    local priority="$3"
    
    curl -s -H "Title: $title" -H "Priority: $priority" -d "$message" "https://ntfy.sh/$NTFY_TOPIC"
}

# Function to display error messages, notify, and exit
error_exit() {
    local error_message="$1"
    echo "Error: $error_message" >&2
    send_notification "❌ Git Push Failed" "$error_message" "high"
    exit 1
}

# Function to create the configuration file
create_config() {
    echo "Configuration file not found. Let's create one."
    
    # Prompt for Git repository URL
    read -p "Enter the Git repository URL: " git_repo_url
    while [[ -z "$git_repo_url" ]]; do
        read -p "Git repository URL cannot be empty. Please enter it: " git_repo_url
    done

    # Prompt for Docker stacks path
    read -p "Enter the absolute local path to your Docker stacks directory: " docker_stacks_path
    while [[ -z "$docker_stacks_path" ]]; do
        read -p "Path cannot be empty. Please enter the path: " docker_stacks_path
    done
    
    # Prompt for Git commit message
    read -p "Enter the default Git commit message (press Enter for 'Automated commit'): " git_commit_message
    
    # --- NTFY Addition ---
    # Prompt for NTFY topic (optional)
    read -p "Enter your NTFY topic (optional, leave blank to disable notifications): " ntfy_topic
    
    # Create the config file
    echo "Creating configuration file: $CONFIG_FILE"
    echo "GIT_REPO_URL=\"$git_repo_url\"" > "$CONFIG_FILE"
    echo "DOCKER_STACKS_PATH=\"$docker_stacks_path\"" >> "$CONFIG_FILE"
    echo "GIT_COMMIT_MESSAGE=\"${git_commit_message:-'Automated commit'}\"" >> "$CONFIG_FILE"
    echo "NTFY_TOPIC=\"$ntfy_topic\"" >> "$CONFIG_FILE" # --- NTFY Addition ---
    
    echo "Configuration file created successfully."
}

# --- Script Start ---

# Check if config file exists, if not, create it
if [ ! -f "$CONFIG_FILE" ]; then
    create_config
fi

# Load the configuration
source "$CONFIG_FILE"

# --- Failsafes ---

# Check if git is installed
if ! command -v git &> /dev/null; then
    error_exit "Git is not installed. Please install git and try again."
fi

# Check if curl is installed (for NTFY)
if [ -n "$NTFY_TOPIC" ] && ! command -v curl &> /dev/null; then
    error_exit "Curl is not installed, but is required for NTFY notifications."
fi

# Check if the Docker stacks path exists
if [ ! -d "$DOCKER_STACKS_PATH" ]; then
    error_exit "The specified Docker stacks path does not exist: $DOCKER_STACKS_PATH"
fi

# --- Main Logic ---

# Navigate to the Docker stacks directory
cd "$DOCKER_STACKS_PATH" || error_exit "Could not navigate to the Docker stacks directory."

# Check if the directory is a git repository
if [ ! -d ".git" ]; then
    echo "This directory is not a git repository. Initializing one now..."
    git init
fi

# Check if a remote named 'origin' exists
if ! git remote get-url origin &> /dev/null; then
    echo "Git remote 'origin' not found. Adding it now..."
    git remote add origin "$GIT_REPO_URL"
fi

# Check for changes to commit
if git diff-index --quiet HEAD --; then
    echo "No changes to commit."
    send_notification "ℹ️ No Changes to Commit" "Script ran successfully, but there were no new changes in $DOCKER_STACKS_PATH." "default"
    exit 0
fi

echo "Adding files to git..."
git add .

echo "Committing changes..."
git commit -m "$GIT_COMMIT_MESSAGE"

echo "Pushing changes to the remote repository..."
git push -u origin main

# Check the exit status of the push command
if [ $? -eq 0 ]; then
    echo "Docker stacks pushed to git successfully!"
    send_notification "✅ Git Push Successful" "Your Docker stacks were successfully pushed from $(hostname)." "default"
else
    error_exit "The 'git push' command failed."
fi
