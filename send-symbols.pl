#! /usr/bin/perl -w

use strict;
use Socket;
use File::Basename;
use Getopt::Std;
use Cwd qw(abs_path);

my %opts = ();
getopts('fsh:p:', \%opts);
my $host = get_host();
my $port = get_port();

sub files_in_dir
{
	my ($path) = @_;
	opendir(my $dh, $path) || die "can't opendir $path: $!";
	my @arr = grep { !/^\./ } readdir($dh);
    closedir $dh;
	return map { Cwd::abs_path("$path/$_") } @arr;
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
	my $path = shift @_;
	my %data = ();
	my @files = files_in_dir($path);
	my $file;
	foreach $file (@files) {
		if (-d $file) {
			my $subdir = files_in_dir_to_hash($file);
			my $subfile;
			foreach $subfile (keys %$subdir) {
				$data{$subfile} = $subdir->{$subfile};
			}
			next;
		}
		$data{$file} = slurp_file($file);
	}
	return \%data;
}

sub read_from_socket
{
	my ($sock, $n) = @_;
	my $data = undef;
	my $buf = undef;
	for(;;) {
		recv($sock, $buf, $n - (length $data), 0);
		$data .= $buf;
		if (length $data == $n) {
			return $data;
		}
	}
	return undef;
}

sub receive_message
{
	my ($sock) = @_;

	my $header = read_from_socket($sock, 512);
	if ($header) {
		my $datalen = int substr($header, 0, 256);
		my $data = read_from_socket($sock, $datalen);
		if ($data) {
			return $data;
		} else {
			print "unable to read $datalen bytes of data\n";
			return undef;
		}
	} else {
		return undef;
	}
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

sub make_header
{
	my ($cmd, $data) = @_;
	return sprintf("%-256d%-256.256s%s",
			length $data,
			$cmd,
			$data);
}

sub make_connection
{
	my ($func) = @_;

	print "connecting to $host:$port\n";

	my $proto = getprotobyname('tcp');
	my $iaddr = inet_aton($host);
	my $paddr = sockaddr_in($port, $iaddr);

	local *SOCK;
	socket(SOCK, PF_INET, SOCK_STREAM, $proto) or die "socket: $!";
	connect(SOCK, $paddr) or die "connect: $!";
	binmode(SOCK);
	print "connected.\n";

	send(SOCK, "#!nu", 0);
	print "sent magic.\n";

	&$func(\*SOCK);
	print "done.\n";

	my $data;
	while ($data = receive_message(\*SOCK)) {
		print "msg: $data";
	}

	close SOCK or die "close: $!";

}

sub send_cmd
{
	my ($sock, $cmd) = @_;

	print "sending $cmd\n";

	my $sendstr = make_header("", $cmd);
	send($sock, $sendstr, 0);
}

sub read_file
{
	my ($file) = @_;
	local *FH;
	open FH, $file;
	my $str = <FH>;
	chomp $str;
	close FH;
	return $str;
}

sub write_file
{
	my ($file, $data) = @_;
	local *FH;
	open FH, ">$file";
	print STDERR "writing to '$file' data '$data'\n";
	print FH $data;
	close FH;
}

sub get_host
{
	my $host_file = "$ENV{HOME}/.nu-host";
	if ($opts{h}) {
		write_file($host_file, $opts{h});
		return $opts{h};
	}
	if (-f $host_file) {
		return read_file($host_file);
	}
	return '172.20.10.1';
}

sub get_port
{
	my $port_file = "$ENV{HOME}/.nu-port";
	if ($opts{p}) {
		write_file($port_file, $opts{p});
		return $opts{p};
	}
	if (-f $port_file) {
		return read_file($port_file);
	}
	return 6502;
}

sub get_symbols_path
{
	my $symbols_file = "$ENV{HOME}/.nu-symbols";
	if ($opts{d}) {
		write_file($symbols_file, $opts{d});
		return $opts{d};
	}
	if (-f $symbols_file) {
		return read_file($symbols_file);
	}
	return "/ios/Nu/symbols.nu";
}

sub get_cmd
{
	my @arr = @ARGV;
	if (not scalar @arr) {
		die("no command specified");
	}

	@arr = map { escapestr($_) } @arr;
	my $cmd = join ' ', @arr;
	if (not $opts{s}) {
		$cmd = "(" . $cmd . ")";
	}

	return $cmd;
}

sub update_timestamp
{
	my ($timestamp, @path) = @_;
	if ($timestamp) {
		utime $timestamp, $timestamp, @path;
	}
}

sub get_timestamp
{
	my ($path) = @_;
	my @arr = stat($path);
	return $arr[9];
}

sub parse_filename
{
	my ($path) = @_;
	if ($path =~ m/\/symbols\.nu\/(.+)$/) {
		return $1;
	}
	return undef;
}

sub wait_for_response
{
	my ($sock) = @_;
	my $data = undef;
	while ($data = receive_message($sock)) {
		if ($data eq "1\n") {
			return 1;
		} elsif ($data eq "0\n") {
			return 0;
		}
	}
}

sub send_hash
{
	my ($sock, $timestamp, $data) = @_;

	my $key;
	foreach $key (sort keys %$data) {

		my $subpath = parse_filename($key);
		if (not $subpath) {
#			print "skipping $key\n";
			next;
		}

		my $file_timestamp = get_timestamp($key);
		if ($file_timestamp < $timestamp) {
#			print "timestamp ${file_timestamp} indicates not modified, skipping $key $timestamp\n";
			next;
		}

		my $dir = dirname($subpath);
		my $file = basename($subpath);

		print "sending $dir/$file ($key)\n";

		my $val = join '', @{$data->{$key}};
		my $sendstr = make_header(
			"(fn (x) (write-symbol \"" . escapestr($dir) . "\" \"" . escapestr($file) . "\" x))",
			$val);
		send($sock, $sendstr, 0);

		if (!wait_for_response($sock)) {
			print "did not receive acknowledgement\n";
		}
	}
}

sub do_cmd
{
	my $cmd = get_cmd();
	make_connection(sub { send_cmd(shift, $cmd) });
}

sub do_symbols
{
	my $symbols_path = get_symbols_path();

	my $new_timestamp = time;
	my $last_timestamp = get_timestamp($symbols_path);
	my $timestamp;
	if ($opts{f}) {
		print "force enabled\n";
		$timestamp = 0;
	} else {
		$timestamp = $last_timestamp;
	}
	make_connection(sub {
		send_hash(shift, $timestamp, files_in_dir_to_hash($symbols_path));
		update_timestamp($new_timestamp, $symbols_path);
	});
}

&do_symbols;

