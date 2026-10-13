# MacAwake: Keep Your Mac Awake from the Menu Bar

**MacAwake is a free, open-source macOS menu bar app that keeps your Mac awake for as long as you choose: 15 minutes, a few hours, a custom time, or until you stop it.** When the timer ends, your Mac goes back to its normal sleep settings on its own.

It is a simple alternative to the `caffeinate` terminal command and to apps like Amphetamine, KeepingYouAwake, and Caffeine. Use it to keep a MacBook awake during long downloads, builds, presentations, or while Claude Code and other AI coding agents work overnight.

## Features

- **One-click presets:** 15 min, 30 min, 1 hour, 2 hours, 4 hours, or Until I stop.
- **Custom duration:** set hours (0–23) and minutes (5-minute steps), then press Start.
- **Live countdown in the menu bar:** an empty mug means your Mac sleeps normally; a steaming cup shows the time left (for example `1:42`).
- **Keep screen on, or let it turn off:** with the switch off, the display can sleep while the Mac, network, and apps keep running.
- **Ends on its own:** sleep is allowed again the moment the timer runs out, or if the app quits or crashes.
- **No Dock icon, no account, no tracking.** Native Swift and SwiftUI with a Liquid Glass panel, light and dark mode.

## Requirements

- macOS 26 (Tahoe) or later
- To build from source: Xcode 26 or later (Swift 6.2+)

## Install (build from source)

```bash
git clone https://github.com/isiddharthsingh/keep-mac-awake.git
cd keep-mac-awake
./scripts/build-app.sh
open build/MacAwake.app
```

To keep it, move `build/MacAwake.app` into your Applications folder.

## How to use

1. Click the mug icon in the menu bar.
2. Pick a preset, or set hours and minutes under **Custom** and press **Start**.
3. Click **Stop** to end early. Click the icon again, press Esc, or click anywhere else to close the panel.

## FAQ

### How do I keep my Mac awake?

Open MacAwake from the menu bar and pick how long. Your Mac will not go to sleep until the time is up, then normal sleep settings return automatically. Without an app, you can run `caffeinate -di -t 3600` in Terminal to stay awake for one hour.

### How do I keep my Mac awake while Claude Code or other AI agents run?

Choose **Until I stop** (or a long duration), turn **Keep screen on** off so the display can rest, keep the Mac plugged in, and leave the lid open. Agents keep working while the screen is off or locked. macOS decides you are idle from keyboard and mouse activity, so an agent working in a terminal does not keep the Mac awake by itself.

### Will downloads and network connections keep running when the screen is off?

Yes. With **Keep screen on** turned off, only the display sleeps. Wi-Fi stays connected and downloads, uploads, syncing, builds, and calls keep running.

### Does MacAwake keep my Mac awake with the lid closed?

No. Closing a MacBook lid puts it to sleep unless it is plugged into power with an external display (clamshell mode). To stay awake with the lid closed you can run `sudo pmset -a disablesleep 1`, and `sudo pmset -a disablesleep 0` to undo it. Use it with care: a closed MacBook in a bag can overheat.

### Does it work on battery?

Yes. Unlike `caffeinate -s`, which only works on AC power, MacAwake keeps the Mac awake on battery too. macOS will still force sleep when the battery is nearly empty.

### What is the difference between MacAwake and the caffeinate command?

They use the same macOS mechanism: IOKit power assertions. **Keep screen on** matches `caffeinate -di`, and with it off MacAwake matches `caffeinate -i`. MacAwake adds a menu bar countdown, presets, and a timer you can change without opening Terminal.

### Is MacAwake an alternative to Amphetamine, KeepingYouAwake, or Caffeine?

Yes, for the most common case: keeping your Mac awake for a set time from the menu bar. Amphetamine offers more triggers (apps, downloads, schedules) and lid-closed sessions; MacAwake stays small, native, and open source.

### What happens if MacAwake quits or crashes?

macOS releases its sleep assertions automatically, so your Mac returns to normal sleep. It can never get stuck awake.

### How can I check that it is working?

Run this in Terminal while a session is active:

```bash
pmset -g assertions | grep MacAwake
```

You will see `MacAwake is keeping the Mac awake` for each active assertion.

## How it works

MacAwake creates a `PreventUserIdleSystemSleep` power assertion while a session runs, plus `PreventUserIdleDisplaySleep` when **Keep screen on** is enabled. The countdown follows the wall clock, so it stays correct if the Mac sleeps anyway (for example when the lid is closed) and ends the session as soon as the time is up.

## Development

```bash
swift test               # run the test suite
./scripts/build-app.sh   # build build/MacAwake.app
```

- `src/AwakeCore`: session logic, duration formatting, and the IOKit power assertion wrapper
- `src/Awake`: the menu bar icon and the glass dropdown panel
- `tests/AwakeCoreTests`: tests, including one that checks the real assertions macOS reports

## License

MacAwake is released under the [MIT License](LICENSE).
