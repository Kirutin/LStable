# Warehouse 13 Lesbian Cyberpunk prompt
if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
    eval "$(starship init bash)"
fi
