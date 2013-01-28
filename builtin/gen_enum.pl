#!/usr/bin/perl

use strict;

my $namespace = shift @ARGV;
if (not $namespace) {
	die("please specify namespace");
}

my $line;
while ($line = <STDIN>) {
	chomp $line;
	print qq{install_int(\@"$namespace", \@"$line", $line);\n};
}

