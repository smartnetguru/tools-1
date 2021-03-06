#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );
use DBI;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiWmfDumps.pl");

# get the params
my $databaseHost = "localhost";
my $databasePort = "3306";
my $databaseName = "";
my $databaseUsername = "";
my $databasePassword = "";
my $projectCode = "";
my $installPath = "";
my $withHistory;
my $withoutImages;
my $withPageLinks;
my $withExternalLinks;
my $withTemplateLinks;
my $withMetaPages;
my $withSiteStats;
my $withPageRestrictions;
my $withUserGroups;
my $withLogging;
my $tmpDir = "/tmp";
my $version = "latest";
my $cmd;

## Get console line arguments
GetOptions('databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databaseName=s' => \$databaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
	   'projectCode=s' => \$projectCode,
	   'withoutImages' => \$withoutImages,
	   'withTemplateLinks' => \$withTemplateLinks,
	   'withPageLinks' => \$withPageLinks,
	   'withExternalLinks' => \$withExternalLinks,
	   'withMetaPages' => \$withMetaPages,
	   'withHistory' => \$withHistory,
	   'withLogging' => \$withLogging,
	   'withSiteStats' => \$withSiteStats,
	   'withPageRestrictions' => \$withPageRestrictions,
	   'withUserGroups' => \$withUserGroups,
	   'installPath=s' => \$installPath,
	   'version=s' => \$version,
	   'tmpDir=s' => \$tmpDir,
	   );

if (!$databaseName || !$projectCode) {
    print "usage: ./mirrorWmfDumps.pl --projectCode=enwiki --databaseName=MYDB [--tmpDir=/tmp] [--installPath=/var/www/mw/] [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff] [--withoutImages] [--withTemplateLinks] [--withPageLinks] [--version=latest] [--withMetaPages] [--withExternalLinks] [--withHistory] [--withSiteStats] [--withLogging] [--withPageRestrictions] [--withUserGroups]\n";
    exit;
}

if ($databaseUsername && !$databasePassword) {
    $databasePassword = query("Database password:", "");
}

if ($withLogging && !$installPath) {
    print "Please specify --installPath";
    exit 1;
}

if ( ! -e "$installPath/LocalSettings.php") {
    print "installPath is not valid, $installPath/LocalSettings.php does not exist.";
    exit 1;
}

# Create temporary directory
$tmpDir = $tmpDir."/wmfDumps";
unless ( -d "$tmpDir" ) {
    `mkdir $tmpDir`;
}

# Download the XML & SQL files
if ($withHistory) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pages-meta-history.xml.bz2;";
    unless ($withoutImages) {
	$cmd .= "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-oldimage.sql.gz"; `$cmd`;
    }
} elsif ($withMetaPages) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pages-meta-current.xml.bz2";
} else {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pages-articles.xml.bz2";
}
`$cmd`;

$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-redirect.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-categorylinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-category.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-langlinks.sql.gz"; `$cmd`;

if ($withPageLinks) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pagelinks.sql.gz"; `$cmd`;
}

if ($withTemplateLinks) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-templatelinks.sql.gz"; `$cmd`;
}

if ($withExternalLinks) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-externallinks.sql.gz"; `$cmd`;
}

if ($withSiteStats) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-site_stats.sql.gz"; `$cmd`;
}

if ($withLogging) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pages-logging.xml.gz"; `$cmd`;
}

if ($withPageRestrictions) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-page_restrictions.sql.gz"; `$cmd`;
}

if ($withUserGroups) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-user_groups.sql.gz"; `$cmd`;
}

unless ($withoutImages) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-image.sql.gz"; `$cmd`;
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-imagelinks.sql.gz"; `$cmd`;
}

# Install and compile the mwdumper
my $mwDumperDir = $tmpDir."/mwdumper/";
$cmd = "cd $tmpDir; svn co -r59325 http://svn.wikimedia.org/svnroot/mediawiki/trunk/mwdumper/"; `$cmd`;
$cmd = "cd $mwDumperDir/src; javac org/mediawiki/dumper/Dumper.java"; `$cmd`; 

# Prepare DB connection
my $dsn = "DBI:mysql:$databaseName;host=$databaseHost:$databasePort";
my $dbh;
my $req;
my $sth;
$dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");

# Truncate necessary tables
foreach my $table ("revision", "page", "text", "imagelinks", "templatelinks", "redirect", "externallinks", "image", "oldimage", "langlinks", "logging", "recentchanges", "searchindex", "pagelinks", "l10n_cache", "job", "category", "categorylinks", "archive", "filearchive", "site_stats" ) {
    $req = "TRUNCATE $table";
    $sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
}

# Upload the XML
print "Parsing content XML file...\n";
my $mysqlCmd = "mysql --user=$databaseUsername --password=$databasePassword $databaseName";

if ($withHistory) {
    unless ($withoutImages) {
	$cmd = "gzip -d -c $tmpDir/$projectCode-$version-oldimage.sql.gz | $mysqlCmd"; `$cmd`;
    }

    $cmd = "cd $mwDumperDir; java -classpath ./src org.mediawiki.dumper.Dumper --format=sql:1.5 ../$projectCode-$version-pages-meta-history.xml.bz2 | bzip2 > $projectCode-sql.bz2";
} elsif ($withMetaPages) {
    $cmd = "cd $mwDumperDir; java -classpath ./src org.mediawiki.dumper.Dumper --format=sql:1.5 ../$projectCode-$version-pages-meta-current.xml.bz2 | bzip2 > $projectCode-sql.bz2";
} else {
    $cmd = "cd $mwDumperDir; java -classpath ./src org.mediawiki.dumper.Dumper --format=sql:1.5 ../$projectCode-$version-pages-articles.xml.bz2 | bzip2 > $projectCode-sql.bz2";
}
system "$cmd";
print "Parsing content XML file finished.\n";

$cmd = "cd $mwDumperDir; bzip2 -c -d $projectCode-sql.bz2 | $mysqlCmd";
system "$cmd";
print "Pages uploaded to the database.\n";

# Upload the SQL
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-redirect.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-categorylinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-langlinks.sql.gz | $mysqlCmd"; `$cmd`;

if ($withPageLinks) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-pagelinks.sql.gz | $mysqlCmd"; `$cmd`;
}

if ($withTemplateLinks) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-templatelinks.sql.gz | $mysqlCmd"; `$cmd`;
}

if ($withExternalLinks) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-externallinks.sql.gz | $mysqlCmd"; `$cmd`;
}

if ($withSiteStats) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-site_stats.sql.gz | $mysqlCmd"; `$cmd`;
}

if ($withLogging) {
    $cmd = "php \"$installPath/maintenance/importDump.php\" \"$tmpDir/$projectCode-$version-pages-logging.xml.gz\"; php \"$installPath/maintenance/rebuildrecentchanges.php\""; `$cmd`;
}

if ($withPageRestrictions) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-page_restrictions.sql.gz | $mysqlCmd"; `$cmd`;
}

if ($withUserGroups) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-user_groups.sql.gz | $mysqlCmd"; `$cmd`;
}

unless ($withoutImages) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-image.sql.gz | $mysqlCmd"; `$cmd`;
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-imagelinks.sql.gz | $mysqlCmd"; `$cmd`;
}

print "Everything finished.\n";

exit;
