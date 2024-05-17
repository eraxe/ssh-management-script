#!/bin/bash

CONFIG_DIR="$HOME/.ssh"
CONFIG_FILE="$CONFIG_DIR/servers"
PASSWORD_FILE="$CONFIG_DIR/.server_credentials"
LOG_FILE="$HOME/ssh_management_script.log"

# Ensure required directories and files exist
mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "sshpass could not be found, please install it."
    exit 1
fi

# Function to add a new server
add_server() {
    read -p "Enter server name: " server_name
    read -p "Enter server IP: " server_ip
    read -p "Enter username: " username
    read -s -p "Enter server password: " server_password
    echo
    echo "$server_name:$server_ip:$username" >> "$CONFIG_FILE"
    echo "$server_name:$server_password" >> "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    echo "$(date) - Added server: $server_name" >> "$LOG_FILE"
}

# Function to list servers
list_servers() {
    echo "Configured servers:"
    awk -F: '{print $1}' "$CONFIG_FILE"
}

# Function to edit a server
edit_server() {
    local servers=()
    while IFS= read -r line; do
        server_name=$(echo "$line" | awk -F: '{print $1}')
        servers+=("$server_name" "$server_name")
    done < "$CONFIG_FILE"

    if [ ${#servers[@]} -eq 0 ]; then
        echo "No servers found!"
        return 1
    fi

    server_name=$(dialog --colors --menu "Select server to edit" 15 50 8 "${servers[@]}" 3>&1 1>&2 2>&3 3>&-)
    clear

    if [ -z "$server_name" ]; then
        echo "No server selected!"
        return 1
    fi

    server_ip=$(awk -F: -v name="$server_name" '$1 == name {print $2}' "$CONFIG_FILE")
    username=$(awk -F: -v name="$server_name" '$1 == name {print $3}' "$CONFIG_FILE")
    server_password=$(awk -F: -v name="$server_name" '$1 == name {print $2}' "$PASSWORD_FILE")

    if [ -z "$server_ip" ]; then
        echo "Server not found!"
        echo "$(date) - Error: Server $server_name not found" >> "$LOG_FILE"
        exit 1
    fi

    read -p "Enter new server IP (current: $server_ip): " new_server_ip
    read -p "Enter new username (current: $username): " new_username
    read -s -p "Enter new server password: " new_server_password
    echo

    sed -i "/^$server_name:/c\\$server_name:$new_server_ip:$new_username" "$CONFIG_FILE"
    sed -i "/^$server_name:/c\\$server_name:$new_server_password" "$PASSWORD_FILE"

    echo "$(date) - Edited server: $server_name" >> "$LOG_FILE"
}

# Function to delete a server
delete_server() {
    local servers=()
    while IFS= read -r line; do
        server_name=$(echo "$line" | awk -F: '{print $1}')
        servers+=("$server_name" "$server_name")
    done < "$CONFIG_FILE"

    if [ ${#servers[@]} -eq 0 ]; then
        echo "No servers found!"
        return 1
    fi

    server_name=$(dialog --colors --menu "Select server to delete" 15 50 8 "${servers[@]}" 3>&1 1>&2 2>&3 3>&-)
    clear

    if [ -z "$server_name" ]; then
        echo "No server selected!"
        return 1
    fi

    sed -i "/^$server_name:/d" "$CONFIG_FILE"
    sed -i "/^$server_name:/d" "$PASSWORD_FILE"

    echo "$(date) - Deleted server: $server_name" >> "$LOG_FILE"
}

# Function to connect to a server
connect_server() {
    local servers=()
    while IFS= read -r line; do
        server_name=$(echo "$line" | awk -F: '{print $1}')
        servers+=("$server_name" "$server_name")
    done < "$CONFIG_FILE"

    if [ ${#servers[@]} -eq 0 ]; then
        echo "No servers found!"
        return 1
    fi

    server_name=$(dialog --colors --menu "Select server to connect" 15 50 8 "${servers[@]}" 3>&1 1>&2 2>&3 3>&-)
    clear

    if [ -z "$server_name" ]; then
        echo "No server selected!"
        return 1
    fi

    server_ip=$(awk -F: -v name="$server_name" '$1 == name {print $2}' "$CONFIG_FILE")
    username=$(awk -F: -v name="$server_name" '$1 == name {print $3}' "$CONFIG_FILE")
    server_password=$(awk -F: -v name="$server_name" '$1 == name {print $2}' "$PASSWORD_FILE")

    if [ -z "$server_ip" ]; then
        echo "Server not found!"
        echo "$(date) - Error: Server $server_name not found" >> "$LOG_FILE"
        exit 1
    fi

    echo "$(date) - Connecting to server: $server_name ($server_ip)" >> "$LOG_FILE"
    sshpass -p "$server_password" ssh -o StrictHostKeyChecking=no "$username@$server_ip" || {
        echo "$(date) - Error: Permission denied for $server_name ($server_ip)" >> "$LOG_FILE"
        echo "Permission denied, please try again."
    }
}

# Function to generate SSH key
generate_ssh_key() {
    ssh-keygen -t rsa -b 2048
    echo "$(date) - Generated SSH key" >> "$LOG_FILE"
}

# Function to generate SSH key and copy it to server
generate_and_copy_id() {
    generate_ssh_key
    copy_current_key
}

# Function to copy current SSH key to server
copy_current_key() {
    local servers=()
    while IFS= read -r line; do
        server_name=$(echo "$line" | awk -F: '{print $1}')
        servers+=("$server_name" "$server_name")
    done < "$CONFIG_FILE"

    if [ ${#servers[@]} -eq 0 ]; then
        echo "No servers found!"
        return 1
    fi

    server_name=$(dialog --colors --menu "Select server to copy key to" 15 50 8 "${servers[@]}" 3>&1 1>&2 2>&3 3>&-)
    clear

    if [ -z "$server_name" ]; then
        echo "No server selected!"
        return 1
    fi

    server_ip=$(awk -F: -v name="$server_name" '$1 == name {print $2}' "$CONFIG_FILE")
    username=$(awk -F: -v name="$server_name" '$1 == name {print $3}' "$CONFIG_FILE")
    server_password=$(awk -F: -v name="$server_name" '$1 == name {print $2}' "$PASSWORD_FILE")

    if [ -z "$server_ip" ]; then
        echo "Server not found!"
        echo "$(date) - Error: Server $server_name not found" >> "$LOG_FILE"
        exit 1
    fi

    echo "$(date) - Copying SSH key to server: $server_name ($server_ip)" >> "$LOG_FILE"
    sshpass -p "$server_password" ssh-copy-id -o StrictHostKeyChecking=no "$username@$server_ip" || {
        echo "$(date) - Error: Permission denied for $server_name ($server_ip)" >> "$LOG_FILE"
        echo "Permission denied, please try again."
    }
}

# Display help
display_help() {
    echo "SSH Server Management Script"
    echo "Usage:"
    echo "  sshnow -c | --connect           Connect to a server"
    echo "  sshnow -a | --add               Add a new server"
    echo "  sshnow -e | --edit              Edit an existing server"
    echo "  sshnow -d | --delete            Delete a server"
    echo "  sshnow -l | --list-servers      List all configured servers"
    echo "  sshnow -g | --generate-key      Generate SSH key"
    echo "  sshnow -gcp | --generate-and-copy-id Generate SSH key and copy it to a server"
    echo "  sshnow -cp | --copy-current-key Copy current SSH key to a server"
    echo "  sshnow -h | --help              Display this help message"
}

# Main logic
if [ "$#" -eq 0 ]; then
    connect_server
else
    case "$1" in
        -c|--connect)
            connect_server
            ;;
        -a|--add)
            add_server
            ;;
        -e|--edit)
            edit_server
            ;;
        -d|--delete)
	    delete_server
            ;;
        -l|--list-servers)
            list_servers
            ;;
        -g|--generate-key)
            generate_ssh_key
            ;;
        -gcp|--generate-and-copy-id)
            generate_and_copy_id
            ;;
        -cp|--copy-current-key)
            copy_current_key
            ;;
        -h|--help|*)
            display_help
            ;;
    esac
fi
