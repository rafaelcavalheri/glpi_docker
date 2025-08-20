#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create initial database configuration
log "Criando configuração inicial do banco de dados..."
mkdir -p /usr/share/glpi/config
cat > /usr/share/glpi/config/config_db.php << EOF
<?php
class DB extends DBmysql {
   public \$dbhost = '$GLPI_DB_HOST';
   public \$dbuser = '$GLPI_DB_USER';
   public \$dbpassword = '$GLPI_DB_PASSWORD';
   public \$dbdefault = '$GLPI_DB_NAME';
   public \$use_utf8mb4 = true;
   public \$allow_myisam = false;
   public \$allow_datetime = true;
   public \$allow_signed_keys = false;
}
EOF

# Set correct permissions
chown -R www-data:www-data /usr/share/glpi /var/lib/glpi /etc/glpi
chmod -R 755 /usr/share/glpi /var/lib/glpi /etc/glpi
chmod -R 777 /var/lib/glpi/files

# Start Apache in foreground
if [ "$1" = 'apache2-foreground' ]; then
    source /etc/apache2/envvars
    exec apache2 -DFOREGROUND
fi 