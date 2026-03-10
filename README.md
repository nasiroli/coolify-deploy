# Deployment Guide

This document covers running the application with Docker locally and deploying to Coolify.

---

## 1. Running locally with Docker

Run the app and a PostgreSQL database in containers using Docker Compose.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) (v2+)

### Steps

1. **Create environment file**

   ```bash
   cp .env.example .env
   ```

2. **Set `APP_KEY`** (required). Either generate one locally:

   ```bash
   php artisan key:generate
   ```

   or set it manually in `.env` (e.g. `APP_KEY=base64:...`).

3. **Start the stack**

   ```bash
   docker compose up --build
   ```

   The app is served at **http://localhost:8080**. The database is created automatically; migrations run on first start (`AUTORUN_ENABLED=true`).

4. **Optional: run artisan in the app container**

   ```bash
   docker compose exec app php artisan migrate
   docker compose exec app php artisan tinker
   ```

### Local Compose layout

| Service   | Image / build      | Port (host) | Notes                          |
|----------|--------------------|-------------|---------------------------------|
| `app`    | Built from `Dockerfile` | 8080 → 80   | Laravel (Nginx + PHP-FPM)       |
| `postgres` | `postgres:17-alpine`   | —           | DB: `nasiro_li`, user: `nasiro_li`, password: `secret` |

Database credentials are set in `docker-compose.yml` and passed to the app; you can change them there and in `.env` if you override `DB_*` for other tooling.

### Stopping

```bash
docker compose down
```

Data is kept in a named volume (`postgres_data`). To remove it too:

```bash
docker compose down -v
```

---

## 2. Deploy on Coolify with Docker

You can deploy either with Coolify’s **Dockerfile** build or with a **Docker Compose** resource. Both use the same app image (Nginx + PHP-FPM, port 80).

### Prerequisites

- A Coolify instance (v4+).
- A PostgreSQL database (Coolify “Database” resource or external). Note the internal hostname, port, database name, user, and password.

### Option A: Coolify “Dockerfile” (build from repo)

1. In Coolify: **Add resource** → **Application** → connect your Git repository.
2. Set **Build pack** to **Dockerfile**.
   - Dockerfile path: `Dockerfile` (default).
3. Set **Ports Exposes** to **80**.
4. Add **environment variables** (e.g. in “Developer” view):
   - `APP_KEY` (e.g. `base64:...` from `php artisan key:generate --show`).
   - `APP_ENV=production`
   - `APP_DEBUG=false`
   - `APP_URL=https://your-domain.com`
   - `DB_CONNECTION=pgsql`
   - `DB_HOST=<postgres-internal-hostname>`
   - `DB_PORT=5432`
   - `DB_DATABASE=...`
   - `DB_USERNAME=...`
   - `DB_PASSWORD=...`
   - `AUTORUN_ENABLED=true` (optional; runs migrations on container start).
5. If the database is another Coolify resource: enable **Connect To Predefined Network** so the app can reach it.
6. In **Domains**, add your domain and set the port to **80** (e.g. `https://your-domain.com:80`).
7. **Deploy**.

**Alternative: Nginx Unit (port 8000)**  
To use the official Coolify Laravel + Unit setup:

- Set Dockerfile path to **`Dockerfile.unit`**.
- Set **Ports Exposes** to **8000**.
- In Domains, use port **8000** (e.g. `https://your-domain.com:8000`).
- Add a **Post-deployment** command (once or “Execute after deploy”):

  ```bash
  php artisan optimize:clear && php artisan config:clear && php artisan route:clear && php artisan view:clear && php artisan optimize
  ```

### Option B: Coolify “Docker Compose” (pre-built image)

Use this when the image is built elsewhere (e.g. Coolify build, CI, or registry) and you want to run it via Compose (e.g. with persistent storage).

1. **Build and push the image** (or let Coolify build from the same repo and use the generated image name). Example:

   ```bash
   docker build -t your-registry/nasiroli:latest .
   docker push your-registry/nasiroli:latest
   ```

2. In Coolify: **Add resource** → **Docker Compose**.
3. Paste the contents of **`docker-compose.coolify.yml`** (or point to it if Coolify supports a path).
4. Set **environment variables** in Coolify for the stack (they are injected into the Compose file):
   - `DOCKER_IMAGE` (e.g. `your-registry/nasiroli:latest`) if you’re not using the default in the file.
   - `APP_KEY`, `APP_URL`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`.
5. Enable **Connect To Predefined Network** so the app container can reach the PostgreSQL service.
6. In **Domains**, set your domain and port **80** (e.g. `https://your-domain.com:80`).
7. **Deploy**.

**Storage permissions (when using the Compose volume for `storage`):**  
After the first deploy, in Coolify open **Command Center**, select the server, and run (replace `<STORAGE_VOLUME_PATH>` with the actual storage path from Coolify’s Storages):

```bash
mkdir -p <STORAGE_VOLUME_PATH>/framework/{sessions,views,cache}
chmod -R 775 <STORAGE_VOLUME_PATH>/framework
```

### Custom domain in Coolify

When you add a **custom domain** (e.g. `app.example.com`) in your application’s **Domains** in Coolify, this is what happens:

1. **Proxy** – Coolify’s reverse proxy (Traefik or Caddy) listens on **443** for that domain, terminates HTTPS (e.g. Let’s Encrypt), and forwards requests to your container on the port you exposed (80 or 8000). Your app container never sees the public domain or SSL; it only sees HTTP from the proxy.

2. **DNS** – You point the domain at the Coolify server: add an **A** record (and optionally **AAAA** for IPv6) with your server’s IP. Coolify then handles the hostname and certificates.

3. **Laravel** – The app must know its public URL so links, redirects, and assets use `https://` and the correct host:
   - Set **`APP_URL`** in Coolify to the full public URL, e.g. `https://app.example.com` (no trailing slash). Laravel uses this for `url()`, `asset()`, redirects, and emails.
   - This project already calls **`trustProxies(at: '*')`** in `bootstrap/app.php`, so Laravel correctly uses the `X-Forwarded-Proto` / `X-Forwarded-Host` headers from the proxy. No code change is needed.

4. **Domains in Coolify** – In the app’s **Domains** field, enter your domain and the **internal** port (e.g. `https://app.example.com:80` or `:8000` for Unit). The port is the one your container exposes, not 443.

**Checklist for a custom domain:** DNS A → server IP; domain + port in Coolify Domains; `APP_URL=https://your-domain.com` in env; deploy.

---

### Summary: Coolify + Docker

| Item | Value |
|------|--------|
| Default Dockerfile | `Dockerfile` (Nginx + PHP-FPM) |
| Unit Dockerfile | `Dockerfile.unit` (Nginx Unit) |
| App port (main) | 80 |
| App port (Unit) | 8000 |
| Database | PostgreSQL (`DB_CONNECTION=pgsql`) |
| Compose file for Coolify | `docker-compose.coolify.yml` |

Ensure `APP_KEY` and all `DB_*` variables are set in Coolify; enable **Connect To Predefined Network** when the database is in the same Coolify project.
