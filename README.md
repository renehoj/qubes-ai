# qai – AI help in the dom0 terminal on Qubes OS

`qai` sends the last command and its output from your dom0 terminal to an AI
running in a separate qube (`ai-llm`), and shows the answer as plain text in
the terminal.

```
$ ls /does-not-exist
ls: cannot access '/does-not-exist': No such file or directory
$ qai
qai: sending 210 bytes to ai-llm ...
── answer from ai-llm ──────────────────────
...
```

## Usage

| Command | What is sent |
|---|---|
| `qai` | last command + output + default question |
| `qai "why does it fail?"` | last command + output + your question |
| `qai -n 3 "question"` | the last 3 commands |
| `qai -q "question"` | only the question (e.g. a follow-up) |
| `qai --new` | starts a new session |
| `qai --dry-run ...` | shows what would be sent – sends nothing |

Put the question in quotes if it contains `?`, `*` or similar characters.

**Session:** All terminals share one conversation with the AI, so you can ask
follow-up questions. `qai --new` starts over. The conversation id is stored in
`~/.local/state/qai/session`, and the conversation itself is kept in `llm`'s
log in `ai-llm`.

**Language:** The AI answers in English by default. If you write your own
question, it answers in the language of the question (`qai "hvorfor fejler
den?"` gives an answer in Danish). The language of the command output is not
used.

**Limits:** Each command's output is limited to 300 lines. If it is still over
6 KB after that, the first and last 3 KB are sent with a note that content is
missing from the middle. Full-screen programs (vim, less, top …) are not sent.
Everything can be changed in `~/.config/qai/config`.

## Security

- **Only dom0 initiates.** `qai` calls `qvm-run --pass-io ai-llm <fixed command>`.
  No qrexec policy is added, so `ai-llm` gets no new access to dom0.
- **The prompt is sent on stdin** and is never put into the command string.
  Output containing `'`, `$(...)` etc. can therefore not be interpreted as
  shell code in `ai-llm`.
- **The answer is never executed.** It is only printed. It is not inserted on
  the command line, and nothing is evaluated.
- **The answer is sanitized before it is shown.** All escape sequences and
  control characters are removed, except newline and tab. The same goes for
  bidi characters. This prevents the answer from changing the window title,
  writing to the clipboard (OSC 52), making the terminal send input back, or
  hiding text. The answer is limited to 64 KB and 120 seconds.
- **The buffer is kept in RAM only.** `qai-shell` keeps the last 20 commands in
  `$XDG_RUNTIME_DIR/qai/` (tmpfs, mode 0700), and the file is deleted when the
  terminal is closed.
- **You decide what is sent.** Nothing is sent until you type `qai`. Use
  `--dry-run` to see exactly what will be sent.

## How it works

- `bin/qai-shell` is a small PTY wrapper in Python, started from `~/.bashrc`.
  It passes everything to the terminal unchanged. On the side, it splits the
  output into "command + output" records using two invisible OSC markers from
  `share/qai/hooks.bash` (`PS0` and `PROMPT_COMMAND`).
- `bin/qai` reads the buffer, builds the prompt, calls `qvm-run` and shows the
  sanitized answer.
- Only Python 3 and bash are used. No packages need to be installed in dom0.

If `qai-shell` cannot start, the terminal falls back to plain bash
(`--selftest` is checked before `exec`). To disable the wrapper in a single
terminal, run `QAI_DISABLE=1 bash`.

## Installation

**1. In `ai-llm`:** `llm` must be able to read the prompt from stdin, and
logging must be enabled (the default) for sessions to work:

```bash
echo "What is the capital of Germany?" | ~/llm/bin/llm -m deepseek-flash -o show_reasoning false
```

**2. Copy the code to dom0** (from the qube holding the repository, here `dev`):

```bash
qvm-run -p dev 'tar -C ~/src -c qubes-ai' | tar -C ~ -x
```

**3. In dom0, as your normal user:**

```bash
cd ~/qubes-ai && ./install.sh
```

Open a new terminal. Edit `~/.config/qai/config` if your qube or model has a
different name.

Uninstall with `./install.sh --uninstall`.

## Known limitations

- Commands that are not saved in history (e.g. with `HISTCONTROL=ignorespace`
  and a leading space) are shown as "unknown command". Their output is still
  sent.
- If you use `llm` directly in `ai-llm` at exactly the moment `qai` starts a
  new session, the wrong conversation may be picked.
