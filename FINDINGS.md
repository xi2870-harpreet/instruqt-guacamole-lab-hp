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

## G2 — a container that never gets a network namespace is reported as a network-plugin failure  (P2, sharpened)

Originally logged as a reproduction of the known `plugin type="tuning"` error.
Controlled probes on 2026-09-08 changed the picture: this is **deterministic and
image-specific**, and the error message points at the wrong resource.

### The failure

```
unable to create resource "resource.container.desktop": unable to connect
container to network resource.network.main, successfully rolled back container:
failed to attach container 9007b363... to network main: failed to attach to
network main: plugin type="tuning" failed (add): failed to Statfs
"/proc/1621/ns/net": no such file or directory
```

### It is not intermittent, and it is not one plugin

Four fresh sessions on the same commit, across two days, all failed at
`resource.container.desktop`. But the CNI plugin named **changes between runs**:

| Run | Date | Container id | Plugin named | Missing path |
|-----|------|--------------|--------------|--------------|
| 1 | 8 Sept | `9007b363…` | `tuning` | `/proc/1621/ns/net` |
| 2 | 8 Sept | `9007b363…` | `tuning` | `/proc/1621/ns/net` (cached page, same session — see G4) |
| 3 | 8 Sept | `e475f081…` | **`loopback`** | `/proc/1614/ns/net` |
| 4 | 10 Sept | `5dfe0f5c…` | **`bridge`** | `/proc/1803/ns/net` |

Three different plugins spanning the whole chain — `loopback` runs first,
`bridge` does the actual attach, `tuning` is near the end — so **no single
plugin is at fault**. Every run shares the one thing that matters:
`/proc/<pid>/ns/net` **does not exist by the time the chain runs**. The
container's network namespace is already gone.

Run 4 states this outright, because `bridge` reports it more fully than the
others do:

```
plugin type="bridge" failed (add): failed to open netns "/proc/1803/ns/net":
failed to Statfs "/proc/1803/ns/net": no such file or directory
```

`failed to open netns` is the actual condition. The plugin name in the message
is incidental — it is whichever plugin happened to reach for the namespace
first.

### Controlled probes: the image is the variable, not the topology

Each probe changed exactly one thing and left the rest of the HCL byte-identical
(two containers, one `resource "network"`, same aliases, same ports, no health
checks, no `exec`).

| Probe | Desktop image | Runs as | Result |
|-------|---------------|---------|--------|
| repro | `consol/ubuntu-xfce-vnc:latest` | UID 1000 | **fails, 4/4** |
| 1 (`ea9a2c0`) | `nginx:alpine` | root | **starts, reaches "Enter lab"** |
| 2 (`77aa4cf`) | `nginxinc/nginx-unprivileged:alpine` | UID 101 | **starts, reaches "Enter lab"** |

This rules out the two obvious explanations:

- **Not the topology.** Two containers attaching to one network is fine.
- **Not the non-root UID.** A non-root image starts without complaint.

So it keys on `consol/ubuntu-xfce-vnc:latest` specifically. The observable is
that its namespace disappears mid-create; the most likely reading is that its
process exits during startup, though I have not been able to confirm that from
inside the platform.

### Platform logs settle it: the same network attaches the other container fine

Pulled from the Logs page at `severity=DEBUG` for the failing session
`15b4qgmajzkk` (full dump: `artifacts/session-15b4qgmajzkk.log`). Both
containers in the *same session*, on the *same* `resource.network.main`:

```
--- desktop: FAILS
11:20:09.956  Creating Docker Container      [desktop.container.sandbox.internal]
11:20:11.587  Attaching container to CNI network      (+1.631s)
11:20:11.685  Container stopped gracefully, removing  (+0.098s)
11:20:11.693  Unable to create container     ref = resource.container.desktop

--- guacamole: SUCCEEDS
11:20:23.719  Creating Docker Container      [guacamole.container.sandbox.internal]
11:20:24.174  Attaching container to CNI network      (+0.455s)
11:20:24.371  DNS record registered  x4
```

The guacamole container attaches to that network and registers DNS **11 seconds
later in the same sandbox build**. So the network, the CNI chain and the bridge
plugin are all healthy — within the very session that reports a network failure.
This is a tighter control than my two image probes, because nothing differs
except which container is being attached.

