#!/bin/bash

set -eo pipefail

############################################################################
##############################" functions ##################################
############################################################################

# generate ssl for server and client
generate_ssl () {
  mkdir /tmp/ssl
  /bin/bash $PROJ_PATH/gen-ssl.sh mariadb.example.com /tmp/ssl
  cat /tmp/ssl/ca.crt /tmp/ssl/server.crt > /tmp/ssl/ca_server.crt
  export TEST_DB_SERVER_CERT=/tmp/ssl/ca_server.crt
  export TEST_DB_SERVER_CERT_STRING=$(cat /tmp/ssl/ca_server.crt)

  export TEST_DB_SERVER_PRIVATE_KEY_PATH=/tmp/ssl/server.key
  export TEST_DB_SERVER_PUBLIC_KEY_PATH=/tmp/ssl/public.key
}

# decrypt
decrypt () {
  sudo apt-get update > /dev/null 2>&1
  sudo apt-get install -y git-crypt

  tee /tmp/key.hex <<<$CONNECTOR_TEST_SECRET_KEY
  xxd -plain -revert /tmp/key.hex /tmp/key.txt

  cd $PROJ_PATH
  git-crypt unlock /tmp/key.txt
  cd ..
  export CONNECTOR_TEST_SECRET_KEY='removed'
  rm /tmp/key.txt
  rm /tmp/key.hex
}

# launch docker instances
launch_docker () {
  export TEST_REQUIRE_TLS=0
  export ENTRYPOINT=$PROJ_PATH/travis/sql
  export ENTRYPOINT_PAM=$PROJ_PATH/travis/pam

  export COMPOSE_FILE=$PROJ_PATH/travis/docker-compose.yml

  export TEST_DB_HOST=mariadb.example.com
  export TEST_DB_PORT=3305
  export TEST_DB_USER=boby
  export TEST_DB_PASSWORD=heyPassw0@rd
  echo "configuring mysql additional type"
  sleep 1

  if [[ "$TYPE" == mysql ]] ; then
    if [[ "$VERSION" == 5.7 ]] ; then
      export ADDITIONAL_CONF="--default-authentication-plugin=mysql_native_password --sha256-password-public-key-path=/etc/sslcert/public.key --sha256-password-private-key-path=/etc/sslcert/server.key"
    else
      export ADDITIONAL_CONF="--default-authentication-plugin=mysql_native_password --caching-sha2-password-private-key-path=/etc/sslcert/server.key --caching-sha2-password-public-key-path=/etc/sslcert/public.key --sha256-password-public-key-path=/etc/sslcert/public.key --sha256-password-private-key-path=/etc/sslcert/server.key"
    fi
  fi
  echo "ending configuring mysql additional type"
  sleep 1
  if [ "$TYPE" == "maxscale" ] ; then
      # maxscale ports:
      # - non ssl: 4006
      # - ssl: 4009
      export TEST_DB_PORT=4006
      export TEST_MAXSCALE_TLS_PORT=4009
      export COMPOSE_FILE=$PROJ_PATH/travis/maxscale-compose.yml
      if [ "$DEBUG" = true ] ; then
        docker-compose -f ${COMPOSE_FILE} build
      else
        docker-compose -f ${COMPOSE_FILE} build > /dev/null
      fi
  fi

  mysql=( mysql --protocol=TCP -u${TEST_DB_USER} -h${TEST_DB_HOST} --port=${TEST_DB_PORT} ${TEST_DB_DATABASE} --password=$TEST_DB_PASSWORD)


  # launch docker server and maxscale
  docker-compose -f ${COMPOSE_FILE} up -d

  # wait for docker initialisation
  for i in {15..0}; do
    if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
        break
    fi
    echo 'data server still not active'
    sleep 5
  done

  if [ "$i" = 0 ]; then
    if echo 'SELECT 1' | "${mysql[@]}" ; then
        break
    fi

    docker-compose -f ${COMPOSE_FILE} logs
    if [ "$TYPE" == "maxscale" ] ; then
        docker-compose -f ${COMPOSE_FILE} exec maxscale tail -n 500 /var/log/maxscale/maxscale.log
    fi
    echo >&2 'data server init process failed.'
    exit 1
  fi

  echo 'data server active !'

  if [[ "$TYPE" != "mysql" && "$TYPE" != "mariadb-es" && "$TYPE" != "build" ]] ; then

    export TEST_PAM_USER=testPam
    export TEST_PAM_PWD=myPwd
    echo 'add PAM user'
    # execute pam
    docker-compose -f ${COMPOSE_FILE} exec -u root db bash /pam/pam.sh
    sleep 1
    echo 'reboot server'
    docker-compose -f ${COMPOSE_FILE} stop db
    docker-compose -f ${COMPOSE_FILE} start db

    # wait for restart
    for i in {30..0}; do
      if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
          break
      fi
      echo 'data server restart still not active'
      sleep 2
    done

    if [ "$i" = 0 ]; then
      if echo 'SELECT 1' | "${mysql[@]}" ; then
          break
      fi

      docker-compose -f ${COMPOSE_FILE} logs
      if [ "$TYPE" == "maxscale" ] ; then
          docker-compose -f ${COMPOSE_FILE} exec maxscale tail -n 500 /var/log/maxscale/maxscale.log
      fi
      echo >&2 'data server restart process failed.'
      exit 1
    fi
  fi
}




