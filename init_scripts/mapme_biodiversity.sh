!/bin/bash

# Variables to be filled-in
FULL_NAME="$1" # eg. "BETSAKA/training"
PROJ_NAME="${FULL_NAME##*/}" # then "training"
# Creation of automatic variables
WORK_DIR=/home/onyxia/work/${PROJ_NAME}
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git # As initial

# Git
# git config --global user.email "${GIT_USER_MAIL}"
# git config --global user.name "${GIT_USER_NAME}"
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users $WORK_DIR

# Copy files from s3
mc cp -r s3/projet-betsaka/diffusion/${PROJ_NAME}/data $WORK_DIR #Ne prendre que data
chown -R onyxia:users $WORK_DIR # make sure users have rights to edit

# Update and upgrade the package list
echo "[INFO] Updating package list..."
apt-get update && apt-get upgrade -y || log_and_exit "Failed to update packages."

# Install necessary libraries if not present
echo "[INFO] Installing necessary libraries..."
apt-get install -y software-properties-common || log_and_exit "Failed to install software-properties-common."

# Add the Ubuntugis PPA and update package list
echo "[INFO] Adding Ubuntugis PPA..."
add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable && apt-get update || log_and_exit "Failed to add Ubuntugis PPA."

# Install GDAL, GEOS, and PROJ libraries
echo "[INFO] Installing GDAL, GEOS, PROJ, and other libraries..."
apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev || log_and_exit "Failed to install geospatial libraries."

# Install additional packages passed as arguments 
if [ $# -gt 0 ]; then
    for pkg in "$@"
    do
        Rscript -e "install.packages('$pkg')"
    done
fi

# Set the UI 
# launch RStudio in the right project
# Copied from InseeLab UtilitR
    echo \
    "
    setHook('rstudio.sessionInit', function(newSession) {
        if (newSession && !identical(getwd(), \"'$WORK_DIR'\"))
        {
            message('On charge directement le bon projet :-) ')
            rstudioapi::openProject('$WORK_DIR')
            # For a slick dark theme
            rstudioapi::applyTheme('Merbivore')
            # Console where it should be
            rstudioapi::executeCommand('layoutConsoleOnRight')
        }
    }, action = 'append')
    " >> /home/onyxia/work/.Rprofile

# Update RStudio keyboard shortcuts configuration
mkdir -p /home/onyxia/.config/rstudio/keybindings
cat <<EOT > /home/onyxia/.config/rstudio/keybindings/rstudio_bindings.json
{
    "pasteLastYank": ""
}
EOT
