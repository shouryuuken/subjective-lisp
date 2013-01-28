#!/usr/bin/perl

use strict;

my $line;
while ($line = <STDIN>) {
	chomp $line;
	next if ($line !~ s/^\(bridge constant //);
	next if ($line !~ s/\)$//);
	if ($line =~ m/^([^\s]+)\s+(.+)$/) {
		my $name = $1;
		my $sig = $2;
		$sig =~ s/\"//g;
		print "$name $sig\n";
	}
}

