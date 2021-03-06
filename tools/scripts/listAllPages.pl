#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../classes/";

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("listAllPages.pl");

# get the params
my $host = "";
my $path = "";
my $namespace;
my $filter = "all";
my $username = "";
my $password = "";
my $prefix = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'filter=s' => \$filter,
	   'namespace=s' => \$namespace,
	   'prefix=s' => \$prefix,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   );

if (!$host || !($filter eq "all" || $filter eq "nonredirects" || $filter eq "redirects")) {
    print "usage: ./listAllPages.pl --host=my.wiki.org --namespace=0 [--path=w] [--filter=[all|redirects|nonredirects]] [--prefix=foobar] [--username=foo] [--password=bar]\n";
    exit;
}

my $site = Mediawiki::Mediawiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);
if ($username) {
    $site->user($username);
    $site->password($password);
}
$site->setup();

foreach my $page ($site->allPages($namespace, $filter, $prefix)) {
    print $page."\n";
}

exit;
