#!/bin/bash


# Parses the argument from the onyxia init 
FULL_NAME="$1" # eg. "BETSAKA/training"
PROJ_NAME="${FULL_NAME##*/}" # then "training"
# Creation of automatic variables
WORK_DIR=/home/onyxia/work/${PROJ_NAME} # then "/home/onyxia/work/training"
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git # then "github.com/BETSAKA/training"

# Clone git repo
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users $WORK_DIR

# Copy files from s3
mc cp -r s3/projet-betsaka/${PROJ_NAME} /home/onyxia/work/
chown -R onyxia:users $WORK_DIR # make sure users have rights to edit

# Set vscode settings
# Path to the VSCode settings.json file
# Path to the VSCode settings.json file
SETTINGS_FILE="${HOME}/.local/share/code-server/User/settings.json"

# Check if the settings.json file exists, otherwise create a new one
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "No existing settings.json found. Creating a new one."
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo "{}" > "$SETTINGS_FILE"  # Initialize with an empty JSON object
fi


code-server --user-data-dir ~/.local/share/code-server --extensions-dir ~/.local/share/code-server/extensions "$WORK_DIR"
