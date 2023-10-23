#!/bin/ash

date +"%Y-%m-%d %H:%M:%S" > /tmp/script_execution_time.txt

LOG_FILE="/tmp/script.log"
MAX_SIZE_BYTES="1000000" # Maximum file size in bytes (1M)

# Check if the log file exists
if [ -f "$LOG_FILE" ]; then
    # Get the current size of the log file in bytes using ls
    CURRENT_SIZE_BYTES=$(ls -l "$LOG_FILE" | awk '{print $5}')

    # Compare the current size to the maximum size
    if [ "$CURRENT_SIZE_BYTES" -gt "$MAX_SIZE_BYTES" ]; then
        # Calculate the number of bytes to keep (remove the first half)
        BYTES_TO_KEEP=$((CURRENT_SIZE_BYTES / 2))

        # Use dd to truncate the log file while keeping the last half
        dd if="$LOG_FILE" of="$LOG_FILE.tmp" bs="$BYTES_TO_KEEP" count=1
        mv "$LOG_FILE.tmp" "$LOG_FILE"
        echo "\n\n[MAIN] File truncated." >> /tmp/script.log
    else
        echo "\n\n[MAIN] File size is within the limit."  >> /tmp/script.log
    fi
else
    echo "\n\n[MAIN] Log file does not exist."  >> /tmp/script.log
fi
