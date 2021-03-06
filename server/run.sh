#!/bin/bash -ex

# Run script for kegbot appserver.

die() {
  echo "Error: $@"
  exit 1
}

do_mysql() {
  mysql -B -u "${KEGBOT_DB_USER}" --password="${KEGBOT_DB_PASS}" -h "${KEGBOT_DB_HOST}" -P ${KEGBOT_DB_PORT} "${@}"
  return $?
}

### Main routines

setup_env() {
  # Copy host information from docker links, if present.
  if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ]; then
    export KEGBOT_DB_HOST="${MYSQL_PORT_3306_TCP_ADDR}"
    export KEGBOT_DB_PORT="${MYSQL_PORT_3306_TCP_PORT}"
  fi
  if [ -n "${REDIS_PORT_6379_TCP_ADDR}" ]; then
    export KEGBOT_REDIS_HOST="${REDIS_PORT_6379_TCP_ADDR}"
    export KEGBOT_REDIS_PORT="${REDIS_PORT_6379_TCP_PORT}"
  fi

  # Set defaults
  if [ -z "${KEGBOT_DB_NAME}" ]; then
    export KEGBOT_DB_NAME="kegbot"
  fi
  if [ -z "${KEGBOT_DB_USER}" ]; then
    export KEGBOT_DB_USER="root"
  fi
  if [ -z "${KEGBOT_DB_PASS}" ]; then
    export KEGBOT_DB_PASS=""
  fi
  if [ -z "${KEGBOT_DB_PORT}" ]; then
    export KEGBOT_DB_PORT=3306
  fi

  if [ -z "${KEGBOT_REDIS_PORT}" ]; then
    export KEGBOT_REDIS_PORT=6379
  fi

  # Verify mandatory variables.
  if [ -z "${KEGBOT_DB_HOST}" ]; then
    die "Must set KEGBOT_DB_HOST or MYSQL_PORT_3306_TCP_{ADDR,PORT}"
  fi
  if [ -z "${KEGBOT_REDIS_HOST}" ]; then
    die "Must set KEGBOT_REDIS_HOST or REDIS_PORT_6379_TCP_{ADDR,PORT}"
  fi

  export KEGBOT_SETTINGS_DIR=/kegbot-settings
  export C_FORCE_ROOT=True   ## needed by celery
}

wait_for_mysql() {
  if ! do_mysql "${KEGBOT_DB_NAME}" -e "show tables"; then
    do_mysql -e "create database ${KEGBOT_DB_NAME};"
    kegbot syncdb --all --noinput -v 0
    kegbot migrate --all --fake --noinput -v 0
    do_mysql "${KEGBOT_DB_NAME}" -e "show tables"
  fi
}

wait_for_redis() {
  redis-cli -h "${KEGBOT_REDIS_HOST}" -p ${KEGBOT_REDIS_PORT} ping
}

# Perform first-launch setup.
maybe_setup_kegbot() {
  kegbot collectstatic --noinput -v 0
  #do_mysql -e "create database ${KEGBOT_DB_NAME};" || die "Could not create database."
  true
}

run_daemons() {
  kegbot run_all --logs_dir=/kegbot-data --gunicorn_options="-b 0.0.0.0:8000"
}

run_all() {
  setup_env

  wait_for_mysql
  wait_for_redis

  maybe_setup_kegbot
  ls -ld /kegbot-data
  ls -l /kegbot-data
  echo `date` >> /kegbot-data/runlog
  run_daemons
}

run_all