# Nginx Setup Guide for Chatwoot - Step by Step

Complete guide to set up Nginx reverse proxy for Chatwoot on Ubuntu server.

## 📋 Prerequisites

- Ubuntu server with sudo access
- Nginx installed: `sudo apt update && sudo apt install nginx -y`
- Domain name pointing to your server IP
- Chatwoot deployed in Docker (port 3080)

## 🔍 Step 1: Check Existing Setup

**Check existing nginx configurations:**
```bash
# List existing nginx sites
ls -la /etc/nginx/sites-available/
ls -la /etc/nginx/sites-enabled/

# See what domains are already configured
sudo grep -r "server_name" /etc/nginx/sites-available/

# Check if ports 80/443 are in use
sudo netstat -tlnp | grep -E ':80|:443'
```

**Your existing directories:**
```
/var/www/
├── apaya/
├── api.kokotree.com/
├── certificates/
├── html/
└── kokotree.com/
```

Chatwoot will use: `/var/www/apaya/chatwoot/` ✅

## 🌐 Step 2: Choose Your Domain

**Public Domain URL Options:**

**Domain:** `chat.apaya.com` ✅

**Public URLs:**
- Dashboard: `https://chat.apaya.com`
- Widget SDK: `https://chat.apaya.com/packs/js/sdk.js`

**Important:** 
- Make sure DNS A record points to your server IP before proceeding!
- DNS record: `chat.apaya.com` → `YOUR_SERVER_IP`

## 📝 Step 3: Copy and Edit Nginx Config

```bash
# Copy the config file
sudo cp nginx-chatwoot.conf /etc/nginx/sites-available/chatwoot

# Edit the file
sudo nano /etc/nginx/sites-available/chatwoot
```

**Domain is already configured:** `chat.apaya.com`

The nginx config file already has the domain set. If you need to change it, look for:
- `server_name chat.apaya.com;` (in HTTP server block)
- `server_name chat.apaya.com;` (in HTTPS server block)

## ✅ Step 4: Enable the Site

```bash
# Create symlink to enable the site
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t
```

**Expected output:**
```
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

If you see errors, check the config file for typos.

## 🚀 Step 5: Start Nginx (HTTP First)

```bash
# Reload nginx to apply changes
sudo systemctl reload nginx

# Check nginx status
sudo systemctl status nginx
```

**Verify Chatwoot is accessible:**
```bash
# Test HTTP connection (before SSL)
curl -I http://chat.apaya.com
```

You should see HTTP 200 or 302 response.

## 🔒 Step 6: Install SSL Certificate

```bash
# Install certbot if not already installed
sudo apt install certbot python3-certbot-nginx -y

# Obtain SSL certificate (replace with your domain)
sudo certbot --nginx -d chat.apaya.com

# Follow the prompts:
# - Enter your email address
# - Agree to terms of service
# - Choose: Redirect HTTP to HTTPS? (Yes - recommended)
```

**Certbot will automatically:**
- ✅ Obtain SSL certificates
- ✅ Update nginx configuration
- ✅ Set up auto-renewal

## 🔧 Step 7: Verify SSL Setup

After certbot completes, verify:

```bash
# Test HTTPS connection
curl -I https://chat.apaya.com

# Check certificate
sudo certbot certificates

# Test auto-renewal
sudo certbot renew --dry-run
```

## 📊 Step 8: Verify Everything Works

```bash
# Check nginx is running
sudo systemctl status nginx

# Check Chatwoot container is running
sudo docker ps | grep chatwoot

# Check port 3080 is accessible
sudo netstat -tlnp | grep :3080

