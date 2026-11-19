# BSOD Interactive developer intro

`bsod-interactive-startup.ogv` is the complete supplied `startup_video.mp4`,
converted to Godot 4.3's built-in Theora/Vorbis playback format. Original 1920x1080
resolution, frame rate, image framing and stereo soundtrack are retained.

The startup scene plays this once when the application opens, before the game
scene creates its title music. Natural completion and keyboard/controller skip
both enter the normal title menu. F/F11 still toggle fullscreen. Returning to
the title from a match does not replay the developer intro.

Conversion: validated FFmpeg essentials build with
`-c:v libtheora -q:v 8 -g 30 -pix_fmt yuv420p -c:a libvorbis -q:a 6`.
The installed FFmpeg 8.1.1 full build produced corrupt Theora output even though
encoding returned success. Do not use it to regenerate this file. Decode the
entire output with `-xerror -i output.ogv -f null NUL`, then inspect native game
playback before packaging. A playback-start check alone cannot detect corruption.
The source MP4 in the user's branding folder is unmodified. The packaged game
includes the converted video and does not depend on that external folder.
