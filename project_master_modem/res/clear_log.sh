#!/bin/ash

LOG_FILE="/etc/project_master_modem/res/script.log"
MAX_SIZE_BYTES="1500000"  # Maximum file size in bytes (1.5MB)
TMP_FILE="/tmp/script.log.tmp"  # Temporary file path in /tmp/

# Check if the log file exists
if [ -f "$LOG_FILE" ]; then
    # Get the current size of the log file in bytes using ls
    CURRENT_SIZE_BYTES=$(ls -l "$LOG_FILE" | awk '{print $5}')

    # Compare the current size to the maximum size
    if [ "$CURRENT_SIZE_BYTES" -gt "$MAX_SIZE_BYTES" ]; then
        # Calculate the number of bytes to keep (remove 20% of the file)
        BYTES_TO_KEEP=$((CURRENT_SIZE_BYTES * 80 / 100))

        # Use dd to truncate the log file while keeping 80% of its size
        dd if="$LOG_FILE" of="$TMP_FILE" bs=1 count="$BYTES_TO_KEEP" skip=1
        mv "$TMP_FILE" "$LOG_FILE"

        date +"%Y-%m-%d %H:%M:%S" > /tmp/last_time_log_trimmed.txt
        echo "File truncated."
    else
        echo "File size is within the limit."
    fi
else
    echo "Log file does not exist."
fi
