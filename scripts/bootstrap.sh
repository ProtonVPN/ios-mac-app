#!/bin/sh

secrets_folder="protonvpn-secrets"

# Check if brew is installed
echo "Looking for Brew..👀"
which -s brew
if [[ $? != 0 ]] ; then
    # Install Homebrew
    echo "Brew not found... 😪"
    echo "Installing Brew 🍻!"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check if go is installed
echo "Check if go package is installed"
if brew list go &>/dev/null; then
    echo "go package found ✅"
else
    echo "go not found, installing package.. 👷🏼‍♂️"
    brew install go && echo "Go installed successfully 🤙🏻"
fi

# Obfuscated constants
if credentials.sh checkout &>/dev/null; then
    echo "Credentials repo not found.."
    echo "Clone to ../$secrets_folder and link credentials 🕵🏻.."
    if ./scripts/credentials.sh setup -p ../$secrets_folder -r git@gitlab.protontech.ch:ProtonVPN/apple/secrets.git; then
        exit 1
    fi
    # Updating .gitconfig
    echo "Updating .gitconfig file.."
    if grep -q credsdir = ../.gitconfig; then
        Some Actions # SomeString was found
    fi    
else
    echo "Credentials repo found ✅"
fi

# Updating .gitconfig
echo "Updating .gitconfig file.."
if ! grep -q "credsdir =" ./.gitconfig; then
    destinationPath="$(dirname "$PWD")"
    printf "\n[vpn]\n    credsdir = $destinationPath/$secrets_folder" >> ./.gitconfig
    echo "gitconfig updated successfully 🎊" 
else
    echo "gitconfig: secrets path found 👍🏻" 
fi

# Link submodule to the project
echo "Linking and updating submodules.."
git submodule update --init

# Open project
echo "Opening ProtonVPN Xcode project 👾"
xed .
