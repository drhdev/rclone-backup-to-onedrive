#!/bin/bash

############################
# CONFIGURATION VARIABLES  #
############################

# Logging
LOGFILE="/var/log/backup_to_onedrive.log"
exec > >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

# Backup sources
BACKUP_ETC=true                 # /etc contains system-wide configuration files
BACKUP_VAR_WWW=true             # /var/www contains website files
BACKUP_VAR_LIB=true             # /var/lib contains important application data
BACKUP_VAR_LOG=false            # /var/log contains log files (usually not needed)
BACKUP_VAR_SPOOL=false          # /var/spool contains print jobs, mail queues, etc.
BACKUP_HOME=true                # /home contains user directories
BACKUP_SCRIPTS=true             # /usr/local/bin contains custom scripts
BACKUP_MYSQL=true               # /var/backups/mysql contains MySQL dumps
BACKUP_VAR_PYTHON=true          # /var/python contains Python project files
BACKUP_VAR_DATA=true            # /var/data contains data files
BACKUP_VAR_SHARED=true          # /var/shared contains shared files

# Backup directories
BACKUP_SOURCES=()
[ "$BACKUP_ETC" = true ] && BACKUP_SOURCES+=("/etc")
[ "$BACKUP_VAR_WWW" = true ] && BACKUP_SOURCES+=("/var/www")
[ "$BACKUP_VAR_LIB" = true ] && BACKUP_SOURCES+=("/var/lib")
[ "$BACKUP_VAR_LOG" = true ] && BACKUP_SOURCES+=("/var/log")
[ "$BACKUP_VAR_SPOOL" = true ] && BACKUP_SOURCES+=("/var/spool")
[ "$BACKUP_HOME" = true ] && BACKUP_SOURCES+=("/home")
[ "$BACKUP_SCRIPTS" = true ] && BACKUP_SOURCES+=("/usr/local/bin")
[ "$BACKUP_MYSQL" = true ] && BACKUP_SOURCES+=("/var/backups/mysql")
[ "$BACKUP_VAR_PYTHON" = true ] && [ -d "/var/python" ] && BACKUP_SOURCES+=("/var/python")
[ "$BACKUP_VAR_DATA" = true ] && [ -d "/var/data" ] && BACKUP_SOURCES+=("/var/data")
[ "$BACKUP_VAR_SHARED" = true ] && [ -d "/var/shared" ] && BACKUP_SOURCES+=("/var/shared")

# Temporary backup directory (compressed tarballs are stored here temporarily before being uploaded to OneDrive)
LOCAL_BACKUP_DIR="/var/backups/backup_to_onedrive_local"

# OneDrive backup directories (requires prior setup of rclone)
CHOSENNAME=$(hostname)          # Change this to your preferred backup identifier like "myserver"
DATE=$(date +%Y%m%d%H%M%S)
DAILY_BACKUP_DIR="onedrive:/backups/$CHOSENNAME/daily"
WEEKLY_BACKUP_DIR="onedrive:/backups/$CHOSENNAME/weekly"
MONTHLY_BACKUP_DIR="onedrive:/backups/$CHOSENNAME/monthly"

# Retention periods (in days)
DAILY_RETENTION=7   # Keep daily backups for 7 days
WEEKLY_RETENTION=30 # Keep weekly backups for 30 days
MONTHLY_RETENTION=180 # Keep monthly backups for 6 months (approximately 180 days)

# Explanation:
# DAILY_RETENTION: Number of daily backups to keep. Backups older than this will be deleted.
# WEEKLY_RETENTION: Number of weekly backups to keep. Backups older than this will be deleted.
# MONTHLY_RETENTION: Number of monthly backups to keep. Backups older than this will be deleted.

# Backup file name configuration
BACKUP_FILENAME="$DATE-$CHOSENNAME.tar.gz" # Example: 20230601123000-servername.tar.gz
# You can customize the backup file name by changing the above line, e.g.,
# BACKUP_FILENAME="$DATE-dailybackup.tar.gz"
# BACKUP_FILENAME="backup-$CHOSENNAME-$DATE.tar.gz"

