#!/bin/bash

docker network create dockerwp

docker run --name nginx-proxy --net dockerwp -p 80:80 -p 443:443 \
	-v ~/certs:/etc/nginx/certs \
	-v ~/nginx_conf/custom_settings.conf:/etc/nginx/conf.d/custom_settings.conf \
	-v /etc/nginx/vhost.d \
	-v /usr/share/nginx/html \
	-v /var/run/docker.sock:/tmp/docker.sock:ro \
	--label com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy -d \
	--restart always jwilder/nginx-proxy

docker run --name letsencrypt-nginx-proxy-companion --net dockerwp \
	-v ~/certs:/etc/nginx/certs:rw \
	-v /var/run/docker.sock:/var/run/docker.sock:ro \
	--volumes-from nginx-proxy -d \
	--restart always jrcs/letsencrypt-nginx-proxy-companion

