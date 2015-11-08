#!/bin/bash

until nc -z ${DB_PORT_3306_TCP_ADDR} ${DB_PORT_3306_TCP_PORT}; do
    echo "$(date) - waiting for mysql..."
    sleep 2
done

###########
# Ensure parameters.yml exists with user data and is updated to the latest version.
###########

    if [ ! -e /app/config/parameters.yml ]; then
        mkdir /app/config >/dev/null 2>&1
        cp /var/www/app/config/parameters.yml.dist /app/config/parameters.yml
    fi
    rm /var/www/app/config/parameters.yml >/dev/null 2>&1
    ln -s /app/config/parameters.yml /var/www/app/config/parameters.yml

    composer install -vvv --optimize-autoloader --no-interaction --prefer-dist --working-dir=/var/www

    if [ ! -e /app/Resources ]; then
        mkdir /app/Resources >/dev/null 2>&1
        mv /var/www/app/Resources/* /app/Resources/ >/dev/null 2>&1
    fi

    rm -Rf /var/www/app/Resources >/dev/null 2>&1
    ln -s /app/Resources /var/www/app/Resources

###########
# Update nginx and database configuration.
###########

    set_parameter() {
        key="$1"
        value="$2"
        sed -ri "s/$key.*/$key: \"$value\"/" /var/www/app/config/parameters.yml
    }

    # Database settings from linked DB container
    set_parameter "ravaj.database.host" ${DB_PORT_3306_TCP_ADDR}
    set_parameter "ravaj.database.password" ${DB_ENV_MYSQL_ROOT_PASSWORD}

    # Generate nginx config
    j2 /site.conf.j2 > /etc/nginx/conf.d/default.conf

###########
# Install a new app or migrate existing one.
###########

    cd /var/www

    # if db not exists
    php app/console doctrine:query:sql "SELECT COUNT(*) FROM sylius_user;" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        php app/console ravaj:install --no-interaction
        php app/console ravaj:install:sample-data --no-interaction
    else
        php app/console ravaj:update --no-interaction
    fi

    # fix permissions
    chmod -Rf 0777 app/cache
    chmod -Rf 0777 app/logs

###########
# Execute PID 1.
###########

    exec "$@"

