#!/bin/sh -eu

name="${1}"

lxc exec "${name}" -- sh -c "mkdir -p \
    /opt/.config/rbw \
    /opt/.vimrc \
    /opt/.vim/colors \
    /root/.config"

lxc exec "${name}" -- sh -c "\
    ln -s /opt/.vimrc/.vimrc /root/.vimrc && \
    ln -s /opt/.vim /root/.vim && \
    ln -s /opt/.config/rbw /root/.config/rbw"

lxc profile add "${name}" "${name}"

