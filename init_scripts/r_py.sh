# Enable setting python environment from RStudio

R -e "Sys.setenv(RETICULATE_PYTHON = '/usr/bin/python3')"
R -e "install.packages(c('reticulate'))"

