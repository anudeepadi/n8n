# n8n Setup for Ubuntu 24.04 LTS Server

This guide provides a complete setup for n8n workflow automation on Ubuntu 24.04 LTS.

## Quick Setup

1. **Copy the setup script to your Ubuntu server:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/setup-n8n-ubuntu.sh
   # OR copy the script manually from this repository
   ```

2. **Make it executable:**
   ```bash
   chmod +x setup-n8n-ubuntu.sh
   ```

3. **Run the setup:**
   ```bash
   ./setup-n8n-ubuntu.sh
   ```

## What the Script Does

The setup script automatically:

- ✅ Updates your Ubuntu system
- ✅ Installs Docker and Docker Compose
- ✅ Creates n8n configuration files
- ✅ Sets up proper directory structure
- ✅ Configures basic authentication
- ✅ Creates systemd service for auto-start
- ✅ Configures firewall (if UFW is active)
- ✅ Starts n8n container

## Default Configuration

### Access Information
- **URL:** `http://YOUR_SERVER_IP:5678`
- **Username:** `admin`
- **Password:** `n8n_password_change_me` ⚠️ **CHANGE THIS!**

### Installation Directory
- **Location:** `/opt/n8n/`
- **Data:** `/opt/n8n/data/`
- **Local Files:** `/opt/n8n/local-files/`
- **Config:** `/opt/n8n/.env`

## Post-Installation Tasks

### 1. Change Default Password
```bash
sudo nano /opt/n8n/.env
# Change N8N_BASIC_AUTH_PASSWORD to a secure password
sudo systemctl restart n8n
```

### 2. Configure Domain (Optional)
If you have a domain name:
```bash
sudo nano /opt/n8n/.env
# Change WEBHOOK_URL=http://your-domain.com:5678/
sudo systemctl restart n8n
```

### 3. Set Up SSL/TLS (Recommended for Production)

#### Option A: Using Nginx Reverse Proxy
```bash
sudo apt install nginx certbot python3-certbot-nginx

# Create nginx config
sudo nano /etc/nginx/sites-available/n8n
```

Add this configuration:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site and get SSL certificate:
```bash
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d your-domain.com
```

Update n8n configuration:
```bash
sudo nano /opt/n8n/.env
# Change:
# N8N_PROTOCOL=https
# WEBHOOK_URL=https://your-domain.com/
sudo systemctl restart n8n
```

### 4. Database Migration to PostgreSQL (Production)

For production environments, consider using PostgreSQL:

1. **Install PostgreSQL:**
```bash
sudo apt install postgresql postgresql-contrib
sudo -u postgres createuser n8n
sudo -u postgres createdb n8n_db -O n8n
sudo -u postgres psql -c "ALTER USER n8n PASSWORD 'secure_password';"
```

2. **Update n8n configuration:**
```bash
sudo nano /opt/n8n/.env
# Change database settings:
# DB_TYPE=postgresdb
# DB_POSTGRESDB_HOST=localhost
# DB_POSTGRESDB_PORT=5432
# DB_POSTGRESDB_DATABASE=n8n_db
# DB_POSTGRESDB_USER=n8n
# DB_POSTGRESDB_PASSWORD=secure_password
```

3. **Restart n8n:**
```bash
sudo systemctl restart n8n
```

## Management Commands

### Service Management
```bash
# Start n8n
sudo systemctl start n8n

# Stop n8n
sudo systemctl stop n8n

# Restart n8n
sudo systemctl restart n8n

# Check status
sudo systemctl status n8n

# Enable auto-start (already done by script)
sudo systemctl enable n8n
```

### Docker Commands
```bash
# Navigate to n8n directory
cd /opt/n8n

# View logs
docker compose logs -f

# Stop containers
docker compose down

# Start containers
docker compose up -d

# Update n8n to latest version
docker compose pull
docker compose up -d
```

## Backup and Restore

### Backup
```bash
# Create backup directory
sudo mkdir -p /backup/n8n

# Backup data and configuration
sudo tar -czf /backup/n8n/n8n-backup-$(date +%Y%m%d).tar.gz /opt/n8n/
```

### Restore
```bash
# Stop n8n
sudo systemctl stop n8n

# Restore from backup
sudo tar -xzf /backup/n8n/n8n-backup-YYYYMMDD.tar.gz -C /

# Start n8n
sudo systemctl start n8n
```

## Troubleshooting

### Check if n8n is running
```bash
docker ps | grep n8n
sudo systemctl status n8n
```

### View logs
```bash
cd /opt/n8n
docker compose logs -f
journalctl -u n8n -f
```

### Reset n8n (⚠️ This will delete all data)
```bash
sudo systemctl stop n8n
sudo rm -rf /opt/n8n/data/*
sudo systemctl start n8n
```

### Common Issues

1. **Port 5678 already in use:**
   ```bash
   sudo lsof -i :5678
   # Kill the process or change the port in .env file
   ```

2. **Docker permission denied:**
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

3. **Firewall blocking access:**
   ```bash
   sudo ufw allow 5678/tcp
   # Or for HTTPS
   sudo ufw allow 443/tcp
   ```

## Security Best Practices

1. **Change default password immediately**
2. **Use HTTPS in production**
3. **Regularly update the system and Docker images**
4. **Use PostgreSQL for production databases**
5. **Implement proper backup strategies**
6. **Monitor logs for suspicious activity**
7. **Use a reverse proxy (nginx/apache) for SSL termination**
8. **Consider using fail2ban for additional security**

## Support

- **n8n Documentation:** https://docs.n8n.io/
- **n8n Community:** https://community.n8n.io/
- **Docker Documentation:** https://docs.docker.com/

## License

This setup script is provided as-is. Please refer to n8n's official license for the software itself. 