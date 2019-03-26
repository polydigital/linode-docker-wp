#!/bin/bash

# Get the secrets 
while [[ -z "$SITENAME" ]]
do
  read -p "Enter a new site name for this server: " SITENAME
done

while [[ -z "$WPFQDN" ]]
do
  read -p "Enter a domain name (e.g. www.mysite.co.uk): " WPFQDN
done

while [[ -z "$CERTEMAIL" ]]
do
  read -p "Enter an email for certificate: " CERTEMAIL
done

while [[ -z "$MYSQLROOTPASSWORD" ]]
do
  read -s -p "Enter a password for root MySQL: " MYSQLROOTPASSWORD
done

while [[ -z "$MYSQLPASSWORD" ]]
do
  read -s -p "Enter a password for WP user MySQL: " MYSQLPASSWORD
done

MYSQLDBNAME=$SITENAME-mariadb
MYSQLUSER=wp-$SITENAME-dbuser
WPMEMORYCONF=$SITENAME-memorylimit.ini


# increase allowed memory limit for uploads on wordpress - this file is mounted from home dir
printf "file_uploads = On\nmemory_limit = 64M\nupload_max_filesize = 64M\npost_max_size = 64M\nmax_execution_time = 600" > ~/$WPMEMORYCONF

docker run --name $MYSQLDBNAME --net dockerwp \
	-v ~/$MYSQLDBNAME:/var/lib/mysql \
	-e MYSQL_ROOT_PASSWORD=$MYSQLROOTPASSWORD \
	-e MYSQL_DATABASE=$MYSQLDBNAME \
	-e MYSQL_USER=$MYSQLUSER \
	-e MYSQL_PASSWORD=$MYSQLPASSWORD \
	-d --restart always mariadb

docker run --name $SITENAME --net dockerwp \
	-v ~/$SITENAME:/var/www/html \
	-v ~/$WPMEMORYCONF:/usr/local/etc/php/conf.d/uploads.ini \
	-e WORDPRESS_DB_HOST=$MYSQLDBNAME:3306 \
	-e WORDPRESS_DB_NAME=$MYSQLDBNAME \
	-e WORDPRESS_DB_USER=$MYSQLUSER \
	-e WORDPRESS_DB_PASSWORD=$MYSQLPASSWORD \
	-e VIRTUAL_HOST=$WPFQDN \
	-e LETSENCRYPT_HOST=$WPFQDN \
	-e LETSENCRYPT_EMAIL=$CERTEMAIL \
	-d --restart always wordpress