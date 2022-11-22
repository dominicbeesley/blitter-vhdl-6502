#!/bin/perl

my $rix = 0;

my %cstart = ();

while (<>) {
    my $l = $_;
    $l =~ s/[\r\n]*//;
    
    if ($l =~ /^\s*$/) {
        #do nowt
    } elsif ($l =~ /^\s*(x\"[0-9a-f]{1,2}\"(\s*,\s*x\"[0-9a-f]{1,2}"){7})\s*,?\s*?\s*$/i) { 
        my $ll = $1;
        $ll =~ s/x//g;
        $ll =~ s/\"//g;
        $ll =~ s/,$//;

        my $c = int($rix / 2);

        my @v = map { hex($_) } split /,/, $ll;

        scalar(@v) == 8 or die "Wrong number of items on line $ll : " . scalar(@v);

        my $ix = 0;
        foreach my $vv (@v) {
            my $ix2 = (8 * ($rix & 0x01)) + $ix;

            $vv & 0x40 && die "!!! 0x40 %02X %01X = %02X\n", $c, $ix2, $vv;

            (($vv & 0x80) xor (($c & 0x80) && ($c & 0x20))) and $ix2 < 10 and die sprintf "!!! top bit set %02X %01X = %02X\n", $c, $ix2, $vv;

            $vv = $vv & 0x3F;

            if ($vv) {

                if (!$cstart{$c}) {
                    print "\n\n";
                    if ($c >= 32 && $c <= 127) {
                        printf "-- CH=%02X \"%s\"\n", $c, chr($c);
                    } else {
                        printf "-- CH=%02X \n", $c;
                    }
                    $cstart{$c} = 1;
                }


                printf "         when x\"%02X%01X\" => Q <= \"%06b\"\n", $rix/2, $ix2, $vv;                
            }
            $ix ++;
        }

        $rix++;

    } else {
      die "Bad input line";
    }
    
}