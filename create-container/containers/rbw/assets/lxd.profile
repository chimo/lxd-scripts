description: rbw profile
config:
  raw.idmap: uid 1000 0
devices:
  rbw_configs:
    path: /opt/.config/rbw
    source: /home/chimo/.config/rbw
    type: disk
  vim_configs:
    path: /opt/.vim/colors
    source: /home/chimo/devel/dotfiles/.vim/colors
    type: disk
  vimrc_configs:
    path: /opt/.vimrc
    source: /home/chimo/devel/dotfiles/.vimrc
    type: disk
name: rbw

