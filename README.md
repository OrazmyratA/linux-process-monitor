# Linux Process Monitor

This script monitors the 'test' process and sends HTTP requests to a monitoring endpoint. It uses systemd to run periodically.

## Features:
*   Checks for the presence of the 'test' process every minute.
*   Sends an HTTPS request to `https://test.com/monitoring/test/api` if the process is running.
*   Logs process restarts and monitoring server errors to `/var/log/monitoring.log`.
*   Configured to run as a systemd service.

## Requirements:
*   `bash`
*   `pgrep`
*   `curl`
*   `systemd`
*   Root privileges for installation and systemd setup.

## Installation:

1.  **Clone the repository:**
    ```bash
    git clone <URL_ВАШЕГО_РЕПОЗИТОРИЯ>
    cd <имя_вашего_репозитория>
    ```

2.  **Move the monitoring script to a system directory:**
    ```bash
    sudo mv monitor_test_process.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/monitor_test_process.sh
    ```

3.  **Install systemd units:**
    ```bash
    sudo cp monitoring-test.service monitoring-test.timer /etc/systemd/system/
    ```

4.  **Reload systemd and enable the timer:**
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable monitoring-test.timer
    sudo systemctl start monitoring-test.timer
    ```

5.  **Check status:**
    ```bash
    systemctl status monitoring-test.timer
    systemctl status monitoring-test.service
    tail -f /var/log/monitoring.log
    ```

6.  **Create the 'test' process:**
    The script monitors a process named 'test'. You need to ensure this process is running. For testing, you can use:
    ```bash
    # As root or with sudo
    nohup sh -c 'exec -a test sleep 3600' &
    ```
    (Note: Ensure your bash version supports `exec -a` or adapt the script/process creation accordingly.)

## Configuration:
Edit the `monitor_test_process.sh` script to change `MONITORING_URL`, `PROCESS_NAME`, `LOG_FILE`, or `PID_FILE`.

## Troubleshooting:
*   Check logs: `tail -f /var/log/monitoring.log`
*   Check systemd status: `systemctl status monitoring-test.service` and `systemctl status monitoring-test.timer`
*   Ensure `curl` is installed: `sudo apt update && sudo apt install curl`
