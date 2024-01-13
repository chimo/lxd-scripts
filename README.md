# lxd-scripts

## Usage

```
Usage: ./update-containers.sh [-a] [-h] [-P] [-R] [-S]

options:
-a      all containers (stopped containers will be started, upgraded and stopped)
-h      show this help message and exit
-P      do not run the post-upgrade script
-R      do not restart the container after upgrade
-S      do not snapshot the container before upgrade
```

## In-progress

* Support "dist-upgrade" (via "-d" flag. This is under development in the
  support-dist-upgrade branch)

## TODOs

* Support lxd projects (via "-p" flag). The default behaviour should list
  projects and iterate through all of them
* README: Explain what this is, "documentation"
* Automated tests

