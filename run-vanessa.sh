#!/bin/bash
# Headless-прогон Vanessa Automation внутри контейнера (RUN_MODE=vatest).
# Все параметры передаются через переменные окружения (см. docker-compose.yml).
# Скрипт формирует рабочий params.json из шаблона (подстановка ИБ, учётных
# данных, тегов и каталогов вывода) и запускает 1cv8c в режиме TESTMANAGER.
set -uo pipefail

# --- Платформа / бинарь тонкого клиента ---
PLATFORM_VER="${PLATFORM_VER:-8.3.27.2074}"
ONEC_BIN="${ONEC_BIN:-/opt/1cv8/x86_64/${PLATFORM_VER}/1cv8c}"

# --- Расположение репозитория и артефактов ---
REPO="${REPO:-/workspace}"
FEATURES="${FEATURES:-$REPO/tests/e2etests}"
TOOLS="${TOOLS:-$REPO/tools}"
VA_EPF="${VA_EPF:-$TOOLS/vanessa-automation-single.epf}"
# Шаблон параметров VA. По умолчанию — существующий VAParams.json из репозитория
# (единый источник истины); все Linux-специфичные значения переопределяются ниже.
PARAMS_TEMPLATE="${PARAMS_TEMPLATE:-$REPO/VAParams.json}"
OUT="${OUT:-/out}"

# --- Подключение к информационной базе ---
IB_SRV="${IB_SRV:?need IB_SRV}"
IB_REF="${IB_REF:?need IB_REF}"
IB_USER="${IB_USER:-}"
IB_PWD="${IB_PWD:-}"

# --- Отбор сценариев по тегам (списки через запятую/пробел) ---
VA_TAGS="${VA_TAGS:-}"
VA_EXCLUDE_TAGS="${VA_EXCLUDE_TAGS:-}"

TESTCLIENT_PORT="${TESTCLIENT_PORT:-48010}"
WAIT_TIMEOUT_MIN="${WAIT_TIMEOUT_MIN:-120}"

export DISPLAY="${DISPLAY:-:0}"

if [ ! -x "$ONEC_BIN" ]; then
  echo "FAILED: не найден бинарь тонкого клиента: $ONEC_BIN" >&2
  exit 2
fi
if [ ! -f "$PARAMS_TEMPLATE" ]; then
  echo "FAILED: не найден шаблон параметров: $PARAMS_TEMPLATE" >&2
  exit 2
fi

mkdir -p "$OUT/.allure-results" "$OUT/.screenshots" "$OUT/logs"
BUILD_STATUS="$OUT/BuildStatus.log"
rm -f "$BUILD_STATUS"

# --- Преобразование списка тегов в JSON-массив: "a,b c" -> ["a","b","c"] ---
list_to_json() {
  local raw="${1//,/ }"
  local arr="[]" t
  for t in $raw; do
    arr="$(jq -c --arg t "$t" '. + [$t]' <<<"$arr")"
  done
  echo "$arr"
}
TAGS_JSON="$(list_to_json "$VA_TAGS")"
EXCLUDE_JSON="$(list_to_json "$VA_EXCLUDE_TAGS")"

# --- Готовим рабочий params.json ---
# 1С допускает завершающие запятые в JSON, а jq — нет. Убираем их перед разбором.
CLEAN_PARAMS="/tmp/VAParams.src.json"
sed -E ':a;N;$!ba;s/,([[:space:]]*[]}])/\1/g' "$PARAMS_TEMPLATE" > "$CLEAN_PARAMS"

RUN_PARAMS="/tmp/VAParams.run.json"
jq \
  --arg ib "Srvr=\"$IB_SRV\";Ref=\"$IB_REF\";" \
  --arg dop "/N\"$IB_USER\" /P\"$IB_PWD\" " \
  --argjson port "$TESTCLIENT_PORT" \
  --argjson tags "$TAGS_JSON" \
  --argjson extags "$EXCLUDE_JSON" \
  --arg allure "$OUT/.allure-results" \
  --arg junit "$OUT" \
  --arg screens "$OUT/.screenshots" \
  '
     ."КлиентТестирования"."ДанныеКлиентовТестирования"[0]."ПутьКИнфобазе" = $ib
   | ."КлиентТестирования"."ДанныеКлиентовТестирования"[0]."ДопПараметры" = $dop
   | ."КлиентТестирования"."ДанныеКлиентовТестирования"[0]."ПортЗапускаТестКлиента" = $port
   | ."КлиентТестирования"."ДанныеКлиентовТестирования"[0]."ИмяКомпьютера" = "localhost"
   | ."КлиентТестирования"."ДанныеКлиентовТестирования"[0]."ТипКлиента" = "Тонкий"
   | ."СписокТегов" = $tags
   | ."СписокТеговИсключение" = $extags
   | ."ОтчетAllure"."КаталогВыгрузкиAllure" = $allure
   | ."ОтчетJUnit"."КаталогВыгрузкиJUnit" = $junit
   | ."КаталогВыгрузкиСкриншотов" = $screens
   | ."КомандаСделатьСкриншот" = ""
   | ."ЗавершитьРаботуСистемы" = true
   | ."ЗакрытьTestClientПослеЗапускаСценариев" = true
  ' "$CLEAN_PARAMS" > "$RUN_PARAMS"