############################################################################
############################## main ########################################
############################################################################


export PROJ_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DEBUG=false
while getopts ":t:v:d:debug:" flag; do
    case "${flag}" in
        t) TYPE=${OPTARG};;
        v) VERSION=${OPTARG};;
        d) DATABASE=${OPTARG};;
        debug) DEBUG=("1" == ${OPTARG});;
    esac
done

echo "TYPE: $TYPE"
echo "VERSION: $VERSION"
echo "DATABASE: $DATABASE"
echo "DEBUG: $DEBUG"
echo "PROJ_PATH: $PROJ_PATH"

export TEST_DB_DATABASE=$DATABASE
export TYPE_VERS=$"$TYPE:$VERSION"

case $TYPE in
    skysql|skysql-ha)
        if [ -z "$CONNECTOR_TEST_SECRET_KEY" ] ; then
          echo "private environment variable CONNECTOR_TEST_SECRET_KEY must be provided for $TYPE"
          exit 10
        fi
        decrypt
        if [ "$DEBUG" = true ] ; then
          source $PROJ_PATH/secretdir/${TYPE}.sh
        else
          source $PROJ_PATH/secretdir/${TYPE}.sh > /dev/null
        fi
        ;;

    maxscale)
        if [ -z "$TEST_DB_DATABASE" ] ; then
          echo "database must be provided for $TYPE"
          exit 20
        fi
        generate_ssl
        launch_docker
        ;;

    mariadb|mysql)
        if [ -z "$VERSION" ] ; then
          echo "version must be provided for $TYPE"
          exit 30
        fi
        if [ -z "$TEST_DB_DATABASE" ] ; then
          echo "database must be provided for $TYPE"
          exit 31
        fi
        generate_ssl
        echo "ssl files configured"
        launch_docker
        ;;

    mariadb-es)
        if [ -z "$CONNECTOR_TEST_SECRET_KEY" ] ; then
          echo "private environment variable CONNECTOR_TEST_SECRET_KEY must be provided for $TYPE"
          exit 40
        fi
        if [ -z "$VERSION" ] ; then
          echo "version must be provided for $TYPE"
          exit
        fi
        if [ -z "$TEST_DB_DATABASE" ] ; then
          echo "database must be provided for $TYPE"
          exit 41
        fi

        decrypt

        mapfile ES_TOKEN < $PROJ_PATH/secretdir/mariadb-es-token.txt
        # change to https://github.com/mariadb-corporation/MariaDB-ES-Docker
        # when PR https://github.com/mariadb-corporation/MariaDB-ES-Docker/pull/2 is fixed
        git clone https://github.com/rusher/MariaDB-ES-Docker.git
        cd MariaDB-ES-Docker
        docker build --no-cache -t mariadb-es:$VERSION --build-arg ES_TOKEN=$ES_TOKEN --build-arg ES_VERSION=$VERSION -f Dockerfile .
        cd ..
        generate_ssl
        launch_docker
        ;;

    build)
        if [ -z "$TEST_DB_DATABASE" ] ; then
          echo "database must be provided for $TYPE"
          exit 50
        fi
        /bin/bash $PROJ_PATH/travis/build/build.sh
        if [ "$DEBUG" = true ] ; then
          docker build -t build:10.6 --label build $PROJ_PATH/travis/build
        else
          docker build -t build:10.6 --label build $PROJ_PATH/travis/build > /dev/null
        fi
        generate_ssl
        launch_docker
        ;;
    *)
      echo "unsupported type: $TYPE"
      exit 60
      ;;
esac
