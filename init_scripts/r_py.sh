# Enable setting python environment from RStudio
export RETICULATE_PYTHON="/usr/bin/python3"
R -e "install.packages(c('reticulate'))"
R -e "Sys.setenv(RETICULATE_PYTHON = '/usr/local/bin/python3')"
