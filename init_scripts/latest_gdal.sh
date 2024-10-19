#!/bin/bash

# Remove existing GDAL and related packages
apt-get autoremove -y gdal-bin libgdal-dev libgeos-dev libproj-dev 

# Remove 'sf' package in R
Rscript -e "remove.packages('sf')"
Rscript -e "remove.packages('terra')"

# Update and install necessary packages
apt-get update && \
apt-get install -y software-properties-common && \
add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable && \
apt-get update && \
apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev libsqlite0-dev

# Install 'sf' package in R from source
Rscript -e "install.packages('sf', type = 'source', repos = 'https://cran.r-project.org/')"
Rscript -e "install.packages('terra', type = 'source', repos = 'https://cran.r-project.org/')"
