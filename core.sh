#!/bin/bash

# Improved error handling and logging
log_file="core.log"

# Function to log messages
log() {
    echo "[$(date -u +'%Y-%m-%d %H:%M:%S')] $1" >> "$log_file"
}

# Set a timeout for commands
execute_with_timeout() {
    local timeout=$1
    shift
    command="$@"
    ( 
        sleep "$timeout" && kill -HUP $$ & 
        eval "$command"
    ) & 
    wait $!
}

# Validate input arguments
if [ "$#" -lt 1 ]; then
    log "Error: No arguments provided."
    exit 1
fi

# Example of improved regex pattern for validation
input="${1}"
if ! [[ "$input" =~ ^[a-zA-Z0-9_]+$ ]]; then
    log "Error: Invalid input '$input'. Only alphanumeric and underscores are allowed."
    exit 1
fi

# Main execution block
log "Starting execution with input: $input"

# Use execute_with_timeout to manage long-running commands with a timeout of 10 seconds
execute_with_timeout 10 some_long_running_command "$input"

# Finish logging
log "Execution completed successfully for input: $input"