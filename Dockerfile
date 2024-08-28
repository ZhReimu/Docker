FROM nginx:stable-alpine

EXPOSE 8000
CMD ["/sbin/entrypoint.sh"]

ARG cachet_ver
ARG archive_url

ENV cachet_ver ${cachet_ver:-3.x}
ENV archive_url ${archive_url:-https://mirror.ghproxy.com/https://github.com/cachethq/Cachet/archive/${cachet_ver}.tar.gz}

ENV COMPOSER_VERSION 1.9.0

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && apk update

RUN apk add --no-cache --update \
    mysql-client \
    php83 \
    php83-apcu \
    php83-bcmath \
    php83-ctype \
    php83-curl \
    php83-dom \
    php83-fileinfo \
    php83-fpm \
    php83-gd \
    php83-iconv \
    php83-intl \
    php83-json \
    php83-mbstring \
    php83-pecl-mcrypt \
    php83-mysqlnd \
    php83-opcache \
    php83-openssl \
    php83-pdo \
    php83-pdo_mysql \
    php83-pdo_pgsql \
    php83-pdo_sqlite \
    php83-phar \
    php83-posix \
    php83-redis \
    php83-session \
    php83-simplexml \
    php83-soap \
    php83-sqlite3 \
    php83-tokenizer \
    php83-xml \
    php83-xmlwriter \
    php83-zip \
    php83-zlib \
    postfix \
    postgresql \
    postgresql-client \
    sqlite \
    sudo \
    wget sqlite git curl bash grep \
    supervisor \
    composer \
    php83-xmlreader

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php83/error.log && \
    ln -sf /dev/stderr /var/log/php83/error.log

RUN adduser -S -s /bin/bash -u 1001 -G root www-data

RUN echo "www-data	ALL=(ALL:ALL)	NOPASSWD:SETENV:	/usr/sbin/postfix" >> /etc/sudoers

RUN touch /var/run/nginx.pid && \
    chown -R www-data:root /var/run/nginx.pid

RUN chown -R www-data:root /etc/php83/php-fpm.d

RUN mkdir -p /var/www/html && \
    mkdir -p /usr/share/nginx/cache && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/lib/nginx && \
    chown -R www-data:root /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/

# Install composer
# RUN wget https://getcomposer.org/installer -O /tmp/composer-setup.php && \
#    wget https://composer.github.io/installer.sig -O /tmp/composer-setup.sig && \
#    php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" && \
#    php /tmp/composer-setup.php --version=$COMPOSER_VERSION --install-dir=bin && \
#    php -r "unlink('/tmp/composer-setup.php');"

WORKDIR /var/www/html/
USER 1001

RUN wget ${archive_url} && \
    tar xzf ${cachet_ver}.tar.gz --strip-components=1 && \
    chown -R www-data:root /var/www/html && \
    rm -r ${cachet_ver}.tar.gz && \
    # php /usr/bin/composer.phar global require "hirak/prestissimo:^0.3" && \
    php /usr/bin/composer.phar install -o && \
    rm -rf bootstrap/cache/*

COPY conf/php-fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx-site.conf /etc/nginx/conf.d/default.conf
COPY conf/.env.docker /var/www/html/.env
COPY entrypoint.sh /sbin/entrypoint.sh

USER root
RUN chmod g+rwx /var/run/nginx.pid && \
    chmod -R g+rw /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/ /etc/php83/php-fpm.d storage
USER 1001