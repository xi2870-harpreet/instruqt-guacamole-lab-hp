# A shell on the desktop container, for inspecting the VNC side.
resource "terminal" "desktop" {
  target = resource.container.desktop
  shell  = "/bin/bash"
}
