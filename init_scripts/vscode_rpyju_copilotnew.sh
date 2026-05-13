#!/bin/bash
# Enable bash debugging to print every command and its result
set -x
# Redirect all output from this script to an easy-to-find log file
exec > >(tee -i /home/onyxia/work/init_script_debug.log) 2>&1

echo "--- STARTING INIT SCRIPT ---"

# Variables to be filled-in from arguments
FULL_NAME="$1" # eg. "BETSAKA/PA-impact-on-deforestation"
PROJ_NAME="${FULL_NAME##*/}" # extracts exactly "PA-impact-on-deforestation"
FOLD_NAME="$2" # eg. "PA-impact-deforestation" (used for mapme/data paths)
shift 2

WORK_DIR=/home/onyxia/work/${PROJ_NAME}
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git 

# 1. Clone Git
echo "Cloning repository..."
git clone $REPO_URL $WORK_DIR

# 2. Pull local fast-access storage (Data and TIFFs)
echo "Copying data from S3..."
mc cp -r s3/projet-betsaka/${FOLD_NAME}/data $WORK_DIR 
mc cp -r s3/projet-betsaka/${FOLD_NAME}/mapme $WORK_DIR

chown -R onyxia:users $WORK_DIR 

# 3. Ensure R Packages for the Cluster (mirai, arrow, dependencies)
echo "Installing base and requested R packages..."
BASE_PKGS="'sf', 'terra', 'dplyr', 'purrr', 'readr', 'tictoc', 'mirai', 'arrow'"

if [ $# -gt 0 ]; then
    # Convert bash arguments list to an R character vector string
    EXTRA_PKGS=$(printf "'%s'," "$@")
    EXTRA_PKGS="${EXTRA_PKGS%,}"
    ALL_PKGS="c(${BASE_PKGS}, ${EXTRA_PKGS})"
else
    ALL_PKGS="c(${BASE_PKGS})"
fi

# Run the R package installation
Rscript -e "install.packages(${ALL_PKGS}, Ncpus = parallel::detectCores())"

# 4. Ensure Python packages for CLIMADA
echo "Installing Python packages..."
pip install climada jupyterlab > /home/onyxia/work/pip_install.log 2>&1

# 5. Install GitHub Copilot Extension (Debuggable Version)
echo "--- DEBUG: Starting Copilot Installation ---"
COPILOT_VSIX="/tmp/copilot.vsix"
COPILOT_CHAT_VSIX="/tmp/copilot-chat.vsix"

echo "Downloading official VSIX files..."
wget -q --show-progress "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot/latest/vspackage" -O ${COPILOT_VSIX} || echo "ERROR: Copilot wget failed!"
wget -q --show-progress "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/copilot-chat/latest/vspackage" -O ${COPILOT_CHAT_VSIX} || echo "ERROR: Copilot Chat wget failed!"

echo "Checking downloaded file sizes (should be several MBs):"
ls -lh /tmp/*.vsix

echo "Determining VS Code executable..."
if command -v code-server &> /dev/null; then
    EDITOR_CMD="code-server"
elif command -v openvscode-server &> /dev/null; then
    EDITOR_CMD="openvscode-server"
elif command -v code &> /dev/null; then
    EDITOR_CMD="code"
else
    echo "ERROR: No VS Code executable found in PATH."
    EDITOR_CMD=""
fi

if [ -n "$EDITOR_CMD" ]; then
    echo "Using executable: $EDITOR_CMD"
    echo "Installing extensions..."
    $EDITOR_CMD --install-extension ${COPILOT_VSIX} --force
    $EDITOR_CMD --install-extension ${COPILOT_CHAT_VSIX} --force
    
    echo "Installed extensions list:"
    $EDITOR_CMD --list-extensions
fi

rm -f ${COPILOT_VSIX} ${COPILOT_CHAT_VSIX}

echo "--- DEBUG: Copilot Installation Script Finished ---"
set +x
