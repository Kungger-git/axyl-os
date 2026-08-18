config.load_autoconfig(False)

# Claude color palette
bg      = "#1a1a2e"
bg_alt  = "#16213e"
fg      = "#e6e1d8"
muted   = "#6e7290"
accent  = "#d97757"
red     = "#ff5555"

# Completion
c.colors.completion.fg                          = fg
c.colors.completion.odd.bg                      = bg
c.colors.completion.even.bg                     = bg_alt
c.colors.completion.category.fg                 = accent
c.colors.completion.category.bg                 = bg
c.colors.completion.category.border.top         = bg
c.colors.completion.category.border.bottom      = muted
c.colors.completion.item.selected.fg            = bg
c.colors.completion.item.selected.bg            = accent
c.colors.completion.item.selected.border.top    = accent
c.colors.completion.item.selected.border.bottom = accent
c.colors.completion.item.selected.match.fg      = bg
c.colors.completion.match.fg                    = accent
c.colors.completion.scrollbar.fg                = accent
c.colors.completion.scrollbar.bg               = bg

# Downloads
c.colors.downloads.bar.bg    = bg
c.colors.downloads.start.fg  = bg
c.colors.downloads.start.bg  = accent
c.colors.downloads.stop.fg   = bg
c.colors.downloads.stop.bg   = fg
c.colors.downloads.error.fg  = red

# Hints
c.colors.hints.fg       = bg
c.colors.hints.bg       = accent
c.colors.hints.match.fg = bg_alt

# Keyhint
c.colors.keyhint.fg        = fg
c.colors.keyhint.suffix.fg = accent
c.colors.keyhint.bg        = bg

# Messages
c.colors.messages.error.fg      = fg
c.colors.messages.error.bg      = red
c.colors.messages.error.border  = red
c.colors.messages.warning.fg    = fg
c.colors.messages.warning.bg    = muted
c.colors.messages.warning.border= muted
c.colors.messages.info.fg       = fg
c.colors.messages.info.bg       = bg

# Prompts
c.colors.prompts.fg          = fg
c.colors.prompts.border      = "1px solid " + accent
c.colors.prompts.bg          = bg_alt
c.colors.prompts.selected.bg = accent
c.colors.prompts.selected.fg = bg

# Statusbar
c.colors.statusbar.normal.fg      = fg
c.colors.statusbar.normal.bg      = bg
c.colors.statusbar.insert.fg      = bg
c.colors.statusbar.insert.bg      = accent
c.colors.statusbar.passthrough.fg = bg
c.colors.statusbar.passthrough.bg = muted
c.colors.statusbar.private.fg     = fg
c.colors.statusbar.private.bg     = bg_alt
c.colors.statusbar.command.fg     = fg
c.colors.statusbar.command.bg     = bg
c.colors.statusbar.caret.fg            = bg
c.colors.statusbar.caret.bg            = accent
c.colors.statusbar.caret.selection.fg  = bg
c.colors.statusbar.caret.selection.bg  = accent
c.colors.statusbar.progress.bg         = accent
c.colors.statusbar.url.fg              = fg
c.colors.statusbar.url.error.fg        = red
c.colors.statusbar.url.hover.fg        = accent
c.colors.statusbar.url.success.http.fg = fg
c.colors.statusbar.url.success.https.fg= fg
c.colors.statusbar.url.warn.fg         = muted

# Tabs
c.colors.tabs.bar.bg              = bg
c.colors.tabs.indicator.start     = accent
c.colors.tabs.indicator.stop      = fg
c.colors.tabs.indicator.error     = red
c.colors.tabs.odd.fg              = muted
c.colors.tabs.odd.bg              = bg
c.colors.tabs.even.fg             = muted
c.colors.tabs.even.bg             = bg_alt
c.colors.tabs.selected.odd.fg     = fg
c.colors.tabs.selected.odd.bg     = bg
c.colors.tabs.selected.even.fg    = fg
c.colors.tabs.selected.even.bg    = bg

# Webpage dark mode
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.enabled       = True

# Fonts (JetBrains Mono throughout)
c.fonts.default_family      = "JetBrains Mono"
c.fonts.default_size        = "11pt"
c.fonts.completion.entry    = "11pt JetBrains Mono"
c.fonts.completion.category = "bold 11pt JetBrains Mono"
c.fonts.statusbar           = "11pt JetBrains Mono"
c.fonts.tabs.selected       = "11pt JetBrains Mono"
c.fonts.tabs.unselected     = "11pt JetBrains Mono"
c.fonts.hints               = "bold 11pt JetBrains Mono"

# Behavior
c.auto_save.session          = True
c.content.autoplay           = False
c.scrolling.smooth           = True
c.tabs.show                  = "multiple"
c.tabs.position              = "top"
c.url.default_page           = "about:blank"
c.url.start_pages            = ["about:blank"]
c.zoom.default               = "100%"