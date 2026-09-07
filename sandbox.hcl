resource "network" "main" {
  subnet = "10.0.250.0/24"
}

# ---------------------------------------------------------------------------
# The Ubuntu desktop. XFCE on a VNC server, reachable on the sandbox network
# as `desktop:5901`. No exec and no file injection: everything it needs comes
# from the image defaults plus environment variables.
# ---------------------------------------------------------------------------
resource "container" "desktop" {
  image {
    name = "consol/ubuntu-xfce-vnc:latest"
  }

  environment = {
    VNC_PW         = "instruqt"
    VNC_RESOLUTION = "1280x800"
    VNC_COL_DEPTH  = "24"
  }

  port {
    local = 5901
  }

  resources {
    cpu    = 2000
    memory = 2048
  }

  network {
    id      = resource.network.main.meta.id
    aliases = ["desktop"]
  }

  health_check {
    timeout = "120s"

    tcp {
      address = "localhost:5901"
    }
  }
}

# ---------------------------------------------------------------------------
# Apache Guacamole, all-in-one (guacd + web app + sqlite in one image), so no
# separate database and no configuration files to inject.
# ---------------------------------------------------------------------------
resource "container" "guacamole" {
  image {
    name = "flcontainers/guacamole:latest"
  }

  environment = {
    EXTENSIONS = ""
  }

  port {
    local = 8080
  }

  resources {
    cpu    = 1000
    memory = 1024
  }

  network {
    id      = resource.network.main.meta.id
    aliases = ["guacamole"]
  }

  health_check {
    timeout = "180s"

    tcp {
      address = "localhost:8080"
    }
  }
}
