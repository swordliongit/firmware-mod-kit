#!/bin/ash

date +"%Y-%m-%d %H:%M:%S" > /tmp/script_execution_time.txt

LOG_FILE="/tmp/script.log"
MAX_SIZE_BYTES="5000000" # Maximum file size in bytes (1M)

# Check if the log file exists
if [ -f "$LOG_FILE" ]; then
    # Get the current size of the log file in bytes using ls
    CURRENT_SIZE_BYTES=$(ls -l "$LOG_FILE" | awk '{print $5}')

    # Debug output
    echo "Current size: $CURRENT_SIZE_BYTES bytes"
    echo "Max size: $MAX_SIZE_BYTES bytes"

    # Compare the current size to the maximum size
    if [ "$CURRENT_SIZE_BYTES" -gt "$MAX_SIZE_BYTES" ]; then
        # Calculate the number of bytes to keep (remove the first half)
        BYTES_TO_KEEP=$((CURRENT_SIZE_BYTES / 2))
        echo "Bytes to keep: $BYTES_TO_KEEP bytes"

        # Use dd to truncate the log file while keeping the last half
        dd if="$LOG_FILE" of="$LOG_FILE.tmp" bs="$BYTES_TO_KEEP" count=1
        mv "$LOG_FILE.tmp" "$LOG_FILE"
        echo "File truncated."
    else
        echo "File size is within the limit."
    fi
else
    echo "Log file does not exist."
fi
