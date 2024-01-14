#!/bin/sh -e

# Install qutebrowser
# We also install vim and a terminal so things like ":edit-url" work
# We also need mesa-dri-gallium so the GUI works
apk add qutebrowser foot vim mesa-dri-gallium

