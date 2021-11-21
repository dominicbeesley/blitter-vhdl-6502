#!/bin/perl

my $in = 0;

while (<>) {
  my $l = $_;
  chomp $l;
  if ($l =~ /^Exports list by name/) {
    $in = 2;
  } elsif ($in) {
    if ($l =~ /^---/) {
      $in--;
    } else {
      while ($l =~ /^\s*([0-9A-Za-z_]+)\s+([0-9A-F]+)\s+(EA|LA)(.*)$/)
      {
        my $sym=$1, $add=$2, $typ=$3, $ret=$4;
  
        printf "%s %s\n", $sym, $add;
  
        $l = $4;
      }
    }
  }
}