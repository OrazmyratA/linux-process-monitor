#!/bin/bash

# --- Конфигурация ---
LOG_FILE="/var/log/monitoring.log"
MONITORING_URL="https://test.com/monitoring/test/api"
PROCESS_NAME="test"
PID_FILE="/var/run/monitoring_test_process.pid" # Используем /var/run/ для временных файлов
# --- Конец Конфигурации ---

# --- Функция для записи в лог ---
log_message() {
    local message="$1"
    # Проверяем, есть ли права на запись в директорию лог-файла.
    # systemd может создать файл, но если директория не существует или нет прав,
    # запись может не удастся.
    if [ -w "$(dirname "$LOG_FILE")" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    else
        # Если нет прав, пишем в stderr, systemd подхватит это.
        echo "CRITICAL: Cannot write to log file $LOG_FILE. Check permissions." >&2
    fi
}

# --- Основная логика мониторинга ---

# 1. Проверяем, запущен ли процесс
CURRENT_PID=$(pgrep -x "$PROCESS_NAME")

if [ -n "$CURRENT_PID" ]; then
    # Процесс запущен

    RESTARTED=false # Флаг для отслеживания перезапуска

    # 2. Отслеживаем перезапуск процесса
    if [ -f "$PID_FILE" ]; then
        # Если файл с PID существует, читаем его
        PREVIOUS_PID=$(cat "$PID_FILE")
        if [ "$PREVIOUS_PID" != "$CURRENT_PID" ]; then
            # PID изменился - это значит, процесс был перезапущен
            log_message "Process '$PROCESS_NAME' was restarted. Old PID: $PREVIOUS_PID, New PID: $CURRENT_PID"
            RESTARTED=true
        # else
            # PID не изменился, процесс продолжает работать.
            # По заданию, логируем только перезапуск, поэтому эту строку можно закомментировать.
            # log_message "Process '$PROCESS_NAME' is running (no restart detected). PID: $CURRENT_PID"
        fi
    else
        # Файл с PID не существует. Это либо первый запуск, либо PID_FILE был удален.
        # Считаем это случаем, когда нужно записать в лог, что процесс запущен.
        log_message "Process '$PROCESS_NAME' started or PID file was missing. PID: $CURRENT_PID"
        RESTARTED=true # Отмечаем как "перезапуск" для обновления PID_FILE
    fi

    # 3. Обновляем PID_FILE, если процесс был перезапущен или это первый запуск
    if [ "$RESTARTED" = true ]; then
        echo "$CURRENT_PID" > "$PID_FILE"
    fi

    # 4. Отправляем HTTPS-запрос на сервер мониторинга
    # -s: silent (без прогресса)
    # -o /dev/null: сбрасываем вывод ответа (нам не нужен сам ответ, только статус)
    # -w "%{http_code}": выводим только HTTP код ответа
    # --connect-timeout 5: таймаут на установку соединения (5 секунд)
    # --max-time 10: общий таймаут на запрос (10 секунд)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$MONITORING_URL")
    CURL_EXIT_CODE=$? # Код возврата curl

    if [ "$CURL_EXIT_CODE" -ne 0 ]; then
        # Ошибка выполнения curl (например, таймаут, недоступен сервер, ошибка DNS)
        log_message "Failed to connect to monitoring server '$MONITORING_URL'. Curl exit code: $CURL_EXIT_CODE. HTTP Code: $HTTP_CODE"
    elif [ "$HTTP_CODE" != "200" ]; then
        # Сервер доступен, но вернул ошибку (не 200 OK)
        log_message "Monitoring server '$MONITORING_URL' returned an error. HTTP Code: $HTTP_CODE"
    # else
        # Все хорошо. Сервер доступен и вернул 200 OK.
        # По заданию, если процесс запущен и сервер доступен, ничего не делаем (т.е. не пишем в лог).
        # log_message "Monitoring server '$MONITORING_URL' is accessible. HTTP Code: $HTTP_CODE"
    fi

else
    # Процесс не запущен
    # Если PID_FILE существует, а процесса нет, значит процесс упал.
    # Удаляем PID_FILE, чтобы при следующем запуске он считался "первым".
    if [ -f "$PID_FILE" ]; then
        log_message "Process '$PROCESS_NAME' is NOT running. Removing stale PID file '$PID_FILE'."
        rm -f "$PID_FILE"
    fi
    # По условию, если процесс не запущен, то ничего не делаем.
    # log_message "Process '$PROCESS_NAME' is NOT running."
fi

exit 0
