# Terminus on Fly.io — Deployment Notes

Notes from deploying [Terminus](https://github.com/usetrmnl/terminus) on Fly.io
as the BYOS server for a Kobo TRMNL display
([trmnl-kobo](https://github.com/usetrmnl/trmnl-kobo)).

## Final architecture

One combined Fly machine running both Puma (HTTP) and Sidekiq (jobs):

- **App:** `trmnl-kobo-server` in `yyz`
- **VM:** `shared-cpu-2x`, 2 GB RAM
- **Postgres:** Fly Postgres, attached as `DATABASE_URL`
- **Redis:** Upstash, accessed as `KEYVALUE_URL` over TLS
- **Storage:** local disk under `public/uploads/` (no object storage)

## Issues hit and how they were fixed

### 1. Worker machine kept auto-stopping

**Symptom:** the `worker` process group machine would briefly run, then go
back to `stopped`. Background jobs (extension builds, scheduled syncs) never
ran. The dashboard sat on "enqueuing" forever.

**Why:** there was no restart policy declared for the worker. When Sidekiq
exited for any reason — a clean exit, a crash, a signal — the machine had no
instruction to come back up. Fly's auto-stop applied to the HTTP service was
fine (it only targeted `app` processes), but nothing was *keeping* the worker
alive.

**Fix:** add an explicit restart policy and disable any auto-stop behavior on
the worker VM in `fly.toml`:

```toml
[[restart]]
  policy = "always"
  retries = 10
  processes = ["worker"]

[[vm]]
  processes = ['worker']
  auto_stop_machines = false
  auto_start_machines = false
```

### 2. Sidekiq crash-looping on boot

**Symptom:** after the restart policy was in place, the worker stayed in
`started` for ~15 seconds then died and rebooted. Logs showed:

```
Sidekiq 8.1.3 connecting to Redis with options {... url: "redis://default:REDACTED@…upstash.io:6379"}
EOFError (redis://…upstash.io:6379)
Main child exited normally with code: 1
```

**Why:** Upstash Redis requires TLS. The `KEYVALUE_URL` secret was set with
the `redis://` (plaintext) scheme, so the Ruby Redis client opened a plaintext
TCP connection to a TLS-only endpoint. Upstash terminated the handshake
immediately, the client read a closed socket, and Sidekiq aborted at startup.

The `redis-cli` example in the Upstash docs uses `--tls` with `redis://`,
which is misleading — clients that *only* take a URL (like the one inside
Sidekiq) need the scheme to indicate TLS.

**Fix:** change the scheme from `redis://` to `rediss://` (two s's).

```bash
fly secrets set KEYVALUE_URL='rediss://default:<token>@<host>.upstash.io:6379' \
  --app trmnl-kobo-server
```

### 3. Extension builds silently produced no image

**Symptom:** clicking "Build" in the dashboard returned 202 and Sidekiq said
the job completed. No errors in `Sidekiq::RetrySet` or `DeadSet`. But no
screen image was produced and the dashboard kept showing the old image.

**Why this was hard to see:** Terminus uses `Dry::Monads::Result` throughout
the rendering pipeline. When the screen renderer fails, it returns
`Failure(...)` rather than raising. Sidekiq sees the job as successful (no
exception), so the job never lands in retry or dead. The actual failure
message is logged at `debug` level, which is silenced by default.

**Diagnosis:** ran the rendering pipeline directly via `fly ssh console` with
a monkey-patch on `Terminus::Aspects::Screens::Shoter` to print the swallowed
exception. This surfaced two stacked problems:

#### 3a. Chromium startup timeout

```
Ferrum::ProcessTimeoutError: Unable to capture screenshot because the
browser could not produce a websocket URL within 10 seconds.
```

Ferrum waits 10 seconds by default for headless Chromium to publish its
DevTools WebSocket URL. On `shared-cpu-1x` that can be too tight (Chromium
startup is CPU-heavy). Bumping CPU to `shared-cpu-2x` helped but didn't fully
resolve — Chromium still occasionally needed >10 seconds.

**Fix:** raise `process_timeout` (and `timeout`) via the `BROWSER` env
setting, which is parsed as JSON per `Terminus::Types::Browser`:

```bash
fly secrets set BROWSER='{"js_errors":false,"process_timeout":30,"timeout":30}'
```

#### 3b. Extension JavaScript errors aborting renders

After fixing the timeout, builds failed with:

```
Ferrum::JavaScriptError: SyntaxError: Unexpected token ';'
```

Some bundled extension templates contain JavaScript that throws at parse or
runtime. Ferrum defaults `js_errors: true`, which makes any uncaught JS error
in the page abort the screenshot operation. For an e-ink display, the
rendered DOM is what matters — JS warnings/errors should not prevent
capture.

**Fix:** the same secret above also sets `js_errors: false`. Ferrum now
ignores JS errors and the screenshot completes.

### 4. Kobo got 404s on screen image URLs

**Symptom:** Kobo display log showed:

```
TRMNL api display returned 0 with {
  "image_url": "https://trmnl-kobo-server.fly.dev/uploads/<hash>.png",
  ...
}
TRMNL fetch image from https://…/uploads/<hash>.png
```

The Kobo successfully called `/api/display`, got a payload with a valid-looking
`image_url`, but the image fetch returned no data. Server logs confirmed:
`GET /uploads/<hash>.png status:404`.

**Why:** Shrine was configured with `Shrine::Storage::FileSystem.new("public",
prefix: "uploads")` — local disk. With separate machines for `app` (HTTP) and
`worker` (Sidekiq):

1. Worker rendered the screen → wrote `public/uploads/<hash>.png` on **its
   own** ephemeral disk
2. Kobo asked an `app` machine for the image → that machine looked at **its
   own** disk, file wasn't there → 404

Fly machines do not share filesystems by default. Volumes can be attached to
a machine but are not shared between machines.

**Fix (this deployment):** collapse to a single machine running both
processes. Both Puma and Sidekiq read/write the same `public/uploads/`
directory.

- Added `scripts/docker/start-all` — a small bash supervisor that starts
  Sidekiq and Puma in the same container and forwards SIGTERM/SIGINT to both
- Removed the separate `worker` process group from `fly.toml`
- Single `app` process group runs `scripts/docker/start-all`
- Scaled to one machine with `fly scale count app=1`
- Bumped to `shared-cpu-2x` / 2 GB to comfortably host Puma + Sidekiq +
  Chromium together

**Alternative (not taken):** switch Shrine to S3 storage backed by Fly's
[Tigris](https://fly.io/docs/reference/tigris/). Cleaner for horizontal
scaling, but requires `Gemfile`/provider changes and was overkill for one
device.

## Final `fly.toml`

```toml
app = 'trmnl-kobo-server'
primary_region = 'yyz'

[build]

[http_service]
  internal_port = 2300
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1
  processes = ['app']

[processes]
  app = "scripts/docker/start-all"

[[restart]]
  policy = "always"
  retries = 10
  processes = ["app"]

[[vm]]
  processes = ['app']
  memory = '2gb'
  cpus = 2
  cpu_kind = 'shared'
  memory_mb = 2048
```

## Required secrets

| Secret | Notes |
|---|---|
| `APP_SECRET` | 64+ char random hex (e.g. `openssl rand -hex 64`) |
| `APP_SETUP` | `true` on first boot to run `hanami db migrate` and asset compile |
| `API_URI` | Public URL the Kobo will reach, e.g. `https://trmnl-kobo-server.fly.dev` |
| `DATABASE_URL` | Set automatically by `fly postgres attach` |
| `KEYVALUE_URL` | Upstash Redis URL — **must use `rediss://`** |
| `HANAMI_PORT` | `2300` |
| `BROWSER` | `{"js_errors":false,"process_timeout":30,"timeout":30}` |

## Operational notes

- **First-run after deploy:** the existing screen records reference image
  files written on whatever machine handled the previous render. After the
  collapse-to-one-machine migration, those files are gone. Trigger a fresh
  build on each extension, or wait for the scheduled synchronizer to refresh
  them, before the Kobo can pull a working image.
- **Cost note:** the standby worker machine that came with the multi-machine
  setup was destroyed during the consolidation. The single combined machine
  costs roughly the same as the previous worker-only machine.
- **Watching logs while diagnosing:**
  ```bash
  fly logs --app trmnl-kobo-server -i <machine-id>
  ```
- **Confirming both processes are running on the combined machine:**
  ```bash
  fly ssh console --app trmnl-kobo-server -C 'ps -ef'
  ```
  Expect to see one `bash scripts/docker/start-all`, one `sidekiq …`, one
  `puma …`.
