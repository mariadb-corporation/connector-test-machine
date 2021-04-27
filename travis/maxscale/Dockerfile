FROM ubuntu:bionic

ARG MAXSCALE_VERSION
RUN apt-get update && apt-get -y install sudo

RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

RUN sudo apt-get install -y software-properties-common
RUN sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
RUN sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mariadb.mirrors.ovh.net/MariaDB/repo/10.5/ubuntu bionic main'

RUN sudo apt update
RUN apt-get install -y curl mariadb-client

RUN curl -o maxscale.deb https://downloads.mariadb.com/MaxScale/2.5.9/debian/pool/main/m/maxscale/maxscale_2.5.9~bionic-1_amd64.deb
RUN dpkg --install maxscale.deb

COPY maxscale/docker-entrypoint.sh /
COPY maxscale/maxscale.cnf /etc/
RUN chmod 777 /etc/maxscale.cnf
RUN chmod 777 /docker-entrypoint.sh


EXPOSE 4006 4007 4008

ENTRYPOINT ["/docker-entrypoint.sh"]