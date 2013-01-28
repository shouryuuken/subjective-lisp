#!/usr/bin/perl

use strict;

sub files_in_dir
{
	my ($path) = @_;
	opendir(my $dh, $path) || die "can't opendir $path: $!";
	my @arr = grep { !/^\./ } readdir($dh);
        closedir $dh;
	return @arr;
}

sub slurp_file
{
	my ($path) = @_;
	local *FH;
	open(FH, $path) || die "unable to open $path: $!";
	my @arr = <FH>;
	close(FH);
	return \@arr;
}

sub files_in_dir_to_hash
{
	my @paths = @_;
	my %data = ();
	my $path;
	foreach $path (@paths) {
		my @files = files_in_dir($path);
		my $file;
		foreach $file (@files) {
			$data{$file} = slurp_file("$path/$file");
		}
	}
	return \%data;
}

sub escapestr
{
	my ($str) = @_;
	$str =~ s/\\/\\\\/g;
	$str =~ s/"/\\"/g;
	$str =~ s/\t/\\t/g;
	$str =~ s/\r/\\r/g;
	$str =~ s/\n/\\n/g;
	return $str;
}

sub hash_to_rom
{
	my ($data) = @_;
	print "char *builtin_rom[] = {\n";

	my $key;
	foreach $key (sort keys %$data) {
		print "\t\"$key\", \"\\\n";
		map { print escapestr($_), "\\\n"; } @{$data->{$key}};
		print "\",\n";
	}

	print "\t0, 0\n";
	print "};\n";
}

hash_to_rom(files_in_dir_to_hash(@ARGV));

