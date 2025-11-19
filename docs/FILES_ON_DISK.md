# What Physical Files Go on the Server?

Since Chatwoot runs entirely in Docker containers, you might wonder: **What files actually need to be on the server's disk?**

## 📁 Deployment Directory Structure

Chatwoot is deployed to: `/var/www/apaya/chatwoot/`

This matches your existing Apaya project structure:
```
/var/www/apaya/
├── apaya-canvas-renderer/
├── apaya-crawler/
├── apaya-langchain/
├── api/
├── app/
├── chatwoot/          ← Chatwoot goes here
├── client/
├── server/
└── site/
```

## 📦 Physical Files on Disk

### Required Files (Synced by Deployment Script)

The deployment script (`deploy-server-build.sh`) syncs the **entire source code** to the server because:

1. **Docker Image is Built on Server** - The Docker image is built directly on the server, so it needs:
   - All source code (Ruby, JavaScript, Vue files)
   - `Dockerfile` (in `docker/Dockerfile`)
   - `docker-compose.production.yaml`
   - Configuration files
   - Build scripts and dependencies

2. **What Gets Synced:**
   ```
   /var/www/apaya/chatwoot/
   ├── app/                    # Rails application code
   ├── config/                 # Rails configuration
   ├── docker/                 # Dockerfiles and entrypoints
   ├── docker-compose.production.yaml
   ├── lib/                    # Ruby libraries
   ├── public/                 # Public assets (but assets are built in container)
   ├── Gemfile                 # Ruby dependencies
   ├── package.json            # Node dependencies
   └── ... (all other source files)
   ```

3. **What Gets Excluded** (not synced):
   - `node_modules/` - Installed during Docker build
   - `.git/` - Version control (not needed on server)
   - `tmp/` - Temporary files
   - `log/` - Log files (generated at runtime)
   - `storage/` - File storage (handled by Docker volume)
   - `public/packs/` - Built assets (generated during Docker build)
   - `.env*` - Environment files (manually created on server)
   - `spec/` - Test files (not needed in production)
   - `deploy/` - Deployment logs (local only)

### Files NOT on Disk (Managed by Docker)

These are stored in **Docker volumes**, not in `/var/www/apaya/chatwoot/`:

1. **Database Data** (`postgres_data` volume)
   - Location: Docker's volume directory (usually `/var/lib/docker/volumes/`)
   - Contains: PostgreSQL database files
   - Managed by: Docker Compose

2. **Redis Data** (`redis_data` volume)
   - Location: Docker's volume directory
   - Contains: Redis cache and session data
   - Managed by: Docker Compose

3. **Application Storage** (`storage_data` volume)
   - Location: Docker's volume directory
   - Contains: Uploaded files, attachments, avatars
   - Managed by: Docker Compose

4. **Precompiled Assets** (inside Docker container)
   - Location: `/app/public/packs/` inside the container
   - Contains: Built JavaScript, CSS, SDK files
   - Built during: Docker image build process
   - Served by: Nginx proxies requests to container (not from disk)

### Environment File (Manual Setup)

**`.env` file** - Must be created manually on the server:
- Location: `/var/www/apaya/chatwoot/.env`
- **NOT synced** by deployment script (for security)
- Contains: Database passwords, API keys, secrets

## 🔍 How to Check What's Actually on Disk

```bash
# SSH into server
ssh kokotree-prod-server

# View directory structure
ls -la /var/www/apaya/chatwoot/

# Check disk usage
du -sh /var/www/apaya/chatwoot/

# View Docker volumes (data NOT on disk)
docker volume ls | grep chatwoot

# Check volume sizes
docker system df -v
```

## 💡 Why Source Code on Disk?

Even though everything runs in Docker, we need source code on disk because:

1. **Docker Build Process** - The Docker image is built on the server using the source code
2. **Asset Compilation** - Assets (SDK, JavaScript, CSS) are compiled during Docker build
3. **Configuration** - Docker Compose needs `docker-compose.production.yaml` file
4. **Migrations** - Database migrations run from the codebase
5. **Debugging** - Having source code helps with troubleshooting

## 🎯 Summary

| Item | Location | Managed By |
|------|----------|------------|
| **Source Code** | `/var/www/apaya/chatwoot/` | Deployment script (rsync) |
| **Environment Config** | `/var/www/apaya/chatwoot/.env` | Manual (you create it) |
| **Database Data** | Docker volume | Docker Compose |
| **Redis Data** | Docker volume | Docker Compose |
| **File Storage** | Docker volume | Docker Compose |
| **Built Assets** | Inside container | Docker (built during image build) |

## 📝 Key Takeaway

**The source code is on disk** (for building Docker images), but **all runtime data** (database, files, cache) is stored in Docker volumes, not in the deployment directory.

This is why you see the full codebase in `/var/www/apaya/chatwoot/` - it's needed to build the Docker image, but the actual running application and its data live inside Docker containers and volumes.

