# Certbot SSL Certificate Troubleshooting

## Error: "No such authorization"

This error means Let's Encrypt cannot verify your domain. Common causes:

1. **DNS not configured** - Domain doesn't point to your server
2. **Port 80 blocked** - Firewall blocking HTTP traffic
3. **Nginx not running** - Web server not accessible
4. **Domain not reachable** - Server can't be accessed from internet

---

## 🔍 Step-by-Step Troubleshooting

### Step 1: Verify DNS Configuration

**From your local machine:**
```bash
# Check if DNS resolves to your server IP
nslookup chat.apaya.com

# Or use dig
dig chat.apaya.com

# Or use host
host chat.apaya.com
```

**Expected:** Should return your server's IP address

**If DNS is wrong:**
- Go to your DNS provider (Cloudflare, GoDaddy, etc.)
- Add/Update A record: `chat.apaya.com` → `YOUR_SERVER_IP`
- Wait 5-15 minutes for DNS propagation
- Verify again with `nslookup`

---

### Step 2: Verify Port 80 is Open

**On your server:**
```bash
# Check if port 80 is listening
sudo netstat -tlnp | grep :80

# Or use ss
sudo ss -tlnp | grep :80

# Check firewall status
sudo ufw status

# If firewall is active, allow port 80
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

**Expected:** Should show nginx listening on port 80

---

### Step 3: Verify Nginx is Running

**On your server:**
```bash
# Check nginx status
sudo systemctl status nginx

# Check if nginx is listening
sudo netstat -tlnp | grep nginx

# Test nginx config
sudo nginx -t

# If nginx is not running, start it
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

### Step 4: Test HTTP Access

**From your local machine (or external server):**
```bash
# Test HTTP connection
curl -I http://chat.apaya.com

# Should return HTTP 200 or 301/302
# If you get "Connection refused" or timeout, DNS/firewall issue
```

**From your server:**
```bash
# Test locally
curl -I http://localhost

# Test via domain
curl -I http://chat.apaya.com
```

**Expected:** Should return HTTP response (not connection refused)

---

### Step 5: Check Nginx Configuration

**On your server:**
```bash
# Verify nginx config is enabled
ls -la /etc/nginx/sites-enabled/ | grep chatwoot

# Check if config exists
ls -la /etc/nginx/sites-available/chatwoot

# View nginx error logs
sudo tail -f /var/log/nginx/error.log

# Test config syntax
sudo nginx -t
```

---

### Step 6: Verify Domain is Accessible from Internet

**From external tool (or different network):**
```bash
# Use online tool or from different network
curl -I http://chat.apaya.com

# Or test from your phone's browser (not on same network)
# Visit: http://chat.apaya.com
```

**If it works locally but not externally:**
- Firewall blocking port 80
- Cloud provider security group blocking port 80
- Router/NAT not forwarding port 80

---

## 🔧 Common Fixes

### Fix 1: DNS Not Configured

```bash
# Check DNS
nslookup chat.apaya.com

# If wrong IP or not resolving:
# 1. Go to DNS provider
# 2. Add A record: chat.apaya.com → YOUR_SERVER_IP
# 3. Wait 5-15 minutes
# 4. Try again
```

### Fix 2: Firewall Blocking Port 80

```bash
# Check firewall
sudo ufw status

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Check cloud provider firewall (AWS, DigitalOcean, etc.)
# Make sure security group allows inbound port 80
```

### Fix 3: Nginx Not Running

```bash
# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

### Fix 4: Nginx Config Not Enabled

```bash
# Enable config
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### Fix 5: Cloud Provider Security Group

**If using AWS, DigitalOcean, Google Cloud, etc.:**
- Check security group/firewall rules
- Ensure inbound port 80 (HTTP) is allowed from `0.0.0.0/0`
- Ensure inbound port 443 (HTTPS) is allowed from `0.0.0.0/0`

---

## ✅ Pre-Flight Checklist Before Certbot

Run these commands to verify everything is ready:

```bash
# 1. DNS resolves correctly
nslookup chat.apaya.com
# ✅ Should show your server IP

# 2. Port 80 is open
sudo netstat -tlnp | grep :80
# ✅ Should show nginx listening

# 3. Nginx is running
sudo systemctl status nginx
# ✅ Should show "active (running)"

# 4. HTTP works
curl -I http://chat.apaya.com
# ✅ Should return HTTP 200/301/302

# 5. Firewall allows port 80
sudo ufw status | grep 80
# ✅ Should show "80/tcp ALLOW"

# 6. Nginx config is enabled
ls -la /etc/nginx/sites-enabled/ | grep chatwoot
# ✅ Should show symlink exists
```

**If all checks pass, then run certbot:**
```bash
sudo certbot --nginx -d chat.apaya.com
```

---

## 🔄 Alternative: Standalone Mode (If Nginx Issues)

If nginx is causing issues, use standalone mode:

```bash
# Stop nginx temporarily
sudo systemctl stop nginx

# Run certbot in standalone mode
sudo certbot certonly --standalone -d chat.apaya.com

# Start nginx again
sudo systemctl start nginx

# Then manually configure SSL in nginx config
# (Certbot will tell you where certificates are saved)
```

---

## 📋 Debug Commands

```bash
# View certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Run certbot with verbose output
sudo certbot --nginx -d chat.apaya.com -v

# Test certbot dry-run (doesn't actually get certificate)
sudo certbot --nginx -d chat.apaya.com --dry-run

# Check what certbot can see
sudo certbot certificates
```

---

## 🆘 Still Not Working?

1. **Check certbot logs:**
   ```bash
   sudo cat /var/log/letsencrypt/letsencrypt.log
   ```

2. **Verify from external network:**
   - Visit `http://chat.apaya.com` from your phone (not on WiFi)
   - Should see Chatwoot or nginx page

3. **Check cloud provider:**
   - AWS: Security Groups
   - DigitalOcean: Firewall
   - Google Cloud: Firewall Rules
   - Azure: Network Security Groups

4. **Try certbot dry-run:**
   ```bash
   sudo certbot --nginx -d chat.apaya.com --dry-run
   ```

5. **Check DNS propagation:**
   - Use https://dnschecker.org
   - Search for `chat.apaya.com`
   - Should show your server IP globally

---

## ✅ Success Indicators

When certbot works, you'll see:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/chat.apaya.com/fullchain.pem
Key is saved at: /etc/letsencrypt/live/chat.apaya.com/privkey.pem
```

Then test:
```bash
curl -I https://chat.apaya.com
# Should return HTTP 200 with SSL certificate
```

