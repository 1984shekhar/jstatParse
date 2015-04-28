#!/usr/bin/perl -w

#
# Parse output of Java jstat garbage collection statistics.  Particularly
# useful for judging garbage collection activity over an interval of time,
# but also useful for judging overall space utilization over time.
#
# Tested with OpenJDK 7 jstat.
#
# Usage:
# jstatGCParse.pl <pid>
#
# Where <pid> is the process ID of your running Hotspot JVM.
#
# BSD Two-Clause License:
#
# Copyright (c) 2015, Brian Koehmstedt
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

use strict;

# CONFIGURE: Interval time period at which jstat stats are collected.
my($INTERVAL_SECONDS) = 60 * 5; # every 5 minutes

# CONFIGURE: What fields you want displayed.
#my($showArrayRef) = ["OGCMX", "OU", "OGCPER", "FGC", "FGCT", "LB", "ECMX", "EU", "ECPER", "YGC", "YGCT", "LB", "PGCMX", "PU", "PGCPER", "LB", "GCT", "GCTDIFF", "TOTEVNTDIFF", "YGCTDIFF", "FGCTDIFF", "YGCDIFF", "FGCDIFF"];
# activity across intervals (won't show anything at interval 0)
my($showArrayRef) = ["GCTDIFF", "TOTEVNTDIFF", "YGCTDIFF", "FGCTDIFF", "YGCDIFF", "FGCDIFF"];

my($codes) = {
  "DSS" => "Desired survivor size (KB).",
  "EC" => "Current eden space capacity (KB).",
  "ECMX" => "Maximum eden space capacity (KB).",
  "E" => "Eden space utilization as a percentage of the space's current capacity.",
  "EU" => "Eden space utilization (KB).",
  "FGC" => "Number of full GC events.",
  "FGCT" => "Full garbage collection time.",
  "GCC" => "Cause of current Garbage Collection.",
  "GCT" => "Total garbage collection time.",
  "LGCC" => "Cause of last Garbage Collection.",
  "MTT" => "Maximum tenuring threshold.",
  "NGC" => "Current new generation capacity (KB).",
  "NGCMN" => "Minimum new generation capacity (KB).",
  "NGCMX" => "Maximum new generation capacity (KB).",
  "OC" => "Current old space capacity (KB).",
  "OGC" => "Current old generation capacity (KB).",
  "OGCMN" => "Minimum old generation capacity (KB).",
  "OGCMX" => "Maximum old generation capacity (KB).",
  "O" => "Old space utilization as a percentage of the space's current capacity.",
  "OU" => "Old space utilization (KB).",
  "PC" => "Current permanent space capacity (KB).",
  "PGC" => "Current permanent generation capacity (KB).",
  "PGCMN" => "Minimum permanent generation capacity (KB).",
  "PGCMX" => "Maximum permanent generation capacity (KB).",
  "P" => "Permanent space utilization as a percentage of the space's current capacity.",
  "PU" => "Permanent space utilization (KB).",
  "S0C" => "Current survivor space 0 capacity (KB).",
  "S0CMX" => "Maximum survivor space 0 capacity (KB).",
  "S0" => "Survivor space 0 utilization as a percentage of the space's current capacity.",
  "S0U" => "Survivor space 0 utilization (KB).",
  "S1C" => "Current survivor space 1 capacity (KB).",
  "S1CMX" => "Maximum survivor space 1 capacity (KB).",
  "S1" => "Survivor space 1 utilization as a percentage of the space's current capacity.",
  "S1U" => "Survivor space 1 utilization (KB).",
  "TT" => "Tenuring threshold.",
  "YGC" => "Number of young generation GC events.",
  "YGCT" => "Young generation garbage collection time.",
  
  # Custom calculated values
  "OGCPER" => "Old generation utilization as percentage of max oldgen capacity",
  "ECPER" => "Eden utilization as percentage of max eden capacity",
  "PGCPER" => "Permgen utilization as percentage of max permgen capacity",
  "GCTDIFF" => "Amount total garbage collection time increased from last interval check",
  "YGCTDIFF" => "Amount total young garbage collection time increased from last interval check",
  "FGCTDIFF" => "Amount full garbage collection time increased from last interval check"
};

