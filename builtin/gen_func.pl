#!/usr/bin/perl

use strict;

my $line;
while ($line = <STDIN>) {
	chomp $line;
	my ($name, $sig) = split ' ', $line;
	print qq{install_builtin(\@"cocoa", \@"$name", \@"(NuBridgedFunction functionWithName:\\"$name\\" signature:\\"$sig\\")");\n};
}

