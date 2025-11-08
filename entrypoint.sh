#!/bin/bash
set -e

# Запускаем VNC сервер в фоне
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no

# Ждем запуска VNC
sleep 2

# Устанавливаем DISPLAY для X11
export DISPLAY=:1

# Запускаем 1cv8c (передаем все аргументы из командной строки)
exec /opt/1cv8/x86_64/1cv8c "$@"
