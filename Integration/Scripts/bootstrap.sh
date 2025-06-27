#!/bin/bash

scripts_folder="${PWD}/Integration/Scripts/"
secrets_folder="$(dirname $PWD)/protonvpn-secrets"

if [[ ! -d "ProtonVPN.xcworkspace" ]]; then
    echo "This script must be launched from the root folder of the project (./Integrations/Scripts/bootstrap.sh)"
    exit -1
fi


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
if ! ${scripts_folder}credentials.sh checkout &> /dev/null; then
    echo "Credentials repo not found.."
    echo -n "Clone to $secrets_folder and link credentials 🕵🏻.. "
    if ${scripts_folder}credentials.sh setup -p $secrets_folder -r git@gitlab.protontech.ch:ProtonVPN/apple/secrets.git; then
        exit 1
    fi
    echo "done."
else
    echo "Credentials repo found ✅"
fi

# Updating .gitconfig
echo "Updating .gitconfig file.."
if ! grep -q "credsdir =" ./.gitconfig &> /dev/null; then
    printf "\n[vpn]\n    credsdir = $secrets_folder\n" >> ./.gitconfig
    echo "gitconfig updated successfully 🎊"
else
    if ! grep -q $secrets_folder ./.gitconfig; then
        echo "Something is wrong with the credentials config path. Sorry you have to fix manually"
        exit -1
    fi
    echo "gitconfig: secrets path found 👍🏻"
fi

# Link submodule to the project
echo "Linking and updating submodules.."
git submodule update --init

# Setup pre-commit hook
echo "Setting up pre-commit git hook"
echo "Copying pre-commit to .git/hooks"
cp git-hooks/pre-commit .git/hooks
echo "Granting pre-commit executable rights"
chmod +x .git/hooks/pre-commit
echo "Granting pre-commit script executable rights"
chmod +x Integration/scripts/swift-format-it.sh

# Open project
echo "Opening ProtonVPN Xcode project 👾"
xed .
