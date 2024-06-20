#!/bin/bash

# Update the package list
sudo apt update

# Install necessary packages
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user

# Configure Kerberos
echo "Please enter your Kerberos realm (e.g., EXAMPLE.COM):"
read KRB_REALM
echo "Please enter your KDC server (e.g., kdc.example.com):"
read KDC_SERVER
echo "Please enter your admin server (e.g., admin.example.com):"
read ADMIN_SERVER

cat <<EOL | sudo tee /etc/krb5.conf
[libdefaults]
    default_realm = $KRB_REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    $KRB_REALM = {
        kdc = $KDC_SERVER
        admin_server = $ADMIN_SERVER
    }

[domain_realm]
    .example.com = $KRB_REALM
    example.com = $KRB_REALM
EOL

# Join the server to the Active Directory domain
echo "Please enter the domain (e.g., example.com):"
read DOMAIN
echo "Please enter the domain admin user:"
read ADMIN_USER
echo "Please enter the domain admin password:"
read -s ADMIN_PASSWORD

echo $ADMIN_PASSWORD | sudo realm join -U $ADMIN_USER $DOMAIN

# Enable and start necessary services
sudo systemctl enable sssd
sudo systemctl start sssd

# Configure SSSD
SSSD_CONF="/etc/sssd/sssd.conf"
sudo bash -c "cat > $SSSD_CONF << EOL
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = ${DOMAIN^^}
realmd_tags = manages-system joined-with-samba
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u@%d
access_provider = ad
EOL"

# Set permissions for sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

# Restart SSSD to apply changes
sudo systemctl restart sssd

# Configure PAM to create home directories on login
sudo pam-auth-update --enable mkhomedir

# Verify domain join
realm list

echo "Setup is complete. The server is now joined to the domain $DOMAIN and users can log in with their AD credentials."
