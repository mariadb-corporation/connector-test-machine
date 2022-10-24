FROM ubuntu:20.04

ARG MAXSCALE_VERSION

RUN apt update

RUN apt-get install -y software-properties-common dirmngr apt-transport-https
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
RUN apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
RUN add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mariadb.mirrors.ovh.net/MariaDB/repo/10.6/ubuntu bionic main'

RUN apt update
RUN apt-get install -y curl mariadb-client
#using 6.1.4, since 6.2.0 has too much error for now
#RUN curl -fLsS -o maxscale.deb https://downloads.mariadb.com/MaxScale/6.2.0/debian/pool/main/m/maxscale/maxscale_6.2.0~bionic-1_amd64.deb
RUN curl -fLsS -o maxscale.deb https://downloads.mariadb.com/MaxScale/${MAXSCALE_VERSION}/packages/ubuntu/jammy/x86_64/maxscale-${MAXSCALE_VERSION}-1.ubuntu.focal.x86_64.deb
RUN dpkg --install ./maxscale.deb

COPY maxscale/docker-entrypoint.sh /
COPY maxscale/maxscale.cnf /etc/
RUN sed -i "s/10.6.99-MariaDB-maxScale-6.1.4/10.6.99-MariaDB-maxScale-${MAXSCALE_VERSION}/g" /etc/maxscale.cnf

RUN chmod 777 /etc/maxscale.cnf
RUN chmod 777 /docker-entrypoint.sh


EXPOSE 4006 4008 4009 4016

ENTRYPOINT ["/docker-entrypoint.sh"]