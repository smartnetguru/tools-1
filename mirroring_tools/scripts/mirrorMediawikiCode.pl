#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use MediaWiki::Code;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiCode.pl");

# get the params
my $host;
my $path;
my $action="info";
my $filter=".*";
my $directory="";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'action=s' => \$action,
	   'filter=s' => \$filter,
	   'directory=s' => \$directory,
	   );

if (!$host || ($action eq "svn" && !$directory) ) {
    print "usage: ./mirrorMediawikiCode.pl --host=my_wiki_host [--path=w] [--action=info|svn|checkout|php] [--filter=*] [--directory=./]\n";
    exit;
}

my $code = MediaWiki::Code->new();
$code->filter($filter);


$code->logger($logger);
$code->directory($directory);
$code->get($host, $path);

if ($action eq "info") {
    print $code->informations();
} elsif ($action eq "svn") {
    print $code->getSvnCommands();
} elsif ($action eq "checkout") {
    my $svn = $code->getSvnCommands();
    foreach my $command (split("\n", $svn)) {
	`$command`;
    }
} elsif ($action eq "php") {
    print $code->php();
}

