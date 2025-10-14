#!/usr/bin/env perl

use strict;
use Text::ParseWords;
use Data::Dumper;
use File::Spec::Functions;
use File::Basename;

# Attempt to update the relative addresses in a set of
# ca65 listing files with data from an ld65 --dbgfile


sub usage($$) {
	my ($fh, $msg) = @_;

	print "ca65lstupdate.pl <debug file> <listings directory>\n";

	
	$msg && die $msg;
}

sub additem($$) {
	my ($hr, $txt) = @_;
	my %r = ();
	foreach my $i (parse_line(q{,}, 0, $txt)) {
		if ($i =~ /^(\w+)=(.*)/) {
			$r{$1} = $2;
		}
	}
	if (exists $r{"id"}) {
		$hr->{$r{"id"}} = \%r;
	}
}

my $fn_dbg = shift or usage(*STDERR, "Missing debug file parameter");
my $dirlst = shift or usage(*STDERR, "Missing listings directory");

-d $dirlst or usage(*STDERR, "\"$dirlst\" is not a directory");

my %files = ();
my %lines = ();
my %mods = ();
my %segs = ();
my %spans = ();
my %syms = ();


open(my $fh_dbg, "<", $fn_dbg) or usage(*STDERR, "Cannot open \"$fn_dbg\" for input : $!");

while (<$fh_dbg>) {
	
	s/[\s\n\t]+$//;

	if (/^file\s+(.*)/) {
		additem(\%files, $1);
	} elsif (/^line\s+(.*)/) {
		additem(\%lines, $1);
	} elsif (/^mod\s+(.*)/) {
		additem(\%mods, $1);
	} elsif (/^seg\s+(.*)/) {
		additem(\%segs, $1);
	} elsif (/^span\s+(.*)/) {
		additem(\%spans, $1);
	} elsif (/^sym\s+(.*)/) {
		additem(\%syms, $1);		
	}



}
close ($fh_dbg);

for my $f (values %files) {
	if ($f->{name} =~ /.(asm|s)$/) {
		my $fnlst = $f->{name};
		$fnlst =~ s/.(asm|s)$/.lst/;
		my $pfnlst = catfile($dirlst, $fnlst);
		if (!-e $pfnlst) {
			# not found try flattening directory
			$pfnlst = catfile($dirlst, basename($fnlst));
		}
		if (-e $pfnlst) {

#			print "PROCESSING $pfnlst\n";

			my $pfnlstrel = "$pfnlst.rel";
			open (my $fh_in, "<", $pfnlst) or die "Cannot open $pfnlst for input : $!";
			open (my $fh_out, ">", $pfnlstrel) or die "Cannot open $pfnlstrel for output : $!";

			# spans by line number
			my %myspans = ();

			print "$f->{name} : $f->{id}\n";
			for my $l (grep { $_->{file} eq $f->{id} && $_->{span}} values(%lines)) {
				$myspans{$l->{line}} = $spans{$l->{span}};
			}


			my $lno = 1;
			while (<$fh_in>) {
				if ($_ =~ /^([0-9a-f]+)r 1\s\s(([0-9A-F]{2}|xx|rr)\s)+\s*$/i) {
					# skip these lines and don't count they're data continuations
				} elsif ($_ =~ /^([0-9a-f]+)r 1(.*)/i) {
					my $rest = $2;
					if (exists $myspans{$lno}) {
						my $s = $myspans{$lno};
						#print $fh_out Dumper($myspans{$lno});
						my $seg = $segs{$s->{seg}};
						printf $fh_out "%06X   ", hex($seg->{start}) + $s->{start};
					} else {
						printf $fh_out "??????   ";
					}				
					print $fh_out "$rest\n";
					$lno++;
				} else {
					print $fh_out $_;
				}
			}
		} else {
			print STDERR "Missing listing file $pfnlst\n";
		}
	}

}


#print Dumper(%files);