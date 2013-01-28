#!/usr/bin/perl

use strict;

my $namespace = shift @ARGV;
if (not $namespace) {
	die("no namespace specified");
}

my $line;

while ($line = <STDIN>) {
	chomp $line;
	if ($line =~ m/^\=static (.+)$/) {
		close FH;
		open (FH, ">$namespace/$1");
	} else {
		print FH "$line\n";
	}
}

close FH;