my($lastResultMapRef);
while(1) {
  $lastResultMapRef = &statRound($lastResultMapRef, $showArrayRef);
  sleep($INTERVAL_SECONDS);
}

sub statRound {
  my($lastResultMapRef, $showKeyArrayRef) = @_;

  my(%result);
  
  my($pid) = $ARGV[0];
  if(!defined($pid) || !$pid) {
    print STDERR "Usage: jstatGCParse.pl <pid>\n";
    exit 1;
  }

  &gc($pid, "-gcnewcapacity", \%result);
  &gc($pid, "-gcoldcapacity", \%result);
  &gc($pid, "-gccapacity", \%result);
  &gc($pid, "-gc", \%result);

  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  
  # new generation = eden + survivor space 0 and 1
  print "Times are in seconds\n\n";
  printf "### START STAT ROUND %02i-%02i-%04i %02i:%02i:%02s ###\n", $mon + 1, $mday, $year + 1900, $hour, $min, $sec;
  show($lastResultMapRef, $showKeyArrayRef, \%result);
  print "### END STAT ROUND ###\n\n";
  
  return \%result;
}

sub show {
  my($lastResultMapRef, $keysRef, $resultMapRef) = @_;

  # set custom values
  $resultMapRef->{"OGCPER"} = sprintf "%.02f", ($resultMapRef->{"OU"} / $resultMapRef->{"OGCMX"}) * 100;
  $resultMapRef->{"ECPER"} = sprintf "%.02f", ($resultMapRef->{"EU"} / $resultMapRef->{"ECMX"}) * 100;
  $resultMapRef->{"PGCPER}"} = sprintf "%.02f", ($resultMapRef->{"PU"} / $resultMapRef->{"PGCMX"}) * 100;
  if(defined($lastResultMapRef)) {
      # Number of seconds total garbage collection time increased from the last block iteration
      $resultMapRef->{"GCTDIFF"} = sprintf "%.03f", $resultMapRef->{"GCT"} - $lastResultMapRef->{"GCT"};

      # Difference of young garbage collection time since last block iteration
      $resultMapRef->{"YGCTDIFF"} = sprintf "%.03f", $resultMapRef->{"YGCT"} - $lastResultMapRef->{"YGCT"};

      # Difference of full garbage collection time since last block iteration
      $resultMapRef->{"FGCTDIFF"} = sprintf "%.03f", $resultMapRef->{"FGCT"} - $lastResultMapRef->{"FGCT"};

      # Number of garbage collection events since last block iteration
      $resultMapRef->{"TOTEVNTDIFF"} = ($resultMapRef->{"FGC"} + $resultMapRef->{"YGC"}) - ($lastResultMapRef->{"FGC"} + $lastResultMapRef->{"YGC"});

      # Number of young garbage collection events since last block iteration
      $resultMapRef->{"YGCDIFF"} = $resultMapRef->{"YGC"} - $lastResultMapRef->{"YGC"};

      # Number of full garbage collection events since last block iteration
      $resultMapRef->{"FGCDIFF"} = $resultMapRef->{"FGC"} - $lastResultMapRef->{"FGC"};
  }

  foreach my $key (@$keysRef) {
    if($key eq "LB") {
      print "\n";
    }
    elsif(defined($resultMapRef->{$key}) && defined(&code($key))) {
      print &code($key), " = $resultMapRef->{$key}\n";
    }
    elsif(defined($resultMapRef->{$key})) {
      print "$key = $resultMapRef->{$key}\n";
    }
  }
}

sub code {
  my($key) = shift;
  my($result) = $codes->{$key};
  if(defined($result)) {
    return "$key: $result";
  }
  return $key;
}

sub gc {
  my($pid, $cmd, $resultMapRef) = @_;
  open(my $fh, "jstat $cmd $pid|") || die "Couldn't execute jstat";
  
  # header
  $_ = <$fh>;
  chop;
  s/^\s+//;
  my($header) = $_;
  my(@fields) = split(/\s+/, $header);
  
  while(<$fh>) {
    chop;
    s/^\s+//;
    my(@values) = split(/\s+/, $_);
    foreach my $i (0 .. $#values) {
      $resultMapRef->{$fields[$i]} = $values[$i];
    }
  }
  
  close($fh);
}
