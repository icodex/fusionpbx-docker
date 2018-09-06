FROM debian:latest
MAINTAINER Darren Williams <support@directvoip.co.uk>

# Install Required Dependencies
RUN apt-get update \
    && apt-get -y install apt-utils apt-transport-https wget lsb-release ca-certificates gnupg \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && sh -c 'echo "deb https://packages.sury.org/php/ jessie main" > /etc/apt/sources.list.d/php.list'

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --force-yes ca-certificates git vim dbus haveged ssl-cert ghostscript libtiff5-dev libtiff-tools nginx curl supervisor net-tools qrencode \
    php7.1 php7.1-cli php7.1-common php7.1-curl php7.1-fpm php7.1-gd php7.1-imap php7.1-json php7.1-mcrypt php7.1-odbc php7.1-opcache php7.1-pgsql php7.1-readline php7.1-sqlite3 php7.1-xml

RUN git clone https://github.com/fusionpbx/fusionpbx.git /var/www/fusionpbx

RUN chown -R www-data:www-data /var/www/fusionpbx \
    && chmod -R 755 /var/www/fusionpbx/secure

RUN sed 's#resources/classes/messages.php#resources/classes/message.php#g' -i /var/www/fusionpbx/core/install/install.php

RUN wget https://raw.githubusercontent.com/fusionpbx/fusionpbx-install.sh/master/debian/resources/nginx/fusionpbx -O /etc/nginx/sites-available/fusionpbx && ln -s /etc/nginx/sites-available/fusionpbx /etc/nginx/sites-enabled/fusionpbx \
    && sed -i /etc/nginx/sites-available/fusionpbx -e 's#unix:.*;#unix:/run/php7.1-fpm.sock;#g' \
    && ln -s /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/private/nginx.key \
    && ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/certs/nginx.crt \
    && rm /etc/nginx/sites-enabled/default

RUN sed 's#post_max_size = .*#post_max_size = 80M#g' -i /etc/php/7.1/fpm/php.ini \
    && sed 's#upload_max_filesize = .*#upload_max_filesize = 80M#g' -i /etc/php/7.1/fpm/php.ini \
    && sed 's#pid = .*#pid = /run/php7.1-fpm.pid#g' -i /etc/php/7.1/fpm/php-fpm.conf \
    && sed 's#/run/php#/run#g' -i /etc/php/7.1/fpm/pool.d/www.conf

RUN echo "deb http://files.freeswitch.org/repo/deb/freeswitch-1.6/ jessie main" > /etc/apt/sources.list.d/freeswitch.list \
    && wget -O - https://files.freeswitch.org/repo/deb/debian/freeswitch_archive_g0.pub | apt-key add - \
    && apt-get update \
    && apt-get upgrade -y

RUN apt-get install -y --force-yes memcached haveged libyuv-dev flac gdb ntp freeswitch-meta-all freeswitch-mod-skypopen-dbg freeswitch-mod-sms-dbg freeswitch-mod-sofia-dbg

RUN mkdir -p /usr/share/freeswitch/sounds/music/default \
    && /bin/cp -a /usr/share/freeswitch/sounds/music/*000 /usr/share/freeswitch/sounds/music/default/

RUN usermod -a -G freeswitch www-data \
    && usermod -a -G www-data freeswitch \
    && chown -R freeswitch:freeswitch /var/lib/freeswitch \
    && chmod -R ug+rw /var/lib/freeswitch \
    && find /var/lib/freeswitch -type d -exec chmod 2770 {} \; \
    && mkdir /usr/share/freeswitch/scripts \
    && chown -R freeswitch:freeswitch /usr/share/freeswitch \
    && chmod -R ug+rw /usr/share/freeswitch \
    && find /usr/share/freeswitch -type d -exec chmod 2770 {} \; \
    && chown -R freeswitch:freeswitch /etc/freeswitch \
    && chmod -R ug+rw /etc/freeswitch \
    && find /etc/freeswitch -type d -exec chmod 2770 {} \; \
    && chown -R freeswitch:freeswitch /var/log/freeswitch \
    && chmod -R ug+rw /var/log/freeswitch \
    && find /var/log/freeswitch -type d -exec chmod 2770 {} \;

ENV PSQL_PASSWORD="psqlpass"
RUN apt-get install -y --force-yes sudo postgresql \
    && apt-get clean

RUN service postgresql start \
    && sleep 10 \
    && echo "psql -c \"CREATE DATABASE fusionpbx\";" | su - postgres \
    && echo "psql -c \"CREATE DATABASE freeswitch\";" | su - postgres \
    && echo "psql -c \"CREATE ROLE fusionpbx WITH SUPERUSER LOGIN PASSWORD '$PSQL_PASSWORD'\";" | su - postgres \
    && echo "psql -c \"CREATE ROLE freeswitch WITH SUPERUSER LOGIN PASSWORD '$PSQL_PASSWORD'\";" | su - postgres \
    && echo "psql -c \"GRANT ALL PRIVILEGES ON DATABASE fusionpbx to fusionpbx\";"  | su - postgres \
    && echo "psql -c \"GRANT ALL PRIVILEGES ON DATABASE freeswitch to fusionpbx\";" | su - postgres \
    && echo "psql -c \"GRANT ALL PRIVILEGES ON DATABASE freeswitch to freeswitch\";" | su - postgres 

USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-freeswitch.sh /usr/bin/start-freeswitch.sh
COPY event_socket.conf.xml /etc/freeswitch/autoload_configs/event_socket.conf.xml
EXPOSE 80/tcp 443/tcp 1719/udp 1720/tcp 3478/udp 3479/udp 5002/tcp 5003/udp 5060/tcp 5060/udp 5070/tcp 5070/udp 5080/tcp 5080/udp 5066/tcp 5066/udp 7443/tcp 16384-32768/udp
VOLUME ["/var/lib/postgresql", "/etc/freeswitch", "/var/lib/freeswitch", "/usr/share/freeswitch", "/var/www/fusionpbx"]
CMD /usr/bin/supervisord -n
