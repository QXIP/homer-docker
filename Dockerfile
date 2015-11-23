#FROM phusion/baseimage:0.9.17
FROM debian:jessie
MAINTAINER L. Mangani <lorenzo.mangani@gmail.com>

# Default baseimage settings
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

RUN groupadd -r mysql && useradd -r -g mysql mysql

# Update and upgrade apt
RUN apt-get update -qq
RUN apt-get upgrade -y

RUN apt-get install --no-install-recommends --no-install-suggests -yqq ca-certificates apache2 php5 php5-cli php5-gd php-pear php5-dev php5-mysql php5-json php-services-json git pwgen && rm -rf /var/lib/apt/lists/*

RUN a2enmod php5

# MySQL

RUN mkdir /docker-entrypoint-initdb.d

# FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
# File::Basename
# File::Copy
# Sys::Hostname
# Data::Dumper
RUN apt-get update && apt-get install -y perl --no-install-recommends && rm -rf /var/lib/apt/lists/*

# gpg: key 5072E1F5: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5

ENV MYSQL_MAJOR 5.6
ENV MYSQL_VERSION 5.6.27

RUN echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list

RUN apt-get update && apt-get install -y mysql-server-5.6 libmysqlclient18 && rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
	&& echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
	&& mv /tmp/my.cnf /etc/mysql/my.cnf


RUN mkdir -p /var/lib/mysql/
RUN chmod -R 755 /var/lib/mysql/

WORKDIR /

RUN git clone --depth 1 https://github.com/sipcapture/homer-api.git /homer-api
RUN git clone --depth 1 https://github.com/sipcapture/homer-ui.git /homer-ui

RUN chmod +x /homer-api/scripts/*
RUN cp /homer-api/scripts/* /opt/

RUN cp -R /homer-ui/* /var/www/html/
RUN cp -R /homer-api/api /var/www/html/
RUN chmod g+w /var/www/html/store/dashboard

COPY data/configuration.php /var/www/html/api/configuration.php
COPY data/preferences.php /var/www/html/api/preferences.php
COPY data/vhost.conf /etc/httpd/conf.d/000-homer.conf

# Kamailio
RUN apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xfb40d3e6508ea4c8
RUN echo "deb http://deb.kamailio.org/kamailio jessie main" >> etc/apt/sources.list
RUN echo "deb-src http://deb.kamailio.org/kamailio jessie main" >> etc/apt/sources.list
#RUN apt-get update -qq && apt-get install --no-install-recommends --no-install-suggests -yqq kamailio rsyslog inotify-tools kamailio-outbound-modules kamailio-sctp-modules kamailio-tls-modules kamailio-websocket-modules kamailio-utils-modules kamailio-mysql-modules && rm -rf /var/lib/apt/lists/*

RUN apt-get update 
RUN apt-get install -f -y kamailio rsyslog kamailio-outbound-modules kamailio-sctp-modules kamailio-tls-modules kamailio-websocket-modules kamailio-utils-modules kamailio-mysql-modules kamailio-extra-modules && rm -rf /var/lib/apt/lists/*

COPY data/kamailio.cfg /etc/kamailio/kamailio.cfg
RUN chmod 775 /etc/kamailio/kamailio.cfg

RUN ln -s /usr/lib64 /usr/lib/x86_64-linux-gnu/

# Install the cron service
RUN apt-get install cron -y

# Add our crontab file
RUN echo "30 3 * * * root /opt/homer_rotate > /dev/null 2>&1" > /crons.conf
RUN crontab /crons.conf

COPY run.sh /run.sh
RUN chmod a+rx /run.sh

# Add persistent MySQL volumes
VOLUME ["/etc/mysql", "/var/lib/mysql", "/var/www/html/store"]

EXPOSE 80
EXPOSE 3306

ENTRYPOINT ["/run.sh"]

