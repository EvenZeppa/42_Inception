*This project has been created as part of the 42 curriculum by ezeppa.*

# Inception

## Description

Inception is a Docker-based infrastructure project that sets up a complete WordPress stack using containers. The project demonstrates advanced Docker and containerization concepts by orchestrating multiple services (Nginx, WordPress, and MariaDB) to create a fully functional website infrastructure.

### Project Goals

- **Understand containerization**: Learn how Docker isolates applications and their dependencies.
- **Multi-container orchestration**: Use Docker Compose to manage relationships between services.
- **Security implementation**: Configure SSL/TLS certificates, environment variables, and secrets management.
- **Persistent data storage**: Implement volume management to ensure data persists across container restarts.
- **Network isolation**: Create custom Docker networks for secure inter-container communication.

### Architecture Overview

The stack consists of three main services (mandatory) plus two bonus services:

1. **Nginx** (Web Server)
	- Serves as the reverse proxy and web server
	- Handles SSL/TLS encryption with self-signed certificates
	- Routes requests to the PHP-FPM server

2. **WordPress** (PHP Application)
	- Runs PHP-FPM for dynamic content generation
	- Manages WordPress core files and plugins
	- Communicates with the MariaDB database

3. **MariaDB** (Database)
	- Provides the relational database backend
	- Stores all WordPress data (posts, users, configurations)
	- Ensures data persistence across container lifecycle

**Bonus services:**
4. **Adminer** — Database management UI at `https://your-domain/adminer`
5. **Static site** — Showcase at `https://your-domain/portfolio` (HTML/CSS, no PHP)
6. **Redis** — Object cache for WordPress (plugin redis-cache)
7. **FTP** — vsftpd server on port 21, access to WordPress volume (user: `ftpuser`, password: `secrets/ftp_password.txt`)

## Instructions

### Prerequisites

- Docker installed on your system (inside a virtual machine, as required by the subject)
- Docker Compose v2 (`docker compose`)
- Bash shell
- Basic understanding of Docker concepts

### Installation & Compilation

1. **Configure environment variables**:
	Copy `srcs/.env.example` to `srcs/.env` and edit it with your login, domain name, and non-sensitive settings:
	```
	LOGIN_NAME=your_login
	DOMAIN_NAME=your_login.42.fr
	SITE_TITLE=Your Site Title
	DATA_DIR=/home/${LOGIN_NAME}/data
	SQL_DATABASE=wordpress
	SQL_USER=wp_user
	SQL_PASSWORD_FILE=/run/secrets/db_password
	SQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_password
	ADMIN_USER=site_owner
	ADMIN_PASSWORD_FILE=/run/secrets/wp_admin_password
	USER_LOGIN=wp_user
	USER_PASS_FILE=/run/secrets/wp_user_password
	```

2. **Create data directories** (as required by the subject). The `make up` command creates them automatically, or you can create them manually:
	```bash
	mkdir -p /home/your_login/data/wordpress
	mkdir -p /home/your_login/data/mariadb
	chmod 755 /home/your_login/data
	```

3. **Create Docker secrets locally** (never commit them):
	```bash
	mkdir -p secrets
	printf '%s' 'change_me_db_password' > secrets/db_password.txt
	printf '%s' 'change_me_db_root_password' > secrets/db_root_password.txt
	printf '%s' 'change_me_wp_admin_password' > secrets/wp_admin_password.txt
	printf '%s' 'change_me_wp_user_password' > secrets/wp_user_password.txt
	printf '%s' 'change_me_ftp_password' > secrets/ftp_password.txt
	chmod 600 secrets/*.txt
	```

4. **Update your hosts file** (domain required by the subject):
	```bash
	sudo nano /etc/hosts
	# Add: <your_local_ip> your_login.42.fr
	```

### Building & Running

The project includes a Makefile for easy management:

```bash
# Start all services
make up

# Stop all services
make down

# View logs
make logs

# Clean all containers and volumes
make fclean

# Rebuild from scratch
make re
```

**Manual Docker Compose commands**:
```bash
cd srcs/
docker compose up -d          # Start in detached mode
docker compose logs -f        # Follow logs
docker compose ps             # View running containers
docker compose down           # Stop services
docker compose down -v        # Stop and remove volumes
```

### Accessing the Website

