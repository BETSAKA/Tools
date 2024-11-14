#!/bin/bash

# Variables to be filled-in
PROJ_NAME=$1

# Creation of automatic variables
WORK_DIR=/home/onyxia/work/${PROJ_NAME}
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/BETSAKA/${PROJ_NAME}.git # As initial

# Git
# git config --global user.email "${GIT_USER_MAIL}"
# git config --global user.name "${GIT_USER_NAME}"
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users /home/onyxia

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

# Set RStudio user preferences to avoid saving/restoring workspace on session close
mkdir -p /home/onyxia/.config/rstudio
cat <<EOT > /home/onyxia/.config/rstudio/rstudio-prefs.json
{
    "save_workspace": "never",
    "load_workspace": false,
    "always_save_history": false,
    "remove_history_duplicates": true,
    "default_project_location": "$WORK_DIR"
}
EOT

chown -R onyxia:users /home/onyxia/
