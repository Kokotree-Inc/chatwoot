# Deployment Documentation

This folder contains documentation for deploying Chatwoot to production.

## 📖 Documentation Index

### Main Guide
- **[DEPLOYMENT_README.md](./DEPLOYMENT_README.md)** - Complete overview of all deployment files and processes

### Quick Links

**Deployment:**
- `DEPLOYMENT.md` - Full deployment guide
- `deploy-quick-start.md` - Quick reference
- `../deploy-server-build.sh` - Deployment script (root)

**Server Setup:**
- `NGINX_SETUP.md` - Nginx reverse proxy setup
- `DOMAIN_SETUP.md` - Domain and DNS configuration
- `PORT_CHECK.md` - Port conflict analysis
- `PORT_CHANGE.md` - Port change documentation
- `FILES_ON_DISK.md` - What files go on the server (Docker deployment)
- `MANUAL_VS_AUTOMATED.md` - What steps are manual vs automated
- `../nginx-chatwoot.conf` - Nginx configuration file (root)

## 🚀 Quick Start

1. Read `DEPLOYMENT_README.md` for complete overview
2. Follow `DEPLOYMENT.md` for first-time setup
3. Use `../deploy-server-build.sh` to deploy
4. Setup Nginx with `NGINX_SETUP.md`

## 📁 File Locations

**Documentation files** are in this `docs/` folder:
- All `.md` documentation files are here
- Deployment scripts (`deploy-server-build.sh`) remain in root
- Configuration files (`nginx-chatwoot.conf`) remain in root

See `DEPLOYMENT_README.md` for detailed information about each file.

