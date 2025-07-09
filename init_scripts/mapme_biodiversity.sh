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

# Update spatial dependencies
sudo apt-get autoremove -y gdal-bin libgdal-dev libgeos-dev libproj-dev 
Rscript -e "remove.packages('sf')"
Rscript -e "remove.packages('terra')"
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
sudo apt-get update
sudo apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev
Rscript -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"
Rscript -e "install.packages('terra', type = 'source', repos = 'https://cran.r-project.org/')"

# Install 'sf' package in R from source
Rscript -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"
Rscript -e "install.packages('terra', type = 'source', repos = 'https://cran.r-project.org/')"

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
