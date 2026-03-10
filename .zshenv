# Skip ubuntus global compinit
# skip_global_compinit=1

# Ensure that XDG Base Directory Specification is followed.
# Documentation: https://specifications.freedesktop.org/basedir-spec/basedir-spec-0.6.html
export XDG_DATA_HOME=${XDG_DATA_HOME:=${HOME}/.local/share}
export XDG_DATA_DIRS=$XDG_DATA_HOME:${XDG_DATA_DIRS:=/usr/local/share:/usr/share}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=${HOME}/.config}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:=/etc/xdg}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:=${HOME}/.cache}

# set shell character sets
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
