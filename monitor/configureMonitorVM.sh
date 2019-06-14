#!/bin/sh

#Updating apt-get
apt-get -y update
#uninstall pip first to avoid conflict with system pip while upgrading pip
python3 -m pip uninstall pip
apt install -y --reinstall python3-pip
pip3 install --user --upgrade pip==19.1.1
pip3 install pyhdb
