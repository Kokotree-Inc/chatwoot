# Deployment Checklist

Follow these steps in order for a complete Chatwoot deployment.

## ✅ Step 1: Run Deployment Script

```bash
./deploy-server-build.sh
```

**What this does:**
- ✅ Syncs code to server
- ✅ Builds Docker image (includes SDK automatically)
- ✅ Starts PostgreSQL and Redis
- ✅ Runs database migrations
- ✅ Starts Rails and Sidekiq
- ✅ Verifies deployment

**Expected time:** 15-30 minutes (first time), 5-10 minutes (subsequent)

**After this step:** Chatwoot is running on `http://localhost:3080` (only accessible from server)

---

## ✅ Step 2: Setup Nginx (Manual - Required)

**Yes, Nginx setup is MANUAL** - the deployment script doesn't configure Nginx.

### 2.1: Copy Nginx Config to Server

**On your local machine:**
```bash
# Copy nginx config to server
scp nginx-chatwoot.conf kokotree-prod-server:/tmp/nginx-chatwoot.conf
```

**Or manually copy the file content** from `nginx-chatwoot.conf` to the server.

### 2.2: Install Nginx Config on Server

**SSH into server:**
```bash
ssh kokotree-prod-server

# Copy config to nginx sites-available
sudo cp /tmp/nginx-chatwoot.conf /etc/nginx/sites-available/chatwoot

# Or if you edited it locally, copy from your local machine:
# sudo nano /etc/nginx/sites-available/chatwoot
# (paste content from nginx-chatwoot.conf)
```

### 2.3: Test Nginx Configuration

```bash
# Test nginx config for syntax errors
sudo nginx -t

# Expected output: "nginx: configuration file ... test is successful"
```

### 2.4: Enable the Site

```bash
# Create symlink to enable the site
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/

# Verify symlink exists
ls -la /etc/nginx/sites-enabled/ | grep chatwoot
```

### 2.5: Reload Nginx

```bash
# Reload nginx to apply changes
sudo systemctl reload nginx

# Or restart if reload doesn't work
sudo systemctl restart nginx

# Check nginx status
sudo systemctl status nginx
```

**After this step:** Chatwoot is accessible via HTTP at `http://chat.apaya.com` (before SSL)

---

## ✅ Step 3: Setup SSL Certificate (Manual - Required)

**Important:** DNS must be configured first! Make sure `chat.apaya.com` points to your server IP.

### 3.1: Verify DNS is Working

```bash
# Check DNS resolution (from your local machine)
nslookup chat.apaya.com

# Should return your server's IP address
```

### 3.2: Install Certbot (if not already installed)

```bash
# SSH into server
ssh kokotree-prod-server

# Install certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### 3.3: Obtain SSL Certificate

```bash
# Run certbot to get SSL certificate
sudo certbot --nginx -d chat.apaya.com

# Follow the prompts:
# - Enter email address
# - Agree to terms
# - Choose whether to redirect HTTP to HTTPS (recommended: Yes)
```

**Certbot will automatically:**
- ✅ Obtain SSL certificate from Let's Encrypt
- ✅ Configure SSL in nginx config
- ✅ Set up auto-renewal
- ✅ Reload nginx

**After this step:** Chatwoot is accessible via HTTPS at `https://chat.apaya.com` ✅

---

## ✅ Step 4: Update Chatwoot Environment (Manual - Required)

### 4.1: Update FRONTEND_URL

**SSH into server:**
```bash
ssh kokotree-prod-server

# Edit .env file
nano /var/www/apaya/chatwoot/.env
```

**Add/Update this line:**
```bash
FRONTEND_URL=https://chat.apaya.com
```

**Save and exit** (Ctrl+X, then Y, then Enter)

### 4.2: Restart Chatwoot Services

```bash
# Restart to apply new environment variable
cd /var/www/apaya/chatwoot
docker compose -f docker-compose.production.yaml restart rails sidekiq
```

---

## ✅ Step 5: Verify Everything Works

### 5.1: Test HTTP (should redirect to HTTPS)

```bash
curl -I http://chat.apaya.com
# Should return 301 redirect to HTTPS
```

### 5.2: Test HTTPS

```bash
curl -I https://chat.apaya.com
# Should return 200 OK
```

### 5.3: Test Widget SDK

Open in browser:
```
https://chat.apaya.com/packs/js/sdk.js
```

Should return JavaScript code (not 404).

### 5.4: Access Dashboard

Open in browser:
```
https://chat.apaya.com
```

Should show Chatwoot login page.

---

## 📋 Quick Reference: All Manual Steps

| Step | What | When | Command |
|------|------|------|---------|
| 1 | Deploy Chatwoot | First | `./deploy-server-build.sh` |
| 2 | Setup Nginx | After deployment | See Step 2 above |
| 3 | Setup SSL | After Nginx | `sudo certbot --nginx -d chat.apaya.com` |
| 4 | Update FRONTEND_URL | After SSL | Edit `.env` file |
| 5 | Restart services | After .env update | `docker compose restart` |

---

## 🆘 Troubleshooting

### Nginx won't start
```bash
# Check nginx config
sudo nginx -t

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

### SSL certificate fails
- Make sure DNS is configured: `nslookup chat.apaya.com`
- Make sure port 80 is open: `sudo ufw allow 80`
- Make sure port 443 is open: `sudo ufw allow 443`

### Chatwoot not accessible
```bash
# Check if Chatwoot is running
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose ps'

# Check Chatwoot logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose logs rails'
```

### Widget SDK 404
```bash
# Check if SDK file exists in container
ssh kokotree-prod-server 'docker exec $(docker ps -q -f name=chatwoot-rails) ls -lh /app/public/packs/js/sdk.js'
```

---

## ✅ Summary

**Automated (deployment script):**
- ✅ Code sync
- ✅ Docker build
- ✅ Database setup
- ✅ Service startup

**Manual (you need to do):**
- ⚠️ Nginx configuration
- ⚠️ SSL certificate setup
- ⚠️ Update FRONTEND_URL in .env
- ⚠️ Restart services after .env update

**After all steps:** Chatwoot is fully deployed and accessible at `https://chat.apaya.com` 🎉

