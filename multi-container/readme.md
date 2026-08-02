# Split-DB deployment

Use `docker-compose.yml` to run the Greenbone stack with **PostgreSQL in its
own container** and the rest of the stack (redis, openvasd, ospd-openvas,
gvmd, gsad) in a second container.

```bash
export TAG="26.08.02.03"
docker compose up -d
```

## Services

- `postgresql` — PostgreSQL 15, data on the `openvas` volume, socket on the
  shared `ovasrun:/run` volume. This container owns `/data/database`; it also
  creates the empty `gvmd` database, roles and extensions on first start.
- `openvas` — the full OpenVAS stack (`SKIPPG=true` skips the local
  PostgreSQL and connects to the database container through the shared
  `/run/postgresql` socket). Web UI on `http://<host>:8080`.

## Backing up the database

```bash
docker compose exec postgresql su - postgres -c "pg_dump -d gvmd" > gvmd-backup.sql
```

## Notes

- Both containers share the `openvas` data volume and the `ovasrun` run
  volume. Keep `command: single` on the openvas service: it makes
  `fs-setup.sh` skip the PostgreSQL data move (no first-boot race with the
  database container) and avoids nuking the shared-volume sockets on restart.
- The old 7-service split was removed because the service scripts are stale
  for the current components (gsad 26.4.0 removed `--mlisten`; ospd uses
  openvasd instead of the mosquitto MQTT architecture).
