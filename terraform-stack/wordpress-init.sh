#!/bin/bash

# Mount EFS
MOUNT_PATH="/var/www"
EFS_DNS_NAME=${vars.efs_dns_name}

[ $(grep -c $${EFS_DNS_NAME} /etc/fstab) -eq 0 ] && \
        (echo "$${EFS_DNS_NAME}:/ $${MOUNT_PATH} nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab; \
                mkdir -p $${MOUNT_PATH}; mount $${MOUNT_PATH})

# Install packages
yum -y update
amazon-linux-extras enable php7.4
yum -y install httpd mod_ssl php php-cli php-gd php-mysqlnd
yum -y install mysql

sed -i 's/post_max_size = 8M/post_max_size = 128M/g'  /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 128M/g'  /etc/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 600/g'  /etc/php.ini
sed -i 's/; max_input_vars = 1000/max_input_vars = 2000/g'  /etc/php.ini
sed -i 's/max_input_time = 60/max_input_time = 300/g'  /etc/php.ini

# Extract variables
export PROJECT_NAME=${vars["project_name"]}
ALB_DNS_NAME=${vars["alb_dns_name"]}
export URL="http://$${ALB_DNS_NAME}"
export DB_NAME=${vars["db_name"]}
export DB_USER=${vars["db_user"]}
export DB_PASSWORD=${vars["db_password"]}
export DB_HOST=${vars["db_host"]}
export WP_ADMIN_USERNAME=${vars["wp_admin_username"]}
export WP_ADMIN_EMAIL=${vars["wp_admin_email"]}
export WP_ADMIN_PASSWORD=${vars["wp_admin_password"]}

# Write db_optimizer.sh
cat > /usr/local/bin/db_optimizer.sh <<'EOF'
#!/bin/bash

# Variables
LOG_FILE="/var/log/db_optimizer.log"
LOCK_FILE="/var/www/.db_optimizer.lock"
WP_CONFIG_FILE="/var/www/html/wp-config.php"

# Extract database credentials from wp-config.php
DB_NAME=$(grep DB_NAME $WP_CONFIG_FILE | cut -d "'" -f 4)
DB_USER=$(grep DB_USER $WP_CONFIG_FILE | cut -d "'" -f 4)
DB_PASSWORD=$(grep DB_PASSWORD $WP_CONFIG_FILE | cut -d "'" -f 4)
DB_CONNECTION_STRING=$(grep DB_HOST $WP_CONFIG_FILE | cut -d "'" -f 4)
DB_HOST=$(echo $DB_CONNECTION_STRING | cut -d ':' -f 1)
DB_PORT=$(echo $DB_CONNECTION_STRING | cut -d ':' -f 2)

# Function to get current date in ISO 8601 format
get_current_date() {
    echo $(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

# Function to get the time in milliseconds since 1970-01-01 00:00:00 UTC
get_current_time() {
    echo $(date +%s%3N)
}

# Function to log table size
log_table_size() {
  local table_name=$1
  local size_in_mb=$(mysql -N -s -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD -e "SELECT round(((data_length + index_length) / 1024 / 1024), 2) AS 'Size in MB' FROM information_schema.TABLES WHERE table_schema = '$DB_NAME' AND table_name = '$table_name';")

  echo -ne "$size_in_mb MB\n"
}

# Function to optimize table
optimize_table() {
  local table_name=$1
  local start_time=$(get_current_time)
  mysqlcheck -o $DB_NAME -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD $table_name > /dev/null
  local end_time=$(get_current_time)
  local duration=$((end_time - start_time))
  echo $duration
}

# Check if another instance of the script is running
if [ -e $LOCK_FILE ]; then
  echo "error: Another instance of this script is already running." >> $LOG_FILE
  exit 1
fi

# Create the lock file to prevent concurrent runs
touch $LOCK_FILE

# Log the current date and time
echo "-" >> $LOG_FILE
echo "  start: $(get_current_date)" >> $LOG_FILE
echo "  affected_tables:" >> $LOG_FILE

# Get list of tables
TABLES=$(mysql -N -s -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD -e "SELECT table_name FROM information_schema.tables WHERE table_schema='$DB_NAME';")

# Loop over tables
for table_name in $TABLES; do
  echo "    - table: $table_name" >> $LOG_FILE
  # Log table size before optimization
  echo "      size_before: $(log_table_size $table_name)" >> $LOG_FILE

  echo "      start: $(get_current_date)" >> $LOG_FILE
  # Optimize table and collect duration
  optimization_duration=$(optimize_table $table_name)
  echo "      end: $(get_current_date)" >> $LOG_FILE
  echo "      duration: $${optimization_duration}ms" >> $LOG_FILE

  # Log table size after optimization
  echo "      size_after: $(log_table_size $table_name)" >> $LOG_FILE
done

# Remove the lock file
rm $LOCK_FILE
echo "  end: $(get_current_date)" >> $LOG_FILE
logger "DB Optimizer service has stopped."
EOF

# Make the script executable
chmod +x /usr/local/bin/db_optimizer.sh


# Write db_optimizer.service
cat > /etc/systemd/system/db-optimizer.service <<'EOF'
[Unit]
Description=DB Optimizer
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/db_optimizer.sh
TimeoutStopSec=20
KillMode=process
RemainAfterExit=no
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# Write db_optimizer.timer
cat > /etc/systemd/system/db-optimizer.timer <<'EOF'
[Unit]
Description=Run db-optimizer on Sunday

[Timer]
OnCalendar=Sun *-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd manager configuration
systemctl daemon-reload

# Enable the db-optimizer service
systemctl enable db-optimizer

# Enable the db-optimizer timer
systemctl enable db-optimizer.timer

# Start the db-optimizer timer
systemctl start db-optimizer.timer

# Start httpd
systemctl enable --now httpd

# Configure firewall
firewall-cmd --add-service=http
firewall-cmd --runtime-to-permanent

# Download Wordpress
WP_ROOT_DIR=$${MOUNT_PATH}/html
LOCK_FILE=$${MOUNT_PATH}/.wordpress.lock
EC2_LIST=$${MOUNT_PATH}/.ec2_list
WP_CONFIG_FILE=$${WP_ROOT_DIR}/wp-config.php


SHORT_NAME=$(hostname -s)
echo "$${SHORT_NAME}" >> $${EC2_LIST}
FIRST_SERVER=$(head -1 $${EC2_LIST})

if [ ! -f $${LOCK_FILE} -a "$${SHORT_NAME}" == "$${FIRST_SERVER}" ]; then
  printenv > $${MOUNT_PATH}/environment.txt

  # Create lock to avoid multiple attempts
	touch $${LOCK_FILE}

  # ALB monitoring healthy during initialization
	echo "OK" > $${WP_ROOT_DIR}/index.html

  # Create uploads directory
  cd $${MOUNT_PATH}
  # Download wordpress
  wget http://wordpress.org/latest.tar.gz
  # Extract wordpress
  tar xzvf latest.tar.gz
  # Remove html directory
	rm -rf $${WP_ROOT_DIR}
  # Move wordpress to html
	mv wordpress html
  # Create uploads directory
  mkdir $${WP_ROOT_DIR}/wp-content/uploads
  # Remove wordpress tarball
	rm -rf latest.tar.gz
  # Download wordpress-cli
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  # Make wordpress-cli executable
  chmod +x wp-cli.phar
  # Move wordpress-cli to /usr/bin
  mv wp-cli.phar /usr/bin/wp
  # Create config via wp-cli.phar
  wp config create --dbname=$${DB_NAME} --dbuser=$${DB_USER} --dbpass=$${DB_PASSWORD} --dbhost=$${DB_HOST} --path=$${WP_ROOT_DIR} --skip-check
  # Install wordpress via wp-cli.phar
  wp core install --url=$${URL} --title=$${PROJECT_NAME} --admin_user=$${WP_ADMIN_USERNAME} --admin_email=$${WP_ADMIN_EMAIL} --admin_password=$${WP_ADMIN_PASSWORD} --skip-email --path=$${WP_ROOT_DIR}
  # Remove default post
  wp post delete $(wp post list --post_type='post' --format=ids --path=$${WP_ROOT_DIR}) --force --path=$${WP_ROOT_DIR}
  # Install wordpress-cli packages
  wp package install git@github.com:wp-cli/import-command.git --path=$${WP_ROOT_DIR}
  wp plugin install wordpress-importer --activate --path=$${WP_ROOT_DIR}
  # Set permissions
  chown -R apache /var/www
  chgrp -R apache /var/www
  chmod 2775 /var/www
  find /var/www -type d -exec sudo chmod 2775 {} \;
  find /var/www -type f -exec sudo chmod 0664 {} \;
  # Write post.xml
cat > /tmp/post.wxr <<'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0"
xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"
xmlns:content="http://purl.org/rss/1.0/modules/content/"
xmlns:wfw="http://wellformedweb.org/CommentAPI/"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:wp="http://wordpress.org/export/1.2/"
>
<channel>
    <title>My Blog</title>
    <link>http://www.example.com</link>
    <description>This is my new WordPress blog.</description>
    <pubDate>Fri, 31 Dec 2021 15:00:00 +0000</pubDate>
    <language>en</language>
    <wp:wxr_version>1.2</wp:wxr_version>
    <item>
        <title>Linux namespaces</title>
        <link>http://www.example.com/linux-namespaces</link>
        <pubDate>Fri, 31 Dec 2021 15:00:00 +0000</pubDate>
        <dc:creator><![CDATA[admin]]></dc:creator>
        <description></description>
        <content:encoded><![CDATA[
        Namespaces are a feature of the Linux kernel that partitions kernel resources such that one set of processes sees one set of resources while another set of processes sees a different set of resources. The feature works by having the same namespace for these resources in the various sets of processes, but those names referring to distinct resources. Examples of resource names that can exist in multiple spaces, so that the named resources are partitioned, are process IDs, hostnames, user IDs, file names, and some names associated with network access, and interprocess communication.

        Namespaces are a fundamental aspect of containers on Linux.

        The term "namespace" is often used for a type of namespace (e.g. process ID) as well for a particular space of names.

        A Linux system starts out with a single namespace of each type, used by all processes. Processes can create additional namespaces and join different namespaces.
        ]]></content:encoded>
        <wp:post_id>123</wp:post_id>
        <wp:post_date>2023-06-04 00:00:00</wp:post_date>
        <wp:comment_status>open</wp:comment_status>
        <wp:ping_status>open</wp:ping_status>
        <wp:post_name>linux-namespaces</wp:post_name>
        <wp:status>publish</wp:status>
        <wp:post_parent>0</wp:post_parent>
        <wp:menu_order>0</wp:menu_order>
        <wp:post_type>post</wp:post_type>
        <wp:post_password></wp:post_password>
        <wp:is_sticky>0</wp:is_sticky>
    </item>
</channel>
</rss>
EOF
  # Import post.xml
  wp import /tmp/post.wxr --authors=create --path=$${WP_ROOT_DIR}
  # Remove post.xml
  rm -rf /tmp/post.wxr
else
	echo "$(date) :: Lock is acquired by another server"  >> /var/log/user-data-status.txt
fi

# Reboot
reboot
