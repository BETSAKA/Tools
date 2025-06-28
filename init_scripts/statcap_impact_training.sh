#!/bin/bash

# Validate that at least one argument is provided
if [ $# -lt 1 ]; then
    echo "[ERROR] No project name provided. Exiting."
    exit 1
fi

# Variables
PROJ_NAME=$1
WORK_DIR=/home/onyxia/work/${PROJ_NAME}
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/BETSAKA/${PROJ_NAME}.git
S3_PATH=s3/projet-betsaka/diffusion/${PROJ_NAME}

# Shift arguments to access additional packages (if any)
shift

# Function to log errors and exit
log_and_exit() {
    echo "[ERROR] $1"
    exit 1
}

# Step 1: Update and upgrade the package list
echo "[INFO] Updating package list..."
apt-get update && apt-get upgrade -y || log_and_exit "Failed to update packages."

# Step 2: Install necessary libraries if not present
echo "[INFO] Installing necessary libraries..."
apt-get install -y software-properties-common || log_and_exit "Failed to install software-properties-common."

# Step 3: Add the Ubuntugis PPA and update package list
echo "[INFO] Adding Ubuntugis PPA..."
add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable && apt-get update || log_and_exit "Failed to add Ubuntugis PPA."

# Step 4: Remove any existing GDAL, GEOS, and PROJ libraries to ensure a clean update
echo "[INFO] Removing existing GDAL, GEOS, and PROJ libraries..."
apt-get remove -y gdal-bin libgdal-dev libgeos-dev libproj-dev || true
apt-get autoremove -y || true

# Step 5: Install the latest versions of GDAL, GEOS, and PROJ libraries from the Ubuntugis PPA
echo "[INFO] Installing the latest versions of GDAL, GEOS, PROJ, and other libraries..."
apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev || log_and_exit "Failed to install geospatial libraries."

# Step 6: Remove and reinstall 'sf' and 'terra' packages in R
echo "[INFO] Removing and reinstalling 'sf' and 'terra' R packages..."
Rscript -e "remove.packages(c('sf', 'terra'))" || true

install_R_package() {
    local pkg=$1
    Rscript -e "tryCatch({install.packages('$pkg', type = 'source', repos = 'https://cran.r-project.org/')}, error=function(e){message('Retrying $pkg installation...'); Sys.sleep(10); install.packages('$pkg', type = 'source', repos = 'https://cran.r-project.org/')})" || log_and_exit "Failed to install R package $pkg."
}

install_R_package "sf"
install_R_package "terra"

# Step 7: Git clone the project repository
echo "[INFO] Cloning project repository..."
git clone $REPO_URL $WORK_DIR || log_and_exit "Failed to clone the repository."
chown -R onyxia:users $WORK_DIR

# Step 8: Copy files from S3
echo "[INFO] Copying files from S3..."
mc cp -r $S3_PATH /home/onyxia/work/ || log_and_exit "Failed to copy files from S3."
chown -R onyxia:users $WORK_DIR

# Step 9: Install additional R packages passed as arguments
echo "[INFO] Installing additional R packages..."
for pkg in "$@"; do
    install_R_package "$pkg"
done

# Step 10: Configure RStudio
echo "[INFO] Configuring RStudio..."
cat <<EOF >> /home/onyxia/work/.Rprofile
setHook('rstudio.sessionInit', function(newSession) {
    if (newSession && !identical(getwd(), "$WORK_DIR"))
    {
        message('On charge directement le bon projet :-) ')
        rstudioapi::openProject('$WORK_DIR')
        rstudioapi::applyTheme('Merbivore')
        rstudioapi::executeCommand('layoutConsoleOnRight')
    }
}, action = 'append')
EOF

# Step 11: Update RStudio keyboard shortcuts
echo "[INFO] Updating RStudio keyboard shortcuts..."
mkdir -p /home/onyxia/.config/rstudio/keybindings
cat <<EOT > /home/onyxia/.config/rstudio/keybindings/rstudio_bindings.json
{
    "pasteLastYank": ""
}
EOT

echo "[INFO] Initialization script completed successfully."
