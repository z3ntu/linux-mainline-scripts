#!/bin/bash

if [ ! -f "$1" ]; then
    echo "Usage: $0 file.md"
    exit 1
fi

if [ -n "$WAYLAND_DISPLAY" ]; then
    COPY_PROG="wl-copy"
else
    COPY_PROG="xsel --clipboard"
fi

pandoc "$1" --from gfm --to mediawiki |
    sed 's|{DSP}|<ref name="DSP"/>|' |
    sed 's|{CCI}|<ref name="CCI"/>|' |
    $COPY_PROG
