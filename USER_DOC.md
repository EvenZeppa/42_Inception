# Inception - User Documentation

This guide explains how to use the Inception infrastructure as an end user or administrator.

## Table of Contents

1. [Understanding the Services](#understanding-the-services)
2. [Starting and Stopping the Project](#starting-and-stopping-the-project)
3. [Accessing the Website and Admin Panel](#accessing-the-website-and-admin-panel)
4. [Managing Credentials](#managing-credentials)
5. [Checking Service Health](#checking-service-health)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Understanding the Services

The Inception stack provides a complete web hosting solution with three services:

### 1. Nginx (Web Server)
- **What it does**: Handles all incoming web requests and serves your website
- **Port**: 443 (HTTPS/SSL)
- **Purpose**: Acts as the entry point for all web traffic
- **Status**: Always running in background

### 2. WordPress (Website Content)
- **What it does**: Powers your website with dynamic content management
- **Features**: Manage posts, pages, users, themes, and plugins
- **User access**: Through the admin panel at `/wp-admin`
- **Port**: Not exposed externally (internal only)

### 3. MariaDB (Database)
- **What it does**: Stores all website data (posts, users, settings, etc.)
- **Port**: Not exposed externally (internal only)
- **Importance**: Cannot function without this; all content depends on it

### 4. Adminer (Bonus)
- **What it does**: Web interface to manage the MariaDB database
- **Access**: `https://your-domain.com/adminer`
- **Login**: Server = `mariadb`, User = `root` (or SQL_USER from .env), Password = from `secrets/db_root_password.txt` (or `secrets/db_password.txt` for SQL_USER)

### 5. Static Site (Bonus)
- **What it does**: Simple HTML/CSS showcase page
- **Access**: `https://your-domain.com/portfolio`

### 6. Redis (Bonus)
- **What it does**: Object cache for WordPress (plugin redis-cache)
- **Purpose**: Improves performance by caching database queries and objects
- **Port**: Internal only (6379)

### 7. FTP (Bonus)
- **What it does**: vsftpd server for direct file access to the WordPress volume
- **Access**: FTP on port 21 (host)
- **Login**: `ftpuser` / Password: from `secrets/ftp_password.txt`
- **Home directory**: `/var/www/html` (WordPress files)

## Starting and Stopping the Project

### Starting the Infrastructure

**Using Make** (recommended):
```bash
cd /path/to/Inception
make up
```

**Manual method**:
```bash
cd /Users/dev/Documents/Workspace/Doker/Inception/srcs
docker-compose up -d
```

The `-d` flag runs containers in the background. Startup takes 10-30 seconds.

### Stopping the Infrastructure

**Using Make**:
```bash
make down
```

**Manual method**:
```bash
cd /Users/dev/Documents/Workspace/Doker/Inception/srcs
docker-compose down
```

**Important**: `down` stops containers but preserves your data (stored in `/home/<login>/data/`).

### Complete Cleanup (Removes Everything)

```bash
make fclean
```

⚠️ **Warning**: This removes all data! Only use if you want to start completely fresh.

## Accessing the Website and Admin Panel

### Prerequisites for Local Access

1. **Edit your hosts file** (so your domain resolves locally):
   ```bash
   sudo nano /etc/hosts
   ```
   
   Add this line:
   ```
   127.0.0.1 your-domain.com
   ```
   
   (Replace `your-domain.com` with the domain in your `.env` file)

2. **Accept the SSL certificate warning** (it's self-signed and expected)

### Accessing the Public Website

Open your browser and navigate to:
```
https://your-domain.com
```

You will see your WordPress website's home page.

### Accessing the WordPress Admin Panel

Navigate to:
```
https://your-domain.com/wp-admin
```

You will be prompted to log in.

### Login Credentials

Use the credentials from the `.env` file:
```
Username: ADMIN_USER    (from .env)
Password: ADMIN_PASSWORD (from .env)
```

Example: use `ADMIN_USER` from `.env` and password from `secrets/wp_admin_password.txt`.

## Managing Credentials

### Locating Your Credentials

All credentials are stored in:
- `srcs/.env` — non-sensitive configuration (domain, usernames)
- `secrets/*.txt` — passwords (never commit these)

### Credential Types

**WordPress Admin User** (from `srcs/.env` and `secrets/wp_admin_password.txt`):
```env
ADMIN_USER=site_owner
ADMIN_PASSWORD_FILE=/run/secrets/wp_admin_password
ADMIN_EMAIL=admin@42.fr
```

**WordPress Regular User**:
```env
USER_LOGIN=wp_user
USER_PASS_FILE=/run/secrets/wp_user_password
USER_EMAIL=user@student.42.fr
```

**Database Credentials** (passwords in secrets):
```env
SQL_DATABASE=wordpress
SQL_USER=wp_user
SQL_PASSWORD_FILE=/run/secrets/db_password
SQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_password
```

### Changing Credentials

#### Change WordPress Admin Password

1. Access the admin panel: `https://your-domain.com/wp-admin`
2. Go to **Users** → **Administrator**
3. Click **Edit**
4. Scroll to **New Password** and generate a new one
5. Click **Update Profile**

#### Change Database Credentials

⚠️ **Warning**: Changing database credentials requires recreation of containers.

1. Stop the stack:
   ```bash
   make down
   ```

2. Edit `.env` file:
   ```bash
   nano srcs/.env
   ```

3. Change `SQL_USER` and update `secrets/db_password.txt`

4. Remove old data (containers will recreate the database):
   ```bash
   rm -rf /home/your_login/data/mariadb/*
   ```

5. Restart:
   ```bash
   make up
   ```

⚠️ **This will lose all database data. Back up if needed!**

## Checking Service Health

### Quick Status Check

```bash
make ps
# or manually:
docker-compose ps
```

You should see three containers with status `Up`:
```
NAME                  STATUS
nginx-container       Up 5 minutes
wordpress-container   Up 4 minutes
mariadb-container     Up 4 minutes
```

### View Live Logs

```bash
make logs
# or manually:
docker-compose logs -f
```

Press `Ctrl+C` to exit log viewing.

### Check Individual Service Logs

```bash
# Nginx logs
docker-compose logs nginx

# WordPress logs
docker-compose logs wordpress

# Database logs
docker-compose logs mariadb
```

### Verify Website Accessibility

Open your browser and check:
1. `https://your-domain.com` - Should load the homepage
2. `https://your-domain.com/wp-admin` - Should show login form

### Verify Database Connectivity

To check if WordPress can connect to the database:

1. Go to WordPress admin: `https://your-domain.com/wp-admin`
2. If the login page loads, database is working
3. If you get "Error establishing database connection", database is down

### Check Running Processes Inside Containers

```bash
# List all running containers
docker ps

# Get shell access to a container (for advanced debugging)
docker-compose exec wordpress /bin/bash
docker-compose exec mariadb /bin/bash
docker-compose exec nginx /bin/bash
```

## Troubleshooting Common Issues

### Issue: Website Returns "Connection Refused"

**Cause**: Containers might not be running.

**Solution**:
```bash
make up
# Wait 10-15 seconds for startup
```

### Issue: "Error Establishing Database Connection"

**Cause**: WordPress cannot reach MariaDB.

**Solutions**:
1. Check if MariaDB is running:
   ```bash
   docker-compose logs mariadb
   ```

2. Verify credentials in `.env` match the database setup:
   ```bash
   nano srcs/.env
   ```

3. Wait longer - database initialization can take 20-30 seconds:
   ```bash
   # Watch the logs
   make logs
   # When you see "mysqld ready for connections", database is ready
   ```

### Issue: SSL Certificate Warning in Browser

**This is normal and expected!**

The certificate is self-signed (not from a trusted authority). 

**To proceed**:
- Chrome: Click "Advanced" → "Proceed to..." 
- Firefox: Click "Advanced" → "Accept the Risk and Continue"
- Safari: Continue anyway

### Issue: Cannot Access `your-domain.com`

**Cause**: Domain not configured in hosts file or `.env`.

**Solution**:
1. Check your `.env`:
   ```bash
   cat srcs/.env | grep DOMAIN_NAME
   ```

2. Verify hosts file has the same domain:
   ```bash
   sudo nano /etc/hosts
   # Should have: 127.0.0.1 your-domain.com
   ```

3. Clear browser cache and try again

### Issue: Cannot Log In to WordPress

**Cause**: Incorrect credentials or database corruption.

**Solutions**:
1. Verify credentials in `.env`:
   ```bash
   cat srcs/.env | grep ADMIN
   ```

2. Check if WordPress is fully initialized:
   ```bash
   docker-compose logs wordpress
   # Wait for: "WordPress setup is complete"
   ```

3. Reset everything (deletes all content):
   ```bash
   make fclean
   rm -rf /home/your_login/data/*
   make up
   ```

### Issue: Containers Keep Crashing

**Check logs** to find the specific error:
```bash
make logs
```

**Common causes**:
- Database not initialized yet (wait 30 seconds)
- Permissions issues with `/home/<login>/data/` directories
- Port 443 already in use

**Fix permissions**:
```bash
chmod 755 /home/your_login/data
chmod 777 /home/your_login/data/wordpress
chmod 777 /home/your_login/data/mariadb
```

### Issue: Cannot Write to WordPress (Permission Denied)

**Cause**: File permission issues.

**Solution**:
```bash
# Make data directory writable (replace your_login with your login)
sudo chown -R 33:33 /home/your_login/data/wordpress
sudo chmod -R 755 /home/your_login/data/wordpress
```

(33 is the www-data user ID inside containers)

## Getting Help

If issues persist:

1. **Check logs** for error messages:
   ```bash
   make logs | tail -100
   ```

2. **Verify all containers are running**:
   ```bash
   docker-compose ps
   ```

3. **Restart everything**:
   ```bash
   make down
   sleep 5
   make up
   sleep 20  # Give services time to initialize
   ```

4. **Check disk space** - Docker needs space for images and volumes:
   ```bash
   df -h
   ```

5. **Consult the README.md** for technical details and architecture information
