# Your init script
#
# Atom will evaluate this file each time a new window is opened. It is run
# after packages are loaded/activated and after the previous editor state
# has been restored.
#
# An example hack to log to the console when each text editor is saved.
#
# atom.workspace.observeTextEditors (editor) ->
#   editor.onDidSave ->
#     console.log "Saved! #{editor.getPath()}"

atom.commands.add 'atom-workspace', 'dot-atom:demo', ->
  atom.notifications.addInfo "Hello from dot-atom:demo"

# Toggle between light and dark theme.
atom.commands.add 'atom-workspace', 'dot-atom:toggle-theme', ->
  activeThemes = atom.themes.getActiveThemeNames()

  if activeThemes[0].indexOf("light") > 0
    atom.config.set("core.themes", ["one-dark-ui", "one-dark-syntax"])
  else
    atom.config.set("core.themes", ["one-light-ui", "one-light-syntax"])
