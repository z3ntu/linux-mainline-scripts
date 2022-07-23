#!/bin/bash

if [ ! -f "$1" ]; then
    echo "Usage: $0 file.md"
    exit 1
fi

pandoc "$1" --from gfm --to mediawiki |
    sed 's/{|/{| class="wikitable"/' |
    sed 's|{DSP}|<ref name="DSP"/>|' |
    sed 's|{CCI}|<ref name="CCI"/>|' |
    xsel --clipboard
