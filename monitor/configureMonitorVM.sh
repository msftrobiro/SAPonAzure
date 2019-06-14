#!/bin/sh

#Updating apt-get
apt-get -y update
apt-get install -y python3-pip
python -m pip install -U pip
pip3 install pyhdb
