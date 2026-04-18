---
description: Bring up the Multica self-host stack (Postgres + Go backend + Next.js UI + local daemon) on this host, with port overrides and NFS-backed state.
---

# multica-up

Bring up the self-hosted Multica stack on **this host** (`/home/tolga`). This is a runbook — execute the steps in order and verify as you go. Stop at the first failing check.

## Why these choices

This host's defaults are taken, and all state must land on `/mnt/multica` (NFS share `10.0.100.100:/datapool/multica`, 50G, NFSv4.2, `hard` + `local_lock=none`).

**Port remap** (default → this host):

| Role | Host port | Container port |
|---|---|---|
| Frontend (Next.js) | **14000** | 3000 |
| Backend (Go) | **14080** | 8080 |
| Postgres | **14432** | 5432 |

If those ports are no longer free, pick new ones and update `.env` + verification commands below. Check first with:

```bash
ss -tlnp | grep -E ':(14000|14080|14432) '
```

**State layout on NFS:**

| Path | Contents |
|---|---|
| `/mnt/multica/postgres/` | Postgres data dir — all app state (issues, users, chats, tasks). Bind-mounted into the pg container. |
| `/mnt/multica/workspaces/` | Daemon's `MULTICA_WORKSPACES_ROOT` — per-task agent workdirs and `.repos/` git cache. Reused across tasks on the same (agent, issue) pair (`server/internal/daemon/daemon.go:903-921`). |

Nothing else is stateful. Backend and frontend containers are ephemeral; file uploads require `S3_BUCKET` and fall back to disabled if unset.

**Daemon binary:** use `/usr/local/bin/multica` (installed from the GitHub release), not `make daemon`. The released binary is the same code, runs detached, and ships `status` / `stop` / `logs` subcommands. Verify version match against the repo HEAD before starting (step 5 below).

**Postgres on NFS caveat:** officially supported with your mount options, but every `fsync` round-trips to the NFS server. Acceptable for a single-user self-host. If performance becomes a problem, move `/mnt/multica/postgres/` to local disk and keep workspaces on NFS — that's the "hybrid" fallback.

---

## Step 1 — Prepare NFS directories

```bash
mkdir -p /mnt/multica/postgres /mnt/multica/workspaces

# Postgres in pgvector:pg17 runs as UID 999. Must own the data dir, or pg won't start.
sudo chown -R 999:999 /mnt/multica/postgres
chmod 700 /mnt/multica/postgres            # pg insists on 0700
chmod 755 /mnt/multica/workspaces          # daemon runs as host user (tolga)
```

**Verify the NFS export allows UID 999 writes.** The obvious `sudo -u '#999' touch …` doesn't work on this host — sudo refuses numeric UIDs for non-existent local users. Use a throwaway alpine container instead, which is actually a stricter test because it matches what the real postgres container does:

```bash
docker run --rm -u 999:999 -v /mnt/multica/postgres:/data alpine \
  sh -c 'touch /data/.test && rm /data/.test && echo "NFS UID 999 writable: OK"'
```

If this fails with `EACCES`, the NFS server is squashing the UID. Either fix the export (`no_root_squash` / anonuid mapping) or switch to the hybrid layout (Postgres on local disk).

## Step 2 — Create `.env` in the repo root

Copy the example and set this host's values. **Change `JWT_SECRET`.**

```bash
cd /home/tolga/src/github/multica
test -f .env || cp .env.example .env
git check-ignore .env    # must print ".env" — confirms it won't be committed
```

Then edit `.env` to match:

```bash
# --- Port overrides (host-side) ---
POSTGRES_PORT=14432
PORT=14080
FRONTEND_PORT=14000

# --- Secrets ---
JWT_SECRET=<generate: openssl rand -hex 32>

# --- Public URLs (host-side ports) ---
MULTICA_SERVER_URL=ws://localhost:14080/ws
MULTICA_APP_URL=http://localhost:14000
FRONTEND_ORIGIN=http://localhost:14000
NEXT_PUBLIC_API_URL=http://localhost:14080
NEXT_PUBLIC_WS_URL=ws://localhost:14080/ws

# --- DB (uses Compose DNS, not host port) ---
DATABASE_URL=postgres://multica:multica@postgres:5432/multica?sslmode=disable
POSTGRES_DB=multica
POSTGRES_USER=multica
POSTGRES_PASSWORD=multica

# --- Agent workspaces on NFS (daemon-side, not container) ---
MULTICA_WORKSPACES_ROOT=/mnt/multica/workspaces

# --- Optional (leave empty to disable) ---
RESEND_API_KEY=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=http://localhost:14000/auth/callback
S3_BUCKET=
```

