FROM alpine:3.12

LABEL maintainer="Jade <hmy940118@gmail.com>"

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
	&& apk upgrade \
	&& apk add nginx supervisor vim curl tzdata \
    php7 php7-fpm php7-amqp php7-bcmath php7-ctype php7-curl php7-dom php7-fileinfo php7-ftp php7-gd php7-iconv \
    php7-json php7-mbstring php7-mysqlnd php7-openssl php7-pdo php7-pdo_mysql php7-pdo_sqlite php7-phar php7-posix \
    php7-redis php7-session php7-shmop php7-simplexml php7-soap php7-sockets php7-sqlite3 php7-sysvsem php7-tokenizer \
    php7-xml php7-xmlreader php7-xmlrpc php7-xmlwriter php7-xsl php7-opcache php7-zip \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
	&& echo "${TIMEZONE}" > /etc/timezone \
	&& apk del tzdata \
 	&& rm -rf /var/cache/apk/*

# https://github.com/docker-library/php/issues/240
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/latest-stable/community gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
RUN rm -rf /var/cache/apk/*

# set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini && \
	sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini && \
	sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php7/php.ini && \
	sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini && \
	sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini && \
	sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php7/php.ini

# service config
COPY config/supervisord.conf /etc/supervisord.conf
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/www.conf /etc/php7/php-fpm.d/www.conf

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