## MiSTer filters that are used for C64MEGA65 Release 1

The choice of optimal filters for our CRT emulation was done by KiDra
in March 2022.

### Compromise solution for Release 1

Release 1 of C64MEGA65 only supports horizontal and vertical filters for
performing the CRT emulation. There is no gamma correction and no shadow mask.

This leads to `Scan_Br_120_80.txt` being a bit too bright but the "pure"
version `Scanline_80.txt` being a bit too dark. We found `Scan_Br_110_80.txt`
being optimal for our purposes - at least as long we are not supporting
gamma correction and shadhow mask: The +10% in brightness compensates the
perceived -10% in brightness due to the emulated scan lines.

### KiDRa's optimal filter choice

#### Horizontal filter: lanczos2_12.txt

"It is the option where you set what upscaling method to use.
I use lanczos2_12.txt, because it adds a bit of blur and imperfection around
edges, without going too blurry (it does not replicate composite blending)."

https://github.com/MiSTer-devel/Filters_MiSTer/blob/master/Filters/Upscaling%20-%20Lanczos%20Bicubic%20etc/lanczos2_12.txt

#### Vertical filter: Scan_Br_120_80.txt

"This one adds the scanlines. Br_120 increases the brightness and thus
counterbalances the darkening of the image caused by the Shadow Mask filter.
80 is rather mild in scanlines, because I do not like these overblown dark
scanlines some folks use."

https://github.com/MiSTer-devel/Filters_MiSTer/blob/master/Filters/Scanlines%20-%20Brighter/120pct%20Brightness/Scan_Br_120_80.txt

#### Gamma Correction: CRT_Simulation.txt

"It corrects the gamma curve, because CRTs and LCDs have different gamma
curves and without correction dark parts of the screen would be too bright.
The `CRT Simulation` version creates nice, crisp colors."

https://github.com/MiSTer-devel/Filters_MiSTer/blob/master/Gamma/CRT%20Simulation.txt

#### Shadow Mask: VGA_Squished_BGR_1987.txt

"The shadow mask adds the aperture grill / slot look. VGA squished is one of
the most finely granular shadow masks and to me adds the delicate look of a
classic crt screen."

https://github.com/MiSTer-devel/ShadowMasks_MiSTer/blob/main/Shadow_Masks/Complex%20(Multichromatic)/CRT%20Styles/Subpixel%20BGR%20(Common)/VGA%20%5BSquished%5D%20%5BBGR%5D%20(1987).txt

##### Non recommended alternative: Commodore_1084_BGR_1987.txt

"Commodore 1084 - I would not use that setting, but here the file so you can
experiment with it ... pattern is too prominent ..."

https://github.com/MiSTer-devel/ShadowMasks_MiSTer/blob/main/Shadow_Masks/Complex%20(Multichromatic)/CRT%20Styles/Subpixel%20BGR%20(Common)/Commodore%201084%20%5BBGR%5D%20(1987).txt

