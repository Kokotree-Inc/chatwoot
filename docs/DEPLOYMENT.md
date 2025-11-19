# Chatwoot Production Deployment Guide

This guide explains how to deploy Chatwoot to an Ubuntu production server using the `deploy-server-build.sh` script.

## Prerequisites

1. **Server Setup:**
   - Ubuntu server with Docker and Docker Compose installed
   - SSH access configured (add server to `~/.ssh/config`)
   - Sufficient disk space (at least 10GB free)
   - At least 4GB RAM recommended

2. **Local Machine:**
   - SSH access to production server
   - `rsync` installed
   - Git repository cloned locally

3. **Server Requirements:**
   - Docker 20.10+
   - Docker Compose 2.0+
   - PostgreSQL 16+ with pgvector extension (handled by Docker)
   - Redis (handled by Docker)

## Configuration

Before running the deployment script, configure the following variables in `deploy-server-build.sh`:

```bash
REMOTE_HOST="kokotree-prod-server"  # Your SSH hostname from ~/.ssh/config
DEPLOY_DIR="/var/www/apaya/chatwoot"       # Deployment directory on server
```

## Environment Variables

Ensure your `.env` file is properly configured on the server with:

- `POSTGRES_PASSWORD` - PostgreSQL password
- `REDIS_PASSWORD` - Redis password
- `SECRET_KEY_BASE` - Rails secret key base
- `FRONTEND_URL` - Your frontend URL (e.g., `https://chatwoot.example.com`)
- `RAILS_ENV=production`
- `NODE_ENV=production`
- Other Chatwoot-specific environment variables

**Important:** The `.env` file should already exist on the server. The deployment script excludes `.env` files from syncing for security.

## Deployment Process

The deployment script performs the following steps:

1. **File Checks** - Verifies required files exist
2. **Code Sync** - Syncs code to server (excludes node_modules, .git, etc.)
3. **Stop Services** - Stops existing Docker containers
4. **Build Image** - Builds Docker image on server (includes asset precompilation and SDK build)
5. **Run Migrations** - Runs database migrations
6. **Start Services** - Starts all Docker services
7. **Verify Deployment** - Checks service health and SDK file
8. **Cleanup** - Removes old Docker images

## Running the Deployment

```bash
./deploy-server-build.sh
```

The script will:
- Create a log file in `./deploy/deploy_server_build_TIMESTAMP.log`
- Show colored output with progress indicators
- Handle errors gracefully and provide helpful error messages

## What Gets Built

During the Docker build process:

1. **Ruby Gems** - Installed via `bundle install`
2. **Node Dependencies** - Installed via `pnpm install`
3. **SDK Build** - Automatically built via `pnpm run build:sdk` (triggered by `rake assets:precompile`)
4. **Asset Precompilation** - Rails assets compiled via `rake assets:precompile`
5. **Production Optimization** - Removes development/test dependencies

## Services Deployed

The deployment includes:

- **Rails** - Main web application (port 3080 externally, 3000 internally)
- **Sidekiq** - Background job processor
- **PostgreSQL** - Database with pgvector extension
- **Redis** - Cache and job queue

## Post-Deployment Verification

After deployment, verify:

1. **Services are running:**
   ```bash
   ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml ps'
   ```

2. **Application is accessible:**
   ```bash
   ssh kokotree-prod-server 'curl -I http://localhost:3080'
   ```

3. **SDK file exists:**
   ```bash
   ssh kokotree-prod-server 'docker exec $(docker ps -q -f name=chatwoot-rails) ls -lh /app/public/packs/js/sdk.js'
   ```

4. **Check logs for errors:**
   ```bash
   ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs --tail=50 rails'
   ```

## Common Operations

### View Logs
```bash
# Rails logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs -f rails'

# Sidekiq logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs -f sidekiq'

# All logs
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml logs -f'
```

### Restart Services
```bash
# Restart all
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml restart'

# Restart specific service
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml restart rails'
```

### Run Database Migrations
```bash
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker run --rm --env-file .env --network chatwoot_default -e RAILS_ENV=production chatwoot/chatwoot:latest bundle exec rails db:chatwoot_prepare'
```

### Access Rails Console
```bash
ssh kokotree-prod-server 'cd /var/www/apaya/chatwoot && docker compose -f docker-compose.production.yaml exec rails bundle exec rails console'
```

## Troubleshooting

### Build Fails
- Check server has enough disk space: `df -h`
- Check Docker has enough space: `docker system df`
- Review build logs in the log file

### Services Won't Start
- Check `.env` file exists and is properly configured
- Verify database connection settings
- Check Docker logs: `docker compose logs`

### SDK File Missing
- The SDK is built during Docker image build via `rake assets:precompile`
- Verify build completed successfully
- Check `/app/public/packs/js/sdk.js` exists in container

### Database Connection Issues
- Verify PostgreSQL container is running
- Check `POSTGRES_PASSWORD` in `.env` matches
- Verify network connectivity between containers

## Rollback

To rollback to a previous version:

1. Tag the previous working image before deploying
2. Stop current services
3. Update `docker-compose.production.yaml` to use previous tag
4. Start services

## Security Notes

1. **Never commit `.env` files** - They contain sensitive credentials
2. **Use strong passwords** - Especially for PostgreSQL and Redis
3. **Configure firewall** - Only expose necessary ports
4. **Use HTTPS** - Set up reverse proxy (nginx/Apache) with SSL
5. **Regular updates** - Keep Docker and system packages updated

## Performance Optimization

1. **Resource Limits** - Set appropriate CPU/memory limits in docker-compose
2. **Database Optimization** - Tune PostgreSQL settings for your workload
3. **Redis Configuration** - Configure Redis persistence if needed
4. **Asset CDN** - Use `ASSET_CDN_HOST` for static assets

## Monitoring

Consider setting up:
- Application monitoring (e.g., Sentry)
- Server monitoring (e.g., Prometheus, Grafana)
- Log aggregation (e.g., ELK stack)
- Uptime monitoring

## Support

For issues specific to Chatwoot, refer to:
- [Chatwoot Documentation](https://www.chatwoot.com/docs)
- [Chatwoot GitHub Issues](https://github.com/chatwoot/chatwoot/issues)