# View nginx logs
sudo tail -f /var/log/nginx/chatwoot_access_443.log
```

## 🎯 Port Information

| Service | Port | Status |
|---------|------|--------|
| **Chatwoot Rails** | 3080 | ✅ Bound to localhost (changed from 3000 to avoid conflicts) |
| **PostgreSQL** | 5432 | ✅ Internal only |
| **Redis** | 6379 | ✅ Internal only |
| **Nginx HTTP** | 80 | ✅ Public |
| **Nginx HTTPS** | 443 | ✅ Public |

**No conflicts** with your existing containers (3015, 8282, 8888, 8889) ✅

## 🔍 Troubleshooting

### 502 Bad Gateway

```bash
# Check Chatwoot container
sudo docker ps | grep chatwoot

# Check Chatwoot logs
sudo docker logs chatwoot-rails

# Verify port 3080
sudo netstat -tlnp | grep :3080
```

### SSL Certificate Issues

```bash
# Check DNS is pointing to server
dig chat.apaya.com

# Check firewall allows ports 80/443
sudo ufw status

# View certbot certificates
sudo certbot certificates
```

### Nginx Configuration Errors

```bash
# Test configuration
sudo nginx -t

# View error logs
sudo tail -f /var/log/nginx/chatwoot_error_443.log

# View access logs
sudo tail -f /var/log/nginx/chatwoot_access_443.log
```

### Port Already in Use

```bash
# Check what's using port 80/443
sudo lsof -i :80
sudo lsof -i :443

# Usually it's nginx itself - just reload
sudo systemctl reload nginx
```

## 🔐 Firewall Configuration

If using UFW firewall:

```bash
# Allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'

# Or individually:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check firewall status
sudo ufw status
```

## 📁 Important File Locations

- **Nginx config**: `/etc/nginx/sites-available/chatwoot`
- **Enabled config**: `/etc/nginx/sites-enabled/chatwoot`
- **Access logs**: `/var/log/nginx/chatwoot_access_443.log`
- **Error logs**: `/var/log/nginx/chatwoot_error_443.log`
   - **SSL certificates**: `/etc/letsencrypt/live/chat.apaya.com/`
- **Chatwoot directory**: `/var/www/apaya/chatwoot/`

## 🔄 Maintenance Commands

```bash
# Reload nginx after config changes
sudo nginx -t && sudo systemctl reload nginx

# Renew SSL certificate manually
sudo certbot renew

# View certificate expiry
sudo certbot certificates

# Update nginx
sudo apt update && sudo apt upgrade nginx
```

## ✅ Final Checklist

- [ ] Domain DNS points to server IP
- [ ] Nginx config copied and domain updated
- [ ] Site enabled and tested (`sudo nginx -t`)
- [ ] Nginx reloaded successfully
- [ ] HTTP access working (before SSL)
- [ ] SSL certificate installed with certbot
- [ ] HTTPS access working
- [ ] Chatwoot container running on port 3080
- [ ] No port conflicts

## 🎉 Next Steps

After nginx is configured:

1. **Update Chatwoot `.env` file:**
   ```bash
   # Edit the .env file
   nano /var/www/apaya/chatwoot/.env
   
   # Set FRONTEND_URL to your public domain
   FRONTEND_URL=https://chat.apaya.com
   ```

2. **Restart Chatwoot containers:**
   ```bash
   cd /var/www/apaya/chatwoot
   sudo docker compose -f docker-compose.production.yaml restart
   ```

3. **Access Chatwoot Dashboard:**
   - URL: `https://chat.apaya.com`
   - Login with your admin credentials

4. **Widget SDK URL (for embedding):**
   - SDK: `https://chat.apaya.com/packs/js/sdk.js`
   - Use this URL in your website's widget code

5. **Test the widget** on your website

6. **Monitor logs** for any issues

## 📞 Quick Reference

```bash
# Check nginx status
sudo systemctl status nginx

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# View logs
sudo tail -f /var/log/nginx/chatwoot_error_443.log

# Check Chatwoot
sudo docker ps | grep chatwoot
sudo docker logs chatwoot-rails
```

---

**That's it!** Your Chatwoot instance should now be accessible via HTTPS. 🚀

