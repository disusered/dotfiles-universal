hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("pgrep -x app2unit -- slurp || sh -c 'app2unit -- hyprshot -m region --raw - | app2unit -- swappy -f -'"))
