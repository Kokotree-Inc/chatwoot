# Running Chatwoot Locally with Docker

This guide will help you set up and run Chatwoot locally using Docker Compose.

## Prerequisites

- Docker and Docker Compose installed
- `.env` file configured (see below)

## First-Time Setup

### Option 1: Single Command (Recommended)

Simply run:

```bash
make docker_setup
```

This single command will:
1. Build base image (takes 5-10 minutes first time)
2. Build all services
3. Start PostgreSQL and Redis
4. Start Rails service
5. Setup database (creates database, loads schema, runs migrations, and seeds)
6. Build the SDK (required for chat widget to work)
7. Start all remaining services

### Option 2: Manual Steps

If you prefer to run steps manually:

```bash
# 1. Build base image (takes 5-10 minutes first time)
docker compose build base

# 2. Build all services
docker compose build

# 3. Start database and Redis first
docker compose up -d postgres redis

# 4. Wait for PostgreSQL to be ready (about 30-45 seconds)
sleep 45

# 5. Start Rails service
docker compose up -d rails

# 6. Wait a moment for Rails to start
sleep 15

# 7. Setup database (creates database, loads schema, runs migrations, and seeds)
docker compose exec rails bundle exec rails db:chatwoot_prepare

# 8. Build the SDK (required for chat widget to work)
# Note: Build in vite container as it has node_modules installed
docker compose exec vite pnpm run build:sdk

# 9. Start all services
docker compose up
```

After the initial setup, you can simply run `docker compose up` (or `make docker_up`) to start everything.

## Access the Application

Once all services are running:
- **Application**: http://localhost:3100
- **MailHog UI**: http://localhost:8025

### Default Login Credentials

- **Email**: `john@acme.inc`
- **Password**: `Password1!`

These credentials are created automatically during the seed process (see `db/seeds.rb`).

## Environment Variables

Create a `.env` file in the project root with the following variables:

```bash
# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USERNAME=postgres
POSTGRES_DATABASE=chatwoot
POSTGRES_PASSWORD=your_postgres_password_here

# Redis Configuration
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=your_redis_password_here

# Rails Configuration
SECRET_KEY_BASE=generate_with_rails_secret
RAILS_ENV=development
NODE_ENV=development

# Frontend URL (for local development)
FRONTEND_URL=http://localhost:3100

# Optional: Add other environment variables as needed
```

### Generate SECRET_KEY_BASE

You can generate a secret key with:

```bash
docker compose run --rm rails bundle exec rails secret
```

Or if you have Ruby locally:

```bash
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
```

## Docker Compose Services

The `docker-compose.yaml` file defines the following services:

- **rails**: Main Rails application (port 3100)
- **sidekiq**: Background job processor
- **vite**: Frontend asset bundler (port 3036)
- **postgres**: PostgreSQL database with pgvector (port 5432)
- **redis**: Redis cache/session store (port 6379)
- **mailhog**: Email testing tool (ports 1025, 8025)

## Common Commands

### Start Services

```bash
docker compose up -d
```

### Stop Services

```bash
docker compose down
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f rails
docker compose logs -f sidekiq
docker compose logs -f vite
```

### Rebuild Images

```bash
docker compose build
# or rebuild a specific service
docker compose build rails
```

### Run Database Migrations Manually

```bash
docker compose exec rails bundle exec rails db:migrate
```

### Setup Database (Recommended)

The `db:chatwoot_prepare` task handles everything: creates database if needed, loads schema, runs migrations, and seeds:

```bash
docker compose exec rails bundle exec rails db:chatwoot_prepare
```

### Build SDK (Required for Chat Widget)

The SDK must be built for the chat widget to work. Use the vite container as it has node_modules installed:

```bash
docker compose exec vite pnpm run build:sdk
```

### Manual Database Setup (Alternative)

If you need to run steps individually:

```bash
docker compose exec rails bundle exec rails db:create
docker compose exec rails bundle exec rails db:migrate
docker compose exec rails bundle exec rails db:seed
```

### Access Rails Console

```bash
docker compose exec rails bundle exec rails console
```

### Access PostgreSQL Database

```bash
docker compose exec postgres psql -U postgres -d chatwoot
```

### Restart a Specific Service

```bash
docker compose restart rails
docker compose restart sidekiq
```

## Troubleshooting

### Port Already in Use

If you get port conflicts, check what's using the ports:

```bash
# Check port 3100 (Rails)
lsof -i :3100

# Check port 5432 (PostgreSQL)
lsof -i :5432

# Check port 6379 (Redis)
lsof -i :6379
```

### Database Connection Issues

1. Ensure PostgreSQL container is running:
   ```bash
   docker compose ps postgres
   ```

2. Check PostgreSQL logs:
   ```bash
   docker compose logs postgres
   ```

3. Verify environment variables in `.env` file

### Application Won't Start

1. Check Rails logs:
   ```bash
   docker compose logs rails
   ```

2. Ensure all dependencies are built:
   ```bash
   docker compose build
   ```

3. Try rebuilding from scratch:
   ```bash
   docker compose down -v  # Removes volumes
   docker compose build
   docker compose up -d
   ```

### Clear Everything and Start Fresh

```bash
# Stop and remove containers, networks, and volumes
docker compose down -v

# Rebuild and start
docker compose build
docker compose up -d
```

## Development Workflow

### First Time Setup

1. Build base and all services: `docker compose build base && docker compose build`
2. Start database services: `docker compose up -d postgres redis`
3. Setup database: `docker compose exec rails bundle exec rails db:chatwoot_prepare`
4. Build SDK: `docker compose exec vite pnpm run build:sdk`
5. Start all services: `docker compose up`

### Daily Development

1. **Start Services**: `docker compose up` (or `docker compose up -d` for background)
2. **Make Code Changes**: Edit files locally (mounted as volumes)
3. **Rebuild SDK** (if you changed SDK code): `docker compose exec vite pnpm run build:sdk`
4. **Restart Services**: Use `docker compose restart rails` if needed
5. **View Logs**: Monitor with `docker compose logs -f rails`
6. **Access App**: Open http://localhost:3100

**Note**: The SDK (`pnpm run build:sdk`) must be rebuilt if you make changes to the chat widget SDK code. In production builds, this happens automatically, but in development you need to run it manually.

## Email Testing

MailHog is included for email testing:
- SMTP server: `localhost:1025`
- Web UI: http://localhost:8025

All emails sent by the application will be captured by MailHog.

## Troubleshooting Database/Users

If you need to check users or database state:

```bash
# Access Rails console
docker compose exec rails bundle exec rails console
```

In the console:

```ruby
# Check if any users exist
User.count

# See all users
User.all

# Check for admin user specifically
admin = User.first
puts "Email: #{admin.email}" if admin
puts "Name: #{admin.name}" if admin

# Exit console
exit
```

## Notes

- **Database Setup**: Use `db:chatwoot_prepare` instead of individual db tasks - it handles schema loading, migrations, and seeding automatically
- **SDK Build**: The SDK (`pnpm run build:sdk`) is NOT built automatically in development mode - you must run it manually after setup and when SDK code changes. Use the vite container: `docker compose exec vite pnpm run build:sdk`
- **Code Changes**: Code changes are reflected immediately due to volume mounts (except SDK requires rebuild)
- **Vite Dev Server**: Runs separately on port 3036 for hot module replacement
- **Database Persistence**: Database data persists in Docker volumes even after containers are stopped
- **Port**: The Rails app runs on port **3100** (not 3000) to avoid conflicts

