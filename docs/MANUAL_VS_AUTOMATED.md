# Manual vs Automated Steps

This document clarifies what steps need to be done **manually** (one-time setup) vs what is **automated** by the deployment script.

## ✅ Fully Automated by `deploy-server-build.sh`

The deployment script handles ALL of these automatically:

1. ✅ **Sync code to server** - `rsync` all files
2. ✅ **Build Docker image** - `docker build` (includes SDK build automatically)
3. ✅ **Stop existing services** - `docker compose down`
4. ✅ **Start databases** - `docker compose up -d postgres redis`
5. ✅ **Run migrations** - `docker compose run --rm rails bundle exec rails db:chatwoot_prepare`
6. ✅ **Start services** - `docker compose up -d rails sidekiq`
7. ✅ **SDK Build** - Automatically built during Docker image build via `rake assets:precompile`

### How SDK Build Works

The SDK (`pnpm run build:sdk`) is **automatically** built during Docker image build:

1. Dockerfile runs: `rake assets:precompile` (line 85)
2. `lib/tasks/build.rake` hooks into `assets:precompile`:
   ```ruby
   task before_assets_precompile: :environment do
     system('pnpm install')
     system('pnpm run build:sdk')  # ← SDK built here automatically
   end
   Rake::Task['assets:precompile'].enhance %w[before_assets_precompile]
   ```
3. SDK file created: `/app/public/packs/js/sdk.js` inside container

**You do NOT need to manually run `pnpm run build:sdk`** - it's automatic! ✅

## 🔧 Manual Steps (One-Time Setup)

These steps only need to be done **once** before first deployment:

### 1. Create `.env` File on Server

**Location:** `/var/www/apaya/chatwoot/.env`

**Required variables:**
```bash
# Database
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=chatwoot
POSTGRES_USER=postgres

# Redis
REDIS_PASSWORD=your_redis_password

# Rails
SECRET_KEY_BASE=your_secret_key_base
RAILS_ENV=production
NODE_ENV=production

# Chatwoot
FRONTEND_URL=https://chat.apaya.com
INSTALLATION_NAME=Kokotree Chat

# Other Chatwoot variables as needed
```

**How to create:**
```bash
# SSH into server
ssh kokotree-prod-server

# Create directory
mkdir -p /var/www/apaya/chatwoot

# Create .env file
nano /var/www/apaya/chatwoot/.env

# Paste your environment variables and save
```

### 2. Update `docker-compose.production.yaml` Password

**File:** `docker-compose.production.yaml` (on server after first sync)

**Update line 48:**
```yaml
POSTGRES_PASSWORD=your_secure_password  # Must match .env file
```

**Note:** This is synced by deployment script, but you need to update it once with your password.

### 3. SSH Configuration

**File:** `~/.ssh/config` (on your local machine)

```ssh-config
Host kokotree-prod-server
    HostName YOUR_SERVER_IP
    User YOUR_USERNAME
    IdentityFile ~/.ssh/your_key
```

### 4. Server Prerequisites

**One-time setup on server:**
```bash
# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in for this to take effect

# Verify installation
docker --version
docker compose --version
```

## 📋 Comparison: Chatwoot Guide vs Your Script

### Chatwoot Development Guide Steps:
```bash
# Development (manual steps)
docker compose build base          # ← Not needed (single Dockerfile)
docker compose build               # ← Your script uses: docker build
docker compose up -d postgres redis # ← ✅ Automated
docker compose exec rails bundle exec rails db:chatwoot_prepare # ← ✅ Automated
docker compose up                  # ← ✅ Automated
pnpm run build:sdk                 # ← ✅ Automated (via rake assets:precompile)
```

### Your Deployment Script:
```bash
# Production (automated)
./deploy-server-build.sh
# Does everything above automatically ✅
```

## 🎯 Key Differences

| Step | Chatwoot Guide | Your Script | Status |
|------|----------------|-------------|--------|
| Build base image | `docker compose build base` | Not needed (single Dockerfile) | ✅ N/A |
| Build image | `docker compose build` | `docker build -t chatwoot/chatwoot:latest` | ✅ Automated |
| Start databases | Manual | `docker compose up -d postgres redis` | ✅ Automated |
| Run migrations | Manual | `docker compose run --rm rails db:chatwoot_prepare` | ✅ Automated |
| Start services | Manual | `docker compose up -d rails sidekiq` | ✅ Automated |
| Build SDK | Manual `pnpm run build:sdk` | Automatic (via `rake assets:precompile`) | ✅ Automated |

## ✅ Summary

### What You Need to Do Manually (One-Time):
1. ✅ Create `.env` file on server
2. ✅ Update `POSTGRES_PASSWORD` in `docker-compose.production.yaml` (first time)
3. ✅ Configure SSH access
4. ✅ Install Docker on server (if not already installed)

### What the Script Does Automatically:
1. ✅ Syncs code
2. ✅ Builds Docker image (including SDK)
3. ✅ Starts databases
4. ✅ Runs migrations
5. ✅ Starts services
6. ✅ Verifies deployment

**After initial setup, you only need to run:**
```bash
./deploy-server-build.sh
```

That's it! Everything else is automated. 🚀

