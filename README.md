# YouTube → VLC (Chrome Extension + Native Host)

A Windows toolchain that lets you browse YouTube normally in Chrome, then open the current video in local VLC by clicking a Chrome extension button.

Under the hood it launches VLC with the direct stream URL returned by:

```powershell
vlc "$(yt-dlp --js-runtimes node -f best -g https://www.youtube.com/watch?v=qPKd99Pa2iU)"
```
How it works
Chrome MV3 extension (service worker) reads the current tab URL.

It calls Chrome Native Messaging (chrome.runtime.sendNativeMessage).

A local native host exe receives a JSON message via stdin/stdout framing (4-byte length + UTF-8 JSON).

The host runs yt-dlp --js-runtimes node -f best -g <url> to get a direct stream URL.

The host launches vlc <streamUrl>.

Chrome native host manifest format and framing rules are defined by Chrome’s documentation (required fields, stdio protocol, 1MB message size limit).
See: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging

yt-dlp --js-runtimes is documented in yt-dlp CLI docs/manpage; supported runtimes include deno, node, quickjs, bun.
Example doc reference: https://man.archlinux.org/man/extra/yt-dlp/yt-dlp.1.en

Repository layout
extension/ – Chrome extension (MV3)

native-host/ – C# native messaging host

scripts/ – install/uninstall/test scripts

dist/ – generated host manifest (ignored by git)

Requirements (Windows)
Windows 10/11

Google Chrome

VLC installed

yt-dlp installed

A JS runtime available for yt-dlp extraction (this repo uses --js-runtimes node)

.NET SDK to build the host (recommended: .NET 10 LTS)

Setup (step-by-step)
1) Build & register the native host
Load the extension once to obtain its ID:

Open chrome://extensions

Enable Developer mode

Click Load unpacked and select extension/

Copy the extension ID shown (looks like lnibkekhggopejoohkcfbidmddkjgmdj)

Then register the host (this builds the exe and writes the host manifest to dist/ytvlc-host.json):

cd .\scripts
.\install.ps1 -ExtensionId "<PASTE_EXTENSION_ID_HERE>"
This creates the required registry entry under:

HKCU\Software\Google\Chrome\NativeMessagingHosts\com.ytvlc.player

2) Use it
Open a normal YouTube watch page (URL contains youtube.com/watch?v=...)

Click the extension icon

VLC should open and start streaming

3) Uninstall
cd .\scripts
.\uninstall.ps1
Testing the host without Chrome
cd .\scripts
.\test-host.ps1
Troubleshooting
If Chrome shows: Error when communicating with the native messaging host

Verify the registry entry points to the generated manifest in dist/

Verify the manifest contains name, description, path, type, allowed_origins (no other fields)

Ensure the extension ID in allowed_origins matches the loaded extension’s ID

Check nm-host.log for host-side errors (yt-dlp path, VLC path, runtime issues)

Security notes
Native messaging runs a local executable launched by Chrome. Only extensions listed in allowed_origins can communicate with the host, and wildcards are not allowed.