Subtleties worth remembering:

- `DATABASE_URL` uses `postgres:5432` (Compose-internal DNS), not `localhost:14432`. The backend container talks to Postgres on the internal network.
- `NEXT_PUBLIC_*` vars are belt-and-suspenders — `apps/web/next.config.ts:34-49` already installs rewrites that proxy `/api`, `/ws`, `/auth` from the frontend to `http://backend:8080` server-side, so the browser never needs the backend's external port.
- `MULTICA_WORKSPACES_ROOT` is read by the **daemon** (`server/internal/daemon/config.go:177`), not the backend container. It belongs in the daemon's shell env, but it's fine to also leave it in `.env` for documentation.

## Step 3 — Create the Compose override for NFS-backed Postgres

Write `/home/tolga/src/github/multica/docker-compose.selfhost.override.yml`:

```yaml
services:
  postgres:
    volumes:
      - /mnt/multica/postgres:/var/lib/postgresql/data
```

Keeps the tracked `docker-compose.selfhost.yml` untouched. Compose merges the override when you pass both `-f` flags.

## Step 4 — Bring up the stack

```bash
cd /home/tolga/src/github/multica

# Sanity: render the merged config and confirm Postgres uses the NFS bind mount
docker compose \
  -f docker-compose.selfhost.yml \
  -f docker-compose.selfhost.override.yml \
  config | grep -A6 'postgres:' | head -20
# Expect a bind mount: source: /mnt/multica/postgres, target: /var/lib/postgresql/data

# Bring it up
docker compose \
  -f docker-compose.selfhost.yml \
  -f docker-compose.selfhost.override.yml \
  up -d

# Tail Postgres until it's ready
docker compose \
  -f docker-compose.selfhost.yml \
  -f docker-compose.selfhost.override.yml \
  logs -f postgres
# Expect: "database system is ready to accept connections"
# Permission or lock errors here → re-check step 1 (NFS UID / squash).
```

Verify all three containers are up and healthy:

```bash
docker compose -f docker-compose.selfhost.yml -f docker-compose.selfhost.override.yml ps
ls /mnt/multica/postgres/          # PG_VERSION, base/, global/, pg_wal/, …
curl -sf http://localhost:14080/health || echo 'backend not ready'
curl -sfI http://localhost:14000/ | head -1   # expect HTTP/1.1 200
curl -sf http://localhost:14000/api/health || true  # rewritten → backend
```

## Step 5 — Start the daemon (installed binary)

**Version check first** — the installed binary must match the repo HEAD, or the daemon's wire protocol can drift from the backend:

```bash
multica --help 2>&1 | head -1                              # e.g. "multica 0.1.25 (commit: e477d645)"
git -C /home/tolga/src/github/multica rev-parse --short HEAD   # must match the commit above
```

If they differ, either `git checkout` the repo to the tag matching the installed binary, or update the binary from the GitHub release page for the current HEAD tag. Don't proceed with a mismatch.

Then log the CLI in. **This host is headless — no X, no `xdg-open`, no browser.** The default `multica login` flow (`server/cmd/multica/cmd_auth.go:105-162`) is useless here: it spins up a callback listener on the server's `127.0.0.1:<ephemeral>` and tries to open a browser on the server. Even if you copy the printed URL to a laptop browser, the laptop can't reach that ephemeral callback without tunneling the random port too. Don't try.

The headless path is `multica login --token`, which just prompts for a personal access token on stdin (`cmd_auth.go:225+`).

```bash
# 1. Point the CLI at the local backend (persists to ~/.multica/config.json — flat file, not profile dir)
multica config set server_url http://localhost:14080

# 2. Bootstrap the first user via the web UI (laptop browser via SSH tunnel / reverse proxy):
#    - Open http://localhost:14000 and enter an email.
#    - Backend has no email provider wired (RESEND_API_KEY empty), so the 6-digit OTP
#      is printed to backend stdout instead. Pull it with:
docker compose -f docker-compose.selfhost.yml -f docker-compose.selfhost.override.yml \
  logs -f backend | grep --line-buffered '\[DEV\] Verification code'
#    (`server/internal/service/email.go:33-37`). Paste the 6-digit code in the UI's OTP field.
#    Non-prod master code `888888` also works (`server/internal/handler/auth.go:275`) if grepping is awkward.
#    - Once signed in, go to Settings → Tokens (`packages/views/settings/components/tokens-tab.tsx`),
#      create a new PAT, copy the value — it's only shown once.

# 3. Paste the PAT into the CLI on the server shell:
multica login --token
# On success, the CLI also auto-watches all visible workspaces (cmd_login.go:42-98).
multica config          # token should be (set), workspace_id populated
multica workspace list  # sanity check

# 4. Export daemon env and start detached
export MULTICA_WORKSPACES_ROOT=/mnt/multica/workspaces
export MULTICA_SERVER_URL=ws://localhost:14080/ws
multica daemon start

multica daemon status    # expect "running" + daemon ID + device name
multica daemon logs      # tail recent activity
```

