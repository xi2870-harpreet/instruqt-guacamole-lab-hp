Draft as it stands in the #2-point-0-internal-feedback composer (Instruqt HQ,
T03GN8ZPEGL / C09QRHSCGAV). Plain text on purpose: Slack's WYSIWYG composer only
converts markdown for real typing/pasting, so injected asterisks and backticks
would show up literally. Attachment on the draft: artifacts/session-15b4qgmajzkk.log

---

A container that fails to start is reported as a network error, and the logs show the network is fine

Same "failed to Statfs /proc/<pid>/ns/net" error that Maximilian Dürr (Ergon/Airlock) hit on 6 Aug against a pinned k3s image: https://instruqt.slack.com/archives/C0483S3G1HA/p1786029188338429

It hasn't been raised in this channel, and I don't think it's been diagnosed, so: it is not k3s-specific, it is not a network problem, and the platform logs already contain the proof. His was resource.kubernetes_cluster.k3s, mine is a plain resource.container, so it spans resource types. This is customer-facing, not just an internal probe.

WHAT THE AUTHOR SEES

unable to create resource "resource.container.desktop": unable to connect container to network resource.network.main ... plugin type="bridge" failed (add): failed to open netns "/proc/1803/ns/net": no such file or directory

It names the network, so you go and check your resource "network" block, where there is nothing wrong.

THE NETWORK IS FINE, AND THE SAME SESSION PROVES IT

DEBUG logs for session 15b4qgmajzkk. Both containers, same resource.network.main:

desktop    11:20:11.587  Attaching container to CNI network
desktop    11:20:11.685  Container stopped gracefully, removing
desktop    11:20:11.693  Unable to create container - ref = resource.container.desktop
guacamole  11:20:24.174  Attaching container to CNI network
guacamole  11:20:24.371  DNS record registered x4

The guacamole container attaches to that same network 11 seconds later and registers DNS. So the network, the CNI chain and the bridge plugin are all healthy inside the very session that reports a network failure.

The plugin named also changes between runs - loopback, bridge, tuning across four runs - so it isn't one plugin misbehaving. It's whichever plugin reaches for the namespace first, and the namespace is already gone by then.

THE ERROR RECORD ALREADY KNOWS IT'S THE CONTAINER

The log entry carries ref = "resource.container.desktop". The right attribution is already in the data, and it gets dropped on the way to the author's screen.

WHAT'S MISSING

For the whole failed session, at DEBUG, there is no container exit code, no stdout and no stderr - even though the platform itself logs "Container stopped gracefully". So there's no way for an author to find out why it stopped.

REPRO - 4/4 OVER TWO DAYS

The lab is in our own org, so you can just press Play: https://play.instruqt.com/manage/instruqt-support/labs/ubuntu-guacamole-probe

On branch main it fails every time. Switch the branch to probe/nginx-desktop, which is byte-identical except the desktop image is nginx:alpine, and it starts fine. I also tried nginxinc/nginx-unprivileged:alpine (non-root, UID 101) - starts fine too, so it isn't the non-root UID.

Source, if you'd rather read it than run it: https://github.com/xi2870-harpreet/instruqt-guacamole-lab-hp

ASK

Attribute the failure to the container using the ref already on the record, and log the container's exit code and last output. Either one on its own would have made this a five-minute fix instead of a two-day investigation.

Full DEBUG log dump for the session is attached.
