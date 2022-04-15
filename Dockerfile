FROM alpine:3.8

LABEL maintainer="Jade <hmy940118@gmail.com>"

# mirrors
RUN set -eux && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# php.ini
ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    512M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M
ENV COMPOSER_ALLOW_SUPERUSER 1

# user group
RUN set -eux; \
	addgroup -g 82 -S www-data; \
	adduser -u 82 -D -S -G www-data www-data

# install service
RUN apk update \
	&& apk add nginx supervisor vim curl tzdata \
    php5 php5-fpm php5-bz2 php5-bcmath php5-ctype php5-curl php5-dom php5-ftp php5-gd php5-gettext php5-iconv php5-intl \
    php5-json php5-mysql php5-mysqli php5-openssl php5-pdo php5-pdo_mysql php5-pdo_sqlite php5-pcntl php5-phar php5-posix \
    php5-shmop php5-soap php5-sockets php5-sqlite3 php5-mcrypt php5-xml php5-xmlreader php5-xmlrpc php5-opcache php5-zip \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
	&& echo "${TIMEZONE}" > /etc/timezone \
	&& apk del tzdata \
 	&& rm -rf /var/cache/apk/*

# https://github.com/docker-library/php/issues/240
RUN apk add --no-cache --repository http://mirrors.aliyun.com/alpine/edge/community gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
RUN rm -rf /var/cache/apk/*

# install dependency
RUN apk add autoconf g++ make icu-dev libxslt-dev php5-dev rabbitmq-c rabbitmq-c-dev && \
    ln -s /usr/bin/php5 /usr/bin/php && ln -s /usr/bin/phpize5 /usr/bin/phpize

# install memcached and redis
COPY pkg/sgerrand.rsa.pub /etc/apk/keys/sgerrand.rsa.pub
COPY pkg/php5-memcached-2.2.0-r0.apk /tmp/php5-memcached-2.2.0-r0.apk
COPY pkg/php5-redis-3.1.6-r0.apk /tmp/php5-redis-3.1.6-r0.apk
COPY pkg/igbinary-2.0.6.tar.gz /tmp/igbinary-2.0.6.tar.gz
COPY pkg/amqp-1.11.0.tgz /tmp/amqp-1.11.0.tgz
COPY pkg/memcache-2.2.7.tgz /tmp/memcache-2.2.7.tgz

RUN cd /tmp && apk add php5-memcached-2.2.0-r0.apk && apk add php5-redis-3.1.6-r0.apk

# install memcache
RUN cd /tmp && \
    tar xf memcache-2.2.7.tgz && cd memcache-2.2.7 && \
    phpize && ./configure --with-php-config=/usr/bin/php-config5 && make && make install && \
    echo "extension=memcache.so" >> /etc/php5/conf.d/memcache.ini 

# install igbinary 
RUN cd /tmp && \
    tar xf igbinary-2.0.6.tar.gz && cd igbinary-2.0.6 && \
    phpize && ./configure --with-php-config=/usr/bin/php-config5 && make && make install && \
    echo "extension=igbinary.so" >> /etc/php5/conf.d/igbinary.ini 

# install amqp
RUN cd /tmp && \
    tar xf amqp-1.11.0.tgz && cd amqp-1.11.0 &&\
    phpize && ./configure --with-php-config=/usr/bin/php-config5 -with-amqp && \
    make && make install && \
    echo "extension=amqp.so" >> /etc/php5/conf.d/amqp.ini

# clear
RUN rm -rf /tmp/* && \
    apk del autoconf g++ make icu-dev libxslt-dev php5-dev

# set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php5/php.ini && \
	sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php5/php.ini && \
	sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php5/php.ini && \
	sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php5/php.ini && \
	sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php5/php.ini && \
	sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php5/php.ini

# service config
COPY config/supervisord.conf /etc/supervisord.conf
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/www.conf /etc/php5/php-fpm.d/www.conf

# composer
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# file directory
RUN mkdir -p /webser/data \
    && mkdir -p /webser/logs/supervisor \
    && mkdir -p /webser/logs/nginx \
    && mkdir -p /webser/logs/php \
    && mkdir -p /webser/runtime \
    && mkdir -p /webser/www \
    && chown -R www-data:www-data /webser

EXPOSE 80 443

# workdir
WORKDIR /webser/www

ENTRYPOINT ["/usr/bin/supervisord", "-nc", "/etc/supervisord.conf"]