- **WordPress site**: `https://your-domain.com`
- **WordPress admin panel**: `https://your-domain.com/wp-admin`
- **Adminer** (bonus): `https://your-domain.com/adminer` — Server: `mariadb`, User: `root` ou `SQL_USER`, Password: `secrets/db_root_password.txt` ou `secrets/db_password.txt`
- **Static showcase** (bonus): `https://your-domain.com/portfolio`
- **Login credentials**: the admin username is `ADMIN_USER` from `srcs/.env` on the first install; passwords come from `secrets/*.txt`. If the database volume already exists, WordPress keeps the existing users/passwords (use WP-CLI to update them or recreate volumes).

## Docker Architecture & Design Choices

### Virtual Machines vs Docker

| Aspect | Virtual Machines | Docker |
|--------|------------------|--------|
| **Overhead** | Full OS per instance (~GBs) | Lightweight container (~MBs) |
| **Boot time** | Minutes | Seconds |
| **Resource usage** | High (RAM, disk) | Low |
| **Use case** | Complete OS isolation | Process-level isolation |
| **This project** | ❌ Not suitable | ✅ Chosen for efficiency |

**Why Docker for Inception**: Containers provide enough isolation while minimizing resource consumption, making them ideal for development and CI/CD pipelines.

### Secrets vs Environment Variables

| Method | Pros | Cons | Used in Inception |
|--------|------|------|------------------|
| **Secrets** | Not stored in images or git | Need local files during setup | ✅ Used for DB and WP passwords |
| **Environment Variables** | Simple for non-sensitive config | Not appropriate for passwords | ✅ Used for domain, users, settings |

**Design choice**: The project keeps non-sensitive configuration in `srcs/.env`, and uses Docker secrets (files mounted under `/run/secrets/`) for passwords.

### Docker Network vs Host Network

| Network Type | Isolation | Performance | Security |
|--------------|-----------|-------------|----------|
| **Docker Network** | High (containers isolated) | Slight overhead | Better isolation |
| **Host Network** | None (shares host network) | Better performance | Containers exposed to host |

**Design choice**: The project uses a custom `inception` bridge network. This allows:
- Containers to communicate via internal DNS (e.g., `mariadb:3306`)
- External traffic only through Nginx on port 443
- No unnecessary port exposure

### Docker Volumes vs Bind Mounts

| Type | Use Case | Persistence | Portability |
|------|----------|-------------|-------------|
| **Named Volumes** | Managed data | Managed by Docker | Better for production |
| **Bind Mounts** | Development, specific paths | Direct filesystem | More control |

**Design choice**: The project uses Docker **named volumes** for persistence, backed by host directories under `/home/<login>/data` as required by the subject. The configuration is:

```yaml
volumes:
  wordpress_data:
	 driver: local
	 driver_opts:
		type: none
		o: bind
		device: ${DATA_DIR}/wordpress
```

**Benefits**:
- Easy to backup data outside the project
- Direct access to files from the host
- Useful for development and debugging

## Resources

### Docker & Containerization
- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Compose Guide](https://docs.docker.com/compose/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Nginx & Reverse Proxies
- [Nginx Beginners Guide](https://nginx.org/en/docs/beginners_guide.html)
- [SSL/TLS Configuration in Nginx](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)

### WordPress & PHP
- [WordPress.org Official Site](https://wordpress.org/)
- [WP-CLI Documentation](https://developer.wordpress.org/cli/commands/)
- [PHP-FPM Configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### Database & MariaDB
- [MariaDB Official Documentation](https://mariadb.org/documentation/)
- [MySQL/MariaDB Basics](https://mariadb.com/kb/en/mariadb-basics/)

### Security
- [Let's Encrypt & HTTPS](https://letsencrypt.org/)
- [SSL/TLS Best Practices](https://en.wikipedia.org/wiki/Transport_Layer_Security)
- [Environment Variable Security](https://12factor.net/config)

### AI Usage

AI assistance was used for:
1. **Script validation and debugging** - Reviewing shell scripts (setup.sh, entrypoint.sh) for correctness and best practices
2. **Docker configuration optimization** - Ensuring Dockerfile best practices and minimal image sizes
3. **Documentation structure** - Creating clear, comprehensive documentation following industry standards
4. **Troubleshooting guidance** - Explaining common Docker issues and solutions

AI did not generate the code itself; it provided guidance on structure, debugging, and best practices.
