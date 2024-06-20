#!/bin/bash

# Function to prompt user for input with a default value
prompt_with_default() {
    local PROMPT=$1
    local DEFAULT=$2
    read -p "$PROMPT [$DEFAULT]: " INPUT
    echo "${INPUT:-$DEFAULT}"
}

# Ensure necessary packages are installed
sudo apt update
sudo apt install -y sssd sssd-tools libnss-sss libpam-sss

# Configure SSSD to allow only certain groups
SSSD_CONF="/etc/sssd/sssd.conf"
GROUP_NAME=$(prompt_with_default "Please enter the AD group name that is allowed to SSH" "allowed_group_name")

if grep -q "access_provider = simple" $SSSD_CONF; then
    sudo sed -i "s/^simple_allow_groups = .*/simple_allow_groups = $GROUP_NAME/" $SSSD_CONF
else
    sudo bash -c "echo -e '\naccess_provider = simple\nsimple_allow_groups = $GROUP_NAME' >> $SSSD_CONF"
fi

# Set permissions for sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

# Restart SSSD to apply changes
sudo systemctl restart sssd

# Configure SSH to use PAM and restrict access to the specified group
SSH_CONF="/etc/ssh/sshd_config"

if grep -q "^UsePAM" $SSH_CONF; then
    sudo sed -i 's/^UsePAM.*/UsePAM yes/' $SSH_CONF
else
    echo "UsePAM yes" | sudo tee -a $SSH_CONF
fi

if grep -q "^AllowGroups" $SSH_CONF; then
    sudo sed -i "s/^AllowGroups.*/AllowGroups $GROUP_NAME/" $SSH_CONF
else
    echo "AllowGroups $GROUP_NAME" | sudo tee -a $SSH_CONF
fi

# Restart SSH to apply changes
sudo systemctl restart sshd

echo "SSH access has been restricted to members of the $GROUP_NAME group."
