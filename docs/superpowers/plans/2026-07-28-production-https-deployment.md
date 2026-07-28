# Production HTTPS Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve the existing Home CRM API at `https://api.homecrm.store/api` with the issued certificate while preserving HTTP access.

**Architecture:** Terminate TLS in the existing `nginx:1.27-alpine` container. Keep production-only Nginx configuration and certificate material under `/etc/homecrm`, mount them read-only, and recreate only the Nginx service after preflight validation.

**Tech Stack:** Docker Compose, Nginx 1.27 Alpine, OpenSSL, DigiCert DV TLS certificate

## Global Constraints

- Keep `homecrm-api-1` running throughout the deployment.
- Do not store the certificate or private key in Git.
- Keep HTTP port 80 enabled without adding a redirect.
- Enable only TLS 1.2 and TLS 1.3.
- Set `/etc/homecrm/ssl` to mode `700` and the private key to mode `600`.
- Back up the active Compose and Nginx configuration before activation.

---

### Task 1: Establish the failing HTTPS baseline

**Files:**
- Read: `/etc/homecrm/docker-compose.prod.yml`
- Read: `/www/home_crm/server/docker/nginx/default.conf`

**Interfaces:**
- Consumes: current DNS record `api.homecrm.store -> 120.26.176.85`
- Produces: evidence that HTTPS is not yet listening

- [ ] **Step 1: Verify the public HTTPS endpoint fails before deployment**

```bash
curl --fail --show-error --max-time 10 https://api.homecrm.store/api
```

Expected: FAIL because port 443 is not listening.

- [ ] **Step 2: Verify the API and HTTP container are currently healthy**

```bash
ssh homecrm 'docker ps --filter name=homecrm-api-1 --filter name=homecrm-nginx-1; curl --fail --show-error --max-time 5 http://127.0.0.1/api'
```

Expected: both containers are running and the local HTTP request returns the API health JSON.

### Task 2: Stage and validate production TLS configuration

**Files:**
- Read: `/Users/dev/Downloads/26313920_api.homecrm.store_nginx.zip`
- Create: `/etc/homecrm/ssl/api.homecrm.store.pem`
- Create: `/etc/homecrm/ssl/api.homecrm.store.key`
- Create: `/etc/homecrm/nginx/default.conf`
- Modify: `/etc/homecrm/docker-compose.prod.yml`
- Backup: `/etc/homecrm/backups/20260728-https-before/`

**Interfaces:**
- Consumes: issued PEM certificate and matching private key
- Produces: validated Compose and Nginx configuration ready for activation

- [ ] **Step 1: Verify certificate identity, lifetime, and key match locally**

```bash
openssl x509 -in /tmp/homecrm-cert.JmsBh9/api.homecrm.store.pem \
  -noout -subject -issuer -dates -ext subjectAltName
openssl pkey -in /tmp/homecrm-cert.JmsBh9/api.homecrm.store.key \
  -check -noout
```

Expected: SAN contains `api.homecrm.store`, the certificate is valid through
October 25, 2026, and OpenSSL reports `Key is valid`.

- [ ] **Step 2: Create production Nginx configuration locally**

Create `/tmp/homecrm-https-default.conf` with:

```nginx
server {
    listen 80;
    listen 443 ssl;
    server_name api.homecrm.store;
    root /var/www/html/public;
    index index.php;
    client_max_body_size 12m;

    ssl_certificate /etc/nginx/ssl/api.homecrm.store.pem;
    ssl_certificate_key /etc/nginx/ssl/api.homecrm.store.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass api:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

- [ ] **Step 3: Create the updated production Compose file locally**

Copy `/etc/homecrm/docker-compose.prod.yml` to
`/tmp/homecrm-docker-compose.prod.yml`, then update only the Nginx service:

```yaml
  nginx:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /www/home_crm/server:/var/www/html:ro
      - /etc/homecrm/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/homecrm/ssl:/etc/nginx/ssl:ro
    depends_on:
      - api
    restart: unless-stopped
```

- [ ] **Step 4: Upload files to a temporary server staging directory**

```bash
ssh homecrm 'install -d -m 700 /root/homecrm-https-stage'
scp \
  /tmp/homecrm-cert.JmsBh9/api.homecrm.store.pem \
  /tmp/homecrm-cert.JmsBh9/api.homecrm.store.key \
  /tmp/homecrm-https-default.conf \
  /tmp/homecrm-docker-compose.prod.yml \
  homecrm:/root/homecrm-https-stage/
