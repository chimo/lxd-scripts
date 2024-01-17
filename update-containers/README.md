# lxd-scripts

## Usage

```
Usage: ./update-containers.sh [-a] [-d] [-h] [-P] [-R] [-S] [c1 c2...]

options:
-a      all containers (stopped containers will be started, upgraded and stopped)
-d      perform "dist-upgrade"
-h      show this help message and exit
-P      do not run the post-upgrade script
-R      do not restart the container after upgrade
-S      do not snapshot the container before upgrade
```

