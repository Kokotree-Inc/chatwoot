# Chatwoot Deployment Documentation

This directory contains documentation and scripts for deploying Chatwoot to production servers.

## 📁 Files Overview

### Deployment Scripts

#### `deploy-server-build.sh`
**Location:** Root directory  
**Purpose:** Main deployment script that builds and deploys Chatwoot to Ubuntu production server

**What it does:**
- Syncs code to server via rsync
- Builds Docker image on server (includes SDK build and asset precompilation)
- Runs database migrations
- Starts Docker services (Rails, Sidekiq, PostgreSQL, Redis)
- Verifies deployment
- Cleans up old Docker images

**Usage:**
```bash
./deploy-server-build.sh
```

**Configuration:**
- Edit `REMOTE_HOST` and `DEPLOY_DIR` variables at the top of the script
- Ensure `.env` file exists on server before deployment

---

### Documentation Files

#### `DEPLOYMENT.md`
**Location:** `docs/` directory  
**Purpose:** Comprehensive deployment guide with prerequisites, configuration, and troubleshooting

**Contains:**
- Prerequisites and server requirements
- Environment variables setup
- Deployment process explanation
- Post-deployment verification
- Common operations and commands
- Troubleshooting guide

**When to use:** Read before first deployment or when troubleshooting issues

---

#### `deploy-quick-start.md`
**Location:** `docs/` directory  
**Purpose:** Quick reference guide for deployment

**Contains:**
- One-command deployment
- Pre-deployment checklist
- What happens during deployment
- Common commands
- Troubleshooting tips

**When to use:** Quick reference during deployment

---

#### `NGINX_SETUP.md`
**Location:** `docs/` directory  
**Purpose:** Step-by-step guide for setting up Nginx reverse proxy

**Contains:**
- 8-step installation process
- Domain configuration
- SSL certificate setup with certbot
- Troubleshooting section
- Port information
- Maintenance commands

**When to use:** After deploying Chatwoot, to set up web server and SSL

---

#### `DOMAIN_SETUP.md`
**Location:** `docs/` directory  
**Purpose:** Domain and DNS configuration guide

**Contains:**
- Public domain URL options
- DNS A record setup instructions
- Configuration file locations
- Widget embed code examples
- Verification checklist

**When to use:** Before setting up Nginx, to configure DNS

---

#### `PORT_CHECK.md`
**Location:** `docs/` directory  
**Purpose:** Port conflict analysis and verification

**Contains:**
- Existing container port analysis
- Chatwoot port requirements
- Conflict verification commands
- Solutions for port conflicts

**When to use:** Before deployment, to verify no port conflicts

---

### Configuration Files

#### `nginx-chatwoot.conf`
**Location:** Root directory  
**Purpose:** Nginx reverse proxy configuration for Chatwoot

**Features:**
- Reverse proxy to Chatwoot (port 3080)
- WebSocket support for ActionCable
- Static asset caching
- SSL/HTTPS ready
- Security headers
- File upload support (100MB)

**Usage:**
```bash
sudo cp nginx-chatwoot.conf /etc/nginx/sites-available/chatwoot
sudo nano /etc/nginx/sites-available/chatwoot  # Edit domain
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## 🚀 Quick Start Guide

### First Time Deployment

1. **Read Documentation:**
   - Start with `docs/DEPLOYMENT.md` for overview
   - Check `docs/PORT_CHECK.md` for port conflicts
   - Review `docs/DOMAIN_SETUP.md` for DNS setup

2. **Configure Deployment:**
   - Edit `deploy-server-build.sh`:
     - Set `REMOTE_HOST` (SSH hostname)
     - Set `DEPLOY_DIR` (default: `/var/www/apaya/chatwoot`)

3. **Prepare Server:**
   - Ensure Docker and Docker Compose installed
   - Create `.env` file on server with required variables
   - Set up DNS A record for your domain

4. **Deploy:**
   ```bash
   ./deploy-server-build.sh
   ```

5. **Setup Nginx:**
   - Follow `docs/NGINX_SETUP.md` step-by-step
   - Copy `nginx-chatwoot.conf` to server
   - Install SSL certificate with certbot

6. **Verify:**
   - Access dashboard: `https://chat.apaya.com`
   - Test widget SDK: `https://chat.apaya.com/packs/js/sdk.js`

