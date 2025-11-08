FROM ubuntu:24.04
LABEL maintainer="savilovoa"

# Устанавливаем переменные окружения для локали и таймзоны
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=ru_RU.UTF-8 \
    LANGUAGE="ru_RU:ru:en_US:en" \
    LC_ALL=ru_RU.UTF-8 \
    TZ=Europe/Moscow

# ARGs для пользователя 1С
ARG onec_uid="999"
ARG onec_gid="999"

RUN set -xe && \
    apt-get update && \
    # Принимаем лицензию EULA для mscorefonts
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections && \
    # Установка всех пакетов одним списком
    apt-get install --yes --no-install-recommends \
        # Системные утилиты
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
        zip \
        # Шрифты и зависимости
        ttf-mscorefonts-installer \
        libfreetype6 \
        libfontconfig1 \
        # Зависимости GTK/X11 (без дубликатов)
        libglib2.0-0 \
        dbus-x11 \
        libgl1 \
        libglx0 \
        libgtk-3-0 \
        libgtk2.0-0 \
        libwebkitgtk-6.0-4 \
        libgsf-1-114 \
        libx11-6 \
        libxext6 \
        libxcursor1 \
        libxrandr2 \
        libxcomposite1 \
        libxss1 \
        libxtst6 \
        xvfb \
        libasound2t64 \
        libpng16-16 \
        libtcmalloc-minimal4 \
        libxinerama1 \
        x11-utils \
        x11-xserver-utils \
        # ODBC
        libodbc2 \
        # XFCE (Remote Desktop)
        mousepad \
        xfce4 \
        xfce4-terminal \
        xfce4-goodies \
        # VNC Server
        tigervnc-standalone-server \
        tigervnc-common \
    && \
# --- НАСТРОЙКА ЛОКАЛИ ---
    # (Выполняется здесь же, т.к. locales уже установлены)
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 LANGUAGE="ru_RU:ru:en_US:en" && \
    # --- НАСТРОЙКА ТАЙМЗОНЫ ---
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    # --- ОЧИСТКА ---
    apt-get -qq purge -y pm-utils screensaver* && \
    update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper && \
    # Финальная очистка кэша (исправлен путь /var/lib/apt/lists/*)
    rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

# --- УСТАНОВКА 1C ---
# Добавлена команда COPY для deb-пакетов 1C
# (Предполагается, что они лежат рядом с Dockerfile)
COPY 1c-enterprise*.deb /tmp/
COPY entrypoint.sh /usr/local/bin/

# Устанавливаем 1С и сразу создаем конфиг в одном слое
RUN set -xe && \
    dpkg --install /tmp/1c-enterprise*.deb && \
    # Создаем директорию, если она не создалась
    mkdir -p /opt/1cv8/conf && \
    echo "SystemLanguage=RU" >> /opt/1cv8/conf/conf.cfg && \
    echo "DisableUnsafeActionProtection=*" >> /opt/1cv8/conf/conf.cfg && \
    # Делаем entrypoint исполняемым
    chmod +x /usr/local/bin/entrypoint.sh && \
    # Очищаем /tmp
    rm -f /tmp/*.deb

# --- НАСТРОЙКА ПОЛЬЗОВАТЕЛЯ ---
RUN set -xe && \
    groupadd -r grp1cv8 --gid=$onec_gid && \
    useradd -r -g grp1cv8 --uid=$onec_uid --home-dir=/home/usr1cv8 --shell=/bin/bash usr1cv8 && \
    mkdir -p /home/usr1cv8/.1cv8 && \
    mkdir -p /home/usr1cv8/.vnc && \
    chown -R usr1cv8:grp1cv8 /home/usr1cv8

# --- НАСТРОЙКА VNC ---
USER usr1cv8
WORKDIR /home/usr1cv8

# Установка пароля VNC (по умолчанию: 1c_vnc_pass)
RUN mkdir -p ~/.vnc && \
    echo "1c_vnc_pass" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# Создаем xstartup для запуска XFCE
RUN echo '#!/bin/sh' > ~/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> ~/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> ~/.vnc/xstartup && \
    echo 'exec startxfce4' >> ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

VOLUME /home/usr1cv8/.1cv8

# Порт VNC
EXPOSE 5901

# Запускаем через entrypoint (VNC + 1cv8c)
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []

