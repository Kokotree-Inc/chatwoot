# Chatwoot Domain Setup Guide

## 🌐 Public Domain URLs

### Domain Configuration

**Domain:** `chat.apaya.com` ✅

This follows your existing naming pattern:
- `api.kokotree.com` → API service
- `kokotree.com` → Main website  
- `chat.apaya.com` → Chatwoot service (NEW)

### Public URLs

Once configured, Chatwoot will be accessible at:

| Service | URL |
|---------|-----|
| **Dashboard (Admin)** | `https://chat.apaya.com` |
| **Widget SDK** | `https://chat.apaya.com/packs/js/sdk.js` |
| **API** | `https://chat.apaya.com/api` |

## 📋 DNS Configuration

### Step 1: Add DNS A Record

In your DNS provider (e.g., Cloudflare, Route53, etc.):

```
Type: A
Name: chatwoot (or @ if using root domain)
Value: YOUR_SERVER_IP
TTL: 3600 (or Auto)
```

**Example:**
- Domain: `apaya.com`
- Subdomain: `chat`
- Full domain: `chat.apaya.com`
- Points to: `YOUR_SERVER_IP`

### Step 2: Verify DNS Propagation

```bash
# Check DNS resolution
dig chat.apaya.com

# Or using nslookup
nslookup chat.apaya.com

# Expected: Should return your server IP
```

**Wait 5-15 minutes** for DNS to propagate before proceeding.

## 🔧 Configuration Files

### 1. Nginx Config

File: `/etc/nginx/sites-available/chatwoot`

```nginx
server_name chat.apaya.com;
```

### 2. Chatwoot .env File

File: `/var/www/apaya/chatwoot/.env`

```bash
FRONTEND_URL=https://chat.apaya.com
```

### 3. Widget Embed Code

Use this in your website:

```html
<script>
  (function(d,t) {
    var BASE_URL="https://chat.apaya.com";
    var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
    g.src=BASE_URL+"/packs/js/sdk.js";
    g.async = true;
    s.parentNode.insertBefore(g,s);
    g.onload=function(){
      window.chatwootSDK.run({
        websiteToken: 'YOUR_WEBSITE_TOKEN',
        baseUrl: BASE_URL
      })
    }
  })(document,"script");
</script>
```

## ✅ Verification Checklist

- [ ] DNS A record added (`chat.apaya.com` → Server IP)
- [ ] DNS propagated (check with `dig` or `nslookup`)
- [ ] Nginx config updated with domain
- [ ] SSL certificate installed (via certbot)
- [ ] `.env` file updated with `FRONTEND_URL`
- [ ] Chatwoot containers restarted
- [ ] Dashboard accessible at `https://chat.apaya.com`
- [ ] Widget SDK accessible at `https://chat.apaya.com/packs/js/sdk.js`

## 🔍 Testing URLs

After setup, test these URLs:

```bash
# Dashboard (should redirect to login)
curl -I https://chat.apaya.com

# Widget SDK (should return JavaScript)
curl -I https://chat.apaya.com/packs/js/sdk.js

# API health check
curl https://chat.apaya.com/api
```

## 🚨 Common Issues

### DNS Not Resolving

```bash
# Check DNS
dig chat.apaya.com

# If not resolving, wait longer or check DNS provider
```

### SSL Certificate Failed

- Ensure DNS is pointing to server before running certbot
- Check firewall allows ports 80 and 443
- Verify domain spelling matches DNS record

### Widget Not Loading

- Check SDK URL is accessible: `https://chat.apaya.com/packs/js/sdk.js`
- Verify `FRONTEND_URL` in `.env` matches your domain (`https://chat.apaya.com`)
- Check browser console for CORS errors

## 📝 Summary

**Your Chatwoot will be publicly accessible at:**

- **Dashboard**: `https://chat.apaya.com`
- **Widget SDK**: `https://chat.apaya.com/packs/js/sdk.js`

Make sure to:
1. Set DNS A record
2. Update nginx config
3. Install SSL certificate
4. Update `.env` file
5. Restart containers

That's it! 🎉

