# Сразу собираем всё на чистой Ubuntu 24.04
FROM ubuntu:24.04

USER root
ENV DEBIAN_FRONTEND=noninteractive

# 1. Системные пакеты, локали и зависимости для графики 1С
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     dirmngr \
     gnupg \
     software-properties-common \
     locales \
     dos2unix \
     ca-certificates \
     fontconfig \
     fonts-liberation \
     # Современная библиотека WebKit для Ubuntu 24.04 (нужна для 1С)
     libwebkit2gtk-4.1-0 \
  && apt-add-repository multiverse \
  && apt-get update \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && apt-get install -y --no-install-recommends \
      at-spi2-core \
      procps \
      jq \
      xvfb \
      x11vnc \
      ttf-mscorefonts-installer \
      libglu1-mesa \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf \
  && locale-gen ru_RU.UTF-8

ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# 2. Создаем пользователя и группу 1С (используем ID > 1000 для Ubuntu 24.04)
RUN groupadd -r grp1cv8 --gid=1098 \
  && useradd -r -g grp1cv8 --uid=1098 --home-dir=/home/usr1cv8 --shell=/bin/bash usr1cv8 \
  && mkdir -p /home/usr1cv8/.1cv8 \
  && mkdir -p /home/usr1cv8/.1C/1cestart \
  && touch /home/usr1cv8/.1C/1cestart/ibases.v8i \
  && chown -R usr1cv8:grp1cv8 /home/usr1cv8

# 3. Копируем файлы .deb из папки dist и УСТАНАВЛИВАЕМ их
COPY dist/*.deb /tmp/onec/
RUN dpkg -i /tmp/onec/*.deb || apt-get update && apt-get install -y -f \
  && rm -rf /tmp/onec/ /var/lib/apt/lists/*

# 4. Копируем и настраиваем скрипты запуска
COPY ./entrypoint.sh /entrypoint.sh
COPY ./run-vanessa.sh /run-vanessa.sh
RUN chmod +x /entrypoint.sh /run-vanessa.sh && dos2unix /entrypoint.sh /run-vanessa.sh

ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1440
ENV DISPLAY_HEIGHT=900

EXPOSE 5900

USER usr1cv8
ENTRYPOINT ["/entrypoint.sh"]
