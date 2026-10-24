#!/bin/bash
# Install qai for the current dom0 user (not root).
#   ./install.sh             install or update
#   ./install.sh --uninstall remove again (config and session are kept)
set -euo pipefail

src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin=~/.local/bin
share=~/.local/share/qai
conf=~/.config/qai
bashrc=~/.bashrc
begin='# >>> qai >>>'
end='# <<< qai <<<'

if [[ $EUID -eq 0 ]]; then
    echo "Run install.sh as your normal user, not root." >&2
    exit 1
fi

remove_block() {
    [[ -f $bashrc ]] || return 0
    sed -i "/^$begin\$/,/^$end\$/d" "$bashrc"
}

if [[ ${1:-} == --uninstall ]]; then
    remove_block
    rm -f "$bin/qai" "$bin/qai-shell"
    rm -rf "$share"
    echo "qai has been removed. Config in $conf and session in ~/.local/state/qai were kept."
    exit 0
fi

install -d -m 755 "$bin" "$share"
install -m 755 "$src/bin/qai" "$src/bin/qai-shell" "$bin/"
install -m 644 "$src/share/qai/hooks.bash" "$share/"

install -d -m 700 "$conf"
if [[ ! -e $conf/config ]]; then
    install -m 600 "$src/config.example" "$conf/config"
    echo "Created $conf/config"
else
    # Older versions wrote Danish prompts into the config; comment them out
    # (only if unchanged) so the built-in English/same-language default applies.
    old_prompt='SYSTEM_PROMPT=Du hjælper en bruger, der arbejder i en bash-terminal i dom0 på Qubes OS 4.3. Svar kort og præcist på dansk i ren tekst uden markdown. Hvis du foreslår kommandoer, så forklar hvad de gør.'
    old_question='DEFAULT_QUESTION=Hvad er problemet, og hvordan løser jeg det?'
    if grep -qxF -e "$old_prompt" -e "$old_question" "$conf/config"; then
        awk -v a="$old_prompt" -v b="$old_question" \
            '($0 == a || $0 == b) { print "#" $0; next } { print }' \
            "$conf/config" > "$conf/config.new"
        chmod 600 "$conf/config.new"
        mv "$conf/config.new" "$conf/config"
        echo "Commented out the old Danish prompts in $conf/config - run 'qai --new'"
    fi
fi

remove_block
cat >> "$bashrc" <<'EOF'
# >>> qai >>>
# Run interactive shells inside qai-shell so `qai` can see recent output.
# Disable for one terminal with: QAI_DISABLE=1 bash
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH=$HOME/.local/bin:$PATH ;; esac
if [[ $- == *i* && -z $QAI_WRAPPED && -z $QAI_DISABLE && -x ~/.local/bin/qai-shell ]] &&
    ~/.local/bin/qai-shell --selftest 2>/dev/null; then
    exec ~/.local/bin/qai-shell
fi
[[ -n $QAI_WRAPPED && -r ~/.local/share/qai/hooks.bash ]] && source ~/.local/share/qai/hooks.bash
# <<< qai <<<
EOF

echo "qai is installed. Open a new terminal, run e.g. ls /does-not-exist, then: qai"
