jstatParse
==========

This is a perl script to parse Java jstat output for garbage collection
statistics over intervals of time.

Usage:

Make executable if on a *nix machine:
```
chmod +x jstatParse.pl
```

Run the script:
```
jstatParse.pl <pid>
```

where `<pid>` is the process ID of your running Hotspot JVM.
(If you need that, you can utilize the `jps` utility from the JDK.)

`jstat` from the JDK needs to be in your path.

This script tested with `jstat` from OpenJDK 7.

You can configure the output of the script (the `jstat` fields shown) and
the time interval by editing the constant values towards the top of the
script.
