### Mirko

Hi Michael,
I browsed through your M2M commit "Drive keyboard from system clock (100 MHz)"
and I did not fully get the idea behind it. Can you bring me up to speed?

### Michael


I'm not entirely happy with my change, but the issue is that previously the
keyboard was driven by the main clock, and the keyboard driver includes a
clock divider and this has then to be configured depending on the main clock
speed. There was no mechanism for such configuration within the keyboard
module (the clock divider is hard-coded), and when porting the Apple II core
Oliver and I saw blinking ambulance lights, because the main clock was
different, and hence also the clock driving the keyboard interface.

The solution I push'ed (which was a very quick-and-dirty fix) is to clock the
keyboard using the 100 Mhz system clock. This clock will always be the same
and hence no need for configuration. Then I had to add a CDC (Clock Domain
Crossing) as well. And this CDC I'm not entirely happy with, and would like
to change. Specifically, I'm not entirely sure my implementation actually
works, and furthermore, the CDC handles each bit independently, which is not
good for a counter value - there may occasionally be glitches.

There are other possible solutions to the original problem, including passing
the main clock speed to the keyboard module. But this requires rewriting the
keyboard module.

It's not the same difficulty level as the SD Card controller - it's not even
rocket science :-D

Please give me feedback and/or ideas/suggestions.

### Mirko

OK - now I got it; thank you for sharing.

Indeed this is something we should look at when time is ripe.
Part of the keyboard driver already accepts a clock speed, part of
it is hard coded...

Anyway: Maybe just using the 100 MHZ clock is a great idea and we "just"
need to do the CDC better..

### Result

Michael came up with a better idea - but we did not document it yet.
