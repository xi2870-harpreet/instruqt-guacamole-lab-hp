# Findings from the Ubuntu-desktop-via-Guacamole lab

Lab: `instruqt-support/ubuntu-guacamole-probe` · CLI `2399-280cb75`

---

## G1 — a `tcp` health check is executed as an HTTP probe  (P2, believed new)

### What was declared

`sandbox.hcl` declared **only** TCP health checks. The string `http` did not
appear anywhere in the file:

```hcl
resource "container" "desktop" {
  image { name = "consol/ubuntu-xfce-vnc:latest" }
  health_check {
    timeout = "120s"
    tcp {
      address = "localhost:5901"
    }
  }
}
```

### What happened

```
unable to create resource "resource.container.desktop": timeout waiting for HTTP
health check desktop.container.sandbox.internal:5901
```

The runtime reports an **HTTP** health check for a container where only `tcp`
was configured. Port 5901 is VNC, not HTTP, so an HTTP probe can never succeed
and the container never becomes healthy — the lab fails to start.

Note also that the address was rewritten from `localhost:5901` to
`desktop.container.sandbox.internal:5901`.

### Why this looks like a genuine defect

The container reference documents three distinct health-check types:

```
health_check
   ├─ timeout
   ├─ http[]  (address, method, body, headers, success_codes)
   ├─ tcp[]   (address)
   └─ exec[]  (command, script, exit_code)
```

`instruqt lab validate` accepts the `tcp` form. The error message naming HTTP
while only `tcp` was declared is the tell.

### What the official docs promise

Checked before filing. The docs are unambiguous and carry no caveat.

**1. It is documented as available now, not Post GA.** The feature-availability
table at `/whats-new/overview` lists:

> | [Containers](/reference/sandbox/compute/container) | CPU, memory, and GPU limits, plus health checks that can test **HTTP, TCP, or run a command**. | **Early Access** |

**2. The container reference defines three distinct probe types:**

```
health_check
   ├─ timeout
   ├─ http[] (address, method, body, headers, success_codes)
   ├─ tcp[]  (address)
   └─ exec[] (command, script, exit_code)
```

**3. It specifies the exact behaviour per type.** From the rendered field table
on `/reference/sandbox/compute/container`:

| Block | Documented behaviour |
| --- | --- |
| `http` | "Sends an HTTP request to the address and passes when the response matches the expected success codes" |
| `tcp` | **"Attempts to open a TCP connection to the address. If the connection opens, the check passes."** |
| `exec` | "The check passes when the command exits with code 0." |

**4. There is no caveat.** Searched both the markdown source and the rendered
page for `only http` / `not implemented` / `not supported` / `unsupported` /
`limitation` near `tcp` — nothing.

So the documented contract is precisely "open a TCP connection and pass if it
opens", which is the only sensible probe for a non-HTTP service such as VNC, a
database, or a message broker. The runtime does an HTTP request instead.

### Expected

A `tcp` health check should behave as its own documentation states.

### Minor, same area

Neither of the two `health_check` examples in the container reference uses `tcp`
or `exec` — both use `http`. The other two probe types are defined in the
structure tree and the field table but never shown in an example, which is
probably why this went unnoticed.

### Reproduce

`git checkout 36166e5` in this repo, import as a lab, and play it. Commit
`25a9ad0` is the same lab with the health checks removed.

---

## G2 — reproduction of the known `plugin type="tuning"` network attach failure  (already reported)

With the health checks removed, a later run failed differently:

```
unable to create resource "resource.container.desktop": unable to connect
container to network resource.network.main, successfully rolled back container:
failed to attach container 9007b363... to network main: failed to attach to
network main: plugin type="tuning" failed (add): failed to Statfs
"/proc/1621/ns/net": no such file or directory
```

This is the **same failure Maximilian Dürr (Airlock) reported on 2026-08-06**,
where it was hit while pinning a `rancher/k3s` image version.

The useful new information: it is **not k3s-specific**. Here it occurred with
`consol/ubuntu-xfce-vnc:latest`, an unrelated Ubuntu/XFCE VNC image, on a plain
`resource "network"` with two containers. That widens the scope of the existing
report from "pinned k3s image" to "container network attach in general".

It also appears intermittent: the earlier run of the same lab got far enough to
fail on the health check instead, meaning the network attach succeeded that time.

---

## Design notes, for anyone reusing this lab

Built with **no `exec` and no file injection**, because:

- `template` and `copy` are Post GA
- `exec` against a Debian-based image currently fails with
  `container exec failed with exit code 2`
  (see `instruqt-cloud-labs-hp/FINDING-exec-exit2.md`)

Everything is configured through container `environment` and image defaults. The
Guacamole VNC connection, which would normally need a config file, is created by
the learner in the Guacamole UI instead.

## Still untested

The lab has not yet reached a running state, so these remain open:

- **Does a `service` tab proxy WebSocket upgrades?** Guacamole streams the
  display over `wss://`. This is the question the lab was built to answer.
- **Does a task check script run in a Debian container?** The task targets the
  Debian-based desktop container, which would show whether the exit-code-2
  failure is specific to the `exec` resource.

---

## Note on an earlier finding of mine (D2, `instruqt lab logs`)

While checking these docs I found that the CLI troubleshooting section does
document a remedy for the `lab logs` failure I reported earlier:

> **Lab logs cannot find the lab or fails without a stream:**
> - Authenticate with `instruqt auth login` or set `INSTRUQT_TOKEN`
> - Use `team/lab` in the form `<team-slug>/<lab-slug>`, or pass `--session`

I did not try re-authenticating, so my own observation may simply have been a
stale token and should not be filed on its own. Hrushikesh's report of
2026-08-18 remains the stronger evidence: he logged out, updated the CLI, logged
back in, and still got `Entity not found`.

Nothing in the docs covers the G2 network-attach failure, and there is no
known-issues page in the docs index.