############################
# SCRIPT LOGIC             #
############################

# Create backup directory if it doesn't exist
mkdir -p $LOCAL_BACKUP_DIR

# Create OneDrive directories if they don't exist
rclone mkdir $DAILY_BACKUP_DIR
rclone mkdir $WEEKLY_BACKUP_DIR
rclone mkdir $MONTHLY_BACKUP_DIR

# Create tarball of the backup sources
TAR_CMD="sudo tar -czf $LOCAL_BACKUP_DIR/$BACKUP_FILENAME"
for src in "${BACKUP_SOURCES[@]}"; do
    TAR_CMD+=" $src"
done

eval $TAR_CMD 2>/dev/null

# Sync local backups to OneDrive with date-based versioning
rclone copy $LOCAL_BACKUP_DIR/$BACKUP_FILENAME $DAILY_BACKUP_DIR/

# Move daily backups to weekly and monthly
if [ $(date +%u) -eq 7 ]; then
    rclone move $DAILY_BACKUP_DIR/ $WEEKLY_BACKUP_DIR/
fi

if [ $(date +%d) -eq 01 ]; then
    rclone move $WEEKLY_BACKUP_DIR/ $MONTHLY_BACKUP_DIR/
fi

# Remove local backup files older than the daily retention period
find $LOCAL_BACKUP_DIR -type f -name "*.tar.gz*" -mtime +$DAILY_RETENTION -exec rm {} \;

# Cleanup remote backups older than retention periods
rclone delete --min-age ${DAILY_RETENTION}d $DAILY_BACKUP_DIR/
rclone delete --min-age ${WEEKLY_RETENTION}d $WEEKLY_BACKUP_DIR/
rclone delete --min-age ${MONTHLY_RETENTION}d $MONTHLY_BACKUP_DIR/

############################
# RESTORATION INSTRUCTIONS #
############################

# To restore backups manually, follow these instructions:

# 1. List available backups on OneDrive:
#    rclone lsf onedrive:/backups/$CHOSENNAME/daily/
#    rclone lsf onedrive:/backups/$CHOSENNAME/weekly/
#    rclone lsf onedrive:/backups/$CHOSENNAME/monthly/

# 2. Copy the desired backup from OneDrive to the local system:
#    rclone copy onedrive:/backups/$CHOSENNAME/daily/20230601123000-servername.tar.gz /path/to/restore/
#    rclone copy onedrive:/backups/$CHOSENNAME/weekly/20230601123000-servername.tar.gz /path/to/restore/
#    rclone copy onedrive:/backups/$CHOSENNAME/monthly/20230601123000-servername.tar.gz /path/to/restore/

# 3. Extract the tar.gz file to restore the files:
#    sudo tar -xzf /path/to/restore/20230601123000-servername.tar.gz -C /path/to/restore/

# Example 1: Restore the latest daily backup
#    rclone copy onedrive:/backups/$CHOSENNAME/daily/20230601123000-servername.tar.gz /var/restores/
#    sudo tar -xzf /var/restores/20230601123000-servername.tar.gz -C /var/restores/

# Example 2: Restore a specific weekly backup from OneDrive
#    rclone copy onedrive:/backups/$CHOSENNAME/weekly/20230601123000-servername.tar.gz /var/restores/
#    sudo tar -xzf /var/restores/20230601123000-servername.tar.gz -C /var/restores/

# Example 3: Restore a specific monthly backup and extract it to the original locations
#    rclone copy onedrive:/backups/$CHOSENNAME/monthly/20230601123000-servername.tar.gz /var/restores/
#    sudo tar -xzf /var/restores/20230601123000-servername.tar.gz -C /

# Note: Ensure you have the correct permissions to restore files to the desired locations.
