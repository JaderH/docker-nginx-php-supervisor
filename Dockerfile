FROM alpine:edge

LABEL maintainer="Jade <hmy940118@gmail.com>"

# mirrors
#RUN set -eux && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# php.ini
ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    256M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M
ENV COMPOSER_ALLOW_SUPERUSER 1

# user
RUN adduser -u 82 -D -S -G www-data www-data

# install service
RUN apk update \
	&& apk upgrade \
	&& apk add nginx supervisor vim curl tzdata \
    php8 php8-fpm php8-pgsql php8-bcmath php8-ctype php8-curl php8-dom php8-fileinfo php8-gd php8-iconv \
    php8-mbstring php8-openssl php8-intl php8-phar php8-posix php8-imap php8-soap php8-ldap php8-xmlwriter  \
    php8-tokenizer php8-redis php8-pdo php8-pdo_mysql php8-pdo_sqlite php8-xml php8-simplexml php8-zip \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && cp /usr/bin/php8 /usr/bin/php \
	&& echo "${TIMEZONE}" > /etc/timezone \
	&& apk del tzdata \
 	&& rm -rf /var/cache/apk/*

# https://github.com/docker-library/php/issues/240
RUN apk add --no-cache --repository http://mirrors.ustc.edu.cn/alpine/edge/community gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
RUN rm -rf /var/cache/apk/*

# set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php8/php.ini && \
	sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php8/php.ini && \
	sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php8/php.ini && \
	sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php8/php.ini && \
	sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php8/php.ini && \
	sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php8/php.ini

# service config
COPY config/supervisord.conf /etc/supervisord.conf
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/www.conf /etc/php8/php-fpm.d/www.conf

# composer
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# file directory
RUN mkdir -p /webser/data \
    && mkdir -p /webser/logs/supervisor \
    && mkdir -p /webser/logs/nginx \
    && mkdir -p /webser/logs/php \
    && mkdir -p /webser/www \
    && chown -R www-data:www-data /webser

EXPOSE 80 443

# workdir
WORKDIR /webser/www

ENTRYPOINT ["/usr/bin/supervisord", "-nc", "/etc/supervisord.conf"]