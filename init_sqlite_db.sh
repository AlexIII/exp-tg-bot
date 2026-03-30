set -e

if test -f $EXPBOT_DB_FILE_PATH; then
    echo "Database file $EXPBOT_DB_FILE_PATH exists. Skipping initialization."
else
    if [ -z "$EXPBOT_DB_FILE_PATH" ]; then
        echo "Error: EXPBOT_DB_FILE_PATH environment variable is not set."
        exit 1
    fi
    echo "Initializing SQLite database..."
    sqlite3 $EXPBOT_DB_FILE_PATH < ./schema.sql
    echo "Database initialized successfully."
fi
