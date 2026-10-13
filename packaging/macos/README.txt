Sparta for macOS (Apple Silicon)
================================

A native port of God of War: Ghost of Sparta for the PSP, built on
PortableKit. Sparta does not include any game assets or original game files:
no disc image, no copy of the game's executable or data, and no textures,
models, audio or video from the game. You must provide the files from your
own legally obtained copy of the game: the European release (UCES-01401), as
an uncompressed .iso disc image of your own UMD. The first start checks that
copy and accepts only that release.

Sparta is not affiliated with, endorsed by or sponsored by Sony Interactive
Entertainment, Santa Monica Studio or Ready At Dawn.

Needs: a Mac with Apple Silicon (M1 or newer) and macOS @MINIMUM_SYSTEM_VERSION@ or newer.
Tested on macOS 26 only; older versions have not been tried.


Install
-------

Drag Sparta into the Applications folder.


First start
-----------

This build is not notarized by Apple, so the first time you open it macOS
says that it cannot verify the developer and offers only Done or Move to
Trash. Choose Done, then:

  1. Open System Settings > Privacy & Security.
  2. Scroll down to the message about Sparta and click "Open Anyway".
  3. Confirm with your password or Touch ID, then "Open Anyway" once more.

Or, from Terminal:

    xattr -dr com.apple.quarantine /Applications/Sparta.app

The first start then asks for your disc image in Sparta's own window: pick
the .iso file (or drop it onto the window) and let Sparta check it. Later
starts go straight to the game. Esc, or L3+R3 on a gamepad, opens Sparta's
menu with the settings.

Keyboard: W A S D move, Space is X (jump), E is square, the left mouse
button is triangle, the right mouse button or F is circle, Q and Left Shift
are L and R, Enter is START. The menu lists every key and lets you change
them. PlayStation and Xbox gamepads work too.


Where your data lives
---------------------

    ~/Library/Application Support/Sparta/UCES01401/
        settings.ini   where the image is, and the settings from the menu
        ms0/PSP/SAVEDATA/UCES01401PROFILE00/   your profile save

Updating or deleting Sparta.app leaves this folder alone.


Known problems
--------------

See https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/blob/main/docs/MISSING.md


Report a problem: https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/issues
Third-party software and its licenses: Sparta.app/Contents/Resources/licenses/
