---
title: tmux Cheatsheet
tags:
  - cheatsheet
  - tmux
  - terminal
  - tools
created: 2026-06-26
aliases:
  - tmux commands
  - tmux reference
  - terminal multiplexer
---

# tmux Cheatsheet

> [!note] Prefix key
> Every tmux shortcut starts with the **prefix key**: `Ctrl+b` (default). Press it, release it, then press the command key. Example: `Ctrl+b d` = detach.

> [!tip] Relationship to k9s / kubectl
> tmux is ideal for keeping [[kubectl CLI — Intro to Advanced]] sessions, log tails, and local dev servers alive across disconnects. Split panes to run GRM + logs + a shell side-by-side.

---

## 1. Session Management

Sessions are the top-level container — they persist when you detach.

### CLI commands (outside tmux)

```bash
tmux                          # start new session
tmux new -s <name>            # start named session
tmux ls                       # list sessions
tmux attach                   # attach to last session
tmux attach -t <name>         # attach to named session
tmux kill-session -t <name>   # kill named session
tmux kill-server              # kill all sessions
```

### Inside tmux (prefix + key)

| Shortcut | Action |
|---|---|
| `Ctrl+b d` | Detach from session |
| `Ctrl+b $` | Rename current session |
| `Ctrl+b s` | List / switch sessions (interactive) |
| `Ctrl+b (` | Switch to previous session |
| `Ctrl+b )` | Switch to next session |
| `Ctrl+b L` | Switch to last (most recent) session |

---

## 2. Window Management

Windows are tabs within a session.

| Shortcut | Action |
|---|---|
| `Ctrl+b c` | Create new window |
| `Ctrl+b ,` | Rename current window |
| `Ctrl+b &` | Kill current window (confirm) |
| `Ctrl+b w` | List / switch windows (interactive) |
| `Ctrl+b n` | Next window |
| `Ctrl+b p` | Previous window |
| `Ctrl+b 0–9` | Switch to window by number |
| `Ctrl+b '` | Prompt for window number to switch to |
| `Ctrl+b .` | Move window to a different number |
| `Ctrl+b f` | Find window by name |

---

## 3. Pane Management

Panes split a window into multiple terminals.

### Splitting

| Shortcut | Action |
|---|---|
| `Ctrl+b %` | Split pane **vertically** (side by side) |
| `Ctrl+b "` | Split pane **horizontally** (top / bottom) |

### Navigation

| Shortcut | Action |
|---|---|
| `Ctrl+b ←↑→↓` | Move to pane in direction |
| `Ctrl+b o` | Cycle to next pane |
| `Ctrl+b ;` | Toggle between last two panes |
| `Ctrl+b q` | Show pane numbers (press number to jump) |

### Resizing

| Shortcut | Action |
|---|---|
| `Ctrl+b Ctrl+←↑→↓` | Resize pane (hold Ctrl, tap arrow) |
| `Ctrl+b Alt+←↑→↓` | Resize pane in larger steps |
| `Ctrl+b z` | Toggle pane **zoom** (full-screen) |

### Layout presets

| Shortcut | Layout |
|---|---|
| `Ctrl+b Alt+1` | Even horizontal |
| `Ctrl+b Alt+2` | Even vertical |
| `Ctrl+b Alt+3` | Main horizontal |
| `Ctrl+b Alt+4` | Main vertical |
| `Ctrl+b Alt+5` | Tiled |
| `Ctrl+b Space` | Cycle through layouts |

### Pane operations

| Shortcut | Action |
|---|---|
| `Ctrl+b x` | Kill current pane (confirm) |
| `Ctrl+b !` | Break pane into its own window |
| `Ctrl+b {` | Swap pane with previous |
| `Ctrl+b }` | Swap pane with next |

---

## 4. Copy Mode

Copy mode lets you scroll back and copy text without leaving tmux.

> [!info] Default key bindings are vi-style. Set `set-window-option -g mode-keys vi` in `~/.tmux.conf` to enforce it.

| Shortcut | Action |
|---|---|
| `Ctrl+b [` | Enter copy mode |
| `q` or `Esc` | Exit copy mode |
| `↑↓` / `Ctrl+u` / `Ctrl+d` | Scroll up/down |
| `/` | Search forward |
| `?` | Search backward |
| `n` / `N` | Next / previous search match |
| `Space` | Start selection (vi mode) |
| `Enter` | Copy selection and exit |
| `Ctrl+b ]` | Paste copied text |

### With vi keys enabled (`mode-keys vi`)

```
v      — begin selection
y      — yank (copy) selection
V      — select entire line
Ctrl+v — block selection
```

---

## 5. Miscellaneous

| Shortcut | Action |
|---|---|
| `Ctrl+b ?` | Show all key bindings |
| `Ctrl+b :` | Open tmux command prompt |
| `Ctrl+b t` | Show clock in current pane |
| `Ctrl+b i` | Show window info |
| `Ctrl+b ~` | Show previous messages |
| `Ctrl+b r` | (custom) Reload config — see below |

### Command prompt examples

```
:new-window -n logs        # new window named "logs"
:split-window -h           # split horizontally
:setw synchronize-panes on # type in all panes simultaneously
:setw synchronize-panes off
:source-file ~/.tmux.conf  # reload config
```

---

## 6. Configuration (`~/.tmux.conf`)

> [!warning] Changes to `~/.tmux.conf` don't apply to running sessions until you reload.
> Run `tmux source-file ~/.tmux.conf` or add a reload binding (see below).

### Recommended starter config

```bash
# Remap prefix to Ctrl+a (screen-style)
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Split with | and - (more intuitive)
bind | split-window -h
bind - split-window -v

# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Mouse support
set -g mouse on

# Vi copy mode
set-window-option -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Start windows/panes from 1 (not 0)
set -g base-index 1
setw -g pane-base-index 1

# Increase scrollback buffer
set -g history-limit 50000

# True colour support
set -g default-terminal "tmux-256color"
set-option -ga terminal-overrides ",xterm-256color:Tc"
```

---

## 7. Common Workflows

### Multi-pane dev setup

```bash
tmux new -s dev
# Pane 1: running service
Ctrl+b "       # split top/bottom
# Pane 2: logs
Ctrl+b "
# Pane 3: shell
Ctrl+b z       # zoom any pane to full-screen when needed
```

### Keep a session alive across SSH disconnects

```bash
# On remote:
tmux new -s work
# ... do stuff, then disconnect (Ctrl+b d or SSH drops)

# Reconnect later:
ssh <host>
tmux attach -t work
```

### Run the same command in all panes simultaneously

```
Ctrl+b :  setw synchronize-panes on
```

> [!warning] Remember to turn sync off: `setw synchronize-panes off`

### Detach someone else who is attached

```bash
tmux attach -t <session> -d    # -d detaches all other clients
```

---

## See also

- [[kubectl CLI — Intro to Advanced]]
- [[kubectl Cheatsheet — Telephony Services on Kubernetes]]
- [[gong-java-cheat-sheet]]
