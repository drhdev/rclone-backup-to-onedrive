#!/bin/bash

############################
# CONFIGURATION VARIABLES  #
############################

# Logging Configuration
#LOGFILE="/var/log/rclone_backup_to_onedrive.log"

# Backup Sources Configuration
declare -A BACKUP_PATHS=(
    ["/etc"]=true                   # /etc contains system-wide configuration files
    ["/var/www"]=true               # /var/www contains website files
    ["/var/lib"]=true               # /var/lib contains important application data
    ["/var/log"]=false              # /var/log contains log files (usually not needed)
    ["/var/spool"]=false            # /var/spool contains print jobs, mail queues, etc.
    ["/home"]=true                  # /home contains user directories
    ["/usr/local/bin"]=true         # /usr/local/bin contains custom scripts
    ["/var/backups/mysql"]=true     # /var/backups/mysql contains MySQL dumps
    ["/var/python"]=true            # /var/python contains Python project files
    ["/var/data"]=true              # /var/data contains data files
    ["/var/shared"]=true            # /var/shared contains shared files
)

# Backup Destination Configuration
CHOSENNAME=$(hostname)          # Change this to your preferred backup identifier like "myserver"
DATE=$(date +%Y%m%d%H%M%S)
LOCAL_BACKUP_DIR="/var/backups/rclone_backup_to_onedrive"
DAILY_BACKUP_DIR="onedrive:/backups/$CHOSENNAME/daily"
WEEKLY_BACKUP_DIR="onedrive:/backups/$CHOSENNAME/weekly"
MONTHLY_BACKUP_DIR="onedrive:/backups/$CHOSENNAME/monthly"

# Retention Periods Configuration (in days)
DAILY_RETENTION=7   # Keep daily backups for 7 days
WEEKLY_RETENTION=30 # Keep weekly backups for 30 days
MONTHLY_RETENTION=180 # Keep monthly backups for 6 months (approximately 180 days)

# Backup File Name Configuration
BACKUP_FILENAME="$DATE-$CHOSENNAME.tar.gz" # Example: 20230601123000-servername.tar.gz
# Customize backup file name by changing the above line, e.g.,
# BACKUP_FILENAME="$DATE-dailybackup.tar.gz"
# BACKUP_FILENAME="backup-$CHOSENNAME-$DATE.tar.gz"

############################
# SCRIPT LOGIC             #
############################

# Ensure the log file exists and has the correct permissions
#sudo touch $LOGFILE
#sudo chown backupuser:backupuser $LOGFILE
#sudo chmod 644 $LOGFILE

# Redirect output and errors to log file
#exec > >(sudo tee -a $LOGFILE)
#exec 2> >(sudo tee -a $LOGFILE >&2)

# Create backup directory if it doesn't exist
sudo mkdir -p $LOCAL_BACKUP_DIR

# Create OneDrive directories if they don't exist
rclone mkdir $DAILY_BACKUP_DIR
rclone mkdir $WEEKLY_BACKUP_DIR
rclone mkdir $MONTHLY_BACKUP_DIR

# Create tarball of the backup sources
TAR_CMD="sudo tar -czf $LOCAL_BACKUP_DIR/$BACKUP_FILENAME"
for path in "${!BACKUP_PATHS[@]}"; do
    if [ "${BACKUP_PATHS[$path]}" = true ]; then
        TAR_CMD+=" $path"
    fi
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
sudo find $LOCAL_BACKUP_DIR -type f -name "*.tar.gz*" -mtime +$DAILY_RETENTION -exec rm {} \;

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
