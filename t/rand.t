use strict;

our ($numtests, $bytetests, $quotatests);
BEGIN {
	$numtests	= 10;
	$bytetests	= 3 * 3 * 20 * 2;
	$quotatests	= 1;
}
use Test::More tests => ($numtests + $bytetests + $quotatests);
use Math::RandomOrg qw(randnum randbyte);

# randbyte
for my $i (1 .. 10) {
	my $octets	= randbyte( $i );
	is( length($octets), $i, "randbyte($i)" );
}

my $qbits	= Math::RandomOrg::quota_bits();
my $quota	= Math::RandomOrg::checkbuf();

# randnum
foreach my $max (1, 1_000, 1_000_000_000) {
	foreach my $min (1, 0, -1_000_000_000) {
		foreach my $round (1 .. 20) {
			my $number	= randnum( $min, $max );
			cmp_ok( $number, '>=', $min, "randnum($min, $max) lower bound (x$round)" );
			cmp_ok( $number, '<=', $max, "randnum($min, $max) upper bound (x$round)" );
		}
	}
}

my $new_quota	= Math::RandomOrg::checkbuf();
my $new_qbits	= Math::RandomOrg::quota_bits();
cmp_ok( $quota, '>=', $new_quota, 'checkbuf' );
