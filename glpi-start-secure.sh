#!/bin/bash

# Script de inicialização segura do GLPI
# Configura o diretório raiz web como /var/www/html/glpi/public
# Move diretórios de dados para fora da raiz web
# Inclui detecção automática de versões e upgrade inteligente

set -e

echo "Iniciando configuração segura do GLPI..."

# Definir URL base para API do GitHub
GLPI_BASE_URL="https://github.com/glpi-project/glpi/releases/download"
GLPI_API_URL="https://api.github.com/repos/glpi-project/glpi/releases"

# Função para obter versões disponíveis
get_glpi_versions() {
    echo "Verificando versões disponíveis do GLPI..."
    # Obter as duas últimas versões estáveis (excluindo alpha/beta)
    LATEST_VERSION=$(wget -qO- "$GLPI_API_URL" | grep 'tag_name' | grep -v rc | grep -v alpha | grep -v beta | head -1 | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    PENULTIMATE_VERSION=$(wget -qO- "$GLPI_API_URL" | grep 'tag_name' | grep -v rc | grep -v alpha | grep -v beta | head -2 | tail -1 | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    
    echo "Última versão estável: $LATEST_VERSION"
    echo "Penúltima versão estável: $PENULTIMATE_VERSION"
}

# Função para obter versão instalada
get_installed_version() {
    if [ -f "/var/www/html/glpi/inc/define.php" ]; then
        INSTALLED_VERSION=$(grep "define('GLPI_VERSION'" /var/www/html/glpi/inc/define.php | sed "s/.*'\([0-9.]*\)'.*/\1/")
        echo "Versão instalada: $INSTALLED_VERSION"
    else
        INSTALLED_VERSION=""
        echo "Nenhuma versão instalada encontrada"
    fi
}

# Função para baixar versão específica do GLPI
download_glpi_version() {
    local version=$1
    local filename="glpi-${version}.tgz"
    local url="${GLPI_BASE_URL}/${version}/${filename}"
    
    echo "Baixando GLPI versão $version..."
    if wget -O "/tmp/$filename" "$url"; then
        echo "Download concluído: /tmp/$filename"
        return 0
    else
        echo "Erro ao baixar versão $version"
        return 1
    fi
}

# Função para verificar e criar diretórios necessários
check_and_create_directories() {
    echo "Verificando e criando diretórios necessários..."
    
    # Lista de diretórios essenciais
    local dirs=(
        "/var/lib/glpi/files/_documents"
        "/var/lib/glpi/files/_cache"
        "/var/lib/glpi/files/_cron"
        "/var/lib/glpi/files/_dumps"
        "/var/lib/glpi/files/_graphs"
        "/var/lib/glpi/files/_lock"
        "/var/lib/glpi/files/_pictures"
        "/var/lib/glpi/files/_plugins"
        "/var/lib/glpi/files/_rss"
        "/var/lib/glpi/files/_sessions"
        "/var/lib/glpi/files/_tmp"
        "/var/lib/glpi/files/_uploads"
        "/var/lib/glpi/files/_inventories"
        "/var/lib/glpi/files/_locales"
        "/var/lib/glpi/files/_log"
        "/etc/glpi"
        "/var/log/glpi"
    )
    
    # Criar diretórios se não existirem
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Criando diretório: $dir"
            mkdir -p "$dir"
        fi
        
        # Testar permissão de escrita
        if ! touch "$dir/test_write_permission" 2>/dev/null; then
            echo "Ajustando permissões para $dir..."
            chown www-data:www-data "$dir"
            chmod 775 "$dir"
        else
            rm -f "$dir/test_write_permission"
        fi
    done
    
    echo "Verificação de diretórios concluída."
}

# Função para criar arquivo downstream.php com configurações de segurança
create_downstream_php() {
    cat > /var/www/html/glpi/inc/downstream.php << 'EOF'
<?php
// Definições principais
defined('GLPI_ROOT') or define('GLPI_ROOT', '/var/www/html/glpi');
defined('GLPI_CONFIG_DIR') or define('GLPI_CONFIG_DIR', '/etc/glpi');
defined('GLPI_VAR_DIR') or define('GLPI_VAR_DIR', '/var/lib/glpi/files');
defined('GLPI_MARKETPLACE_DIR') or define('GLPI_MARKETPLACE_DIR', '/var/www/html/glpi/marketplace');

// Configurações de segurança
define('GLPI_USE_CSRF_CHECK', '1');
define('GLPI_CSRF_EXPIRES', '7200');
define('GLPI_CSRF_MAX_TOKENS', '100');
define('GLPI_USE_IDOR_CHECK', '1');
define('GLPI_IDOR_EXPIRES', '7200');
define('GLPI_ALLOW_IFRAME_IN_RICH_TEXT', false);
define('GLPI_SERVERSIDE_URL_ALLOWLIST', ['/^(https?|feed):\/\/[^@:]+(\/.*)?\$/']);

// Diretórios de arquivos
define('GLPI_DOC_DIR',        GLPI_VAR_DIR . '/_documents');
define('GLPI_CACHE_DIR',      GLPI_VAR_DIR . '/_cache');
define('GLPI_CRON_DIR',       GLPI_VAR_DIR . '/_cron');
define('GLPI_DUMP_DIR',       GLPI_VAR_DIR . '/_dumps');
define('GLPI_GRAPH_DIR',      GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCAL_I18N_DIR', GLPI_VAR_DIR . '/_locales');
define('GLPI_LOCK_DIR',       GLPI_VAR_DIR . '/_lock');
define('GLPI_LOG_DIR',        GLPI_VAR_DIR . '/_log');
define('GLPI_PICTURE_DIR',    GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR',        GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR',    GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR',        GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR',     GLPI_VAR_DIR . '/_uploads');
define('GLPI_INVENTORY_DIR',  GLPI_VAR_DIR . '/_inventories');

// Configurações do Marketplace
define('GLPI_MARKETPLACE_ALLOW_OVERRIDE', true);
define('GLPI_MARKETPLACE_MANUAL_DOWNLOADS', true);
define('GLPI_MARKETPLACE_PRERELEASES', false);

// URLs e APIs
define('GLPI_TELEMETRY_URI', 'https://telemetry.glpi-project.org');
define('GLPI_NETWORK_SERVICES', 'https://services.glpi-network.com');
define('GLPI_NETWORK_REGISTRATION_API_URL', 'https://services.glpi-network.com/api/registration/');
define('GLPI_MARKETPLACE_PLUGINS_API_URI', 'https://services.glpi-network.com/api/marketplace/');

// Outras configurações
define('GLPI_INSTALL_MODE', 'TARBALL');
define('GLPI_DISABLE_ONLY_FULL_GROUP_BY_SQL_MODE', '1');
define('GLPI_AJAX_DASHBOARD', '1');
define('GLPI_CALDAV_IMPORT_STATE', 0);
define('GLPI_DEMO_MODE', '0');
define('GLPI_CENTRAL_WARNINGS', '1');
define('GLPI_TEXT_MAXSIZE', '4000');

// use system cron
define('GLPI_SYSTEM_CRON', true);
EOF
    echo "Arquivo downstream.php criado com configurações de segurança"
}

# Verificar se existe arquivo de upgrade ou se deve fazer upgrade automático
UPGRADE_FILE=$(find /tmp -name "*glpi-upgrade*.tgz" -o -name "glpi-upgrade*.tgz" | head -1)
AUTO_UPGRADE=${AUTO_UPGRADE:-false}

# Se AUTO_UPGRADE estiver habilitado, verificar se há atualizações disponíveis
if [ "$AUTO_UPGRADE" = "true" ] && [ -z "$UPGRADE_FILE" ]; then
    echo "Modo de upgrade automático habilitado. Verificando atualizações..."
    get_glpi_versions
    get_installed_version
    
    # Se há uma instalação e ela não é a penúltima versão, fazer upgrade
    if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "$PENULTIMATE_VERSION" ]; then
        echo "Upgrade disponível: $INSTALLED_VERSION -> $PENULTIMATE_VERSION"
        if download_glpi_version "$PENULTIMATE_VERSION"; then
            UPGRADE_FILE="/tmp/glpi-${PENULTIMATE_VERSION}.tgz"
            echo "Arquivo de upgrade preparado: $UPGRADE_FILE"
        fi
    elif [ -z "$INSTALLED_VERSION" ]; then
        echo "Nenhuma instalação encontrada. Baixando penúltima versão estável..."
        if download_glpi_version "$PENULTIMATE_VERSION"; then
            UPGRADE_FILE="/tmp/glpi-${PENULTIMATE_VERSION}.tgz"
            echo "Arquivo de instalação preparado: $UPGRADE_FILE"
        fi
    else
        echo "GLPI já está na penúltima versão estável ($INSTALLED_VERSION). Nenhuma atualização necessária."
    fi
fi

if [ -n "$UPGRADE_FILE" ] && [ -f "$UPGRADE_FILE" ]; then
    echo "Arquivo de upgrade encontrado: $UPGRADE_FILE"
    echo "Iniciando processo de upgrade do GLPI..."
    
    # Verificar se existe instalação atual
    if [ -d "/var/www/html/glpi" ]; then
        echo "Criando backup da instalação atual..."
        BACKUP_DIR="/tmp/glpi-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # Backup dos arquivos principais (exceto dados)
        cp -r /var/www/html/glpi "$BACKUP_DIR/glpi-files"
        
        # Backup das configurações
        if [ -d "/etc/glpi" ]; then
            cp -r /etc/glpi "$BACKUP_DIR/glpi-config"
        fi
        
        echo "Backup criado em: $BACKUP_DIR"
        
        # Extrair nova versão
        echo "Extraindo nova versão do GLPI..."
        cd /var/www/html
        
        # Remover instalação atual (mantendo dados) - tratamento especial para volumes Docker
        if mountpoint -q /var/www/html/glpi 2>/dev/null; then
            echo "Diretório GLPI é um ponto de montagem - limpando conteúdo..."
            find /var/www/html/glpi -mindepth 1 -delete 2>/dev/null || {
                echo "Removendo arquivos individualmente..."
                rm -rf /var/www/html/glpi/* 2>/dev/null || true
                rm -rf /var/www/html/glpi/.* 2>/dev/null || true
            }
        else
            echo "Removendo diretório GLPI..."
            rm -rf glpi
        fi
        
        # Extrair upgrade
        tar -xzf "$UPGRADE_FILE"
        
        # Verificar se foi extraído um diretório com nome diferente de "glpi"
        if [ ! -d "/var/www/html/glpi" ]; then
            EXTRACTED_DIR=$(find /var/www/html -maxdepth 1 -type d -name "*glpi*" | head -1)
            if [ -n "$EXTRACTED_DIR" ] && [ "$EXTRACTED_DIR" != "/var/www/html/glpi" ]; then
                echo "Renomeando diretório extraído para 'glpi'..."
                mv "$EXTRACTED_DIR" /var/www/html/glpi
            fi
        fi
        
        # Restaurar configurações se existirem
        if [ -d "$BACKUP_DIR/glpi-config" ]; then
            echo "Restaurando configurações..."
            cp -r "$BACKUP_DIR/glpi-config"/* /var/www/html/glpi/config/ 2>/dev/null || true
        fi
        
        # Verificar se o upgrade foi bem-sucedido
        if [ -d "/var/www/html/glpi/public" ]; then
            echo "Upgrade do GLPI concluído com sucesso!"
            
            # Executar atualização do banco de dados
            echo "Atualizando banco de dados..."
            cd /var/www/html/glpi
            if [ -f "bin/console" ]; then
                php bin/console db:update --no-interaction || echo "Aviso: Comando db:update não executado (pode não estar disponível)"
            fi
            
            # Verificar e criar diretórios necessários
            check_and_create_directories
            
            # Criar arquivo downstream.php com configurações de segurança
            echo "Criando arquivo downstream.php com configurações de segurança..."
            create_downstream_php
            
            rm -f "$UPGRADE_FILE"
            echo "Backup mantido em: $BACKUP_DIR"
        else
            echo "Erro: Upgrade falhou - restaurando backup..."
            rm -rf /var/www/html/glpi
            mv "$BACKUP_DIR/glpi-files" /var/www/html/glpi
            echo "Backup restaurado. Upgrade cancelado."
            exit 1
        fi
    else
        echo "Nenhuma instalação existente encontrada. Tratando como instalação nova..."
        cd /var/www/html
        tar -xzf "$UPGRADE_FILE"
        
        if [ ! -d "/var/www/html/glpi" ]; then
            EXTRACTED_DIR=$(find /var/www/html -maxdepth 1 -type d -name "*glpi*" | head -1)
            if [ -n "$EXTRACTED_DIR" ] && [ "$EXTRACTED_DIR" != "/var/www/html/glpi" ]; then
                mv "$EXTRACTED_DIR" /var/www/html/glpi
            fi
        fi
        
        if [ -d "/var/www/html/glpi/public" ]; then
            echo "Instalação do GLPI (via upgrade) concluída com sucesso!"
            
            # Criar arquivo downstream.php com configurações de segurança
            echo "Criando arquivo downstream.php com configurações de segurança..."
            create_downstream_php
            
            rm -f "$UPGRADE_FILE"
        else
            echo "Erro: Instalação falhou"
            exit 1
        fi
    fi
elif [ ! -d "/var/www/html/glpi/public" ]; then
    echo "GLPI não encontrado ou incompleto. Procurando arquivo GLPI..."
    
    # Procurar por qualquer arquivo .tgz que contenha "glpi" no nome (exceto upgrade)
    GLPI_FILE=$(find /tmp -name "*glpi*.tgz" ! -name "*glpi-upgrade*.tgz" -o -name "glpi*.tgz" ! -name "glpi-upgrade*.tgz" -o -name "*.tgz" ! -name "*upgrade*.tgz" | head -1)
    
    if [ -n "$GLPI_FILE" ] && [ -f "$GLPI_FILE" ]; then
        echo "Encontrado arquivo GLPI: $GLPI_FILE"
        echo "Extraindo GLPI..."
        cd /var/www/html
        tar -xzf "$GLPI_FILE"
        
        # Verificar se foi extraído um diretório com nome diferente de "glpi"
        if [ ! -d "/var/www/html/glpi" ]; then
            # Procurar por diretório extraído e renomear para "glpi"
            EXTRACTED_DIR=$(find /var/www/html -maxdepth 1 -type d -name "*glpi*" | head -1)
            if [ -n "$EXTRACTED_DIR" ] && [ "$EXTRACTED_DIR" != "/var/www/html/glpi" ]; then
                echo "Renomeando diretório extraído para 'glpi'..."
                mv "$EXTRACTED_DIR" /var/www/html/glpi
            fi
        fi
        
        # Verificar se a extração foi bem-sucedida
        if [ -d "/var/www/html/glpi/public" ]; then
            echo "Extração do GLPI concluída com sucesso!"
            
            # Verificar e criar diretórios necessários
            check_and_create_directories
            
            # Criar arquivo downstream.php com configurações de segurança
            echo "Criando arquivo downstream.php com configurações de segurança..."
            create_downstream_php
            
            # Remover arquivo após extração bem-sucedida
            rm -f "$GLPI_FILE"
        else
            echo "Erro: Extração do GLPI falhou - diretório public não encontrado"
            echo "Conteúdo extraído:"
            ls -la /var/www/html/glpi/
            exit 1
        fi
    else
        echo "Erro: Nenhum arquivo GLPI (.tgz) encontrado em /tmp/"
        echo "Arquivos disponíveis em /tmp/:"
        ls -la /tmp/
        exit 1
    fi
else
    echo "GLPI já está instalado e configurado."
fi

# Criar diretórios de dados fora da raiz web
echo "Criando diretórios de dados seguros..."
mkdir -p /var/lib/glpi/files/{_cache,_cron,_documents,_dumps,_graphs,_lock,_log,_pictures,_plugins,_rss,_sessions,_tmp,_uploads,_inventories,_locales}
mkdir -p /etc/glpi
mkdir -p /var/log/glpi

# Configurar propriedade inicial dos arquivos GLPI
chown -R www-data:www-data /var/www/html/glpi

# Criar diretório config se não existir
echo "Configurando caminhos seguros..."
mkdir -p /var/www/html/glpi/config

# Criar arquivo de configuração local_define.php
cat > /var/www/html/glpi/config/local_define.php << 'EOF'
<?php
// Configuração de diretórios seguros
define('GLPI_VAR_DIR', '/var/lib/glpi/files');
define('GLPI_LOG_DIR', '/var/log/glpi');
define('GLPI_CONFIG_DIR', '/etc/glpi');
EOF

# Criar configuração de banco de dados se as variáveis estiverem definidas
if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_DATABASE" ] && [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
    echo "Configurando banco de dados..."
    cat > /var/www/html/glpi/config/config_db.php << EOF
<?php
class DB extends DBmysql {
   public \$dbhost = '$MYSQL_HOST';
   public \$dbuser = '$MYSQL_USER';
   public \$dbpassword = '$MYSQL_PASSWORD';
   public \$dbdefault = '$MYSQL_DATABASE';
   public \$use_utf8mb4 = true;
   public \$allow_myisam = false;
   public \$allow_datetime = true;
   public \$allow_signed_keys = false;
}
EOF
fi

# Configurar Apache para usar o diretório public como raiz
echo "Configurando Apache para diretório público..."
cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/glpi/public
    
    <Directory /var/www/html/glpi/public>
        Options -Indexes
        AllowOverride All
        Require all granted
        
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    
    # Negar acesso a diretórios sensíveis
    <Directory /var/www/html/glpi/config>
        Require all denied
    </Directory>
    
    <Directory /var/www/html/glpi/files>
        Require all denied
    </Directory>
    
    <Directory /var/www/html/glpi/inc>
        Require all denied
    </Directory>
    
    <Directory /var/www/html/glpi/install>
        Require all denied
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/glpi_error.log
    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

# Habilitar módulos necessários do Apache
echo "Habilitando módulos do Apache..."
a2enmod rewrite
a2enmod headers

# Configurar permissões corretas
echo "Configurando permissões..."
chown -R www-data:www-data /var/www/html/glpi
chown -R www-data:www-data /var/lib/glpi
chown -R www-data:www-data /etc/glpi
chown -R www-data:www-data /var/log/glpi

# Permissões específicas
chmod -R 755 /var/www/html/glpi
chmod -R 775 /var/lib/glpi/files
chmod -R 775 /var/log/glpi
chmod -R 755 /etc/glpi

# Configurar timezone
echo "Configurando timezone..."
echo 'date.timezone = "America/Sao_Paulo"' >> /etc/php/*/apache2/php.ini
echo 'session.cookie_httponly = on' >> /etc/php/*/apache2/php.ini

# Configurar cron para GLPI (desabilitado temporariamente)
# echo "Configurando cron..."
# echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/crontab

# Iniciar serviços
echo "Iniciando serviços..."
# service cron start

echo "Configuração segura do GLPI concluída!"
echo "Diretório raiz web: /var/www/html/glpi/public"
echo "Diretórios de dados: /var/lib/glpi/files"
echo "Configurações: /etc/glpi"
echo "Logs: /var/log/glpi"

# Iniciar Apache em primeiro plano
exec apache2ctl -D FOREGROUND