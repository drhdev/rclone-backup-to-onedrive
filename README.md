# rclone-backup-to-onedrive
A simple bash script and instructions how to backup an Ubuntu Server to OneDrive with a dedicated backupuser.

### 1. Description of the Script

The `rclone_backup_to_onedrive.sh` script automates the process of backing up specified directories and files from an Ubuntu server to OneDrive using `rclone`. It supports daily, weekly, and monthly backup retention policies, configurable by the user. The script also handles automatic deletion of old backups based on user-defined retention periods.

**Parameters that can be set up:**
- `LOGFILE`: Path to the log file.
- `BACKUP_ETC`, `BACKUP_VAR_WWW`, etc.: Boolean values to specify which directories to include in the backup.
- `LOCAL_BACKUP_DIR`: Local directory to store temporary backup files.
- `CHOSENNAME`: Identifier for the backup, typically the hostname.
- `DAILY_BACKUP_DIR`, `WEEKLY_BACKUP_DIR`, `MONTHLY_BACKUP_DIR`: OneDrive paths for storing backups.
- `DAILY_RETENTION`, `WEEKLY_RETENTION`, `MONTHLY_RETENTION`: Retention periods for daily, weekly, and monthly backups.
- `BACKUP_FILENAME`: Format of the backup file name.

### 2. Detailed Setup Instructions

#### Step 1: Create a Backup User

1. **Create the backup user:**
   ```bash
   sudo adduser backupuser
   ```

2. **Add the user to the sudo group:**
   ```bash
   sudo usermod -aG sudo backupuser
   ```

#### Step 2: Copy and Edit the Script

1. **Switch to the backupuser:**
   ```bash
   sudo su - backupuser
   ```

2. **Create the script file:**
   ```bash
   nano /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

3. **Copy and paste the script into the file and save it (Ctrl+X, then Y, then Enter).**

4. **Make the script executable:**
   ```bash
   sudo chmod +x /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

#### Step 3: Allow Password-less Sudo for the Script

1. **Edit the sudoers file:**
   ```bash
   sudo visudo
   ```

2. **Add the following line:**
   ```plaintext
   backupuser ALL=(ALL) NOPASSWD: /usr/local/bin/rclone_backup_to_onedrive.sh, /usr/bin/rclone, /bin/tar
   ```

#### Step 4: Set Up `rclone` for OneDrive

1. **Install rclone:**
   ```bash
   sudo apt install rclone
   ```

2. **Configure rclone:**
   ```bash
   rclone config
   ```
   Follow the prompts to set up OneDrive.

#### Step 5: Run the Script Manually

1. **Run the script manually:**
   ```bash
   sudo -u backupuser /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

#### Step 6: Set Up Cron Job

1. **Edit the crontab for backupuser:**
   ```bash
   sudo crontab -u backupuser -e
   ```

2. **Add the following line to run the script daily at 2 AM:**
   ```plaintext
   0 2 * * * /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

#### Step 7: Set Up Logrotate

1. **Create a logrotate configuration file:**
   ```bash
   sudo nano /etc/logrotate.d/rclone_backup_to_onedrive
   ```

2. **Add the following content:**
   ```plaintext
   /var/log/backup_to_onedrive.log {
       daily
       rotate 7
       compress
       missingok
       notifempty
       create 0640 backupuser backupuser
       sharedscripts
       postrotate
           /usr/sbin/service cron reload > /dev/null
       endscript
   }
   ```

#### Step 8: Testing the `rclone` Connection

1. **Test the `rclone` connection:**
   ```bash
   rclone lsf onedrive:/
   ```

#### Step 9: Finding Errors in Log Files

1. **Check the log file for errors:**
   ```bash
   cat /var/log/backup_to_onedrive.log
   ```

#### Step 10: Restoring Backups

To restore backups manually, follow these instructions:

1. **List available backups on OneDrive:**
   ```bash
   rclone lsf onedrive:/backups/$CHOSENNAME/daily/
   rclone lsf onedrive:/backups/$CHOSENNAME/weekly/
   rclone lsf onedrive:/backups/$CHOSENNAME/monthly/
   ```

2. **Copy the desired backup from OneDrive to the local system:**
   ```bash
   rclone copy onedrive:/backups/$CHOSENNAME/daily/20230601123000-servername.tar.gz /path/to/restore/
   ```

3. **Extract the tar.gz file to restore the files:**
   ```bash
   sudo tar -xzf /path/to/restore/20230601123000-servername.tar.gz -C /path/to/restore/
   ```

**Examples:**

- **Restore the latest daily backup:**
  ```bash
  rclone copy onedrive:/backups/$CHOSENNAME/daily/20230601123000-servername.tar.gz /var/restores/
  sudo tar -xzf /var/restores/20230601123000-servername.tar.gz -C /var/restores/
  ```

- **Restore a specific weekly backup:**
  ```bash
  rclone copy onedrive:/backups/$CHOSENNAME/weekly/20230601123000-servername.tar.gz /var/restores/
  sudo tar -xzf /var/restores/20230601123000-servername.tar.gz -C /var/restores/
  ```

- **Restore a specific monthly backup to the original locations:**
  ```bash
  rclone copy onedrive:/backups/$CHOSENNAME/monthly/20230601123000-servername.tar.gz /var/restores/
  sudo tar -xzf /var/restores/20230601123000-servername.tar.gz -C /
  ```

These steps provide a comprehensive guide to setting up and using the `rclone_backup_to_onedrive.sh` script, ensuring backups are properly configured, executed, and recoverable.
