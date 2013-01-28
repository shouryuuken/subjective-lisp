#!/usr/bin/perl

use strict;

my $line;
while ($line = <STDIN>) {
	chomp $line;
	my ($name, $sig) = split ' ', $line;
	$name =~ s/\"/\\\"/g;
	print qq{install_builtin(\@"cocoa", \@"$name", \@"(NuBridgedConstant constantWithName:\\"$name\\" signature:\\"$sig\\")");\n};
}

