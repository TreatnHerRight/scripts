#!/bin/bash

# ==============================================================================
# --- CONFIGURATION - DO NOT EDIT VALUES HERE ---
# ==============================================================================

# Define the path to the environment file.
ENV_FILE="/opt/scripts/git-push.env"

# Load environment variables from the .env file.
if [ -f "$ENV_FILE" ]; then
    set -a # Automatically export all variables
    source "$ENV_FILE"
    set +a # Stop automatically exporting
else
    # This echo will not be logged as the log file is defined in the .env file.
    echo "FATAL: Configuration file not found at $ENV_FILE. Exiting."
    exit 1
fi

# This line is intentionally kept from the original script to ensure README_FILE is defined.
# It uses the REPO_DIR value loaded from the .env file.
README_FILE="$REPO_DIR/README.md"


# ==============================================================================
# --- SCRIPT LOGIC - DO NOT EDIT BELOW THIS LINE ---
# ==============================================================================

# --- Global Variables ---
CHANGES=""

# --- Logging Function ---
touch "$LOG_FILE"
chown root:root "$LOG_FILE"
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# --- ntfy Notification Function ---
send_notification() {
    if [ "$NTFY_ENABLED" != "yes" ]; then
        return 0
    fi
    PRIORITY="$1"
    TITLE="$2"
    MESSAGE="$3"

    curl -s \
      -H "Authorization: Bearer $NTFY_TOKEN" \
      -H "Markdown: yes" \
      -H "Priority: $PRIORITY" \
      -H "Title: $TITLE" \
      -H "Tags: git,floppy_disk" \
      --data-binary "$MESSAGE" \
      "$NTFY_SERVER/$NTFY_TOPIC" >> "$LOG_FILE" 2>&1
}

# --- Script Start ---
log_message "--- Starting Git Push for '$REPO_NAME' ---"

cd "$REPO_DIR" || {
    ERROR_MSG="Could not change directory to $REPO_DIR. Please check REPO_DIR variable."
    log_message "ERROR: $ERROR_MSG"
    send_notification "urgent" "Git Backup FAILED: $REPO_NAME" "$ERROR_MSG"
    exit 1
}

if [ -f .git/index.lock ]; then
    log_message "WARNING: Found .git/index.lock. Removing."
    rm -f .git/index.lock
fi

log_message "Staging new/modified files..."
git add . >> "$LOG_FILE" 2>&1

if ! git diff-index --quiet HEAD; then
    log_message "Local changes detected..."
    
    CHANGES=$(git diff --name-only --cached)

    # --- README Generation Block ---
    if [ -n "$CHANGES" ]; then
        log_message "Generating README.md with latest changes..."
        # Format for README: surround each filename with backticks for inline code block
        CHANGES_FORMATTED_FOR_README=$(echo "$CHANGES" | sed 's/^/`/' | sed 's/$/`/')
        
        # Create README from scratch, overwriting the old one
        {
            echo "# $REPO_NAME"
            echo ""
            echo "Last automated backup: **$(date '+%Y-%m-%d %H:%M:%S %Z')** by $(hostname)"
            echo ""
            echo "---"
            echo ""
            echo "### Last Commit Includes:"
            echo "$CHANGES_FORMATTED_FOR_README"
        } > "$README_FILE"

        log_message "Staging updated README.md..."
        # Add the newly created README to the commit
        git add "$README_FILE" >> "$LOG_FILE" 2>&1
    fi

    log_message "Committing changes..."
    COMMIT_MSG="Automated commit from $(hostname) on $(date +'%Y-%m-%d %H:%M')"
    git commit -m "$COMMIT_MSG" >> "$LOG_FILE" 2>&1
    COMMIT_STATUS=$?

    if [ $COMMIT_STATUS -ne 0 ]; then
        log_message "ERROR: Git commit failed (status $COMMIT_STATUS)."
        send_notification "high" "Git Commit FAILED: $REPO_NAME" "The git commit command failed. Check log for details."
    else
        log_message "Git commit successful."
    fi
else
    log_message "No local changes to commit."
    if [ "$NOTIFY_ON_NO_CHANGES" = "yes" ]; then
        send_notification "low" "Git Backup: $REPO_NAME" "No local changes to commit."
    fi
    COMMIT_STATUS=0
fi

if [ $COMMIT_STATUS -eq 0 ]; then
    log_message "Attempting git push..."
    git push origin "$GIT_BRANCH" >> "$LOG_FILE" 2>&1
    PUSH_STATUS=$?

    if [ $PUSH_STATUS -ne 0 ]; then
        log_message "ERROR: Git push failed (status $PUSH_STATUS)."
        send_notification "urgent" "Git Push FAILED: $REPO_NAME" "The git push command failed. Check SSH keys or remote status."
    else
        log_message "Git push successful."
        
        if [ -n "$CHANGES" ] && [ "$NOTIFY_ON_SUCCESS" = "yes" ]; then
            # Format for ntfy: create a bulleted list
            CHANGES_FORMATTED_FOR_NTFY=$(echo "$CHANGES" | sed 's/^/* /')

            # Use printf to correctly interpret newlines and format the notification message
            printf -v SUCCESS_MESSAGE "Successfully pushed changes for **%s** from %s.\n\n### Files Changed:\n%s" \
                "$REPO_NAME" "$(hostname)" "$CHANGES_FORMATTED_FOR_NTFY"
            
            # Send the beautifully formatted notification
            send_notification "default" "Git Backup Successful: $REPO_NAME" "$SUCCESS_MESSAGE"
        fi
    fi
fi

log_message "--- Git Push for '$REPO_NAME' Completed ---"
