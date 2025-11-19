# Chatwoot Deployment Guide

Complete guide for deploying Chatwoot to production on Ubuntu server.

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Deployment Scripts](#deployment-scripts)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Process](#deployment-process)
5. [Nginx Setup](#nginx-setup)
6. [SSL Certificate Setup](#ssl-certificate-setup)
7. [Post-Deployment](#post-deployment)
8. [Troubleshooting](#troubleshooting)
9. [Common Commands](#common-commands)

---

## 🚀 Quick Start

### First Time Deployment

```bash
# 1. Deploy Chatwoot
./deploy.sh  # or ./deploy-server-build.sh

# 2. Setup Nginx (manual)
scp nginx-chatwoot.conf kokotree-prod-server:/tmp/
ssh kokotree-prod-server
sudo cp /tmp/nginx-chatwoot.conf /etc/nginx/sites-available/chatwoot
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 3. Setup SSL (manual)
sudo certbot --nginx -d chat.apaya.com

# 4. Update FRONTEND_URL
nano /var/www/apaya/chatwoot/.env
# Add: FRONTEND_URL=https://chat.apaya.com
docker compose -f docker-compose.production.yaml restart rails sidekiq
```

---

## 📦 Deployment Scripts

### Script 1: `deploy.sh` (Registry-Based - Recommended)

**What it does:**
- Builds Docker image locally
- Pushes to Docker Hub registry
- Pulls image on server
- Starts containers

**Configuration:**
Add to `.env`:
```bash
DOCKER_USERNAME=raghavkokotree
REMOTE_HOST=kokotree-prod-server
IMAGE_NAME=chatwoot
IMAGE_TAG=latest
DEPLOY_DIR=/var/www/apaya/chatwoot
PRODUCTION_FRONTEND_URL=https://chat.apaya.com  # Optional
```

**Usage:**
```bash
./deploy.sh
```

**Pros:**
- ✅ Faster deployments (2-5 minutes)
- ✅ No build on server
- ✅ Easy rollback
- ✅ Industry standard

---

### Script 2: `deploy-server-build.sh` (Build on Server)

**What it does:**
- Syncs source code to server (tar/gzip)
- Builds Docker image on server
- Runs database migrations
- Starts containers

**Configuration:**
Edit script variables:
```bash
REMOTE_HOST="kokotree-prod-server"
DEPLOY_DIR="/var/www/apaya/chatwoot"
```

**Usage:**
```bash
./deploy-server-build.sh
```

**Pros:**
- ✅ No registry needed
- ✅ Full control
- ✅ Good for single server

**Cons:**
- ❌ Slower (15-30 minutes)
- ❌ Uses server resources

---

## ✅ Pre-Deployment Checklist

### Server Requirements

- [ ] Ubuntu server with sudo access
- [ ] Docker and Docker Compose installed
- [ ] SSH access configured (`~/.ssh/config`)
- [ ] Domain DNS configured (`chat.apaya.com` → server IP)
- [ ] Ports available (3080, 5432, 6379)
- [ ] `.env` file ready (or will be synced by script)

### Local Machine

- [ ] Git repository cloned
- [ ] `.env` file exists (for `deploy.sh`)
- [ ] Docker installed (for `deploy.sh`)
- [ ] SSH access to server tested

### Environment Variables

Required in `.env`:
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

# Frontend (set after SSL)
FRONTEND_URL=https://chat.apaya.com
```

---

## 🔄 Deployment Process

### Using `deploy.sh` (Registry-Based)

1. **Build and Push:**
   ```bash
   ./deploy.sh
   ```
   - Builds Docker image locally
   - Pushes to Docker Hub
   - Syncs `.env` to server (with production values)
   - Pulls image on server
   - Starts containers

2. **Verify:**
   ```bash
   ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose ps'
   ```

### Using `deploy-server-build.sh` (Build on Server)

1. **Deploy:**
   ```bash
   ./deploy-server-build.sh
   ```
   - Creates tar.gz archive
   - Transfers to server
   - Extracts on server
   - Builds Docker image
   - Runs migrations
   - Starts containers

2. **Verify:**
   ```bash
   ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose ps'
   ```

---

## 🌐 Nginx Setup

### Step 1: Copy Config to Server

```bash
# From local machine
scp nginx-chatwoot.conf kokotree-prod-server:/tmp/nginx-chatwoot.conf
```

### Step 2: Install Config on Server

```bash
# SSH into server
ssh kokotree-prod-server

# Copy to nginx sites-available
sudo cp /tmp/nginx-chatwoot.conf /etc/nginx/sites-available/chatwoot

# Edit if needed (domain is already set to chat.apaya.com)
sudo nano /etc/nginx/sites-available/chatwoot
```

### Step 3: Enable Site

```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Expected: "nginx: configuration file ... test is successful"
```

### Step 4: Reload Nginx

```bash
# Reload nginx
sudo systemctl reload nginx

# Check status
sudo systemctl status nginx

# Test HTTP (before SSL)
curl -I http://chat.apaya.com
```

---

## 🔒 SSL Certificate Setup

### Prerequisites

- ✅ DNS configured (`chat.apaya.com` → server IP)
- ✅ Nginx configured and running
- ✅ Port 80 accessible from internet

### Step 1: Verify DNS

```bash
# From local machine
nslookup chat.apaya.com
# Should return your server IP
```

### Step 2: Install Certbot

```bash
# On server
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### Step 3: Obtain Certificate

```bash
# Run certbot
sudo certbot --nginx -d chat.apaya.com

# Follow prompts:
# - Enter email address
# - Agree to terms
# - Redirect HTTP to HTTPS? (Yes - recommended)
```

Certbot will automatically:
- ✅ Obtain SSL certificate
- ✅ Update nginx config
- ✅ Set up auto-renewal
- ✅ Reload nginx

### Step 4: Verify SSL

```bash
# Test HTTPS
curl -I https://chat.apaya.com

# Check certificate
sudo certbot certificates

# Test auto-renewal
sudo certbot renew --dry-run
```

---

## 🎯 Post-Deployment

### Step 1: Update FRONTEND_URL

```bash
# SSH into server
ssh kokotree-prod-server

# Edit .env file
nano /var/www/apaya/chatwoot/.env

# Add/Update:
FRONTEND_URL=https://chat.apaya.com
```

### Step 2: Restart Services

```bash
cd /var/www/apaya/chatwoot
docker compose -f docker-compose.production.yaml restart rails sidekiq
```

### Step 3: Verify Everything

```bash
# Test HTTPS
curl -I https://chat.apaya.com

# Test SDK
curl https://chat.apaya.com/packs/js/sdk.js | head -20

# Access dashboard
# Open: https://chat.apaya.com
```

---

## 🆘 Troubleshooting

### 502 Bad Gateway

**Cause:** Chatwoot container not running or wrong port

**Fix:**
```bash
# Check containers
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose ps'

# Check logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose logs rails'

# Verify port 3080
ssh kokotree-prod-server 'netstat -tlnp | grep :3080'
```

### SSL Certificate Fails

**Cause:** DNS not configured or port 80 blocked

**Fix:**
```bash
# Verify DNS
nslookup chat.apaya.com

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check nginx is running
sudo systemctl status nginx
```

### Widget SDK 404

**Cause:** SDK not built or wrong path

**Fix:**
```bash
# Check SDK file in container
ssh kokotree-prod-server 'docker exec $(docker ps -q -f name=chatwoot-rails) ls -lh /app/public/packs/js/sdk.js'

# Rebuild if missing (deploy again)
./deploy.sh
```

### Nginx Won't Start

**Fix:**
```bash
# Test config
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log

# Check syntax
sudo nginx -T | grep -A 10 "server_name"
```

### Port Conflicts

**Check existing ports:**
```bash
# On server
docker ps
netstat -tlnp | grep -E ':3080|:5432|:6379'
```

**Chatwoot uses:**
- Port 3080: Rails (bound to localhost)
- Port 5432: PostgreSQL (internal)
- Port 6379: Redis (internal)

### PostgreSQL Restarting / Not Starting

**Cause:** Missing `POSTGRES_PASSWORD` in `.env` or compose file not reading `.env`

**Symptoms:**
- PostgreSQL container keeps restarting
- Logs show: "Database is uninitialized and superuser password is not specified"

**Fix:**
```bash
# 1. Check if password exists in .env
ssh kokotree-prod-server 'grep POSTGRES_PASSWORD /var/www/apaya/chatwoot/.env'

# 2. Verify docker-compose.production.yaml has env_file: .env for postgres service
# (Should have: env_file: .env in postgres section)

# 3. Restart PostgreSQL
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml restart postgres'

# 4. Check logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml logs postgres | tail -20'
```

### Migration Failed / PostgreSQL Not Ready

**Cause:** Migration ran before PostgreSQL was ready, or PostgreSQL was restarting

**Symptoms:**
- Migration container exits with error
- Logs show: "postgres:5432 - no response"
- Rails/Sidekiq services not starting

**Fix:**
```bash
# 1. Verify PostgreSQL is running and healthy
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml ps postgres'

# 2. Check PostgreSQL logs for "ready to accept connections"
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml logs postgres | grep "ready to accept"'

# 3. Remove old migration container if exists
ssh kokotree-prod-server 'docker ps -a | grep rails-run | awk "{print \$1}" | xargs docker rm -f'

# 4. Run migration manually (PostgreSQL must be ready)
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml run --rm \
  -e RAILS_ENV=production \
  rails \
  bundle exec rails db:chatwoot_prepare'

# 5. Start Rails and Sidekiq after migration completes
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml up -d rails sidekiq'
```

### Rails/Sidekiq Not Starting

**Cause:** Migration not completed, or services not started after deployment

**Symptoms:**
- `docker compose ps` shows only postgres and redis
- Port 3080 not accessible
- No rails/sidekiq containers

**Fix:**
```bash
# 1. Check if migration completed
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml run --rm \
  -e RAILS_ENV=production \
  rails \
  bundle exec rails db:migrate:status'

# 2. If migration needed, run it (see "Migration Failed" section above)

# 3. Start Rails and Sidekiq
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml up -d rails sidekiq'

# 4. Verify services are running
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml ps'

# 5. Check Rails logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml logs rails | tail -30'

# 6. Test Rails is responding
ssh kokotree-prod-server 'curl -I http://localhost:3080'
```

### Architecture Mismatch Error

**Cause:** Image built for wrong architecture (e.g., ARM64 on Mac, but server is AMD64)

**Symptoms:**
- Error: "exec format error" or "platform does not match"
- Container exits immediately

**Fix:**
```bash
# 1. Check image architecture
docker inspect raghavkokotree/chatwoot:latest | grep Architecture

# 2. Check server architecture
ssh kokotree-prod-server 'uname -m'

# 3. Rebuild with correct platform (add to .env or deploy.sh)
# BUILD_PLATFORM=linux/amd64

# 4. Rebuild and redeploy
./deploy.sh
```

---

## 🔧 Common Commands

### Deployment

```bash
# Deploy (registry-based)
./deploy.sh

# Deploy (build on server)
./deploy-server-build.sh

# View deployment logs
ls -la deploy/
tail -f deploy/deploy_*.log
```

### Docker Management

```bash
# Check containers
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml ps'

# View logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs -f rails'

# Restart services
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml restart'

# Stop services
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml down'

# Start specific services
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml up -d postgres redis'
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml up -d rails sidekiq'
```

### Database Management

```bash
# Run migration manually
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml run --rm \
  -e RAILS_ENV=production \
  rails \
  bundle exec rails db:chatwoot_prepare'

# Check migration status
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml run --rm \
  -e RAILS_ENV=production \
  rails \
  bundle exec rails db:migrate:status'

# Rails console
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml exec rails \
  bundle exec rails console'

# PostgreSQL console
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml exec postgres \
  psql -U postgres -d chatwoot'
```

### Service Health Checks

```bash
# Check all services status
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml ps'

# Check PostgreSQL logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs postgres | tail -20'

# Check Redis logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs redis | tail -20'

# Check Rails logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs rails | tail -30'

# Check Sidekiq logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs sidekiq | tail -30'

# Test Rails HTTP endpoint
ssh kokotree-prod-server 'curl -I http://localhost:3080'

# Test PostgreSQL connection
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && \
  docker compose -f docker-compose.production.yaml exec postgres \
  pg_isready -U postgres'
```

### Nginx Management

```bash
# Test config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# View logs
sudo tail -f /var/log/nginx/chatwoot_error_443.log
sudo tail -f /var/log/nginx/chatwoot_access_443.log

# Check status
sudo systemctl status nginx
```

### SSL Management

```bash
# View certificates
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

### Clean Server (Fresh Start)

```bash
# Stop containers
cd /var/www/apaya/chatwoot
docker compose -f docker-compose.production.yaml down

# Remove Chatwoot containers/images
docker ps -a | grep chatwoot
docker stop $(docker ps -aq --filter "name=chatwoot") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=chatwoot") 2>/dev/null || true
docker images | grep chatwoot
docker rmi $(docker images -q chatwoot*) 2>/dev/null || true

# Remove volumes (⚠️ deletes database!)
docker volume ls | grep chatwoot
docker volume rm $(docker volume ls -q | grep chatwoot) 2>/dev/null || true

# Clean directory (keep .env)
cd /var/www/apaya
mv chatwoot/.env /tmp/chatwoot.env.backup 2>/dev/null || true
rm -rf chatwoot/*
mkdir -p chatwoot
mv /tmp/chatwoot.env.backup chatwoot/.env 2>/dev/null || true
```

---

## 📊 Port Information

| Service | Port | Binding | Status |
|---------|------|---------|--------|
| Chatwoot Rails | 3080 | 127.0.0.1:3080 | ✅ Localhost only |
| PostgreSQL | 5432 | 127.0.0.1:5432 | ✅ Internal |
| Redis | 6379 | 127.0.0.1:6379 | ✅ Internal |
| Nginx HTTP | 80 | 0.0.0.0:80 | ✅ Public |
| Nginx HTTPS | 443 | 0.0.0.0:443 | ✅ Public |

**No conflicts** with existing Apaya services (3015, 8282, 8888, 8889) ✅

---

## 📁 File Locations

### On Local Machine
- `deploy.sh` - Registry-based deployment script
- `deploy-server-build.sh` - Build-on-server deployment script
- `nginx-chatwoot.conf` - Nginx configuration
- `docs/DEPLOYMENT.md` - This file

### On Server
- `/var/www/apaya/chatwoot/` - Chatwoot deployment directory
- `/var/www/apaya/chatwoot/.env` - Environment variables
- `/etc/nginx/sites-available/chatwoot` - Nginx config
- `/etc/nginx/sites-enabled/chatwoot` - Enabled nginx config
- `/var/log/nginx/chatwoot_*.log` - Nginx logs
- `/etc/letsencrypt/live/chat.apaya.com/` - SSL certificates

---

## 🎯 Summary

**Automated (deployment scripts):**
- ✅ Code sync / Image build
- ✅ Docker build / Image pull
- ✅ Database setup
- ✅ Service startup
- ✅ `.env` sync (with production values)

**Manual (you need to do):**
- ⚠️ Nginx configuration
- ⚠️ SSL certificate setup
- ⚠️ Update FRONTEND_URL (if not auto-set)
- ⚠️ Restart services after .env update

**After all steps:** Chatwoot is fully deployed at `https://chat.apaya.com` 🎉

---

**Last Updated:** 2024  
**Domain:** `chat.apaya.com`  
**Deployment Directory:** `/var/www/apaya/chatwoot`