```

- [ ] **Step 5: Back up and install the staged files**

```bash
ssh homecrm '
install -d -m 700 /etc/homecrm/backups/20260728-https-before
cp -a /etc/homecrm/docker-compose.prod.yml /etc/homecrm/backups/20260728-https-before/
cp -a /www/home_crm/server/docker/nginx/default.conf /etc/homecrm/backups/20260728-https-before/default.conf
install -d -m 700 /etc/homecrm/ssl
install -d -m 755 /etc/homecrm/nginx
install -m 644 /root/homecrm-https-stage/api.homecrm.store.pem /etc/homecrm/ssl/api.homecrm.store.pem
install -m 600 /root/homecrm-https-stage/api.homecrm.store.key /etc/homecrm/ssl/api.homecrm.store.key
install -m 644 /root/homecrm-https-stage/homecrm-https-default.conf /etc/homecrm/nginx/default.conf
install -m 600 /root/homecrm-https-stage/homecrm-docker-compose.prod.yml /etc/homecrm/docker-compose.prod.yml
'
```

- [ ] **Step 6: Run preflight validation without changing the running container**

```bash
ssh homecrm '
docker compose -f /etc/homecrm/docker-compose.prod.yml config --quiet
docker run --rm \
  --network homecrm_default \
  -v /www/home_crm/server:/var/www/html:ro \
  -v /etc/homecrm/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro \
  -v /etc/homecrm/ssl:/etc/nginx/ssl:ro \
  nginx:1.27-alpine nginx -t
'
```

Expected: Compose exits 0 and Nginx reports syntax and configuration success.

### Task 3: Activate and verify HTTPS

**Files:**
- Use: `/etc/homecrm/docker-compose.prod.yml`
- Use: `/etc/homecrm/nginx/default.conf`
- Use: `/etc/homecrm/ssl/api.homecrm.store.pem`
- Use: `/etc/homecrm/ssl/api.homecrm.store.key`

**Interfaces:**
- Consumes: validated production TLS configuration
- Produces: public HTTPS API on port 443

- [ ] **Step 1: Recreate only the Nginx service**

```bash
ssh homecrm 'docker compose -f /etc/homecrm/docker-compose.prod.yml -p homecrm up -d --no-deps --force-recreate nginx'
```

Expected: `homecrm-nginx-1` is recreated while `homecrm-api-1` remains running.

- [ ] **Step 2: Verify the container and local TLS endpoint**

```bash
ssh homecrm '
docker exec homecrm-nginx-1 nginx -t
ss -tlnp | grep -E ":(80|443) "
curl --fail --show-error --max-time 10 \
  --resolve api.homecrm.store:443:127.0.0.1 \
  https://api.homecrm.store/api
'
```

Expected: Nginx validation passes, ports 80 and 443 listen, and HTTPS returns the
API health JSON.

- [ ] **Step 3: Verify the public endpoint and certificate**

```bash
curl --fail --show-error --max-time 10 https://api.homecrm.store/api
openssl s_client -connect api.homecrm.store:443 \
  -servername api.homecrm.store </dev/null 2>/dev/null |
  openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Expected: HTTPS returns HTTP 200 and the served certificate matches
`api.homecrm.store`.

- [ ] **Step 4: Confirm HTTP remains enabled**

```bash
ssh homecrm 'curl --fail --show-error --max-time 5 http://127.0.0.1/api'
```

Expected: HTTP still returns the API health JSON.

- [ ] **Step 5: Remove staging files**

```bash
ssh homecrm 'find /root/homecrm-https-stage -type f -delete; rmdir /root/homecrm-https-stage'
```

Expected: staging files are removed; active files and backup remain.

### Task 4: Roll back if activation validation fails

**Files:**
- Restore: `/etc/homecrm/docker-compose.prod.yml`
- Restore: active Nginx configuration mount

**Interfaces:**
- Consumes: `/etc/homecrm/backups/20260728-https-before/`
- Produces: restored HTTP-only Nginx service

- [ ] **Step 1: Restore the previous Compose file and mount target**

```bash
ssh homecrm '
cp -a /etc/homecrm/backups/20260728-https-before/docker-compose.prod.yml /etc/homecrm/docker-compose.prod.yml
docker compose -f /etc/homecrm/docker-compose.prod.yml -p homecrm up -d --no-deps --force-recreate nginx
docker exec homecrm-nginx-1 nginx -t
curl --fail --show-error --max-time 5 http://127.0.0.1/api
'
```

Expected: HTTP-only service is restored and healthy.

### Task 5: Record the deployment plan

**Files:**
- Create: `docs/superpowers/plans/2026-07-28-production-https-deployment.md`

**Interfaces:**
- Consumes: verified deployment outcome
- Produces: committed operational record without certificate material

- [ ] **Step 1: Review and commit only this plan**

```bash
git diff --check -- docs/superpowers/plans/2026-07-28-production-https-deployment.md
git add docs/superpowers/plans/2026-07-28-production-https-deployment.md
git commit -m "docs: record production HTTPS deployment"
```

Expected: the certificate and private key are not tracked, and unrelated local
iOS/Xcode changes remain unstaged.
