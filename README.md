# GLPI Docker - Configuração Segura

Este projeto configura o GLPI com as melhores práticas de segurança recomendadas pela documentação oficial.

## Funcionalidades

### 🔄 Upgrade Automático
- **Detecção automática**: Verifica automaticamente as versões disponíveis do GLPI via API do GitHub
- **Upgrade inteligente**: Atualiza automaticamente para a penúltima versão estável (mais confiável)
- **Backup automático**: Cria backup da instalação atual antes do upgrade
- **Atualização de banco**: Executa automaticamente `php bin/console db:update` após o upgrade
- **Rollback automático**: Restaura backup em caso de falha no upgrade
- **Configuração**: Habilitado através da variável `AUTO_UPGRADE=true` no docker-compose.yml

## Melhorias de Segurança Implementadas

### 1. Diretório Raiz Web Seguro
- **Configuração**: O diretório raiz do servidor web é configurado como `/var/www/html/glpi/public`
- **Benefício**: Impede acesso direto a arquivos não públicos do GLPI
- **Implementação**: Configuração do Apache VirtualHost apontando para o diretório `public`

### 2. Diretórios de Dados Externos
- **Configuração**: Diretórios de dados movidos para fora da raiz web
- **Localização dos dados**: `/var/lib/glpi/files`
- **Configurações**: `/etc/glpi`
- **Logs**: `/var/log/glpi`
- **Benefício**: Dados sensíveis não ficam acessíveis via web

### 3. Controle de Acesso Rigoroso
- Negação explícita de acesso aos diretórios:
  - `/var/www/html/glpi/config`
  - `/var/www/html/glpi/files`
  - `/var/www/html/glpi/inc`
  - `/var/www/html/glpi/install`

### 4. Configuração PHP Segura
- `session.cookie_httponly = on` - Proteção contra XSS
- Timezone configurado para `America/Sao_Paulo`

## Estrutura de Arquivos

```
glpi-docker/
├── Dockerfile                 # Imagem Docker customizada
├── docker-compose.yml         # Orquestração dos serviços
├── glpi-start-secure.sh       # Script de inicialização segura
├── .env                       # Variáveis de ambiente (criar a partir do .env.example)
├── .env.example               # Template das variáveis de ambiente
├── .gitignore                 # Arquivos ignorados pelo Git
└── README.md                  # Esta documentação
```

## Como Usar

### Pré-requisitos
- Docker e Docker Compose instalados

### Instalação

1. **Clone ou baixe este projeto**

2. **Configure as variáveis de ambiente**:
   ```bash
   # Copie o arquivo de exemplo
   cp .env.example .env
   
   # Edite o arquivo .env com suas configurações
   # IMPORTANTE: Altere as senhas padrão por valores seguros!
   ```

3. **Construa e inicie os containers**:
   ```bash
   docker-compose up --build -d
   ```

4. **Acesse o GLPI**:
   - URL: http://localhost:9020
   - O GLPI será configurado automaticamente com as práticas de segurança

## Upgrade do GLPI

### Upgrade Automático

O sistema possui upgrade automático inteligente que:
- Verifica automaticamente novas versões do GLPI
- Atualiza para a **penúltima versão estável** (mais confiável que a última)
- Cria backup automático antes do upgrade
- Executa rollback em caso de falha

**Para habilitar o upgrade automático**:
1. Edite o arquivo `docker-compose.yml`
2. Adicione a variável de ambiente:
   ```yaml
   environment:
     - AUTO_UPGRADE=true
   ```
3. Reconstrua o container:
   ```bash
   docker-compose down
   docker-compose up --build -d
   ```

**Monitoramento do upgrade**:
```bash
# Verificar logs do upgrade
docker logs glpi_app -f

# Verificar versão atual
docker exec glpi_app grep "version" /var/www/html/glpi/version

```

### Volumes Persistentes

O projeto utiliza volumes Docker para persistir dados:
- `glpi_data`: Código fonte do GLPI
- `glpi_files`: Arquivos de dados (fora da raiz web)
- `glpi_config`: Configurações (fora da raiz web)
- `glpi_logs`: Logs do sistema (fora da raiz web)
- `mariadb_data`: Dados do banco MariaDB

## Configuração do Banco de Dados

As configurações do banco de dados são definidas através das variáveis de ambiente no arquivo `.env`:

- **Host**: mariadb (container)
- **Banco**: Definido pela variável `MYSQL_DATABASE`
- **Usuário**: Definido pela variável `MYSQL_USER`
- **Senha**: Definida pela variável `MYSQL_PASSWORD`

### Variáveis de Ambiente Disponíveis

| Variável | Descrição | Valor Padrão |
|----------|-----------|--------------|
| `MYSQL_ROOT_PASSWORD` | Senha do usuário root do MariaDB | `glpi_root_password` |
| `MYSQL_DATABASE` | Nome do banco de dados | `glpi` |
| `MYSQL_USER` | Usuário do banco de dados | `glpi` |
| `MYSQL_PASSWORD` | Senha do usuário do banco | `glpi_password` |
| `TIMEZONE` | Fuso horário do sistema | `America/Sao_Paulo` |
| `GLPI_PORT` | Porta de acesso ao GLPI | `9020` |
| `AUTO_UPGRADE` | Habilita upgrade automático inteligente | `false` |

**⚠️ IMPORTANTE**: Altere as senhas padrão antes de usar em produção!

## Verificação de Segurança

Após a instalação, você pode verificar se as configurações de segurança estão corretas:

1. **Verificar diretório raiz web**:
   ```bash
   docker exec glpi_app apache2ctl -S
   ```
   Deve mostrar `DocumentRoot /var/www/html/glpi/public`

2. **Verificar localização dos dados**:
   ```bash
   docker exec glpi_app ls -la /var/lib/glpi/files
   docker exec glpi_app ls -la /etc/glpi
   docker exec glpi_app ls -la /var/log/glpi
   ```

3. **Testar acesso negado a diretórios sensíveis**:
   - http://localhost:9020/config/ (deve retornar 403 Forbidden)
   - http://localhost:9020/files/ (deve retornar 403 Forbidden)
   - http://localhost:9020/inc/ (deve retornar 403 Forbidden)

## Logs e Monitoramento

- **Logs do Apache**: `/var/log/apache2/` no container
- **Logs do GLPI**: `/var/log/glpi/` no container
- **Logs do container**: `docker logs glpi_app`

## Manutenção

### Backup
```bash
# Backup dos dados
docker run --rm -v glpi-docker_glpi_files:/data -v $(pwd):/backup alpine tar czf /backup/glpi_files_backup.tar.gz -C /data .

# Backup do banco
docker exec glpi_mariadb mysqldump -u glpi -pglpi_password glpi > backup.sql
```

