FROM alpine:3.19

LABEL maintainer="Jader <hmy940118@gmail.com>"

# mirrors
RUN set -eux && sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories

# php.ini
ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    512M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M
ENV COMPOSER_ALLOW_SUPERUSER 1

# user group
RUN set -eux; \
	adduser -u 82 -D -S -G www-data www-data

# install service
RUN apk update \
	&& apk upgrade \
	&& apk add nginx supervisor vim curl tzdata \
    php83 php83-fpm php83-pecl-amqp php83-bcmath php83-ctype php83-curl php83-dom php83-fileinfo php83-gd php83-iconv \
    php83-mbstring php83-mysqlnd php83-openssl php83-pdo php83-pdo_mysql php83-pdo_sqlite php83-phar php83-posix php83-pecl-swoole \
    php83-pecl-redis php83-session php83-simplexml php83-sockets php83-sqlite3 php83-tokenizer php83-pcntl php83-sodium \
    php83-xml php83-xmlreader php83-xmlwriter php83-opcache php83-zip php83-bz2 php83-calendar php83-pecl-event php83-pecl-xdebug \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
	&& echo "${TIMEZONE}" > /etc/timezone \
	&& apk del tzdata \
 	&& rm -rf /var/cache/apk/*

# https://github.com/docker-library/php/issues/240
RUN apk add --no-cache --repository http://mirrors.ustc.edu.cn/alpine/edge/community gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
RUN rm -rf /var/cache/apk/*

# install the xhprof extension to profile requests
#RUN curl "https://github.com/tideways/php-xhprof-extension/releases/download/v5.0.4/tideways-xhprof-5.0.4-x86_64.tar.gz" -fsL -o ./tideways_xhprof.tar.gz \
#    && tar xf ./tideways_xhprof.tar.gz \
#    && cp ./tideways_xhprof-5.0.4/tideways_xhprof-7.3.so /usr/lib/php83/modules/tideways_xhprof.so \
#    && chmod 755 /usr/lib/php83/modules/tideways_xhprof.so \
#    && echo "extension=tideways_xhprof.so" >> /etc/php83/conf.d/tideways_xhprof.ini \
#    && rm -rf ./tideways_xhprof.tar.gz ./tideways_xhprof-5.0.4 \
RUN echo "opcache.enable_cli = 'On'" >> /etc/php${PHP_BUILD_VERSION}/conf.d/00_opcache.ini \
    && echo "extension=swoole.so" > /etc/php${PHP_BUILD_VERSION}/conf.d/50_swoole.ini \
    && echo "swoole.use_shortname = 'Off'" >> /etc/php${PHP_BUILD_VERSION}/conf.d/50_swoole.ini \

# set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php83/php.ini && \
	sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php83/php.ini && \
	sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php83/php.ini && \
	sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php83/php.ini && \
	sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php83/php.ini && \
	sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php83/php.ini

# service config
COPY config/supervisord.conf /etc/supervisord.conf
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/www.conf /etc/php83/php-fpm.d/www.conf

# composer
RUN ln -s /usr/bin/php83 /usr/bin/php
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

EXPOSE 80 443 8787

# workdir
WORKDIR /webser/www

ENTRYPOINT ["/usr/bin/supervisord", "-nc", "/etc/supervisord.conf"]