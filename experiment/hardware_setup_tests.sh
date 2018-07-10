#!/bin/bash

# Check that all of the directories were created

checkDirectoryExists() {
    DIRECTORY = $1
    if [ -d "$DIRECTORY" ]; then
	# pass the test
    else
    fi
}

