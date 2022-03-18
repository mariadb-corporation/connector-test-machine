#!/bin/bash

set -o pipefail

############################################################################
##############################" functions ##################################
############################################################################

# generate ssl for server and client
generate_ssl () {
  ls -lrt /etc/ssl
  sudo mkdir -p /etc/ssl/mariadb
  sudo /bin/bash $PROJ_PATH/gen-ssl.sh mariadb.example.com /etc/ssl/mariadb $PROJ_PATH/cert $TYPE
  sudo sh -c 'cat /etc/ssl/mariadb/ca.crt /etc/ssl/mariadb/server.crt > /etc/ssl/mariadb/ca_server.crt'
  sudo sh -c 'cat /etc/ssl/mariadb/ca.crt /etc/ssl/mariadb/client.crt > /etc/ssl/mariadb/ca_client.crt'
  export TEST_DB_SERVER_CERT=/etc/ssl/mariadb/ca_server.crt
  export TEST_DB_SERVER_CERT_STRING=$(cat /etc/ssl/mariadb/ca_server.crt)
  export TEST_DB_RSA_PUBLIC_KEY=/etc/ssl/mariadb/public.key
  export TEST_DB_SERVER_CA_CERT=/etc/ssl/mariadb/ca.crt
  export TEST_DB_SERVER_INTERMEDIATE_CERT=/etc/ssl/mariadb/server.crt
  export TEST_DB_CLIENT_KEY=/etc/ssl/mariadb/client.key
  export TEST_DB_CLIENT_CERT=/etc/ssl/mariadb/client.crt
  export TEST_DB_CLIENT_CERT_FULL=/etc/ssl/mariadb/ca_client.crt
  export TEST_DB_CLIENT_PKCS=/etc/ssl/mariadb/fullclient-keystore.p12
  sudo chmod +r /etc/ssl/mariadb/*
  sudo chown -Rv mysql:root /etc/ssl/mariadb
  ls -lrt /etc/ssl/mariadb
}

docker_login () {
  if [ -n "$CONNECTOR_TEST_SECRET_KEY" ] ; then
    decrypt
    mapfile DOCKER_PWD < $PROJ_PATH/secretdir/docker-pwd.txt
    docker login --username mariadbtest --password $DOCKER_PWD
    DOCKER_PWD=removed
  fi
}

# decrypt
decrypt () {
  sudo apt-get update -y
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

remove_mysql () {
  sudo apt-get remove --purge mysql-server mysql-client mysql-common
  sudo apt-get autoremove
  sudo apt-get autoclean
  sudo deluser mysql
  sudo rm -rf /var/lib/mysql
  sudo apt-get purge mysql-server-*
  sudo apt-get purge mysql-client-*
  sudo rm -rf /var/log/mysql
  sudo rm -rf /etc/mysql
}

install_osx () {

  echo 'brew install mariadb !'
  brew install mariadb
  # configuration addition (ssl mostly)
  sudo cp $PROJ_PATH/travis/unix.cnf /etc/mysql/conf.d/unix.cnf
  sudo sh -c "echo 'max_allowed_packet=${PACKET_SIZE}M' >> /etc/mysql/conf.d/unix.cnf"
  sudo sh -c "echo 'innodb_log_file_size=${PACKET_SIZE}0M' >> /etc/mysql/conf.d/unix.cnf"

  sudo ls -lrt /etc/mysql/conf.d/
  sudo chmod +xr /etc/mysql/conf.d/unix.cnf
  tail /etc/mysql/conf.d/unix.cnf

  mysql.server start

  export TEST_REQUIRE_TLS=0

  echo "adding database and user"
  sudo mysql -e "create DATABASE IF NOT EXISTS ${TEST_DB_DATABASE}"
  sudo mysql ${TEST_DB_DATABASE} < $PROJ_PATH/travis/sql/dbinit.sql
  echo "adding database and user done"
}

# install local mariadb
install_local () {
  echo "install local version"
  if [ "$TRAVIS_OS_NAME" == "linux" ]  ; then
    # remove mysql if present
    remove_mysql

    sudo apt-get install software-properties-common dirmngr apt-transport-https
    sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 F1656F24C74CD1D8
    sudo add-apt-repository "deb [arch=amd64,arm64,ppc64el,s390x] https://mirrors.xtom.nl/mariadb/repo/${VERSION}/ubuntu ${TRAVIS_DIST} main"
    sudo apt update
    echo "mariadb-server-${VERSION} mysql-server/root_password password ${TEST_DB_PASSWORD}" | sudo debconf-set-selections
    echo "mariadb-server-${VERSION} mysql-server/root_password_again password ${TEST_DB_PASSWORD}" | sudo debconf-set-selections
    sudo apt-get -y install mariadb-server
    export TEST_REQUIRE_TLS=0

    echo "adding database and user"
    if [ $VERSION == "10.2" ] || [ $VERSION == "10.3" ] ; then
      mysql -uroot --password=${TEST_DB_PASSWORD} -e "create DATABASE IF NOT EXISTS ${TEST_DB_DATABASE}"
      mysql -uroot --password=${TEST_DB_PASSWORD} ${TEST_DB_DATABASE} < $PROJ_PATH/travis/sql/dbinit.sql
    else
      sudo mysql -e "create DATABASE IF NOT EXISTS ${TEST_DB_DATABASE}"
      sudo mysql ${TEST_DB_DATABASE} < $PROJ_PATH/travis/sql/dbinit.sql
    fi
    echo "adding database and user done"


    # configuration addition (ssl mostly)
    sudo cp $PROJ_PATH/travis/unix.cnf /etc/mysql/conf.d/unix.cnf
    sudo sh -c "echo 'max_allowed_packet=${PACKET_SIZE}M' >> /etc/mysql/conf.d/unix.cnf"
    sudo sh -c "echo 'innodb_log_file_size=${PACKET_SIZE}0M' >> /etc/mysql/conf.d/unix.cnf"
    if [ $CLEAR_TEXT == "1" ] ; then
      echo "adding pam_use_cleartext_plugin in conf"
      sudo sh -c "echo '[mariadb]' >> /etc/mysql/conf.d/unix.cnf"
      sudo sh -c "echo 'plugin_load_add=auth_pam' >> /etc/mysql/conf.d/unix.cnf"
      sudo sh -c "echo 'pam_use_cleartext_plugin=ON' >> /etc/mysql/conf.d/unix.cnf"
    fi

    sudo ls -lrt /etc/mysql/conf.d/
    sudo chmod +xr /etc/mysql/conf.d/unix.cnf
    tail /etc/mysql/conf.d/unix.cnf

    if [ "$TYPE" == "mariadb" ] ; then
      export TEST_PAM_USER=testPam
      export TEST_PAM_PWD=myPwd
      echo 'add PAM user'
      sudo bash $PROJ_PATH/travis/pam/pam.sh
    fi

    echo "restart mariadb server"
    sudo service mariadb restart

    # wait for initialisation
    check_server_status 3306
    echo 'server up !'
  fi
}

check_server_status () {
  mysqlCmd=( mysql --protocol=TCP -u${TEST_DB_USER} --port=${1} ${TEST_DB_DATABASE} --password=${TEST_DB_PASSWORD})
  for i in {15..0}; do
    if echo 'SELECT 1' | "${mysqlCmd[@]}" &> /dev/null; then
        break
    fi
    echo 'data server still not active'
    sleep 5
  done

  if [ "$i" = 0 ]; then
    if echo 'SELECT 1' | "${mysqlCmd[@]}" ; then
        break
    fi
    if [ "$TYPE" != "mariadb" ] && [ "$LOCAL" != "1" ] ; then
      docker-compose -f ${COMPOSE_FILE} logs
      if [ "$TYPE" == "maxscale" ] ; then
          docker-compose -f ${COMPOSE_FILE} exec maxscale tail -n 500 /var/log/maxscale/maxscale.log
      fi
    fi

    echo >&2 'data server start process failed.'
    exit 1
  else
    echo 'data server active'
  fi
}

# launch docker instances
launch_docker () {
  export TEST_REQUIRE_TLS=0
  export TEST_DB_PORT=3305
  export ENTRYPOINT=$PROJ_PATH/travis/sql
  export ENTRYPOINT_PAM=$PROJ_PATH/travis/pam
  if [ "$TYPE" == 'mariadb-es' ] ; then
    export ENTRYPOINT=$PROJ_PATH/travis/sql-es
  fi
  export COMPOSE_FILE=$PROJ_PATH/travis/docker-compose.yml

  export PACKET_SIZE_VAL="${PACKET_SIZE}M"
  export INNODB_LOG_FILE_SIZE="${PACKET_SIZE}0M"

  if [ "$TYPE" == mysql ] ; then
    echo "configuring mysql additional type"

    export ADDITIONAL_CONF="--local-infile=ON $ADDITIONAL_CONF"
    if [ "$VERSION" == 5.7 ] ; then
      export ADDITIONAL_CONF="--sha256-password-public-key-path=/etc/sslcert/public.key --sha256-password-private-key-path=/etc/sslcert/server.key"
    else
      export ADDITIONAL_CONF="--caching-sha2-password-private-key-path=/etc/sslcert/server.key --caching-sha2-password-public-key-path=/etc/sslcert/public.key --sha256-password-public-key-path=/etc/sslcert/public.key --sha256-password-private-key-path=/etc/sslcert/server.key"
    fi
    if [ -z "$NATIVE" ] || [ "$NATIVE" == 1 ] ; then
      export ADDITIONAL_CONF="--default-authentication-plugin=mysql_native_password $ADDITIONAL_CONF"
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
      echo "building maxscale version 6.2.0"
      docker-compose -f ${COMPOSE_FILE} build

  fi

  # launch docker server and maxscale
  docker-compose -f ${COMPOSE_FILE} up -d db

  # wait for docker initialisation
  check_server_status 3305

  echo 'data server active !'

  if [ "$TYPE" == "mariadb" ] || [ "$TYPE" == "maxscale" ] ; then

    export TEST_PAM_USER=testPam
    export TEST_PAM_PWD=myPwd
    echo 'add PAM user'
    # execute pam
    docker-compose -f ${COMPOSE_FILE} exec -u root db bash /pam/pam.sh

    sleep 1
    echo 'rebooting server'
    docker-compose -f ${COMPOSE_FILE} stop db
    docker-compose -f ${COMPOSE_FILE} start db

    # wait for restart
    check_server_status 3305
    echo 'server with PAM active !'

    if [ "$TYPE" == "maxscale" ] ; then

      # wait for maxscale initialisation
      echo 'starting maxscale'
      docker-compose -f ${COMPOSE_FILE} up -d maxscale

      check_server_status 4006
      echo 'maxscale active !'
      export TEST_PAM_PORT=4016

      # create PAM user on maxscale
      docker-compose -f ${COMPOSE_FILE} exec -u root maxscale bash /pam/pam-create-user.sh

      docker-compose -f ${COMPOSE_FILE} stop maxscale
      docker-compose -f ${COMPOSE_FILE} start maxscale
      check_server_status 4006
      echo 'maxscale with PAM active !'
    fi
  fi
}




############################################################################
############################## main ########################################
############################################################################


export PROJ_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "parsing parameters"

PACKET_SIZE=20
while getopts ":t:v:d:n:l:p:g:c:" flag; do
    case "${flag}" in
        t) TYPE=${OPTARG};;
        v) VERSION=${OPTARG};;
        d) DATABASE=${OPTARG};;
        n) NATIVE=${OPTARG};;
        l) LOCAL=${OPTARG};;
        p) PACKET_SIZE=${OPTARG};;
        g) DEBUG=${OPTARG};;
        c) CLEAR_TEXT=${OPTARG};;
    esac
done

if [ -z "$PACKET_SIZE" ] ; then
  PACKET_SIZE=20
else
  re='^[0-9]+$'
  if ! [[ $PACKET_SIZE =~ $re ]] ; then
   echo "error: Packet size is not a number" >&2; exit 1
  fi
fi

if [ -z "$NATIVE" ] ; then
  NATIVE=1
fi

if [ -z "LOCAL" ] ; then
  LOCAL=0
fi

if [ -z "DEBUG" ] ; then
  DEBUG="1"
fi

echo "parameters:"
echo "TYPE: ${TYPE}"
echo "VERSION: ${VERSION}"
echo "DATABASE: ${DATABASE}"
echo "DEBUG: ${DEBUG}"
echo "NATIVE: ${NATIVE}"
echo "LOCAL: ${LOCAL}"
echo "PROJ_PATH: ${PROJ_PATH}"
echo "PACKET_SIZE: ${PACKET_SIZE}"
echo "CLEAR_TEXT: ${CLEAR_TEXT}"
if [ -z "$CONNECTOR_TEST_SECRET_KEY" ] ; then
  echo "CONNECTOR_TEST_SECRET_KEY env not set"
else
  echo "CONNECTOR_TEST_SECRET_KEY env set"
fi

export TEST_DB_DATABASE=$DATABASE
export TYPE_VERS=$"$TYPE:$VERSION"
export TEST_DB_HOST=mariadb.example.com
export TEST_DB_PORT=3306
export TEST_DB_USER=boby
export TEST_DB_PASSWORD=heyPassword

echo '{"ipv6":true,"fixed-cidr-v6":"2001:db8:1::/64"}' | sudo tee /etc/docker/daemon.json
sudo service docker restart
export TEST_DB_HOST_IPV6=2001:db8:1::/64

case $TYPE in
    skysql|skysql-ha)
        if [ -z "$CONNECTOR_TEST_SECRET_KEY" ] ; then
          echo "private environment variable CONNECTOR_TEST_SECRET_KEY must be provided for $TYPE"
          exit 10
        fi
        decrypt
        if [ "$DEBUG" == "1" ] ; then
          source $PROJ_PATH/secretdir/${TYPE}.sh
        else
          source $PROJ_PATH/secretdir/${TYPE}.sh > /dev/null
        fi
        ;;

    xpand)
        if [ -z "$CONNECTOR_TEST_SECRET_KEY" ] ; then
          echo "private environment variable CONNECTOR_TEST_SECRET_KEY must be provided for $TYPE"
          exit 10
        fi

        decrypt
        source $PROJ_PATH/secretdir/xpand.sh
        check_server_status 3316
        ;;

    maxscale)
        if [ -z "$TEST_DB_DATABASE" ] ; then
          echo "database must be provided for $TYPE"
          exit 20
        fi
        generate_ssl
        if [ -z "$VERSION" ] ; then
          export MAXSCALE_VERSION=2.5.18
        else
          export MAXSCALE_VERSION=$VERSION
        fi
        echo "using MAXSCALE_VERSION=$MAXSCALE_VERSION"
        docker_login
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
        if [ "$TRAVIS_OS_NAME" == "osx" ] ; then
          install_osx
        else
          if [ "$TYPE" == "mariadb" ] && [ "$LOCAL" == "1" ] ; then
            install_local
          else
            docker_login
            launch_docker
          fi
        fi
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
        export TEST_DB_PASSWORD=$'heyPassw-!µ20§rd'
        decrypt

        mapfile ES_TOKEN < $PROJ_PATH/secretdir/mariadb-es-token.txt
        docker login docker.mariadb.com --username diego.dupin@mariadb.com --password $ES_TOKEN
        docker pull docker.mariadb.com/enterprise-server:$VERSION
        export TYPE_VERS=$"docker.mariadb.com/enterprise-server:$VERSION"

        generate_ssl
        launch_docker
        ;;

    build)
        if [ -z "$TEST_DB_DATABASE" ] ; then
          echo "database must be provided for $TYPE"
          exit 50
        fi
        docker_login

        /bin/bash $PROJ_PATH/travis/build/build.sh
#        if [ "$DEBUG" == "1" ] ; then
          docker build -t build:10.6 --label build $PROJ_PATH/travis/build
#        else
#          docker build -t build:10.6 --label build $PROJ_PATH/travis/build > /dev/null
#        fi
        generate_ssl
        launch_docker
        ;;
    *)
      echo "unsupported type: $TYPE"
      exit 60
      ;;
esac
