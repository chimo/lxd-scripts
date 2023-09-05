config:
  environment.XDG_RUNTIME_DIR: /tmp/1000-runtime-dir
description: GUI LXD profile
devices:
  pipewiresocket:
    bind: container
    connect: unix:/tmp/1000-runtime-dir/pipewire-0
    listen: unix:/tmp/1000-runtime-dir/pipewire-0
    security.gid: "1000"
    security.uid: "1000"
    uid: "1000"
    gid: "1000"
    mode: "0777"
    type: proxy
name: audio
