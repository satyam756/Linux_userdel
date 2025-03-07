#!/bin/bash
 
# Update and upgrade the system
sudo apt-get update -y
sudo apt-get upgrade -y
 
# Install systemctl (systemd is usually pre-installed on most modern Linux distributions)
# If systemd is not installed, you can install it using the following command
sudo apt-get install -y systemd
 
# Install cron
sudo apt-get install -y cron
 
# Ensure cron service is running
sudo systemctl enable cron
sudo systemctl start cron
 
# Install auditd
sudo apt-get install -y auditd
 
# Create an audit rule to monitor deletions in /etc/passwd
echo '-w /etc/passwd -p w -k user_deletion' | sudo tee -a /etc/audit/rules.d/audit.rules
 
# Restart auditd to apply the new rule
sudo systemctl restart auditd
 
# Create the script to remove the home directory of the deleted user
sudo tee /usr/local/sbin/remove_home_dir.sh > /dev/null << 'EOF'
#!/bin/bash
 
# Extract the username from the audit log
username=$(tac /var/log/auth.log | grep delete | head -1 | awk -F"'" '{print $2}' )
 
# Check if the username is not empty
if [ -z "$username" ]; then
    echo "No username found in the audit log."
    exit 1
fi
 
# Check if the user exists
if id "$username" &>/dev/null; then
    echo "User $username still exists, not removing home directory."
else
    # Remove the home directory
    home_dir="/home/$username"
    if [ -d "$home_dir" ]; then
        rm -rf "$home_dir"
        echo "Removed home directory of $username."
    else
        echo "Home directory of $username does not exist."
    fi
fi
EOF
 
# Make the script executable
sudo chmod +x /usr/local/sbin/remove_home_dir.sh
 
# Create a cron job to run the script every minute
sudo crontab -l | { cat; echo "* * * * * /usr/local/sbin/remove_home_dir.sh"; } | sudo crontab -
