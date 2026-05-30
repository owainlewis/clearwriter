# Cloud Run Production Runtime

PAIR runs as one Rails web process on Cloud Run. The MVP does not require a
standing background worker; password reset mail is sent synchronously, and
production Active Job uses the inline adapter.

## Required Environment

Set these values on the Cloud Run service:

- `RAILS_ENV=production`
- `RAILS_MASTER_KEY` from the production credentials key
- `DATABASE_URL` for the Cloud SQL Postgres database, or the split DB variables below
- `APP_HOST=usepair.ai`
- `APP_HOSTS=usepair.ai,www.usepair.ai`
- `APP_PROTOCOL=https`
- `RAILS_LOG_LEVEL=info`

`DATABASE_URL` is the preferred database setting. For Cloud SQL Unix socket
connections, use the native Cloud Run Cloud SQL integration and a URL like:

```sh
postgres://DB_USER:DB_PASSWORD@localhost/DB_NAME?host=/cloudsql/PROJECT:REGION:INSTANCE
```

The `localhost` placeholder is intentional; Rails' URL parser requires a host
in the authority section before the Cloud SQL Unix socket `host` query
parameter can override it.

If `DATABASE_URL` is not set, production falls back to:

- `DB_NAME` defaulting to `pair_production`
- `DB_USER` defaulting to `pair`
- `DB_PASSWORD` or legacy `PAIR_DATABASE_PASSWORD`
- `DB_HOST`, optional; set to `/cloudsql/PROJECT:REGION:INSTANCE` for Cloud SQL sockets
- `DB_PORT`, optional

## Cloud Run Notes

- The container listens on port `3000`; deploy/update the Cloud Run service
  with `--port 3000`.
- `/up` is excluded from SSL redirects and host authorization so Cloud Run
  health checks can reach it during bring-up.
- `usepair.ai`, `www.usepair.ai`, and `*.run.app` hosts are accepted in
  production. Override `APP_HOSTS` if the service uses additional hostnames.
- SSL is still forced for normal traffic. Cloud Run terminates TLS at the
  proxy, and Rails uses `config.assume_ssl = true`.
- Do not set `SOLID_QUEUE_IN_PUMA` for MVP deployments.

## Smoke Check

After deploy:

```sh
curl -I https://SERVICE_URL/up
curl -I https://SERVICE_URL/
```

Then check Cloud Run logs for boot, database, secret, and migration errors.

## Current Production Resources

- Project: `use-pair-ai`
- Cloud Run region: `europe-west1`
- Cloud Run service: `pair`
- Cloud Run URL: `https://pair-647759633477.europe-west1.run.app`
- Domain mappings: `usepair.ai`, `www.usepair.ai`
- Cloud SQL instance: `pair-production-euw1` in `europe-west1`
- Cloud SQL database: `pair_production`
- Cloud SQL user: `pair`
- Runtime service account: `pair-run@use-pair-ai.iam.gserviceaccount.com`
- Secrets: `pair-rails-master-key`, `pair-database-url`

The service is deployed with Cloud Run invoker IAM checks disabled because the
project policy rejects an `allUsers` IAM binding. Revisit this when the custom
domain and edge configuration are in place.

The previous `europe-west2` Cloud Run service, Artifact Registry repository,
Cloud Run source bucket, and Cloud SQL instance have been deleted.
