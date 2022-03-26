
# Snippet that can be expanded into a documentation for the Shell's file- and directory browser

Features:

* Long filename support
* Alphabetically sorted file- and directory listings
* Navigate up/down using the up/down cursor keys
* Page up and page down using the left/right cursor keys
* Enter mounts a disk image
* RUN/STOP exits the file browser without mounting
* Remembers the browsing history, i.e. even while you climb directory trees,
  when you mount the next image, the file selection cursor stands where you
  left off. This is very convenient for mounting multiple subsequent
  disks of a demo in a row.
* Support for both SD card slots: The back slot has precedence over the bottom
  slot: As soon as you insert a card to the back slot, this card is being
  used. SD card changes are detected in real-time; also while being in the
  file browser.

Still missing (in documentation as well as in the framework):

- Filter files (needs subdir flag, framework needs to offer convenient
  file extension checker)
- F1/F3 for manual SD card selection
