resource "layout" "default" {
  column {
    width = "67"

    tab "desktop_shell" {
      title  = "Desktop shell"
      target = resource.terminal.desktop
      active = true
    }
  }

  column {
    width = "33"

    instructions {
      active = true
    }
  }
}
