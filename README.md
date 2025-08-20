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

### 🔒 Upgrade Manual
- **Arquivo de upgrade**: Coloque um arquivo `glpi-upgrade-X.X.X.tgz` na pasta `/tmp` do container
- **Detecção automática**: O sistema detecta e executa o upgrade automaticamente
- **Processo seguro**: Mesmo processo de backup e rollback do upgrade automático

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
- Arquivo GLPI baixado e renomeado

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

### Atualização/Upgrade do GLPI

Este projeto suporta três métodos de atualização:

#### Método 1: Upgrade Automático Inteligente (Novo!)

O sistema agora pode detectar automaticamente novas versões e fazer o upgrade sem intervenção manual:

1. **Habilite o upgrade automático**:
   ```bash
   # Adicione esta variável ao seu .env ou docker-compose.yml
   AUTO_UPGRADE=true
   ```

2. **Inicie o container**:
   ```bash
   docker-compose up --build -d
   ```

**O que acontece no upgrade automático inteligente:**
- 🔍 Verifica automaticamente as versões disponíveis no GitHub
- 📥 Baixa automaticamente a penúltima versão estável (mais segura)
- 🔄 Compara com a versão instalada
- ⬆️ Faz upgrade apenas se necessário
- ✅ Aplica todas as melhorias de segurança e configurações
- 🗄️ Executa atualização do banco de dados automaticamente
- 📁 Cria arquivo `downstream.php` com configurações de segurança avançadas

#### Método 2: Upgrade Manual com Arquivo (Recomendado)

1. **Baixe a nova versão do GLPI**:
   - Acesse: https://github.com/glpi-project/glpi/releases
   - Baixe a versão desejada (ex: `glpi-10.0.18.tgz`)

2. **Renomeie o arquivo para upgrade**:
   ```bash
   # Renomeie o arquivo baixado para glpi-upgrade.tgz
   mv glpi-10.0.18.tgz glpi-upgrade.tgz
   ```

3. **Coloque o arquivo na pasta do projeto**:
   ```bash
   # O arquivo glpi-upgrade.tgz deve estar na pasta do projeto
   ls glpi-upgrade.tgz
   ```

4. **Reconstrua o container**:
   ```bash
   docker-compose up --build -d
   ```

**O que acontece durante o upgrade automático:**
- ✅ Backup automático da instalação atual
- ✅ Preservação de dados e configurações
- ✅ Restauração automática em caso de falha
- ✅ Validação do upgrade
- ✅ Limpeza automática dos arquivos temporários

**⚠️ Importante sobre Upgrades:**
- O backup da instalação anterior é mantido em `/tmp/glpi-backup-[timestamp]` dentro do container
- Os dados do banco de dados são preservados automaticamente
- As configurações personalizadas são restauradas
- Em caso de falha, o sistema restaura automaticamente a versão anterior

## Solução de Problemas

### Container não inicia
```bash
# Verificar logs
docker logs glpi_app

# Verificar se o arquivo GLPI existe
docker exec glpi_app ls -la /tmp/
```

### Problemas de permissão
```bash
# Reconfigurar permissões
docker exec glpi_app chown -R www-data:www-data /var/www/html/glpi
docker exec glpi_app chown -R www-data:www-data /var/lib/glpi
```

## Compatibilidade de Versões

Este projeto é compatível com qualquer versão do GLPI que utilize a estrutura de diretórios padrão. O script de inicialização detecta automaticamente:
- Arquivos `.tgz` com "glpi" no nome
- Qualquer arquivo `.tgz` na pasta do projeto
- Renomeia automaticamente diretórios extraídos para "glpi"

## Segurança Adicional

Para ambientes de produção, considere:

1. **HTTPS**: Configure SSL/TLS
2. **Firewall**: Restrinja acesso às portas necessárias
3. **Backup**: Implemente rotina de backup automatizada
4. **Monitoramento**: Configure alertas de segurança
5. **Atualizações**: Mantenha GLPI e dependências atualizadas

## Referências

- [Documentação oficial do GLPI](https://glpi-install.readthedocs.io/)
- [Guia de segurança do GLPI](https://glpi-install.readthedocs.io/en/latest/install/index.html#security)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GLPI Releases no GitHub](https://github.com/glpi-project/glpi/releases)

## Sistema de Upgrade Automático

### Configuração de Versões

O sistema oferece duas opções para seleção de versão:

#### Penúltima Versão (Recomendado - Padrão)
```bash
USE_LATEST_VERSION=false
```
**Vantagens:**
- ✅ Mais estável e testada pela comunidade
- ✅ Bugs críticos já foram identificados e corrigidos
- ✅ Ideal para ambientes de produção
- ✅ Menor risco de problemas inesperados

#### Última Versão
```bash
USE_LATEST_VERSION=true
```
**Vantagens:**
- ✅ Funcionalidades mais recentes
- ✅ Correções de bugs mais atuais
- ❌ Pode conter bugs ainda não descobertos
- ❌ Menos testada em ambientes reais

### Processo Automático

1. **Verificação**: O sistema consulta a API do GitHub para versões disponíveis
2. **Comparação**: Compara a versão instalada com a versão alvo
3. **Download**: Baixa automaticamente a versão necessária
4. **Backup**: Cria backup completo da instalação atual
5. **Upgrade**: Extrai e configura a nova versão
6. **Atualização**: Executa `php bin/console db:update`
7. **Verificação**: Confirma que o upgrade foi bem-sucedido

### Logs e Monitoramento

Todos os processos são logados e podem ser acompanhados:
```bash
# Visualizar logs do container
docker-compose logs -f glpi

# Logs específicos do upgrade
docker exec glpi-container tail -f /var/log/glpi/upgrade.log
```