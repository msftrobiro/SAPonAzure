#!/bin/sh

#Updating apt-get
apt-get -y update
apt-get install -y python3-pip
pip3 install --user --upgrade pip==19.1.1
pip3 install pyhdb
