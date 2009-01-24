=head1 NAME

Math::RandomOrg - Retrieve random numbers and data from random.org.

=head1 SYNOPSIS

  use Math::RandomOrg qw(randnum randbyte);
  my $number = randnum(0, 10);
  my $octet = randbyte(1);

=head1 DESCRIPTION

Math::RandomOrg provides functions for retrieving random data from the
random.org server. Data may be retrieved in an integer or byte-stream format
using the C<randnum> and C<randbyte> functions respectively.

=head1 REQUIRES

=over 4

=item Carp

=item Exporter

=item Math::BigInt

=item LWP::UserAgent

=item Scalar::Util

=back

=head1 EXPORT

None by default. You may request the following symbols be exported:

=over 4

=item * randnum

=item * randbyte

=back

=cut

package Math::RandomOrg;

use strict;
use warnings;
use Scalar::Util qw(blessed);

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw( checkbuf randnum randbyte randseq );
@EXPORT = qw();
$VERSION = '0.05_01';

use Carp;
use Math::BigInt;
use Math::BigFloat;
use LWP::UserAgent;

my $RAND_MIN	= new Math::BigInt "-1000000000";	# random.org fixed min
my $RAND_MAX	= new Math::BigInt "1000000000";	# random.org fixed max
my $NUM_BUF		= 32;								# at least, request this number of random integers in each request to random.org
my $REQUESTS	= 0;

=head1 FUNCTIONS

=over 4

=cut

{
	my @randnums;

=item C<randnum ( $min, $max )>

Return an integer (specifically a Math::BigInt object) between the bounds [ $min, $max ] (inclusive).

By default, $max and $min are positive and negative 1e9, respectively. These default
values represent random.org's current extrema for the bounds of the randnum function.
Therefore, $min and $max may not exceed the default values.

=cut
	sub randnum (;$$$) {
		my $min		= new Math::BigFloat ((scalar(@_) and defined($_[0])) ? shift : $RAND_MIN);
		my $max		= new Math::BigFloat ((scalar(@_) and defined($_[0])) ? shift : $RAND_MAX);
		my $count	= (scalar(@_) and defined($_[0])) ? shift : 1;
		if ($min < $RAND_MIN or $max > $RAND_MAX) {
			carp "The $min and $max arguments to the randnum() function may not exceed the bounds ($RAND_MIN, $RAND_MAX)!";
			return undef;
		}
		if (scalar(@randnums) < $count) {
			_load_more_numbers( $count );
		}
		
		my @results;
		foreach my $i (1 .. $count) {
			my $num	= new Math::BigFloat (shift(@randnums));
			$num	-= $RAND_MIN;
			$num	*= (1 + $max - $min);
			$num	/= ($RAND_MAX - $RAND_MIN);
			$num	+= $min;
			my $randnum	= Math::BigInt->new( $num->bfloor() );
			push(@results, $randnum);
		}
		
		return wantarray ? @results : $results[0];
	}

	sub _load_more_numbers {
		my $count	= shift;
		my $num		= ($count > $NUM_BUF) ? $count : $NUM_BUF;
#		warn "getting $num more random numbers";
		my $url		= "http://www.random.org/integers/?num=${num}&min=${RAND_MIN}&max=${RAND_MAX}&col=1&base=10&format=plain&rnd=new";
		my $ua		= _ua();
		my $resp	= $ua->get( $url );
		if ($resp->is_success) {
			my $data	= $resp->content;
			@randnums	= map { new Math::BigInt $_ } (split(/\n/, $data));
			$NUM_BUF	= int($NUM_BUF * 1.5);
			$REQUESTS++;
		} else {
			carp "HTTP GET failed: " . $resp->status_line;
			return undef;
		}
	}




=item C<randbyte ( $length )>

Returns an octet-string of specified length (defaults to one byte), which contains random bytes.

$length may not exceed 16,384, as this is the maximum number of bytes retrievable from the
random.org server in one request, and making multiple requests for an unbounded amount of
data would unfairly tax the random.org server. If you need large amounts of random data,
you may wish to try the Math::TrulyRandom module.

=cut
	sub randbyte (;$) {
		my $length	= +(shift || 1);
		my @nums	= randnum( 0, 255, $length );
		my $randbytes	= join( '', map { chr($_) } @nums );
		return $randbytes;
	}
}

=item C<randseq ( $min, $max )>

The randseq script returns a randomized sequence of numbers. This corresponds to dropping
a number of lottery tickets into a hat and drawing them out in random order. Hence, each
number in a randomized sequence occurs exactly once.

Example: C<randseq(1, 10)> will return the numbers between 1 and 10 (both inclusive) in a
random order.

=cut

sub randseq (;$$) {
	die;
	my ($min, $max) = @_;
	return if ( (! defined $min) || (! defined $max) || ($min !~ /^\-?\d+$/) || ($max !~ /^\-?\d+$/) );
	if ($max < $min) {
		carp "MAX must be greater than MIN.";
		return;
	}
	if ($max - $min > 10000) {
		carp "random.org restricts the size of sequences to <= 10,000.";
		return;
	}
	my @sequence = ();
	my $url		= "http://www.random.org/cgi-bin/randseq?min=$min&max=$max";
	my $data	= LWP::Simple::get( $url );
	if (defined($data)) {
		@sequence = map { new Math::BigInt $_ } (split(/\n/, $data));
	} else {
		carp "HTTP GET failed for $url";
		return undef;
	}
	
	return wantarray ? @sequence : \@sequence;
}


=item C<< quota_bits >>

Returns the number of bits of random data still available under this computer's
IP address quota. The quota is (as of this writing on 2009-01-12) 1,000,000
bits, replenishing 200,000 bits per 24 hour period up to a 1,000,000 bit
maximum. See L<http://random.org/quota/> for more information.

=cut

	sub quota_bits {
		my $url		= "http://random.org/quota/?format=plain";
		my $ua		= _ua();
		my $resp	= $ua->get( $url );
		if ($resp->is_success) {
			my $data	= $resp->content;
			if (my ($quota) = ($data =~ m/(\d+)/)) {
				return $quota;
			} else {
				carp "Bad data for $url: '$data'";
				return;
			}
		} else {
			carp "HTTP GET failed: " . $resp->status_line;
			return;
		}
	}
	

=item C<checkbuf()>

This routine takes no parameters and simply returns a single value (e.g., 
C<28>) telling you how full the buffer is (out of 100). A value of 100 indicates
a full buffer, and you are free to hit it with automated clients. At 0%, the
buffer is  empty and requests will hang. When less than 100%, the buffer is being 
filled continually, but doing so takes time.

=cut

	sub checkbuf {
		# the quota is 1,000,000 bits. this call will return how many bits we
		# have left, and we then divide by 10,000 to produce a percentage
		# value (1,000,000 / 100)
		if (my $bits = quota_bits()) {
			return int($bits / 10_000);
		} else {
			return;
		}
	}
	

our $_ua;
sub _ua {
	if (blessed($_ua)) {
		return $_ua;
	} else {
		$_ua	= new LWP::UserAgent;
		$_ua->agent("Math::RandomOrg/${VERSION} (perl client; gwilliams\@cpan.org)");
		return $_ua;
	}
}

1;
__END__

=back

=head1 SEE ALSO

=over 4

=item * L<http://random.org/>

=item * L<Math::TrulyRandom>

=back

=head1 COPYRIGHT

Copyright (c) 2001-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=cut
