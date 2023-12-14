# vim:set ft=dockerfile:
FROM ubuntu:focal

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

# https://bugs.debian.org/830696 (apt uses gpgv by default in newer releases, rather than gpg)
RUN set -ex; \
	apt-get update; \
	if ! which gpg; then \
		apt-get install -y --no-install-recommends gnupg; \
	fi; \
	if ! gpg --version | grep -q '^gpg (GnuPG) 1\.'; then \
# Ubuntu includes "gnupg" (not "gnupg2", but still 2.x), but not dirmngr, and gnupg 2.x requires dirmngr
# so, if we're not running gnupg 1.x, explicitly install dirmngr too
		apt-get install -y --no-install-recommends dirmngr; \
	fi; \
	rm -rf /var/lib/apt/lists/*

# add gosu for easy step-down from root
COPY gosu /usr/local/bin/
COPY gosu.asc /usr/local/bin/

# https://github.com/tianon/gosu/releases
RUN chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

RUN ls -lrt /usr/local/bin/

RUN mkdir /docker-entrypoint-initdb.d

# install "libjemalloc2" as it offers better performance in some cases. Use with LD_PRELOAD
# install "pwgen" for randomizing passwords
# install "tzdata" for /usr/share/zoneinfo/
# install "xz-utils" for .sql.xz docker-entrypoint-initdb.d files
# install "zstd" for .sql.zst docker-entrypoint-initdb.d files
RUN set -ex; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		libjemalloc2 \
		pwgen \
		tzdata \
        libc6 \
		xz-utils \
		zstd \
	; \
	rm -rf /var/lib/apt/lists/*

ARG GPG_KEYS=B42F6819007F00F88E364FD4036A9C25BF357DD4
# pub   rsa4096 2016-03-30 [SC]
#         177F 4010 FE56 CA33 3630  0305 F165 6F24 C74C D1D8
# uid           [ unknown] MariaDB Signing Key <signing-key@mariadb.org>
# sub   rsa4096 2016-03-30 [E]

RUN set -ex; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $GPG_KEYS; do \
		gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	done; \
	gpg --batch --export $GPG_KEYS > /etc/apt/trusted.gpg.d/mariadb.gpg; \
	command -v gpgconf > /dev/null && gpgconf --kill all || :; \
	rm -fr "$GNUPGHOME"; \
	apt-key list

# bashbrew-architectures: amd64 arm64v8 ppc64le
ARG MARIADB_MAJOR=11.3
ENV MARIADB_MAJOR $MARIADB_MAJOR
ARG MARIADB_VERSION=1:11.3.2+maria~focal
ENV MARIADB_VERSION $MARIADB_VERSION
# release-status:Stable
# (https://downloads.mariadb.org/mariadb/+releases/)

# Allowing overriding of REPOSITORY, a URL that includes suite and component for testing and Enterprise Versions
ARG REPOSITORY="http://archive.mariadb.org/mariadb-10.6.4/repo/ubuntu/ focal main"

#RUN set -e;\
#	echo "deb ${REPOSITORY}" > /etc/apt/sources.list.d/mariadb.list; \
#	{ \
#		echo 'Package: *'; \
#		echo 'Pin: release o=MariaDB'; \
#		echo 'Pin-Priority: 999'; \
#	} > /etc/apt/preferences.d/mariadb
# add repository pinning to make sure dependencies from this MariaDB repo are preferred over Debian dependencies
#  libmariadbclient18 : Depends: libmysqlclient18 (= 5.5.42+maria-1~wheezy) but 5.5.43-0+deb7u1 is to be installed

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
RUN set -ex; \
	{ \
		echo "mariadb-server-$MARIADB_MAJOR" mysql-server/root_password password 'unused'; \
		echo "mariadb-server-$MARIADB_MAJOR" mysql-server/root_password_again password 'unused'; \
	} | debconf-set-selections; \
	apt-get update;


RUN apt-get install -y curl libdbi-perl rsync socat libnuma1 libaio1 zlib1g-dev libreadline5 libjemalloc2 libsnappy1v5 libcrack2 apt-utils

#RUN apt-get install -y galera4

COPY *.deb /root/
RUN chmod 777 /root/*

RUN dpkg --install /root/mysql-common*
RUN dpkg --install /root/mariadb-common*
RUN dpkg -R --unpack /root/
RUN apt-get -o Debug::pkgProblemResolver=true install -f -y

RUN apt-get install -y \
# mariadb-backup is installed at the same time so that `mysql-common` is only installed once from just mariadb repos
		mariadb-backup \
		socat \
	; \
	rm -rf /var/lib/apt/lists/*; \
# purge and re-create /var/lib/mysql with appropriate ownership
	rm -rf /var/lib/mysql; \
	mkdir -p /var/lib/mysql /var/run/mysqld; \
	chown -R mysql:mysql /var/lib/mysql /var/run/mysqld; \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	chmod 777 /var/run/mysqld; \
# comment out a few problematic configuration values
	find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user\s)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user\s)/#&/'; \
# don't reverse lookup hostnames, they are usually another container
# Issue #327 Correct order of reading directories /etc/mysql/mariadb.conf.d before /etc/mysql/conf.d (mount-point per documentation)
	if [ ! -L /etc/mysql/my.cnf ]; then sed -i -e '/includedir/i[mariadb]\nskip-host-cache\nskip-name-resolve\n' /etc/mysql/my.cnf; \
# 10.5+
	else sed -i -e '/includedir/ {N;s/\(.*\)\n\(.*\)/[mariadbd]\nskip-host-cache\nskip-name-resolve\n\n\2\n\1/}' \
                /etc/mysql/mariadb.cnf; fi


VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh;
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]
