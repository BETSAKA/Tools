#!/bin/sh

# Installs the latest GDAL version
sudo apt-get autoremove gdal-bin libgdal-dev libgeos-dev libproj-dev 
Rscript -e "remove.packages('sf')"
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable
sudo apt-get update
sudo apt-get install libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev
Rscript -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"