Two more things the logs show:

- **The platform already attributes it correctly.** The error entry carries
  `ref = "resource.container.desktop"`. The container is named in the data
  model; only the surfaced message frames it as a network problem.
- **`Container stopped gracefully, removing`** is logged 98ms after the attach
  begins. The platform knows the container stopped. Whether it exited on its own
  or this line is the rollback doing the removing, I cannot tell from outside —
  and that ambiguity is the point of the next section.

### The gap that makes this undiagnosable

For the entire failed session, at `DEBUG`, there is:

- no container exit code
- no container stdout or stderr
- no entry saying *why* the desktop container stopped

So an author has nothing to act on. The one field that would resolve it —
the exit status of a container the platform itself logs as having stopped — is
not recorded at any severity.

### Why this is worth fixing regardless of the image

The message names `resource.network.main` and a CNI plugin, so an author debugging
it goes looking at their network block — where there is nothing wrong. Three
things would have saved the whole investigation:

1. Attribute the failure to the container, not the network — the log
   entry's own `ref` field already says `resource.container.desktop`.
2. Say that the container exited or that its namespace was never created,
   instead of surfacing a raw `Statfs` error.
3. Surface the container's exit code and last log lines.

### Relation to the earlier report

Maximilian Dürr (Airlock) reported the same `plugin type="tuning"` /
`Statfs /proc/<pid>/ns/net` error on **2026-08-06** while pinning a
`rancher/k3s` image. The new information is that it is **not k3s-specific** and
**not a network problem** — it reproduces on an unrelated Ubuntu/XFCE VNC image,
and identical HCL with a different image starts cleanly.

### Reproduce

```
git clone https://github.com/xi2870-harpreet/instruqt-guacamole-lab-hp
```

- `main` (`55f724a`) — fails every time, 4/4 across two days
- branch `probe/nginx-desktop` — identical but for the image, starts
- tag `repro-g1-g2` — tree as originally filed

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

## Both open questions are now answered

Probe 1 reached a running session, so the two things this lab was built to test
could finally be measured.

### Service tabs do proxy WebSocket upgrades — works as hoped

The `service` tab is served from `https://service-<id>.labs.instruqt.com/`. The
Apache Guacamole web app loaded through it, and a tunnel handshake against that
origin returned:

```
OPEN_proto_guacamole
```

So the proxy completes the `wss://` upgrade **and** negotiates the `guacamole`
subprotocol. No defect here — worth recording as a positive result, because it
means Guacamole-style streaming UIs are viable behind a `service` tab.

### Task check scripts do run in containers — this narrows the exec-exit-2 bug

The task targets the desktop container. Pressing **Check** ran
`scripts/task/desktop_ready/check.sh` inside it and returned the authored
failure message:

> Nothing is listening on 5901 in the desktop container yet.

A clean exit 1, surfaced correctly. Script execution inside a container is
therefore fine, which narrows `container exec failed with exit code 2`
(`instruqt-cloud-labs-hp/FINDING-exec-exit2.md`) to the **`exec` resource
specifically**, rather than to running scripts in containers generally.

---

## G3 — the loading screen does not track the real session state  (P3, more evidence for D1)

Reproduced twice more while running the probes, in both directions:

- Session had **failed**; the original tab still showed `Starting instance`
  indefinitely. A fresh tab on the same URL showed the failure screen.
- Session had become **ready**; the original tab still showed
  `Creating infrastructure`. A fresh tab showed `Enter lab`.

The state is correct on load and then stops updating, so the only reliable way
to know what a session is doing is to reload. This is the same defect as D1,
which I originally mis-diagnosed as a session hang.

## G4 — a failed session is sticky, and `Exit` does not clear it  (P3, new)

On the failure screen:

- **`Exit` does nothing.** The screen stays, and the session is not cleared.
- **`?reference=<branch>` is ignored.** Requesting a different git ref returned
  the previous failed session — same container id, same sandbox directory, and
  the error still quoting the *old* branch's image.

The only thing that actually cleared it was **Stop** followed by **Play** from
the manage page. Until then, every attempt to retry looked like a fresh failure
but was a cached page from the first one — which is how I initially mistook a
cached error for a second reproduction.

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
