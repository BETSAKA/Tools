#!/bin/bash

# This script is exectued at onyxia pod startup to:
# - clone a github repository specified as first Onyxia init argument "user_or_org/repo"
# - update GDAL and linux spatial libraries: required for latest mapme.biodiversity functionalities
# - install the packages listed as onyxia init argument after the repo name (space separated)
# - copy on the pod local storage the content of the s3 folder named "projet-betsaka/user/data"


# Parses the argument from the onyxia init 
FULL_NAME="$1" # eg. "BETSAKA/training"
PROJ_NAME="${FULL_NAME##*/}" # then "training"
# Creation of automatic variables
WORK_DIR=/home/onyxia/work/${PROJ_NAME} # then "/home/onyxia/work/training"
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/${FULL_NAME}.git # then "github.com/BETSAKA/training"

# Clone git repo
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users $WORK_DIR

# Update linux spatial dependencies
sudo apt-get autoremove -y gdal-bin libgdal-dev libgeos-dev libproj-dev 
Rscript -e "remove.packages('sf')"
Rscript -e "remove.packages('terra')"
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
apt-get update
apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev
Rscript -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"
Rscript -e "install.packages('terra', type = 'source', repos = 'https://cran.r-project.org/')"

# Install additional packages passed as arguments 
if [ $# -gt 0 ]; then
    for pkg in "$@"
    do
        Rscript -e "install.packages('$pkg')"
    done
fi

# Copy files from s3
mc cp -r s3/projet-betsaka/PA_impacts_fires/data /home/onyxia/work/${PROJ_NAME}
mc cp -r s3/projet-betsaka/PA_impacts_fires/mapme /home/onyxia/work/${PROJ_NAME}
chown -R onyxia:users $WORK_DIR # make sure users have rights to edit

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
