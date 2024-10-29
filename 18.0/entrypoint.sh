#!/bin/bash

set -e

# Extract connection parameters from DATABASE_URL
if [ -v DATABASE_URL ]; then
    # Parse DATABASE_URL
    proto="$(echo $DATABASE_URL | grep '://' | sed -e's,^\(.*://\).*,\1,g')"
    url="$(echo ${DATABASE_URL/$proto/})"
    userpass="$(echo $url | sed -e 's,@.*$,,g')"
    hostportdb="$(echo $url | sed -e 's,^[^@]*@,,g')"
    
    USER="$(echo $userpass | cut -d ':' -f1)"
    PASSWORD="$(echo $userpass | cut -d ':' -f2)"
    HOST="$(echo $hostportdb | cut -d '/' -f1 | cut -d ':' -f1)"
    PORT="$(echo $hostportdb | cut -d '/' -f1 | cut -d ':' -f2)"
    DB_NAME="$(echo $hostportdb | cut -d '/' -f2 | cut -d '?' -f1)"
    
    # Default to 5432 if PORT is not specified in DATABASE_URL
    : ${PORT:=5432}
else
    # Use default values if DATABASE_URL is not set
    HOST=${DB_PORT_5432_TCP_ADDR:='db'}
    PORT=${DB_PORT_5432_TCP_PORT:=5432}
    USER=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}
    PASSWORD=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}
fi

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}

check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"
#check_config "db_name" "$DB_NAME"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
