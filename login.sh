#!/bin/bash

# Improved login.sh script for enhanced security

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to validate input
validate_input() {
    if [[ -z "$1" ]]; then
        handle_error "Input cannot be empty."
    fi
}

# Get user input and validate
read -p "Enter username: " username
validate_input "${username}"
read -sp "Enter password: " password
validate_input "${password}"

# Check for duplicates in user input
if [[ "${username}" == "admin" ]]; then
    handle_error "This username is already taken. Please choose another one."
fi

# Simulating secure authentication (replace with actual logic)
echo "Authenticating user..."

# Simulate success
if [ $? -eq 0 ]; then
    echo "User authenticated successfully!"
else
    handle_error "Authentication failed."
}