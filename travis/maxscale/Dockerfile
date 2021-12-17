FROM ubuntu:bionic

RUN apt-get update && apt-get -y install sudo

RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

RUN sudo apt-get install -y software-properties-common dirmngr apt-transport-https
RUN sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
RUN sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
RUN sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mariadb.mirrors.ovh.net/MariaDB/repo/10.6/ubuntu bionic main'

RUN sudo apt update
RUN apt-get install -y curl mariadb-client

RUN curl -fLsS -o maxscale.deb https://dlm.mariadb.com/1937827/maxscale/6.2.0/packages/ubuntu/bionic/x86_64/maxscale-6.2.0-1.ubuntu.bionic.x86_64.deb
RUN sudo dpkg --install ./maxscale.deb

COPY maxscale/docker-entrypoint.sh /
COPY maxscale/maxscale.cnf /etc/
RUN chmod 777 /etc/maxscale.cnf
RUN chmod 777 /docker-entrypoint.sh


EXPOSE 4006 4007 4008

ENTRYPOINT ["/docker-entrypoint.sh"]