If you'd rather skip the CLI entirely, hand-edit `~/.multica/config.json` — schema from `server/internal/cli/config.go:19-27`:

```json
{
  "server_url": "http://localhost:14080",
  "token": "<PAT from UI>",
  "workspace_id": "<uuid>"
}
```

All fields `omitempty`. `chmod 600` after editing. Note `app_url` is only read by the browser login flow we're not using; leaving it unset is fine.

**Persist the env vars** across logins (optional) — add to `~/.bashrc`:

```bash
echo 'export MULTICA_WORKSPACES_ROOT=/mnt/multica/workspaces' >> ~/.bashrc
echo 'export MULTICA_SERVER_URL=ws://localhost:14080/ws'      >> ~/.bashrc
```

Or wrap in a systemd user unit for auto-start on boot.

## Step 6 — End-to-end smoke test

1. Open `http://localhost:14000` in the **laptop** browser (through whatever SSH tunnel / reverse proxy gets the port through — the server has no browser).
2. Sign in as the account you created in Step 5 (OTP from backend logs via `grep '\[DEV\] Verification code'`, or master code `888888` in non-prod).
3. Create an issue, assign it to an agent that uses the `claude` provider.
4. Watch the daemon pick it up on the server shell: `multica daemon logs`.
5. Confirm a new workdir appears under `/mnt/multica/workspaces/<workspaceID>/` once the agent starts.
6. Confirm Claude Code uses your subscription: `ps auxf | grep 'claude -p'` shows the subprocess; no `ANTHROPIC_API_KEY` is passed in its env (`cat /proc/<pid>/environ | tr '\0' '\n' | grep -i anthropic` should be empty).

## Teardown

```bash
# Stop the daemon
multica daemon stop

# Stop the stack (data persists on NFS)
docker compose \
  -f docker-compose.selfhost.yml \
  -f docker-compose.selfhost.override.yml \
  down

# Full wipe (nukes all state on NFS — careful)
docker compose \
  -f docker-compose.selfhost.yml \
  -f docker-compose.selfhost.override.yml \
  down -v
sudo rm -rf /mnt/multica/postgres/* /mnt/multica/workspaces/*
```

## Troubleshooting

- **Postgres won't start / permission denied on `/var/lib/postgresql/data`** — NFS UID 999 isn't writable. Re-check step 1 verification. Fix the NFS export or fall back to a local bind mount for Postgres only.
- **Frontend returns 502 on `/api/*`** — backend container isn't healthy. Check `docker compose logs backend`. Likely bad `DATABASE_URL` (should point to `postgres:5432`, not `localhost:14432`).
- **Daemon can't reach backend** — `MULTICA_SERVER_URL` wrong or not exported in the shell that ran `multica daemon start`. `multica daemon stop && multica daemon start` after fixing.
- **`claude -p` fails with auth error** — your `~/.claude/` session expired. Run `claude login` on the host and retry.
- **Port already in use on `up -d`** — another container grabbed 14000/14080/14432 since the plan was written. Pick new ports, update `.env`, re-run.
- **Agent can't find workdir / permission errors on `/mnt/multica/workspaces`** — daemon is running as a different UID than the one that owns the directory. Fix with `sudo chown -R tolga:tolga /mnt/multica/workspaces`.
- **`multica login` opens `https://multica.ai` or fails to open anything** — you invoked the default browser flow on a headless server. Use `multica login --token` with a PAT minted from the UI's Settings → Tokens instead (see Step 5). The browser flow is not viable on this host regardless of which env vars you set, because the callback runs on the server's ephemeral `127.0.0.1` port.
- **No `[DEV] Verification code` lines in backend logs when requesting OTP** — either `RESEND_API_KEY` got accidentally populated (the fallback only triggers when it's empty — `server/internal/service/email.go:33-37`), or the UI call never reached the backend. Check `docker compose logs backend --tail 50` for the `SendCode` request itself.
