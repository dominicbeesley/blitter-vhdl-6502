#!/bin/perl

while (<>) {
	my $l = $_;
	chomp $l;

	if ($l =~ /^al\s+([0-9A-F]{1,6})\s+\.(.*)$/i)
	{
		my $addr=$1;
		my $sym=$2;

		$sym =~ s/^@/_/;

		print "DEF $sym $addr\n";
	}
}