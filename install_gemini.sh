#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "Checking for Node.js installation..."

if command_exists node; then
    echo "Node.js is already installed (Version: $(node -v))"
else
    echo "Node.js not found. Installing Node.js..."
    # Using NodeSource for a modern version (LTS)
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    
    NODE_MAJOR=20
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    
    sudo apt-get update
    sudo apt-get install nodejs -y
fi

echo "Checking for Gemini CLI..."

if command_exists gemini; then
    echo "Gemini CLI is already installed."
else
    echo "Installing Gemini CLI (@google/gemini-cli)..."
    # Using sudo for global install, though --location=global is preferred in some setups
    sudo npm install -g @google/gemini-cli
fi

if command_exists gemini; then
    echo "Installation successful!"
    gemini --version
else
    echo "Installation failed or 'gemini' is not in your PATH."
    echo "Try running: export PATH=\$PATH:\$(npm config get prefix)/bin"
fi
