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
