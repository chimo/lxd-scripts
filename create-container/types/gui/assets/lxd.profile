config:
  environment.QT_QPA_PLATFORM: wayland
  environment.WAYLAND_DISPLAY: wayland-1
  environment.XDG_RUNTIME_DIR: /tmp/1000-runtime-dir
description: GUI LXD profile
devices:
  mygpu:
    type: gpu
  waylandsocket:
    bind: container
    connect: unix:/tmp/1000-runtime-dir/wayland-1
    gid: "1000"
    listen: unix:/mnt/wayland1/wayland-1
    mode: "0777"
    security.gid: "1000"
    security.uid: "1000"
    type: proxy
    uid: "1000"
name: gui

