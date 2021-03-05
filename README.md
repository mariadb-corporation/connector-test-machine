# connector-test-machine

## development
sudo apt-get install -y git-crypt
git-crypt export-key /path/to/testing_machine_key.txt

after cloning :
git-crypt unlock /path/to/testing_machine_key.txt

## to use : 

```
git clone https://github.com/rusher/connector-test-machine.git
source connector-test-machine/launch.sh -tTYPE -vVERSION -dDATABASE
```

possible TYPE value : 

* mariadb
* mysql
* build
* maxscale
* mariadb-es (enterprise)  
* skysql
* skysql-ha

version is mandatory for non skysql env.

example :
```
source ./launch.sh -tmariadb -v10.5 -dtestj
source ./launch.sh -tskysql -dtestj
```

Server will be launched if needed, those environments variables will be set : 

TLS env variables 
* TEST_DB_SERVER_CERT_STRING server certificate chain
* TEST_DB_SERVER_CERT path to server certificate
* TEST_DB_SERVER_PRIVATE_KEY_PATH
* TEST_DB_SERVER_PUBLIC_KEY_PATH

others  
* TEST_DB_USER user
* TEST_DB_HOST host
* TEST_DB_PASSWORD password
* TEST_DB_DATABASE database  
* TEST_DB_PORT server port
* TEST_MAXSCALE_TLS_PORT (for maxscale, TLS port differ than port without ssl)
* TEST_REQUIRE_TLS to indicate if connection required TLS
* TEST_PAM_USER and TEST_PAM_PWD 

