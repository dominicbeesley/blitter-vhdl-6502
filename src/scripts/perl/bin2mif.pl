#!/usr/bin/env perl

# bin2mif - convert a binary file to an Altera .mif file
#

use strict;

sub Usage {
	my ($msg, $exit) = @_;

	my $fh = ($exit)?*STDERR:*STDOUT;

	print $fh "
bin2bitvector.pl [options] <binary file>

options:
	--fill <X=0>A value to use to fill unused space before/after the data
	--size <N>  The file will be padded/truncated to this size
	--b4 <N>    The file will be padded with N fill bytes before the binary
	            data
";

	if ($msg) {
		print $fh "$msg\n";
	}

	if ($exit) {
		exit $exit;
	}
}

##############################################################################
#################################### main ####################################
##############################################################################

my $fill="0";
my $size=-1;
my $b4=0;

while (scalar @ARGV && $ARGV[0] =~ /^-/) {

	my $sw = shift;

	if ($sw =~ /^-(-?)h/)
	{
		Usage();
		exit 0;
	}
	elsif ($sw eq "--fill") 
	{
		$fill = uc(shift);

		$fill >= 0 && $b4 < 0x100 or Usage "Bad fill parameter '$fill' should be >=0 and <=255\n", 1;
	}
	elsif ($sw eq "--b4") 
	{
		$b4 = shift;

		$b4 > 0 && $b4 < 0x10000 or Usage "Bad b4 parameter '$b4' should be >0 and <65536\n", 1;
	}
	else {
		die Usage("unknown switch $sw", 1);
	}
	
}

if (scalar @ARGV != 1) {
	Usage ("incorrect number of arguments", 1)
}

my $fn_in = shift;

open (my $fh_in, "<:raw:", $fn_in) or Usage "Cannot open input file \"$fn_in\" : $!";

for (my $i = 0; $i < $b4 && ($size == -1 || $i < $size); $i++) {
	print $fill x 8 . "\n";
}

my $buf;
read($fh_in, $buf, 65536);

my @bin = unpack("C*", $buf);
my $l = length($buf);

if ($size > 0 && $l + $b4 > $size) {
	$l = $size-$b4;
}

printf "-- mif file produced by bin2mif.pl\n";
printf "WIDTH = 8;\n";
printf "DEPTH = %d;\n", ($size>0)?$size:$l;
printf "ADDRESS_RADIX = HEX;\n";
printf "DATA = HEX;\n";
printf "CONTENT\n";
printf "BEGIN\n";

for (my $i = 0; $i < $l; $i++) {
	printf "%04x : %02x;\n", $i, $bin[$i];
}

if ($size > 0 && $l + $b4 < $size) {
	printf "[%04x..%04x] : %02x;\n", $l, ($size - 1), $fill;
}

printf "END;\n";

close $fn_in;