# qai bash hooks - sourced from ~/.bashrc, but only inside qai-shell.
#
# Emits two private OSC markers that qai-shell uses to cut the terminal
# stream into "command + output" records:
#   PS0            -> ESC ] 6973 ; S ; <nonce> BEL            (command starts)
#   PROMPT_COMMAND -> ESC ] 6973 ; E ; <nonce> ; <exit> ; <histnum> ; <base64 cmd> BEL
# Terminals ignore unknown OSC sequences, so nothing becomes visible.

[[ -n $QAI_WRAPPED && -n $QAI_NONCE ]] || return 0
[[ -n $__qai_hooks_loaded ]] && return 0
__qai_hooks_loaded=1

PS0+=$'\e]6973;S;'"$QAI_NONCE"$'\a'

__qai_precmd() {
    local ec=$? line num cmd
    line=$(HISTTIMEFORMAT= builtin history 1)
    if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]+(.*)$ ]]; then
        num=${BASH_REMATCH[1]}
        cmd=${BASH_REMATCH[2]}
    fi
    printf '\e]6973;E;%s;%d;%s;%s\a' "$QAI_NONCE" "$ec" "${num:-0}" \
        "$(printf '%s' "$cmd" | base64 -w0)"
    return $ec
}

# Must run first so it sees the exit status of the user's command.
PROMPT_COMMAND=(__qai_precmd "${PROMPT_COMMAND[@]}")
