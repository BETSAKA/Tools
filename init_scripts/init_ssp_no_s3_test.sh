#!/bin/bash



# Creation of automatic variables
WORK_DIR=/home/onyxia/work/mapme_impact_training
REPO_URL=https://${GIT_PERSONAL_ACCESS_TOKEN}@github.com/BETSAKA/mapme_impact_training.git # As initial

# Git
# git config --global user.email "${GIT_USER_MAIL}"
# git config --global user.name "${GIT_USER_NAME}"
git clone $REPO_URL $WORK_DIR
chown -R onyxia:users /home/onyxia

# Install additional packages passed as arguments 

        Rscript -e "install.packages('gt')"
