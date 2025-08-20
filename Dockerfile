FROM debian:12-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    apache2 \
    php \
    php-mysql \
    php-ldap \
    php-xmlrpc \
    php-imap \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-apcu \
    php-intl \
    php-zip \
    php-bz2 \
    wget \
    mariadb-client

# Copiar qualquer arquivo GLPI (.tgz) da raiz do projeto
COPY *.tgz /tmp/

# Enable Apache modules
RUN a2enmod rewrite

# Copiar script de inicialização segura
COPY glpi-start-secure.sh /opt/glpi-start-secure.sh
RUN chmod +x /opt/glpi-start-secure.sh

# Instalar cron (removido temporariamente para evitar problemas de rede)
# RUN apt-get install -y cron

# Usar o script de inicialização segura
CMD ["/opt/glpi-start-secure.sh"]