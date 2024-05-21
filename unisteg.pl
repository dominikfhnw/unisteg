use 5.008;
use warnings;
no warnings 'uninitialized';
use strict;

use Encode;
use Unicode::Normalize;

my $secret;
my $origsecret;
my $sc;
my $sbits;

my $dc;
my $dbits;

my $count;

BEGIN {
	my $d = !!$ENV{DEBUG};
	*DEBUG = sub(){ $d };
	binmode STDERR, ":utf8" if $d;
}
sub dbg {
	print STDERR @_, "\n" if DEBUG;
}

sub pushbit {
	my $bit = shift;
	$dc += 1<<$dbits if $bit;
	$dbits++;
	if($dbits == 8){
		if($dc == 0){
			$dc = ord "\n";
		}
		print chr $dc;
		$dbits = 0;
		$dc = 0;
	}
}

sub popbit {
	if($sbits == 0){
		if(length$secret == 0){
			$secret = "\0$origsecret";
		}
		$sbits = 8;
		$sc = ord substr($secret, 0, 1);
		$secret = substr($secret, 1);
	}
	my $bit = $sc & 1;
	$sc >>= 1;
	$sbits--;
	return $bit;
}

sub utfdec {
	my $line = shift || $_;
	$line =~ s/\\/\\x5C/g;
	return decode('utf8', $line, Encode::FB_PERLQQ);
}

sub utfprint {
	my $line = shift || $_;
	$line = encode('utf8', $line);
	$line =~ s/\\x([A-F0-9]{2})/chr hex $1/ge;
	print $line;
}

sub decomposable {
	my $char = shift || $_;
	my $l = length(NFD($char));

	if(length($char) == $l){
		return 0;
	}
	if(NFC($char) ne $char){
		return 0;
	}
	if($l == 3){
		return 0;
	}
	return $l;
}

sub composable {
	my $a = shift;
	my $b = shift;
	my $comb = NFC($a.$b);
	return length($comb) != 2;
}

sub loop {
	my $line = shift;
	my $a = shift;
	my $b = shift;
	my $out = '';
	my $last;

	for (split//,$line) {
		if(decomposable){
			dbg "DEC ";
			$count++;
			$a->();
		}
		next if not defined $last;
		if(composable($last,$_)){
			dbg "COM ";
			$b->();
		}

	}
	continue {
		$last = $_;
		$out .= $_;
	}

	return $out;
}

sub unsteg {
	loop shift || $_, sub{ pushbit 0 }, sub{ pushbit 1 };
}

sub steg {
	loop shift || $_, sub{ $_ = NFD($_) if popbit };
}

my $encode = 0;
if($ARGV[0] eq "-e"){
	shift;
	$secret = shift;
	$origsecret = $secret;
	$encode = 1;
}

while(<>){
	$_ = utfdec;

	if($encode){
		#$_ = NFC($_);
		utfprint steg
	}else{
		unsteg
	}
}

if($encode){
	printf STDERR "Capacity: %d bytes\n", $count >> 3;
}
