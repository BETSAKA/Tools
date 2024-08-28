# Enable setting python environment from RStudio

R -e "install.packages(c('reticulate'))"
R -e "reticulate::use_python('/usr/bin/python3')"
