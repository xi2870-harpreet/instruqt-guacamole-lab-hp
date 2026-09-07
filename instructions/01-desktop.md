# An Ubuntu desktop in the browser, through Guacamole

This lab runs two containers on one sandbox network:

| Container | What it is | Reachable as |
|---|---|---|
| `desktop` | Ubuntu with XFCE, served over VNC | `desktop:5901` |
| `guacamole` | Apache Guacamole (all-in-one) | the **Guacamole** tab |

Guacamole is a clientless remote desktop gateway: it speaks VNC to the desktop
container and renders it as HTML5 in your browser, so nothing is installed
locally.

<instruqt-task id="desktop_ready"></instruqt-task>

## Sign in to Guacamole

Open the **Guacamole** tab and sign in:

| | |
|---|---|
| Username | `guacadmin` |
| Password | `guacadmin` |

## Add the desktop as a connection

Guacamole ships with no connections, so create one:

1. Top right, open the **guacadmin** menu and choose **Settings**
2. Go to the **Connections** tab and click **New Connection**
3. Fill in:
   - **Name** — `Ubuntu desktop`
   - **Protocol** — `VNC`
4. Under **Parameters → Network**:
   - **Hostname** — `desktop`
   - **Port** — `5901`
5. Under **Parameters → Authentication**:
   - **Password** — `instruqt`
6. **Save**

Then click **Home** and open **Ubuntu desktop**. The XFCE session appears in the
tab.

## If the desktop looks black

The VNC server can take a few seconds after the container is healthy. Use the
**Desktop shell** tab to check it:

```
ss -ltn | grep 5901
ls /headless/.vnc/
```

> The desktop's VNC password is `instruqt`, set through the `VNC_PW` environment
> variable in `sandbox.hcl`. The container runs as UID 1000 with `HOME=/headless`,
> so the VNC state lives under `/headless/.vnc/`, not `/root`.
