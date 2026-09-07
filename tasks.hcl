# NOTE: this task deliberately runs its check script inside a Debian-based
# container. An `exec` resource against a Debian image currently fails with
# "container exec failed with exit code 2" (see instruqt-cloud-labs-hp,
# FINDING-exec-exit2.md). If this check runs fine, the fault is specific to the
# exec resource rather than to script execution in containers generally.
resource "task" "desktop_ready" {
  description     = "Confirm the VNC desktop is up"
  success_message = "The desktop is listening - now connect to it from Guacamole."

  config {
    target  = resource.container.desktop
    timeout = "60s"
  }

  condition "vnc_listening" {
    description = "VNC server is listening on port 5901"

    check {
      script          = "scripts/task/desktop_ready/check.sh"
      failure_message = "Nothing is listening on 5901 in the desktop container yet"
    }
  }
}
