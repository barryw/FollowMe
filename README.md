
              ______    _ _                 __  __
             |  ____|  | | |               |  \/  |
             | |__ ___ | | | _____      __ | \  / | ___
             |  __/ _ \| | |/ _ \ \ /\ / / | |\/| |/ _ \
             | | | (_) | | | (_) \ V  V /  | |  | |  __/
             |_|  \___/|_|_|\___/ \_/\_/   |_|  |_|\___|


### Introduction

This is a C64 rendition of the 70s game Simon. The object is to mimick the notes that he computer plays which gets harder and harder the more notes that are played. It was inspired by a tutorial I found on Youtube here: https://www.youtube.com/watch?v=A7vYSsLS00Y

### Building

Everything is driven from a `Makefile`. As long as you have VICE in your path and `x64sc` is available, you can run `make run` to start Follow Me in VICE.

### Playing

Start by selecting a level from 1 to 5 where 1 is the fastest and 5 is the slowest. Repeat the notes that the computer plays. If you get it wrong, a buzzer will sound and the game will end.

