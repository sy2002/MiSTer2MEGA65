We are currently hardcoding in democore_video.vhd:

Line #128:          h_pol     => '1',
Line #133:          v_pol     => '1',

so we are not using the values from G_VIDEO_MODE.H_POL and G_VIDEO_MODE.V_POL.

Reason: ascaler expects positive polarity.

MiSTer has a module that detects and corrects the polarity.

We might consider adding something similar in our framework. 
