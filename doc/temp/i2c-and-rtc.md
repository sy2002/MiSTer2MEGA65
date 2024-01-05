## I2C interface:

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

## RTC

This entity contains a free-running internal timer, running independently of the                                                   
external RTC. The internal timer can be stopped and started, and can be set (when
stopped). Furthermore, when internal timer is stopped, the date/time can be copied
between the internal timer and the external RTC.

Address | Data
0x7000  | Hundredths of a second (BCD format, 0x00-0x99)
0x7001  | Seconds                (BCD format, 0x00-0x60)
0x7002  | Minutes                (BCD format, 0x00-0x59)
0x7003  | Hours                  (BCD format, 0x00-0x23)
0x7004  | DayOfMonth             (BCD format, 0x01-0x31)
0x7005  | Month                  (BCD format, 0x01-0x12)
0x7006  | Year since 2000        (BCD format, 0x00-0x99)
0x7007  | DayOfWeek              (0x00 = Monday)
0x7008  | Command                (bit 0 : RO : I2C Busy)
                                 (bit 1 : RW : Copy from RTC to internal)
                                 (bit 2 : RW : Copy from internal to RTC)
                                 (bit 3 : RW : Internal Timer Running)

Addresses 0x7000 to 0x7007 provide R/W access to the internal timer.

The Command byte (address 0x08) is used to start or stop the internal timer, and to
synchronize with the external RTC.  Any changes to the internal timer are only allowed
when the internal timer is stopped. So addresses 0x00 to 0x07 are read-only, when the
internal timer is running.
The protocol for synchronizing with the RTC is as follows:
1. Stop the internal timer by writing 0x00 to Command.
2. Read from Command and make sure value read is zero (otherwise wait).
3. Write either 0x02 (read from RTC) or 0x04 (write to RTC) to the command byte.
4. Read from Command and wait until value read is zero. (Note: The I2C transaction
   takes approximately 1 millisecond to complete).
5. Start the internal timer by writing 0x08 to Command.
Optionally, you may use auto-start in step 3 above by writing 0x0A or 0x0C. This
will automatically re-start the internal timer right after the I2C transaction is
complete, so that step 5 can be skipped.
Note: The Command byte automatically clears, when the command is completed. Reading
from the Command byte gives the status of the current command.

