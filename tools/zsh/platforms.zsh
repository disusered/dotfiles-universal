export _linux=_wsl=_macos=_cywin=_mingw=_impossible=_freebsd="false"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  _linux="true"

  if [[ $(uname -a) == *"WSL"* ]]; then
    _wsl="true"
  fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
  _macos="true"

elif [[ "$OSTYPE" == "cygwin" ]]; then
  # POSIX compatibility layer and Linux environment emulation for Windows
  _cywin="true"

elif [[ "$OSTYPE" == "msys" ]]; then
  # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
  _mingw="true"

elif [[ "$OSTYPE" == "win32" ]]; then
  _impossible="true"

elif [[ "$OSTYPE" == "freebsd"* ]]; then
  _freebsd="true"
fi
