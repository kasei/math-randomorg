use strict;
use warnings;

use inc::Module::Install;

name				'Math-RandomOrg';
all_from			'lib/Math/RandomOrg.pm';
author				'Gregory Todd Williams <gwilliams@cpan.org>';
license				'perl';

build_requires		'Test::More'				=> '0.42';

perl_version		'5.006';

requires			'Math::BigInt'				=> 1.15;
requires			'LWP'						=> 0;
requires			'Scalar::Util'				=> 0;

no_index			'directory'		=> 'examples';

author_tests('xt');

sign;

WriteAll;
