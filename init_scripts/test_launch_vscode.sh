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

# Set startup folder
VSCODE_ARGS_DIR="${HOME}/.local/share/code-server"
mkdir -p "$VSCODE_ARGS_DIR"

cat > "${VSCODE_ARGS_DIR}/argv.json" <<EOF
{
  "openInFolder": "${WORK_DIR}"
}
EOF
