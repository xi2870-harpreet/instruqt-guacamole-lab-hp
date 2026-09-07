# Ubuntu desktop via Guacamole (Instruqt Labs 2.0)

An XFCE desktop served over VNC and rendered in the browser by Apache
Guacamole, using **containers only**.

## Why it is built this way

Two Labs 2.0 constraints shaped the design:

- `template` and `copy` are **Post GA**, so no configuration files can be
  injected into a container.
- an `exec` resource against a Debian-based image currently fails with
  `container exec failed with exit code 2` (see
  `instruqt-cloud-labs-hp/FINDING-exec-exit2.md`).

So this lab uses **no `exec` and no file injection**. Everything is configured
through container `environment` and image defaults, and the one piece of setup
that would normally need a config file — the Guacamole connection to the VNC
host — is done by the learner in the Guacamole UI instead.

## Shape

```
network main
├── container desktop    consol/ubuntu-xfce-vnc     VNC on 5901, alias `desktop`
└── container guacamole  flcontainers/guacamole     web UI on 8080, alias `guacamole`

service   guacamole:8080  -> "Guacamole" tab
terminal  desktop         -> "Desktop shell" tab
```

## Incidental test

The task's check script runs inside the Debian-based `desktop` container. If it
passes, the exit-code-2 failure is specific to the `exec` resource rather than
to running scripts in containers generally.

## Image facts, verified from the registry rather than assumed

`consol/ubuntu-xfce-vnc:latest`

- exposes `5901/tcp` (VNC) and `6901/tcp` (noVNC)
- runs as **UID 1000**, `HOME=/headless` — VNC state is under `/headless/.vnc/`
- `VNC_PW` defaults to `vncpassword`; this lab overrides it to `instruqt`
- entrypoint `/dockerstartup/vnc_startup.sh --wait`, left untouched

`flcontainers/guacamole:latest`

- exposes `8080/tcp` (web) and `4822/tcp` (guacd, internal only)
- runs as root, entrypoint `/startup.sh`, Guacamole 1.6.0
- carries `POSTGRES_*` defaults but no `POSTGRES_HOST`, so it uses its bundled
  database and needs no external one

## The thing actually worth watching

Guacamole streams the remote display over a **WebSocket**. This lab is therefore
a real test of whether a `service` tab proxies WebSocket upgrades, not just
plain HTTP. If the Guacamole UI loads and authenticates but the desktop panel
stays blank or disconnects, suspect the service proxy rather than the desktop
container — check the browser console for a failed `wss://` upgrade before
blaming VNC.

