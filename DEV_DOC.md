# Inception - Developer Documentation

This guide explains how to set up, build, and maintain the Inception infrastructure from a developer's perspective.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Building the Project](#building-the-project)
4. [Container Management](#container-management)
5. [Volume & Data Management](#volume--data-management)
6. [Debugging & Monitoring](#debugging--monitoring)
7. [Project Structure](#project-structure)
8. [Modifying Services](#modifying-services)

## Prerequisites

### Required Software

- **Docker**: Version 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose**: Version 1.29+ (usually bundled with Docker Desktop)
- **Bash**: For shell scripts and Makefile
- **Make**: For running Make commands
- **Git**: For version control

### System Requirements

- **Disk space**: At least 2GB free (for images and volumes)
- **RAM**: 2GB minimum (4GB+ recommended)
- **Network**: Ports 443 available (HTTPS)

### Verification

```bash
# Check Docker version
docker --version
# Expected: Docker version 20.10+

# Check Docker Compose version
docker-compose --version
# Expected: Docker Compose version 1.29+

# Check Make
make --version
```

## Environment Setup

### 1. Clone the Repository

```bash
cd /home/ezeppa/Documents/Workspace/Inception
```

### 2. Configure Environment Variables

Edit the `.env` file in `srcs/`:

```bash
nano srcs/.env
```

**Required variables**:
```env
# Domain configuration
DOMAIN_NAME=ezeppa.42.fr

# Database
SQL_DATABASE=wordpress
SQL_USER=wp_user
SQL_PASSWORD=secure_password_here
SQL_ROOT_PASSWORD=root_password_here

# WordPress Admin User
ADMIN_USER=admin_login
ADMIN_PASSWORD=admin_password
ADMIN_EMAIL=admin@example.com

# WordPress Regular User
USER_LOGIN=regular_user
USER_PASS=user_password
USER_EMAIL=user@example.com
```

**Important notes**:
- Use strong passwords for production
- Database names and usernames are used in multiple places
- Update `DOMAIN_NAME` to match your domain
- These values are injected into containers via `env_file` directive

### 3. Create Data Directories

```bash
# Create host directories
mkdir -p /home/ezeppa/data/wordpress
mkdir -p /home/ezeppa/data/mariadb

# Set proper permissions
chmod 755 /home/ezeppa/data
chmod 777 /home/ezeppa/data/wordpress
chmod 777 /home/ezeppa/data/mariadb
```

**Why**: Docker volumes store data in these paths (as required by the subject). The `make up` command creates them automatically.

### 4. Update Local DNS (for development)

```bash
# Add entry to /etc/hosts
echo "127.0.0.1 ezeppa.42.fr" | sudo tee -a /etc/hosts
```

Replace `ezeppa.42.fr` with the value of `DOMAIN_NAME` from your `.env` if needed.

## Building the Project

### Using the Makefile

The Makefile provides convenient commands:

```bash
# Build images and start containers
make up

# Stop containers (preserves data)
make down

# Stop and remove everything (removes volumes)
make fclean

# Rebuild from scratch
make re

# View running containers
make ps

# View live logs
make logs
```

### Manual Docker Compose Commands

```bash
cd srcs/

# Build images
docker-compose build

# Start services
docker-compose up -d

# View status
docker-compose ps

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Understand the Build Process

Each service has a `Dockerfile`:

**Nginx Dockerfile**:
1. Starts from `debian:bookworm` base image
2. Installs `nginx` and `openssl`
3. Generates self-signed SSL certificates
4. Copies custom Nginx configuration
5. Starts Nginx in foreground mode

**WordPress Dockerfile**:
1. Starts from `debian:bookworm` base image
2. Installs PHP 8.4-FPM and extensions
3. Installs WP-CLI for WordPress management
4. Copies entrypoint script
5. Runs entrypoint which downloads WordPress and creates configuration

**MariaDB Dockerfile**:
1. Starts from `debian:bookworm` base image
2. Installs MariaDB server
3. Copies setup script
4. Runs setup which initializes database and creates users

### Build Times

- **First build**: 2-5 minutes (downloads base images)
- **Subsequent builds**: 10-30 seconds (uses cache)
- **Startup after build**: 15-30 seconds (containers initializing)

## Container Management

### View Running Containers

```bash
# Show status
docker-compose ps

# Show with more details
docker-compose ps -a

# Show using native Docker
docker ps
```

### Get Shell Access to Container

```bash
# Access WordPress container
docker-compose exec wordpress /bin/bash

# Access MariaDB container
docker-compose exec mariadb /bin/bash

# Access Nginx container
docker-compose exec nginx /bin/bash
```

**Useful commands inside containers**:

In WordPress:
```bash
# Check WordPress files
ls -la /var/www/html/

# Edit WordPress config
nano /var/www/html/wp-config.php

# Run WP-CLI commands
wp --allow-root user list
```

In MariaDB:
```bash
# Connect to database
mysql -u root -p

# List databases
mysql -e "SHOW DATABASES;"

# Query WordPress database
mysql -u root -p -e "USE wordpress; SHOW TABLES;"
```

In Nginx:
```bash
# Check config
cat /etc/nginx/sites-enabled/inception-site.conf

# Check SSL certificates
ls -la /etc/nginx/ssl/

# View access logs
tail -f /var/log/nginx/access.log
```

### View Logs

```bash
# All services
docker-compose logs

# Follow logs (live)
docker-compose logs -f

# Specific service
docker-compose logs wordpress

# Last N lines
docker-compose logs --tail 50

# Since specific time
docker-compose logs --since 2025-02-03T12:00:00
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart wordpress

# Stop, then start (without removing)
docker-compose stop
docker-compose start
```

### Remove & Rebuild

```bash
# Rebuild specific service
docker-compose build wordpress

# Build and restart service
docker-compose up -d --build wordpress

# Remove all containers and rebuild
docker-compose down
docker-compose up -d --build
```

## Volume & Data Management

### Understanding the Volume Configuration

From `docker-compose.yml`:

```yaml
volumes:
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/wordpress
  
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/mariadb
```

**Explanation**:
- `DATA_DIR` comes from `srcs/.env` (typically `/home/<login>/data`)
- Type `none` with `bind` option = named volume backed by host path
- Data persists in `/home/<login>/data/` even if containers are deleted

### Where Data is Stored

```
Host Machine:
/home/<login>/data/
├── wordpress/          (mounted to /var/www/html in WordPress container)
│   ├── wp-content/     (themes, plugins, uploads)
│   ├── wp-config.php   (database connection)
│   └── index.php
└── mariadb/            (mounted to /var/lib/mysql in MariaDB container)
    ├── mysql/          (system database)
    ├── wordpress/      (application database)
    └── performance_schema/

Replace <login> with your 42 login (LOGIN_NAME from .env).
```

### Backup Data

```bash
# Backup WordPress files
tar -czf wordpress_backup.tar.gz /home/ezeppa/data/wordpress/

# Backup database
tar -czf mariadb_backup.tar.gz /home/ezeppa/data/mariadb/

# Or directly from container
docker-compose exec mariadb mysqldump -u root -p"${SQL_ROOT_PASSWORD}" --all-databases > backup.sql
```

### Restore Data

```bash
# Restore WordPress
tar -xzf wordpress_backup.tar.gz -C /

# Restore database
tar -xzf mariadb_backup.tar.gz -C /

# Or from SQL dump
docker-compose exec -T mariadb mysql -u root -p"${SQL_ROOT_PASSWORD}" < backup.sql
```

### Clean Volumes (Reset Everything)

```bash
# Stop containers and remove volumes
docker-compose down -v

# Remove data directories
rm -rf /home/ezeppa/data/wordpress/*
rm -rf /home/ezeppa/data/mariadb/*

# Restart (will recreate from Dockerfiles)
docker-compose up -d
```

⚠️ **Warning**: This deletes all data!

## Debugging & Monitoring

### Check Container Health

```bash
# View container resource usage
docker stats

# Check specific container
docker inspect nginx-container
docker inspect wordpress-container
docker inspect mariadb-container
```

### Verify Network Connectivity

```bash
# From host to container
docker-compose exec wordpress ping mariadb
docker-compose exec wordpress ping nginx

# DNS resolution
docker-compose exec wordpress getent hosts mariadb
```

### Check Port Bindings

```bash
# View port mappings
docker-compose ps

# Check which process is using port 443
lsof -i :443
```

### Monitor Real-Time Activity

```bash
# Watch all logs
docker-compose logs -f

# Watch specific service
docker-compose logs -f wordpress

# With timestamps
docker-compose logs -f -t
```

### Common Debug Scenarios

**WordPress can't connect to database**:
```bash
# Check MariaDB is running
docker-compose logs mariadb

# Check WordPress sees the host
docker-compose exec wordpress getent hosts mariadb

# Manually test connection
docker-compose exec wordpress mysql -h mariadb -u wp_user -p"${SQL_PASSWORD}" -e "SELECT 1;"
```

**Nginx not serving requests**:
```bash
# Check Nginx logs
docker-compose logs nginx

# Verify Nginx config
docker-compose exec nginx nginx -t

# Check if port 443 is open
lsof -i :443
```

**Slow startup**:
```bash
# Track initialization progress
docker-compose logs -f

# Look for messages like:
# "mysqld: ready for connections"
# "WordPress setup is complete"
```

## Project Structure

```
Inception/
├── Makefile                           # Make commands for easy management
├── README.md                          # User-facing documentation
├── USER_DOC.md                        # End-user documentation
├── DEV_DOC.md                         # Developer documentation (this file)
├── .gitignore                         # Git ignore patterns
└── srcs/
    ├── .env                           # Environment variables (sensitive!)
    ├── docker-compose.yml             # Orchestration configuration
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile             # Nginx image definition
        │   ├── conf/
        │   │   └── inception-site.conf # Nginx server configuration
        │   └── tools/
        ├── wordpress/
        │   ├── Dockerfile             # WordPress image definition
        │   ├── conf/
        │   │   └── www.conf            # PHP-FPM pool configuration
        │   └── tools/
        │       └── entrypoint.sh       # WordPress initialization script
        └── mariadb/
            ├── Dockerfile             # MariaDB image definition
            └── tools/
                └── setup.sh            # Database initialization script
```

### Key Files Explained

**docker-compose.yml**:
- Defines three services: nginx, wordpress, mariadb
- Specifies image builds, ports, volumes, networks, environment variables
- Sets up dependencies (depends_on)
- Configures restart policies

**Dockerfile** (each service):
- Base image selection (debian:bookworm)
- Package installation
- Configuration file copying
- Entrypoint/CMD definition

**Configuration Files**:
- `inception-site.conf`: Nginx reverse proxy configuration, SSL setup
- `www.conf`: PHP-FPM pool configuration
- `.env`: Sensitive data (passwords, domain name)

**Entrypoint Scripts**:
- `entrypoint.sh` (WordPress): Waits for DB, downloads WordPress, creates config
- `setup.sh` (MariaDB): Initializes database, creates users

**Makefile**:
- Convenience wrapper around docker-compose commands
- Common targets: up, down, fclean, re, ps, logs

## Modifying Services

### Modifying Nginx Configuration

1. Edit `srcs/requirements/nginx/conf/inception-site.conf`
2. Rebuild and restart:
   ```bash
   docker-compose up -d --build nginx
   ```
3. Verify configuration:
   ```bash
   docker-compose exec nginx nginx -t
   ```

### Modifying PHP Configuration

1. Edit `srcs/requirements/wordpress/conf/www.conf`
2. Rebuild and restart:
   ```bash
   docker-compose up -d --build wordpress
   ```

### Modifying Database Initialization

1. Edit `srcs/requirements/mariadb/tools/setup.sh`
2. Remove existing database data:
   ```bash
   rm -rf /home/ezeppa/data/mariadb/*
   ```
3. Rebuild and restart:
   ```bash
   docker-compose up -d --build mariadb
   ```

### Adding WordPress Plugins

**Method 1: Using WP-CLI inside container**:
```bash
docker-compose exec wordpress wp plugin install jetpack --activate --allow-root
```

**Method 2: Manually in WordPress Admin**:
1. Access `https://ezeppa.42.fr/wp-admin`
2. Go to **Plugins** → **Add New**
3. Search and install

**Method 3: Direct file copy** (for development):
```bash
cp -r /path/to/plugin /home/ezeppa/data/wordpress/wp-content/plugins/
```

### Installing WordPress Themes

**Method 1: Using WP-CLI**:
```bash
docker-compose exec wordpress wp theme install twentytwentythree --activate --allow-root
```

**Method 2: WordPress Admin**:
1. Access admin panel
2. Go to **Appearance** → **Themes**
3. Search and install

### Database Optimization

```bash
# Optimize all tables
docker-compose exec mariadb mysql -u root -p"${SQL_ROOT_PASSWORD}" -e \
  "USE wordpress; OPTIMIZE TABLE wp_posts, wp_postmeta, wp_comments;"

# Check database size
docker-compose exec mariadb mysql -u root -p"${SQL_ROOT_PASSWORD}" -e \
  "SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024, 2) AS size_mb FROM information_schema.tables GROUP BY table_schema;"
```

## Advanced Topics

### Enable WordPress Debug Mode

Edit WordPress config inside container:
```bash
docker-compose exec wordpress nano /var/www/html/wp-config.php
```

Add or modify:
```php
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
```

Debug logs will appear in `/var/www/html/wp-content/debug.log`.

### Performance Monitoring

```bash
# Watch CPU and memory usage
docker stats --no-stream

# Check I/O performance
docker-compose exec mariadb iostat -x 1 5

# Check disk usage
du -sh /home/ezeppa/data/wordpress
du -sh /home/ezeppa/data/mariadb
```

### Network Diagnostics

```bash
# Test DNS between containers
docker-compose exec wordpress nslookup mariadb

# Check open ports inside container
docker-compose exec wordpress netstat -tln

# Trace network requests
docker-compose exec wordpress tcpdump -i eth0 -n 'port 3306'
```

### Update Docker Images

```bash
# Pull latest base images
docker-compose pull

# Rebuild with latest bases
docker-compose build --no-cache

# Restart
docker-compose up -d
```

---

For questions or issues, refer to README.md for architectural details and USER_DOC.md for operational guidance.
