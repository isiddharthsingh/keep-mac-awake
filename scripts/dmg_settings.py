# dmgbuild settings for MacAwake.dmg, used by scripts/make-release.sh:
#   dmgbuild -s scripts/dmg_settings.py -D app=build/MacAwake.app -D background=assets/dmg-background.png MacAwake build/MacAwake.dmg
# dmgbuild writes the Finder layout (.DS_Store) directly, so no Finder scripting or permissions are needed.
import os.path

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
app_name = os.path.basename(app)

files = [app]
symlinks = {"Applications": "/Applications"}
# No hide_extensions: it writes Finder info onto the signed app, which breaks its code signature.
# Finder already hides ".app" unless the user shows all filename extensions.
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")  # volume icon

# The @2x sibling of the background is combined into a Retina TIFF automatically.
background = defines["background"]  # noqa: F821
format = "UDZO"

# Matches assets/dmg-background.svg: a 660x400 content area, icons centered at y=190.
# Finder's window bounds include the title bar (32 pt on macOS 26 and later), so the window is 432 tall.
window_rect = ((200, 120), (660, 432))
default_view = "icon-view"
icon_size = 128
text_size = 12
icon_locations = {app_name: (165, 190), "Applications": (495, 190)}
