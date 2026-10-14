Sparta for Windows (64-bit)
===========================

A native port of God of War: Ghost of Sparta for the PSP, built on
PortableKit. Sparta does not include any game assets or original game files:
no disc image, no copy of the game's executable or data, and no textures,
models, audio or video from the game. You must provide the files from your
own legally obtained copy of the game: the European release (UCES-01401), as
an uncompressed .iso disc image of your own UMD. The first start checks that
copy and accepts only that release.

Sparta is not affiliated with, endorsed by or sponsored by Sony Interactive
Entertainment, Santa Monica Studio or Ready At Dawn.

Needs: Windows 10 or 11, 64-bit, and a graphics card with Vulkan (any recent
AMD, NVIDIA or Intel card with up-to-date drivers). Tested on Windows 11 with
an AMD Radeon RX 7600.


Install
-------

Unzip the Sparta folder anywhere (not inside Program Files) and start
Sparta.exe. Nothing is installed; to remove Sparta, delete the folder.

This build is not signed, so Windows SmartScreen may say that it protected
your PC. Click "More info", then "Run anyway".


First start
-----------

The first start asks for your disc image in Sparta's own window: pick the
.iso file (or drop it onto the window) and let Sparta check it. Later starts
go straight to the game. Esc, or L3+R3 on a gamepad, opens Sparta's menu
with the settings.

Keyboard: W A S D move, Space is X (jump), E is square, the left mouse
button is triangle, the right mouse button or F is circle, Q and Left Shift
are L and R, Enter is START. The menu lists every key and lets you change
them. PlayStation and Xbox gamepads work too.


Where your data lives
---------------------

    %APPDATA%\Sparta\UCES01401\
        settings.ini   where the image is, and the settings from the menu
        ms0\PSP\SAVEDATA\UCES01401PROFILE00\   your profile save

Updating or deleting the Sparta folder leaves this folder alone.


Known problems
--------------

See https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/blob/main/docs/MISSING.md


Report a problem: https://github.com/arnaldolima1/gow-ghost-of-sparta-pc/issues
Third-party software and its licenses: the licenses folder.
