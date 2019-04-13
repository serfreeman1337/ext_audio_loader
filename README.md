### Description
VLC extension for autoload external audio track and subtitles shared with video file.
Audio track and subtitles should have same name as video. Dir example:
* show_01.mkv
* Your Dub\show_01.mka
* Subs\Signs\show_01.ass

Allowed extensions can be changed in source code.

### Usage
* Enable "Autoload external audio track and subtitles" in "View" menu.
* Play video file.

### Known bugs
* Messed up playlist order (you can still navigate using next/prev buttons as before).
* Auto select only works with english and russian interface language.

### Installation:
Copy the .lua file into appropriate lua extensions folder (Create directory if it does not exist!):
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions
* Windows (current user): %APPDATA%\VLC\lua\extensions
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/