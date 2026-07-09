#!/bin/bash
set -e

echo "=== Запуск виртуального экрана Xvfb ==="
# Запускаем X-сервер в фоне
Xvfb :0 -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24" &
# Даем ему 2 секунды на инициализацию
sleep 2

echo "=== Запуск VNC-сервера (порт 5900) ==="
# Пароль VNC задаётся через переменную окружения VNC_PASSWORD.
# Если она не задана — сервер поднимается без пароля (-nopw).
if [ -n "${VNC_PASSWORD:-}" ]; then
  mkdir -p "$HOME/.vnc"
  x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null 2>&1 || true
  x11vnc -forever -shared -rfbauth "$HOME/.vnc/passwd" -display :0 &
else
  echo "ВНИМАНИЕ: VNC_PASSWORD не задан — VNC работает без пароля (-nopw)"
  x11vnc -forever -shared -nopw -display :0 &
fi
sleep 1

# Режим работы контейнера:
#   RUN_MODE=interactive (по умолчанию) — интерактивная VNC-станция с лаунчером 1С.
#   RUN_MODE=vatest        — headless-прогон Vanessa Automation через /run-vanessa.sh.
if [ "${RUN_MODE:-interactive}" = "vatest" ]; then
  echo "=== Режим vatest: запуск Vanessa Automation ==="
  exec /run-vanessa.sh
else
  echo "=== Запуск платформы 1С:Предприятие (интерактивно) ==="
  # 1cestart форкает процесс запуска (1cv8s) и сразу завершается,
  # поэтому запускаем его в фоне и держим контейнер живым, пока работают Xvfb и VNC.
  /opt/1cv8/common/1cestart &
  # Контейнер живёт, пока работает виртуальный экран и VNC-сервер
  wait
fi
