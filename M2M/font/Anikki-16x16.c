/* Anikki-16x16 font, taken from https://github.com/k80w/consolefonts

   Generate a 16-bit .rom file that can be imported by VHDL

   Hint: The usage of "unsigned" "everywhere" is very important.
   Otherwise the conversion result will be wrong.

   done by sy2002 in January 2021
*/

#include <stdio.h>
#include "Anikki-16x16.h"

int main()
{
    FILE*  f = fopen("Anikki-16x16.rom", "w");

    unsigned char bin[17];
    bin[16] = 0;
    unsigned int i = 0;    

    while (i < FONT_SIZE)
    {
        unsigned int font = ((unsigned int) FONT[i] << 8) + FONT[i + 1];
        for (int j = 15; j >= 0; j--)
            bin[15 - j] = ((unsigned int) 1 << j) & font ? '1' : '0';
        fprintf(f,"%s\n", bin);
        i += 2;
    }

    fclose(f);
    return 0;
}