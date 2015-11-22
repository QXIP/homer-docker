#FROM phusion/baseimage:0.9.17
FROM debian:jessie
MAINTAINER L. Mangani <lorenzo.mangani@gmail.com>

# Default baseimage settings
ENV HOME /root
#RUN /etc/my_init.d/00_regen_ssh_host_keys.sh
#CMD ["/sbin/my_init"]

ENV DEBIAN_FRONTEND noninteractive

# Update and upgrade apt
RUN apt-get update -qq
RUN apt-get upgrade -y

RUN apt-get install --no-install-recommends --no-install-suggests -yqq ca-certificates apache2 php5 php5-cli php5-gd php-pear php5-dev php5-mysql php5-json php-services-json git mysql-server-5.5 mysql-client pwgen && rm -rf /var/lib/apt/lists/*

RUN a2enmod php5

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
RUN apt-get install -f -y kamailio rsyslog kamailio-outbound-modules kamailio-sctp-modules kamailio-tls-modules kamailio-websocket-modules kamailio-utils-modules kamailio-mysql-modules && rm -rf /var/lib/apt/lists/*

COPY data/kamailio.cfg /etc/kamailio/kamailio.cfg

# Install the cron service
RUN apt-get install cron -y

# Add our crontab file
RUN echo "30 3 * * * root /opt/homer_rotate > /dev/null 2>&1" > /crons.conf
RUN crontab /crons.conf

COPY run.sh /run.sh

# Add persistent MySQL volumes
VOLUME ["/etc/mysql", "/var/lib/mysql", "/var/www/html/store"]

EXPOSE 80

ENTRYPOINT ["/run.sh"]

