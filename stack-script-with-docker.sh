#!/bin/bash
#<UDF name="USERNAME" label="Username">
#<UDF name="USERPASSWORD" label="Password">
#<UDF name="USERPUBKEY" label="User SSH public key" default="">
#<UDF name="HOSTNAME" label="Hostname" default="">
#<UDF name="FQDN" label="Fully qualified domain name" default="">
#<UDF name="TZ" label="Time Zone" default="Europe/London" example="Example: Europe/London (see: http://bit.ly/TZlisting)" />

# Last update: March 26 2019
# Author: Tom Broughton
# try to get some output into a log 
exec >/var/log/stackscript.log 2>&1
#include some linode helpers
source <ssinclude StackScriptID="1">
#get the ip address that has been assigned
IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

# set up host using linode helpers
system_set_hostname "$HOSTNAME"
system_add_host_entry "$IPADDR" "$HOSTNAME"
system_add_host_entry "$IPADDR" "$FQDN"

# Set timezone
if [ -n $TZ ]
then
	timedatectl set-timezone $TZ
fi


### Install Docker ###

# remove any old docker packagaes
apt-get remove docker docker-engine docker.io containerd runc

# install packages to allow apt over https
apt-get update -q -y
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -q -y

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

##todo: check gpg key fingerprint and error if not matched with official docker one.

# Add docker repository
add-apt-repository \
	"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
	&& apt-get update -q -y

# Install Docker
apt-get install docker-ce docker-ce-cli containerd.io -q -y

# start Docker daemon on boot
systemctl enable docker

# Install Docker Compose
curl -L https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-composechmod +x /usr/local/bin/docker-compose

### add non-root user and add to sudo

# Set up ssh user account
adduser $USERNAME --disabled-password --gecos ""
echo "$USERNAME:$USERPASSWORD" | chpasswd
adduser $USERNAME sudo

# add user to docker so sudo isnt' required all the time
groupadd docker && usermod -aG docker $USERNAME

# If user provided an SSH public key, whitelist it, disable SSH password authentication, and allow passwordless sudo
if [ ! -z "$USERPUBKEY" ]; then
  mkdir -p /home/$USERNAME/.ssh
  echo "$USERPUBKEY" >> /home/$USERNAME/.ssh/authorized_keys
  chown -R "$USERNAME":"$USERNAME" /home/$USERNAME/.ssh
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

### some security

# fail2ban
apt-get install fail2ban -q -y

#add ssh to the fail2ban jail
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
awk '/[sshd]/ { print; print "enabled=true"; next }1' /etc/fail2ban/jail.local

# Set up firewall
apt-get install ufw -q -y
ufw allow ssh
ufw allow 22
ufw allow 80
ufw allow 443
ufw default allow outgoing
ufw default deny incoming
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
ufw enable

# use linode helper to disable ssh root access
ssh_disable_root
service sshd restart

