# Visibility

The dock's only reason to exist is an empty desktop.

| Event | Dock |
|---|---|
| focused tag has 0 windows for `dockShowDelay` (400 ms) | shows: slide up + fade over `dockSlide` (180 ms) |
| a window maps on the focused tag | hides at once, no animation |
| switch to a tag with windows | hides at once |
| switch to an empty tag | shows after `dockShowDelay` |
| reduceMotion | shows and hides without motion |

No hover-to-reveal, no hot corner, no timer: the window count decides.
