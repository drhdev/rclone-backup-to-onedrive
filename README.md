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

#### Step 1. Install Required Software

First, ensure that `rclone` and `cron` are installed on your Ubuntu server.

   ```bash
   sudo apt update
   sudo apt install rclone cron
   ```

#### Step 2: Create a Backup User

1. **Create the backup user:**
   ```bash
   sudo adduser backupuser
   ```

2. **Add the user to the sudo group:**
   ```bash
   sudo usermod -aG sudo backupuser
   ```

#### Step 3: Copy and Edit the Script

1. **Switch to the backupuser:**
   ```bash
   sudo su - backupuser
   ```

2. **Create the script file:**
   ```bash
   sudo nano /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

3. **Copy and paste the script into the file and save it (Ctrl+X, then Y, then Enter).**

4. **Make the script executable:**
   ```bash
   sudo chmod +x /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

#### Step 4: Prepare Backup Directory and Logfile
   
1. **Create and Set permissions for the backup directory:**
   ```bash
   sudo mkdir -p /var/backups/rclone_backup_to_onedrive
   sudo chown -R backupuser:backupuser /var/backups/rclone_backup_to_onedrive
   sudo chmod 755 /var/backups/rclone_backup_to_onedrive
   ```

2. **Create and Set permissions for the logfile:**
   ```bash
   sudo touch /var/log/rclone_backup_to_onedrive.log
   sudo chown backupuser:backupuser /var/log/rclone_backup_to_onedrive.log
   sudo chmod 644 /var/log/rclone_backup_to_onedrive.log
   ```

#### Step 5: Allow Password-less Sudo for the Script

1. **Edit the sudoers file:**
   ```bash
   sudo visudo
   ```

2. **Add the following lines:**
   ```plaintext
   backupuser ALL=(ALL) NOPASSWD: /usr/local/bin/rclone_backup_to_onedrive.sh
   backupuser ALL=(ALL) NOPASSWD: /usr/bin/rclone, /bin/tar, /bin/mv, /bin/chmod, /bin/touch, /bin/ls, /usr/bin/find, /bin/mkdir
   ```

#### Step 6: Set Up `rclone` for OneDrive

1. **Install rclone:**
   ```bash
   sudo apt install rclone
   ```

2. **Configure rclone:**
   ```bash
   sudo -u backupuser -i
   sudo rclone config
   ```
   Follow the prompts to set up OneDrive.

3. **Create a new remote:**
   - Type `n` for a new remote and press Enter.

4. **Name the remote:**
   - Enter a name for the remote, for example, `onedrive`.

5. **Choose your cloud storage provider:**
   - You will be presented with a list of cloud storage providers. Type the number corresponding to OneDrive (typically 22 for Microsoft OneDrive) and press Enter.

6. **Client ID and Secret:**
   - If you have a custom client ID and secret, enter them when prompted. Otherwise, leave these fields blank and press Enter.

7. **Edit advanced config:**
   - Type `n` and press Enter.

8. **Do not use auto config:**
   - When aksed for using auto config, type `n` and press Enter since you are on a remote server without a GUI. This will give you instructions how to ru web browser for authentication.
   - Follow the on-screen instructions to perform a manual configuration (e.g. on a Mac by using `rclone authorize "onedrive"` after installing rclone locally with `brew install rclone`).

9. **Authenticate:**
   - A browser window will open, prompting you to log in to your Microsoft account and grant access to `rclone`.
   - After granting access, you will receive a success message, and you can close the browser.

10. **Finish the configuration:**
   - In the local terminal you will find a message like `Paste the following into your remote machine --->` followed by a long access token.
   - Copy this exact access token and enter it in the terminal window of your server where it says `Then paste the result below:` and the line starts with `result>`.
   - You should then be able to `Choose a number from below, or type in an existing value` where you choose `1`for `OneDrive Personal or Business`.
   - The terminal will return `Found 1 drives, please select the one you want to use:` and you choose `0` and confirm with `Y` and the question about the token also with `Y`.
   - You then get to see that onedrive is successfully configured as a a `current remote`
   - Type `q` to quit the `rclone` configuration.

11. **Test the configuration:**
    Verify the setup by listing the contents of your OneDrive.

      ```bash
      rclone lsf onedrive: -vv
      ```

12. **Exit from backupuser:**
    Leave the backupuser mode.

    ```bash
      exit
      ```

#### Step 7: Run the Script Manually

1. **Run the script manually:**
   ```bash
   sudo -u backupuser /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

#### Step 8: Set Up Cron Job

1. **Edit the crontab for backupuser:**
   ```bash
   sudo crontab -u backupuser -e
   ```

2. **Add the following line to run the script daily at 2 AM:**
   ```plaintext
   0 2 * * * /usr/local/bin/rclone_backup_to_onedrive.sh
   ```

#### Step 9: Monitoring

1. **Regulary check the log file for errors:**
   ```bash
   cd /var/log
   ```
   Look for rclone_backup_to_onedrive.log logfiles.

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
