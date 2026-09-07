resource "page" "desktop" {
  title = "Ubuntu desktop via Guacamole"
  file  = "instructions/01-desktop.md"

  activities = {
    desktop_ready = resource.task.desktop_ready
  }
}

resource "lab" "main" {
  title       = "Ubuntu desktop via Guacamole"
  description = "An XFCE desktop served over VNC and rendered in the browser by Apache Guacamole, built with containers only."

  settings {
    timelimit {
      duration   = "1h"
      show_timer = true
    }
  }

  layout = resource.layout.default

  content {
    chapter "desktop" {
      title = "Desktop"

      page "desktop" {
        reference = resource.page.desktop
      }
    }
  }
}
