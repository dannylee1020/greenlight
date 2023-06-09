#!/bin/bash
set -eu
# ====================================== #
# VARIABLES
# ====================================== #

TIMEZONE=America/Los_Angeles

USERNAME=greenlight

read -p "Enter  password for greenlight DB user: " DB_PASSWORD

export LC_ALL=en_US.UTF-8

# ====================================== #
# SCRIPT LOGIC
# ====================================== #
add-apt-repository --yes universe
apt update

timedatectl set-timezone ${TIMEZONE}
apt --yes install locales-all

useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

passwd --delete "${USERNAME}"

chage --lastday 0 "${USERNAME}"


# Copy the SSH keys from the root user to the new user
rsync --archive --chown=${USERNAME}:${USERNAME} /root/.ssh /home/${USERNAME}

# Configure the firewall to allow SSH, HTTP and HTTPS traffic.
ufw allow 22
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Install fail2ban.
apt --yes install fail2ban

# Install the migrate CLI tool.
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.14.1/migrate.linux-amd64.tar.gz | tar xvz
mv migrate.linux-amd64 /usr/local/bin/migrate

# Install Postgres
apt --yes install postgresql

# Set up the greenlight DB and create a user account with the password entered earlier.
sudo -i -u postgres psql -c "CREATE DATABASE greenlight"
sudo -i -u postgres psql -d greenlight -c "CREATE EXTENSION IF NOT EXISTS citext"
sudo -i -u postgres psql -d greenlight -c "CREATE ROLE greenlight WITH LOGIN PASSWORD '${DB_PASSWORD}'"

# Add a DSN for connecting to the greenlight database
# with environment variables in the /etc/environment file
echo "GREENLIGHT_DB_DSN='postgres://greenlight:${DB_PASSWORD}@localhost/greenlight'" >> /etc/environment


# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
# give permission to read and run apt
chmod 664 /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo apt update
sudo apt install caddy

# upgrade all packages
apt -yes -o Dpkg::Options::="--force-confnew" upgrade

echo "Script complete! Rebooting ..."
reboot


