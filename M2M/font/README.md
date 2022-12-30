Workflow: How to generate a font
================================

1. Find a `psf` font (for example by googling for `free psf fonts`).

2. Untar `nafe-0.1.tar.gz` and `psftools-1.1.1.tar.gz` into two subdirectories
   of this folder.

3. Compile both tools by using `make` for nafe and by using the `./configure`
   and `make` sequence for psftools. If you get an error while compiling
   `nafe` you might need to add `#include <stdlib.h>` to both `*.c` files.

4. Optional step: Use `psf2txt` from `nafe` to create a human-readable
   text version of your font. You can edit the font with a text editor and
   then convert it back to a `psf` font using `nafe`'s `txt2psf`.

5. Use `psf2inc` from `psftools` to generate a C include file.

6. Modify the C include file similar to `Anikki-16x16-m2m.h` by removing
   unneeded lines and by adding `FONT_SIZE` and the `FONT` array: Basically
   you need to remove a couple of lines at the beginning of the output of
   `psf2inc` and copy/paste the beginning and end of `Anikki-16x16-m2m.h` to
   your own `*.h` file.

6. Copy, rename and modify `Anikki-16x16-m2m.c` to fit the needs of your font.

7. Compile and run your C file to generate a `.rom` file.

Potential for a future optimized workflow
-----------------------------------------

It is possible to settle on a `psftools`-only workflow, i.e. to work without
`nafe`: `psftools` are offering `psf2txt` and `txt2psf`, too. Just like
`nafe`. But `txt2psf` in the available versions as of writing this (1.0.14
and 1.1.1) is crashing on some operating systems such as macOS because of
an undefined use of C's `strcpy` command in line 180 of the file `txt2psf.c`.
If we replace in this very line

```C
strcpy(linebuf, c);
```

whith this

```C
memmove(linebuf, c, 1 + strlen(c));
```

then it works like a charme. At a later stage we might either decide to
patch the source code by ourselves and settle on a `nafe`-only workflow
or we wait for an
[official new release](https://www.seasip.info/Unix/PSF/).

We should then also write a wrapper include file that just includes the
output of `psftools` without the need of manual editing. And we might want
to add a Makefile or a Bash file or something like that to automate the
process a bit more.
