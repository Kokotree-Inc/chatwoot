# Deployment Documentation

This folder contains documentation for deploying Chatwoot to production.

## 📖 Main Guide

**[DEPLOYMENT.md](./DEPLOYMENT.md)** - Complete deployment guide covering:
- Quick start
- Deployment scripts (`deploy.sh` and `deploy-server-build.sh`)
- Pre-deployment checklist
- Nginx setup
- SSL certificate setup
- Post-deployment steps
- Troubleshooting
- Common commands

## 🚀 Quick Start

1. Read **[DEPLOYMENT.md](./DEPLOYMENT.md)** for complete guide
2. Choose deployment script:
   - `deploy.sh` - Registry-based (recommended)
   - `deploy-server-build.sh` - Build on server
3. Setup Nginx and SSL (see DEPLOYMENT.md)

## 📁 Related Files

**Deployment Scripts (root directory):**
- `deploy.sh` - Registry-based deployment
- `deploy-server-build.sh` - Build-on-server deployment

**Configuration Files (root directory):**
- `nginx-chatwoot.conf` - Nginx reverse proxy configuration

**Documentation:**
- `docs/DEPLOYMENT.md` - Main deployment guide (this is all you need!)

---

**Domain:** `chat.apaya.com`  
**Deployment Directory:** `/var/www/apaya/chatwoot`
