# Weather forecast from wttr.in (defaults to Tijuana)
weather() {
    curl -s "v2.wttr.in/${*:-Tijuana}?F"
}

# JSON weather data with full details
weatherjson() {
    curl -s "wttr.in/${*:-Tijuana}?format=j1" | jq
}

# Weather with Nerd Fonts (day variant)
weathernerd() {
    curl -s "v2d.wttr.in/${*:-Tijuana}"
}

# Moon phase
moon() {
    curl -s "wttr.in/Moon${1:+@$1}"
}

# Weather map (kitty graphics protocol)
weathermap() {
    local loc="${*:-Tijuana}"
    curl -s "v3.wttr.in/${loc// /+}.png" | kitten icat
}
