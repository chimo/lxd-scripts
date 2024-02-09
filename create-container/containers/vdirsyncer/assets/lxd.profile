description: vdirsyncer profile
config:
  raw.idmap: uid 1000 0
devices:
  calendars:
    path: /root/.calendars/
    source: /home/chimo/.calendars
    type: disk
  configs:
    path: /root/.vdirsyncer/
    source: /home/chimo/.vdirsyncer
    type: disk
name: vdirsyncer

