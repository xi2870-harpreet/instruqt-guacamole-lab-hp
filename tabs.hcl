# The Guacamole web UI - this is the "Ubuntu UI via Guacamole" surface.
resource "service" "guacamole" {
  target = resource.container.guacamole
  port   = 8080
  scheme = "http"
}

# A shell on the desktop container, for inspecting the VNC side.
resource "terminal" "desktop" {
  target = resource.container.desktop
  shell  = "/bin/bash"
}
