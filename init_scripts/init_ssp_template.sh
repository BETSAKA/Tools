# Variables to be filled-in
PROJ_NAME=my_project

# Creation of automatic variables
WORK_DIR=/home/onyxia/work/${PROJ_NAME}
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/BETSAKA/${PROJ_NAME}.git # As initial

# Git
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users $WORK_DIR

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
