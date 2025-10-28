FROM ubuntu
MAINTAINER savilovoa
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
	ca-certificates \
	wget \
	locales \
	language-pack-ru \
	tzdata \
	p7zip-rar \
	p7zip-full \
	git \
	curl \
	sudo \
	nano \
	unzip \
	zip
  && rm -rf \
	/var/lib/api/lists/* \
	/var/cache/debconf \
	/tmp/*

RUN set -xe &&
	echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections && \
	apt-get update && \
	apt-get install --yes --no-install-recommends \
	ttf-mscorefonts-installer \
	libfreetype6 \
	libfontconfig1 \
	libglib2.0-0 \
	dbus-x11 \
	libgl1 \
	libglx0 \
	libgtk-3-0 \
	libgtk2.0-0 \
	libwebkitgtk-3.0-0 \
	libgsf-1-114





RUN localedef --inputfile ru_RU --force --charmap UTF-8 --alias-file /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.utf8

libgsf-1-114
ENV PLATFORM_VERSION 83
ENV SERVER_VERSION 8.3.12-1595
RUN dpkg --install /tmp/1c-enterprise$PLATFORM_VERSION-common_${SERVER_VERSION}_amd64.deb 2> /dev/null \
  && dpkg --install /tmp/1c-enterprise$PLATFORM_VERSION-server_${SERVER_VERSION}_amd64.deb 2> /dev/null \
  && dpkg --install /tmp/1c-enterprise$PLATFORM_VERSION-ws_${SERVER_VERSION}_amd64.deb 2> /dev/null \
  && rm /tmp/*.deb \
  && mkdir --parent /var/log/1C /home/usr1cv8/.1cv8/1C/1cv8/conf \
  && chown --recursive usr1cv8:grp1cv8 /var/log/1C /home/usr1cv8

COPY container/docker-entrypoint.sh /
COPY container/logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf

ENTRYPOINT ["/docker-entrypoint.sh"]

VOLUME /home/usr1cv8
VOLUME /var/log/1C

EXPOSE 1540-1541 1560-1591

CMD ["ragent"]
