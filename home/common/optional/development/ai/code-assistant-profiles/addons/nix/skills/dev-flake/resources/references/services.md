# Services Reference

Patterns for `services-flake` beyond the base template. Read the module source under
`$(nix eval --raw .#inputs.services-flake.outPath)/nix/services/` when an option isn't here;
options change between releases.

## Launcher behaviour

- `nix run .#services` runs process-compose in the foreground with its TUI (F10 quits).
  Add `-- -t=false` for headless.
- The generated launcher passes `--no-server`, so `process-compose down` can't reach it.
  Stop it from its own terminal, or `pgrep -x process-compose | xargs kill -TERM`.
- Put `dataDir = ".data/<name>"` on every service and gitignore `.data/`.

## Postgres: match production ownership and roles

When production runs migrations as a non-superuser owner and grants to other roles,
reproduce that shape locally so grants are exercised, not bypassed:

```nix
postgres."pg" = {
  enable = true;
  dataDir = ".data/pg";
  listen_addresses = "127.0.0.1";
  port = 55432; # not 5432, so it never meets a system Postgres
  superuser = "app_owner"; # initdb -U: owns every initialDatabase
  initialDatabases = [{name = "app";}];
  initialScript.after = ''
    CREATE ROLE app_writer LOGIN;
    CREATE ROLE dashboard_reader LOGIN;
  '';
};
```

- Local auth is `trust` by default (the module's generated `pg_hba.conf`), so passwords are
  ignored. Clients that insist on one can send any value.
- If migrations create roles, make them `IF NOT EXISTS ... NOLOGIN`: locally the
  initialScript creates them first with `LOGIN`; in production the operator does.

## Grafana: provisioned datasource and live dashboards

```nix
grafana."grafana" = {
  enable = true;
  dataDir = ".data/grafana";
  http_port = 3000;
  extraConf = {
    "auth.anonymous" = { enabled = true; org_role = "Admin"; };
    auth.disable_login_form = true;
    # Grafana's install dir is the read-only Nix store; preinstalls fail noisily otherwise.
    plugins.preinstall_disabled = true;
  };
  datasources = [{
    name = "app";
    uid = "app"; # same uid as production, so dashboard JSON moves between them unchanged
    type = "grafana-postgresql-datasource";
    url = "127.0.0.1:55432";
    user = "dashboard_reader";
    isDefault = true;
    jsonData = { database = "app"; sslmode = "disable"; postgresVersion = 1800; };
  }];
  providers = [{
    name = "app";
    type = "file";
    allowUiUpdates = true;
    # Grafana expands $PWD at runtime: dashboards load live from the repo, not a store copy.
    options.path = "$PWD/grafana/dashboards";
  }];
};
```

- A Nix path (`options.path = ./grafana/dashboards;`) copies the directory into the store
  at evaluation, so edits need a rebuild. The `$PWD` form needs the services started from
  the repo root, which is what a Justfile recipe does.
- Connecting as the production read-only role locally catches missing grants before deploy.
- Verify without a browser: `curl -s localhost:3000/api/datasources/uid/<uid>/health`, and
  run a panel's SQL through `POST /api/ds/query`.
