# Port Change: 3000 → 3080

## Why the Change?

Port 3000 is commonly used by development servers and could conflict with other services. We've changed Chatwoot to use **port 3080** externally to avoid conflicts. Port 3080 is less commonly used and provides better isolation.

## What Changed

### Docker Configuration
- **External Port**: Changed from `3000` to `3080`
- **Internal Port**: Still `3000` (inside container)
- **Binding**: `127.0.0.1:3080:3000` (host:container)

### Updated Files

1. **`docker-compose.production.yaml`**
   ```yaml
   ports:
     - '127.0.0.1:3080:3000'  # Changed from 3000:3000
   ```

2. **`nginx-chatwoot.conf`**
   ```nginx
   upstream chatwoot_backend {
       server 127.0.0.1:3080;  # Changed from 3000
   }
   ```

3. **`deploy-server-build.sh`**
   - Updated health check URLs to use port 3080
   - Updated command examples

4. **Documentation Files**
   - `NGINX_SETUP.md` - Updated all port references
   - `PORT_CHECK.md` - Updated port analysis
   - All troubleshooting commands updated

## Port Mapping

| Service | External Port | Internal Port | Binding |
|---------|---------------|---------------|---------|
| Chatwoot Rails | **3080** | 3000 | 127.0.0.1:3080 |
| PostgreSQL | 5432 | 5432 | 127.0.0.1:5432 |
| Redis | 6379 | 6379 | 127.0.0.1:6379 |
| Nginx HTTP | 80 | - | 0.0.0.0:80 |
| Nginx HTTPS | 443 | - | 0.0.0.0:443 |

## Benefits

✅ **No conflicts** with common development ports  
✅ **Safer** - Less likely to conflict with other services  
✅ **Still localhost-only** - Not exposed publicly  
✅ **Nginx handles public access** - Port 3080 only accessible from localhost

## Verification

After deployment, verify the port:

```bash
# Check if port 3080 is listening
sudo netstat -tlnp | grep :3080

# Test local connection
curl -I http://localhost:3080

# Check Docker port mapping
docker ps | grep chatwoot-rails
```

## Important Notes

- **Nginx** proxies to `127.0.0.1:3080` (not 3000)
- **Public access** is via Nginx on ports 80/443 only
- **Port 3080** is only accessible from localhost (127.0.0.1)
- **No public exposure** - Port 3080 is not exposed to the internet

## Migration from Port 3000

If you have an existing deployment using port 3000:

1. Update `docker-compose.production.yaml` port mapping
2. Update nginx config upstream server
3. Restart containers:
   ```bash
   docker compose -f docker-compose.production.yaml down
   docker compose -f docker-compose.production.yaml up -d
   ```
4. Reload nginx: `sudo systemctl reload nginx`

---

**All configurations updated!** Port 3080 is now used throughout. 🚀