echo "=== Параметры прогона Vanessa Automation ==="
echo "  Клиент 1С:  $ONEC_BIN"
echo "  ИБ:         Srvr=$IB_SRV;Ref=$IB_REF (пользователь: ${IB_USER:-<пусто>})"
echo "  Теги вкл.:  $TAGS_JSON"
echo "  Теги искл.: $EXCLUDE_JSON"
echo "  Фичи:       $FEATURES"
echo "  Отчёты:     $OUT"
echo "  TestClient: localhost:$TESTCLIENT_PORT"

# --- Параметры запуска Vanessa Automation (ключ /C) ---
VA_C="StartFeaturePlayer"
VA_C="$VA_C;ВерсияПлатформыДляГенерацииEPF=/opt/1cv8/x86_64/${PLATFORM_VER}/"
VA_C="$VA_C;КаталогФич=${FEATURES}"
VA_C="$VA_C;КаталогиБиблиотек=${FEATURES}/ExportScenarios"
VA_C="$VA_C;КаталогОтносительноКоторогоНадоСтроитьИерархию=${FEATURES}"
VA_C="$VA_C;КаталогПроекта=${FEATURES}"
VA_C="$VA_C;ПутьКФайлуДляВыгрузкиСтатусаВыполненияСценариев=${BUILD_STATUS}"
VA_C="$VA_C;ИмяКаталогаЛогОшибок=${OUT}/logs"
VA_C="$VA_C;ИмяФайлаЛогВыполненияСценариев=${OUT}/logs/exec.log"
VA_C="$VA_C;КаталогВыгрузкиAllure=${OUT}/.allure-results"
VA_C="$VA_C;КаталогВыгрузкиJUnit=${OUT}"
VA_C="$VA_C;VAParams=${RUN_PARAMS}"

echo "=== Запуск TESTMANAGER ==="
ONEC_OUT="$OUT/logs/1c_out.log"
ONEC_CONSOLE="$OUT/logs/1c_console.log"
"$ONEC_BIN" ENTERPRISE \
  /IBConnectionString"Srvr=\"${IB_SRV}\";Ref=\"${IB_REF}\";" \
  /N"${IB_USER}" /P"${IB_PWD}" \
  /DisableStartupMessages /DisableStartupDialogs \
  /TESTMANAGER \
  /Execute "${VA_EPF}" \
  /C"${VA_C}" \
  /Out "$ONEC_OUT" >"$ONEC_CONSOLE" 2>&1 &
ONEC_PID=$!

echo "=== Ожидание завершения (до ${WAIT_TIMEOUT_MIN} мин) ==="
deadline=$(( $(date +%s) + WAIT_TIMEOUT_MIN * 60 ))
while kill -0 "$ONEC_PID" 2>/dev/null; do
  if [ -f "$BUILD_STATUS" ]; then
    # VA дописала файл статуса — даём процессу немного времени на самозакрытие
    sleep 5
    break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ТАЙМАУТ: превышено время ожидания прогона" >&2
    break
  fi
  sleep 10
done

# Гарантированно завершаем процесс, если он ещё жив
if kill -0 "$ONEC_PID" 2>/dev/null; then
  kill "$ONEC_PID" 2>/dev/null || true
  sleep 3
  kill -9 "$ONEC_PID" 2>/dev/null || true
fi

if [ ! -f "$BUILD_STATUS" ]; then
  echo "FAILED: файл статуса не создан ($BUILD_STATUS)" >&2
  echo "--- 1c_out.log ---" >&2; cat "${ONEC_OUT:-}" 2>/dev/null >&2 || true
  echo "--- 1c_console.log (tail) ---" >&2; tail -n 40 "${ONEC_CONSOLE:-}" 2>/dev/null >&2 || true
  exit 1
fi

echo "=== Содержимое BuildStatus.log ==="
cat "$BUILD_STATUS" || true
echo

# Ненулевой код возврата при признаках падений (окончательный вердикт — по junit в CI)
if grep -Eiq 'fail|ошиб|error|broken|provoke' "$BUILD_STATUS"; then
  echo "РЕЗУЛЬТАТ: обнаружены падения сценариев" >&2
  exit 1
fi

echo "РЕЗУЛЬТАТ: прогон завершён успешно"
exit 0
