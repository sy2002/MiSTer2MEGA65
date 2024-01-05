I2C interface:

I've done a lot of refactoring in the I2C interface. You might have noticed that the
interface described in M2M/vhdl/i2c/i2c_controller.vhd is a bit cumbersome to use.
Basically, the idea is that you set up (configure) a complete I2C transaction, and then
start it, and finally inspect the result of the transaction.
The above is a bit unwieldy and therefore, I've added a simple 8-bit memory-mapped
interface to the I2C devices. This is not meant for the end user, and probably not even
for the CPP. The only use-case I see is for debugging.  Anyway, the interface is very
simple.
Start by executing:
* MC FFF4 0005
* MC FFF5 BBSS
where BB is the I2C bus number, and SS is the I2C slave address.
Then you have a 256-byte window from 0x7100 to 0x71FF accessing the registers in the I2C
device. The valid combinations of BB and SS are:
* 0050 : U36. 2K Serial EEPROM
* 0034 : R3 only: U37. Audio DAC
* 006F : R3 only: U38. Real-Time Clock Module
* 0057 : R3 only: U38. SRAM within RTC
* 0054 : R3 only: U39. 128K CMOS Serial EEPROM
* 0051 : R4/R5 only: U38. Read-Time Clock Module
* 0056 : R4/R5 only: U39. 128K CMOS Serial EEPROM
* 01xx : TBD. GROVE connector. This could e.g. be the "fixed" RTC.
* 0220 : R4/R5 only: U32. I/O expander.
* 0261 : R4/R5 only: U12. DC/DC converter.
* 0267 : R4/R5 only: U14. DC/DC converter.
* 0350 : HDMI EDID. Can be used to probe the supported screen resolutions of the monitor
* 0450 : VGA EDID. Can be used to probe the supported screen resolutions of the monitor
* 0519 : AUDIO. This device does not support the simple 8-bit memory mapped interface.
Note: All I2C devices can still be accessed using the more clunky transaction-based
interface.
So to summarize: We need I2C communication to interact with the RTC device, and I then
generalized it to make it support all available I2C devices.