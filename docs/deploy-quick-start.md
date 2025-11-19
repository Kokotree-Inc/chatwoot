# Quick Start Deployment Guide

## One-Command Deployment

```bash
./deploy-server-build.sh
```

## Pre-Deployment Checklist

- [ ] SSH access configured (`~/.ssh/config` entry for server)
- [ ] `.env` file exists on server with all required variables
- [ ] Server has Docker and Docker Compose installed
- [ ] At least 10GB free disk space on server
- [ ] Updated `REMOTE_HOST` and `DEPLOY_DIR` in `deploy-server-build.sh`

## What Happens During Deployment

1. ✅ **File Validation** - Checks for required files
2. 📁 **Code Sync** - Syncs code to server (excludes node_modules, .git, etc.)
3. 🛑 **Stop Services** - Gracefully stops existing containers
4. 🔨 **Build Image** - Builds Docker image with:
   - Ruby gems installation
   - Node dependencies (pnpm)
   - SDK build (`pnpm run build:sdk`)
   - Asset precompilation (`rake assets:precompile`)
5. 🗄️ **Start Databases** - Starts PostgreSQL and Redis
6. 🔄 **Run Migrations** - Executes database migrations
7. 🚀 **Start Apps** - Starts Rails and Sidekiq
8. 🔍 **Verify** - Checks service health and SDK file
9. 🧹 **Cleanup** - Removes old Docker images

## Key Differences from Development

- **SDK Build**: Automatically built during Docker image build (via `rake assets:precompile`)
- **Asset Precompilation**: All assets compiled during build
- **Production Mode**: Uses production-optimized settings
- **No Hot Reload**: Static assets served from `/public`

## Troubleshooting

### Build Takes Too Long
- Normal for first build (15-30 minutes)
- Subsequent builds are faster (5-10 minutes)
- Check server resources: `docker stats`

### Services Won't Start
```bash
# Check logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs'

# Check .env file
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && ls -la .env'
```

### SDK File Missing
The SDK is built automatically during Docker build. If missing:
1. Check build logs for errors
2. Verify `rake assets:precompile` completed successfully
3. Rebuild: `./deploy-server-build.sh`

## Common Commands

```bash
# View logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs -f rails'

# Restart services
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml restart'

# Check status
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml ps'

# Rails console
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml exec rails bundle exec rails console'
```

## Next Steps After Deployment

1. **Configure Reverse Proxy** - Set up nginx/Apache with SSL
2. **Set Up Monitoring** - Configure application monitoring
3. **Backup Strategy** - Set up database backups
4. **Performance Tuning** - Optimize based on usage

For detailed information, see [DEPLOYMENT.md](./DEPLOYMENT.md) in this directory

