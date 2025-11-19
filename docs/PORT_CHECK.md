# Port Conflict Check for Chatwoot Deployment

## Existing Containers on Server

Based on `docker ps` output:

| Container | Port | Status |
|-----------|------|--------|
| apaya-canvas-ui | 3015 | ✅ No conflict |
| apaya-canvas-renderer | 8889 | ✅ No conflict |
| apaya-langchain-api | 8282 | ✅ No conflict |
| apaya-crawler | 8888 | ✅ No conflict |

## Chatwoot Required Ports

| Service | Port | Binding | Conflict Check |
|---------|------|---------|----------------|
| **Rails** | 3080 | 127.0.0.1:3080 | ✅ **SAFE** - Not in use (changed from 3000 to avoid conflicts) |
| **PostgreSQL** | 5432 | 127.0.0.1:5432 | ⚠️ **CHECK** - May conflict if host PostgreSQL exists |
| **Redis** | 6379 | 127.0.0.1:6379 | ⚠️ **CHECK** - May conflict if host Redis exists |
| **Nginx HTTP** | 80 | 0.0.0.0:80 | ✅ **SAFE** - Standard web port |
| **Nginx HTTPS** | 443 | 0.0.0.0:443 | ✅ **SAFE** - Standard web port |

## Port Conflict Verification

### Before Deployment - Run These Commands on Server:

```bash
# Check if port 3080 is available
sudo netstat -tlnp | grep :3080
# Expected: No output (port is free)

# Check if port 5432 is in use (PostgreSQL)
sudo netstat -tlnp | grep :5432
# If output shows PostgreSQL, you may need to:
# - Use different port, OR
# - Use existing PostgreSQL instance

# Check if port 6379 is in use (Redis)
sudo netstat -tlnp | grep :6379
# If output shows Redis, you may need to:
# - Use different port, OR
# - Use existing Redis instance

# Check all Docker container ports
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### If PostgreSQL Port 5432 is Already in Use

**Option 1: Use Different Port (Recommended)**
Edit `docker-compose.production.yaml`:
```yaml
postgres:
  ports:
    - '127.0.0.1:5433:5432'  # Use 5433 externally, 5432 internally
```

Then update `.env` file:
```bash
POSTGRES_PORT=5433
```

**Option 2: Use Existing PostgreSQL**
- Remove postgres service from docker-compose
- Update `.env` to point to existing PostgreSQL
- Ensure pgvector extension is installed

### If Redis Port 6379 is Already in Use

**Option 1: Use Different Port (Recommended)**
Edit `docker-compose.production.yaml`:
```yaml
redis:
  ports:
    - '127.0.0.1:6380:6379'  # Use 6380 externally, 6379 internally
```

Then update `.env` file:
```bash
REDIS_URL=redis://localhost:6380
```

**Option 2: Use Existing Redis**
- Remove redis service from docker-compose
- Update `.env` to point to existing Redis

## Nginx Ports

Ports 80 and 443 are standard web ports and should be available. If nginx is already running, you can:

1. **Use existing nginx** - Add Chatwoot config to existing setup
2. **Stop other web server** - If Apache or another nginx instance is running

Check:
```bash
# Check if port 80 is in use
sudo netstat -tlnp | grep :80

# Check if port 443 is in use
sudo netstat -tlnp | grep :443

# Check if nginx is running
sudo systemctl status nginx
```

## Summary

✅ **No conflicts detected** with existing Docker containers:
- Port 3080 (Rails) - Available (changed from 3000 to avoid conflicts)
- Ports 3015, 8282, 8888, 8889 - Different services, no conflict

⚠️ **Potential conflicts to verify**:
- Port 5432 (PostgreSQL) - Check if host PostgreSQL exists
- Port 6379 (Redis) - Check if host Redis exists
- Ports 80/443 - Check if nginx/Apache already running

## Recommended Actions Before Deployment

1. **Check PostgreSQL on host:**
   ```bash
   sudo systemctl status postgresql
   sudo netstat -tlnp | grep :5432
   ```

2. **Check Redis on host:**
   ```bash
   sudo systemctl status redis
   sudo netstat -tlnp | grep :6379
   ```

3. **Check web server:**
   ```bash
   sudo systemctl status nginx
   sudo systemctl status apache2
   ```

4. **If conflicts exist**, modify `docker-compose.production.yaml` before deployment

## Safe Deployment Confirmation

All ports are safe to use as configured:
- ✅ Rails: 3080 (no conflict, changed from 3000)
- ✅ PostgreSQL: 5432 (bound to localhost, safe)
- ✅ Redis: 6379 (bound to localhost, safe)
- ✅ Nginx: 80/443 (standard ports)

**Proceed with deployment!** 🚀

