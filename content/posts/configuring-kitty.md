---
title: "Configuring Kitty"
date: 2020-06-07T16:30:02+02:00
draft: false
keywords: Kitty, tty, terminal, config, iTerm
description: Configuring Kitty with some iTerm2 shortcuts
icon: 🐱
---

I love the [Kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator for its speed! Ever since I started doing more work in the terminal, it became painfully clear to me that the standard terminal.app on Mac and even [iTerm2](https://www.iterm2.com/) (although an amazing product!) were not cutting it anymore for me in terms of speed. 

However, since I started using Kitty, I noticed how used I was to some of the shortcuts that "just work" when using terminal.app and iTerm2. In this short post we'll go over some configuration settings to make Kitty behave more like iTerm2 and have the best of both worlds!

## What we'll be configuring

* `cmd` + arrow keys for jumping to beginning or end of the line.
* `alt` + arrow keys for jumping between words.
* Only vertical splits by default
* Switching between Tabs (Kitty calls them Windows)
by using `cmd` + 1-9 numeric keys
* Some visual tweaks

## Relevant config

```text
# don't draw extra borders, but fade the inactive text a bit
active_border_color none
inactive_text_alpha 0.6

# tabbar should be at the top
tab_bar_edge top
tab_bar_style separator
tab_separator " ┇"

# open new split (window) with cmd+d retaining the cwd
map cmd+d new_window_with_cwd

# open new tab with cmd+t
map cmd+t new_tab_with_cwd

# new split with default cwd
map cmd+shift+d new_window

# switch between next and previous splits
map cmd+]        next_window
map cmd+[        previous_window

# clear the terminal screen
map cmd+k combine : clear_terminal scrollback active : send_text normal,application \x0c

# jump to beginning and end of word
map alt+left send_text all \x1b\x62
map alt+right send_text all \x1b\x66

# jump to beginning and end of line
map cmd+left send_text all \x01
map cmd+right send_text all \x05

# Map cmd + <num> to corresponding tabs
map cmd+1 goto_tab 1
map cmd+2 goto_tab 2
map cmd+3 goto_tab 3
map cmd+4 goto_tab 4
map cmd+5 goto_tab 5
map cmd+6 goto_tab 6
map cmd+7 goto_tab 7
map cmd+8 goto_tab 8
map cmd+9 goto_tab 9
```

See the [full config](https://github.com/Tmw/dotfiles/blob/master/.config/kitty/kitty.conf) in my Dotfiles and see all available configuration options [here](https://sw.kovidgoyal.net/kitty/conf.html).

Cheers! 🐈