---

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Server has Docker and Docker Compose installed
- [ ] SSH access configured (`~/.ssh/config`)
- [ ] `.env` file created on server with all required variables
- [ ] DNS A record pointing to server IP
- [ ] Ports checked for conflicts (`docs/PORT_CHECK.md`)
- [ ] Deployment script configured (`deploy-server-build.sh`)

### Deployment
- [ ] Run deployment script: `./deploy-server-build.sh`
- [ ] Verify Docker containers are running
- [ ] Check Chatwoot logs for errors
- [ ] Verify SDK file exists: `/app/public/packs/js/sdk.js`

### Post-Deployment
- [ ] Nginx configuration copied and domain set
- [ ] Nginx site enabled and tested
- [ ] SSL certificate installed with certbot
- [ ] HTTPS access verified
- [ ] Dashboard accessible
- [ ] Widget SDK accessible
- [ ] `.env` file updated with `FRONTEND_URL`

---

## 🔧 Configuration Reference

### Environment Variables (.env)

Required variables for Chatwoot:

```bash
# Database
POSTGRES_PASSWORD=your_password
POSTGRES_HOST=postgres
POSTGRES_USERNAME=postgres
POSTGRES_DATABASE=chatwoot

# Redis
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=your_redis_password

# Rails
SECRET_KEY_BASE=your_secret_key
RAILS_ENV=production
NODE_ENV=production

# Frontend URL (set after nginx setup)
FRONTEND_URL=https://chat.apaya.com

# Other required variables...
```

### Server Ports

| Service | Port | Binding |
|---------|------|---------|
| Chatwoot Rails | 3080 | 127.0.0.1:3080 |
| PostgreSQL | 5432 | 127.0.0.1:5432 |
| Redis | 6379 | 127.0.0.1:6379 |
| Nginx HTTP | 80 | 0.0.0.0:80 |
| Nginx HTTPS | 443 | 0.0.0.0:443 |

---

## 📞 Common Commands

### Deployment
```bash
# Deploy to server
./deploy-server-build.sh

# View deployment logs
ls -la deploy/
tail -f deploy/deploy_server_build_*.log
```

### Docker Management
```bash
# Check containers
ssh server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml ps'

# View logs
ssh server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs -f rails'

# Restart services
ssh server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml restart'
```

### Nginx Management
```bash
# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# View logs
sudo tail -f /var/log/nginx/chatwoot_error_443.log
```

---

## 🆘 Troubleshooting

### Deployment Issues
- See `docs/DEPLOYMENT.md` → Troubleshooting section
- Check deployment logs in `deploy/` directory
- Verify server has enough disk space and RAM

### Nginx Issues
- See `docs/NGINX_SETUP.md` → Troubleshooting section
- Check nginx error logs: `/var/log/nginx/chatwoot_error_*.log`
- Verify Chatwoot container is running on port 3080

### Port Conflicts
- See `docs/PORT_CHECK.md` for conflict resolution
- Check existing containers: `docker ps`
- Verify ports: `sudo netstat -tlnp`

### Domain/DNS Issues
- See `docs/DOMAIN_SETUP.md` for DNS configuration
- Verify DNS: `dig chat.apaya.com`
- Check DNS propagation before running certbot

---

## 📚 Additional Resources

- **Chatwoot Official Docs:** https://www.chatwoot.com/docs
- **Docker Documentation:** https://docs.docker.com
- **Nginx Documentation:** https://nginx.org/en/docs/
- **Certbot Documentation:** https://certbot.eff.org/docs

---

## 📝 File Locations Summary

### On Local Machine
- `deploy-server-build.sh` - Deployment script (root)
- `nginx-chatwoot.conf` - Nginx configuration (root)
- `docs/DEPLOYMENT_README.md` - This file
- `docs/DEPLOYMENT.md` - Full deployment guide
- `docs/NGINX_SETUP.md` - Nginx setup guide
- `docs/DOMAIN_SETUP.md` - Domain configuration guide
- `docs/PORT_CHECK.md` - Port conflict analysis
- `docs/deploy-quick-start.md` - Quick reference
- `docs/PORT_CHANGE.md` - Port change documentation

### On Server
- `/var/www/apaya/chatwoot/` - Chatwoot deployment directory
- `/etc/nginx/sites-available/chatwoot` - Nginx config
- `/etc/nginx/sites-enabled/chatwoot` - Enabled nginx config
- `/var/log/nginx/chatwoot_*.log` - Nginx logs
- `/etc/letsencrypt/live/chat.apaya.com/` - SSL certificates

---

**Last Updated:** 2024  
**Maintained by:** Kokotree Team

