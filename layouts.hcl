resource "layout" "default" {
  column {
    width = "67"

    tab "guacamole" {
      title  = "Guacamole"
      target = resource.service.guacamole
      active = true
    }

    tab "desktop_shell" {
      title  = "Desktop shell"
      target = resource.terminal.desktop
    }
  }

  column {
    width = "33"

    instructions {
      active = true
    }
  }
}
