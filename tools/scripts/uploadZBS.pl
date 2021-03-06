#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use utf8;
use strict;
use warnings;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use HTML::Template;
use File::Basename;

my $commonsHost = "commons.wikimedia.org";
my $overwrite = 0;
my $overwriteDescriptionOnly = 0;
my $dbPassword;
my $dbUsername;
my $dbh;
my $username;
my $password;
my $pictureDirectory;
my $metadataFile;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my %metadatas;
my $templateCode = "=={{int:filedesc}}==
{{Artwork     
  |artist           = <TMPL_VAR NAME=AUTHOR>
  |other_fields_1   = <TMPL_VAR NAME=OTHER_FIELD_1>
  |title            = <TMPL_VAR NAME=TITLE>
  |description      = {{de|<TMPL_VAR NAME=DESCRIPTION>}}
  |date             = <TMPL_VAR NAME=DATE>
  |medium           = <TMPL_VAR NAME=MEDIUM>
  |dimensions       = <TMPL_VAR NAME=DIMENSIONS>
  |institution      = {{institution:Zentralbibliothek Solothurn}}
  |location         = 
  |references       =
  |object history   =
  |credit line      =
  |inscriptions     =
  |notes            = 
  |accession number = Call number <TMPL_VAR NAME=SYSID>
  |source           = Zentralbibliothek Solothurn
  |permission       = Public domain
  |other_fields_2   = <TMPL_VAR NAME=OTHER_FIELD_2>
  |other_versions   = 
}}
{{Zentralbibliothek Solothurn}}
{{PD-old-70-1923}}

[[Category:Historical images of Solothurn]]
";

my %imgs = (
"a0754 (1)" => "a_0754_1.tif",
"a0754 (2)" => "a_0754_2.tif",
"a0754 (3)" => "a_0754_3.tif",
"a0754 (4)" => "a_0754_4.tif",
"a0754 (5)" => "a_0754_5.tif",
"a0877 (1-2)" => "a_0877_1.tif",
"a0877 (3-4)" => "a_0877_3.tif",
"a0877_2" => "a_0877_2.tif",
"a0877_4" => "a_0877_4.tif",
"a0924 (1)" => "a_0924_1.tif",
"a0924 (2)" => "a_0924_2.tif",
"a0924 (3)" => "a_0924_3.tif",
"a0924 (4)" => "a_0924_4.tif",
"a0995" => "a_0995_1.tif",
"a1032_2" => "a_1032_2.tif",
"a1032_3" => "a_1032_3.tif",
"a1072" => "a_1072_1.tif",
"a1072_2" => "a_1072_2.tif",
"a1072_3" => "a_1072_3.tif",
"a1072_4" => "a_1072_4.tif",
"a1072_5" => "a_1072_5.tif",
"a1072_6" => "a_1072_6.tif",
"a1072_7" => "a_1072_7.tif",
"a1072_8" => "a_1072_8.tif",
"a1072_9" => "a_1072_9.tif",
"a1078_02" => "a_1078_02.tif",
"a1078_03" => "a_1078_03.tif",
"a1078_04" => "a_1078_04.tif",
"a1078_05" => "a_1078_05.tif",
"a1078_06" => "a_1078_06.tif",
"a1078_07" => "a_1078_07.tif",
"a1078_08" => "a_1078_08.tif",
"a1078_09" => "a_1078_09.tif",
"a1078_10" => "a_1078_10.tif",
"a1078_11" => "a_1078_11.tif",
"a1078_12" => "a_1078_12.tif",
"aa0284_1" => "aa_0284_1.tif",
"aa0352" => "aa_0352_1.tif",
"aa0352_2" => "aa_0352_2.tif",
"aa0452 /2" => "aa_0452_2.tif",
"aa0505 1" => "aa_0505_1.tif",
"aa0505 2" => "aa_0505_2.tif",
"aa0505 4" => "aa_0505_4.tif",
"aa0599 /2" => "aa_0599_2.tif",
"aa0801 /1" => "aa_0801_1.tif",
"aa0801_2" => "aa_0801_2.tif"
);

my %technique = (
"aquatinta" => "Aquatint",
"autotypie" => "Autotype",
"bister" => "Bister",
"federlithographie" => "Pen lithograph",
"gouache" => "Gouache",
"heliographie" => "Heliography",
"holzschnitt" => "Woodcut",
"holzstich" => "Wood engraving",
"kaltnadel" => "Drypoint",
"kreidelithographie" => "Chalk lithograph",
"kupferstich" => "Copper engraving",
"lichtdruck" => "Collotype",
"lichtpaus-radierung" => "Diazocopy etching",
"linolschnitt" => "Linocut",
"mezzotinto" => "Mezzotint engraving",
"mischtechnik" => "Mixed technique",
"monotypie" => "Monotype",
"offset-verfahren" => "Offset",
"pastell" => "Pastel",
"photographie" => "Photograph",
"photokopie" => "Photocopy",
"punktierradierung" => "Stipple etching",
"radierung" => "Etching",
"reproduktion" => "Reproduction",
"stahlstich" => "Steel engraving",
"lithographie" => "Lithograph",
"tonlithographie" => "Toned lithograph",
"umrissstich" => "Contour engraving",
"zinkographie" => "Zincography",
);

my %techniqueAttribute = (
"aquarelliert" => "watercolor techniques applied",
"blau" => "blue",
"braun" => "brown",
"farbig" => "color",
"farbig-hellblau" => "color, light blue",
"farbig-rötlich" => "color, reddish",
"farbig-zweifarbig" => "bicolor",
"farbig-dreifarbig" => "tricolor",
"farbig-vierfarbig" => "four-color",
"grau" => "grey",
"grauer Grundton" => "grey basic tint",
"grün" => "green",
"hellgrüner Grundton" => "light green basic tint",
"koloriert" => "colored",
"mit Kreiden überarbeitet" => "retouched with chalk",
"sepia" => "sepia",
"teilkoloriert" => "partly colored",
"weiss gehöht" => "highlighted with white", 
);

sub usage() {
    print "uploadZBS.pl is a script to upload files from the Solothurn central library.\n";
    print "\tuploadZBS --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --dbUsername=<MYSQL_USERNAME> --dbPassword=<MYSQL_PASSWORD>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<ID>                    Upload only this/these image(s)\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
    print "--overwrite                      Force re-upload of picture\n";
    print "--overwriteDescriptionOnly       Force re-upload of the description\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'dbUsername=s' => \$dbUsername,
	   'dbPassword=s' => \$dbPassword,
	   'directory=s' => \$pictureDirectory,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'overwrite' => \$overwrite,
	   'overwriteDescriptionOnly' => \$overwriteDescriptionOnly,
	   'filter=s' => \@filters,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$pictureDirectory || !$dbUsername || !$dbPassword) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n\t--dbUsername=<MYSQL_USERNAME>\n\t--dbPassword=<MYSQL_PASSWORD>\n";
    exit;
};

unless (-d $pictureDirectory) {
    die "'$pictureDirectory' seems not to be a valid directory.";
}

unless ($delay =~ /^[0-9]+$/) {
    die "The delay '$delay' seems not valid. This should be a number.";
}

# Check connections to remote services
connectToCommons();

# Select all images from the database
$dbh = DBI->connect("DBI:mysql:database=zbs;host=localhost;port=3306", $dbUsername, $dbPassword, { RaiseError => 1 }) 
    or die "Connection impossible à la base de données 'zbs' !\n $! \n $@\n$DBI::errstr"; 
my %images; 
my $prep = $dbh->prepare('SELECT * FROM  zbsolothurn_grafiksammlung_metadaten') or die $dbh->errstr; 
$prep->execute() or die "Unable to execute SQL select request\n"; 
while (my $image = $prep->fetchrow_hashref()) { 
    $images{$image->{'id_we'}} = $image; 
} 
$prep->finish(); 

# Go through all images
foreach my $imageId (keys(%images)) {
    my $image = $images{$imageId};

    # Check the filter
    if (!$image->{'we_signatur'} && !scalar(@filters) || 
	$image->{'we_signatur'} && scalar(@filters) && !(grep {$_ eq $image->{'we_signatur'}} @filters)) {
	next;
    }

    # Get image path
    unless (exists($imgs{ $image->{'we_signatur'} })) {
	print STDERR "Unable to match ".$image->{'we_signatur'}."\n";
	exit 1;
    }

    my $filename = $imgs{ $image->{'we_signatur'} } ;
    $filename =~ s/^(a+)(\d+)$/$1_$2/;
    $filename = "$pictureDirectory$filename";#.tif";
    unless ( -e $filename) {
	print STDERR "Unable to find '".$image->{'we_signatur'}."' corresponding file path.\n";
	next;
    } else {
	printLog("'".$image->{'we_signatur'}."' matchs file '".$filename."'");
    }

    # Compute metadata;
    my %metadata;
    $metadata{'sysid'} = $image->{'we_signatur'};
    $metadata{'author'} = $image->{'we_kuenstler1'}.($image->{'we_kuenstler2'} ? ",<br/>".$image->{'we_kuenstler2'} : "");
    $metadata{'other_field_1'} = ($image->{'we_stecher'} ? "{{Information field|name=Engraver|value=".$image->{'we_stecher'}."}}" : "").
	($image->{'we_verleger'} ? "{{Information field|name=Publisher|value=".$image->{'we_verleger'}."}}" : "");
    $metadata{'title'} = $image->{'we_titel'};
    $metadata{'description'} = $image->{'we_inhalt'};
    $metadata{'date'} = $image->{'we_ez_jahr2'} ? "{{other date|between|".$image->{'we_ez_jahr1'}."|".$image->{'we_ez_jahr2'}."}}" : $image->{'we_ez_jahr1'};
    if (exists($technique{lc($image->{'we_technik'})}) && exists($techniqueAttribute{lc($image->{'we_technikattribut'})})) {
	$metadata{'medium'} = "{{Technique|1=".$technique{lc($image->{'we_technik'})}."|2=paper|adj=".$techniqueAttribute{lc($image->{'we_technikattribut'})}."}}";
    } else {
	$metadata{'medium'} = $image->{'we_technik'}.($image->{'we_technikattribut'} ? ", ".$image->{'we_technikattribut'} : "");
    }
    $metadata{'dimensions'} = "{{Size|unit=cm|width=".$image->{'we_bild_breite'}."|height=".$image->{'we_bild_hoehe'}."}}";
    $metadata{'other_field_2'} = ($image->{'we_formalsw'} ? "{{Information field|name=ZBS form heading|value=".$image->{'we_formalsw'}."}}" : "").
	($image->{'we_formalsw2'} ? ", {{Information field|name=ZBS form heading|value=".$image->{'we_formalsw2'}."}}" : "");

    # Compute new filename
    my $newFilename = $metadata{'title'};
    utf8::encode($newFilename);
    utf8::decode($newFilename);
    $newFilename =~ s/ /_/g;
    $newFilename =~ s/[^\w]//g;
    $newFilename = substr($newFilename, 0, 190);
    $newFilename = "Zentralbibliothek_Solothurn_-_".$newFilename."_-_".$metadata{'sysid'}.".tif";
    $newFilename =~ s/ /_/g;
    $newFilename =~ s/[_]+/_/g;
    $newFilename =~ s/Milizen_Milices_de_Soleure_Unter_Bild_Bezeichnungen_der_Dargestellten_Frei_Corps_Jäger_z_Pferd_Corpsfranc_Chasseurs_à_cheval_Lieutenant_Escadron//g;
    $newFilename =~ s/Olten_OLTEN_Ville_dans_le_Canton_de_Soleure_du_Côté_du_Midi_A_Dunneren_Riviere_B_Château_de_Wartenfels_//g;
    $newFilename =~ s/l_NÔTRE_DAME_DE_LA_PIERRE_Dans_le_Canton_de_Soleure_du_Côté_du_Septentrion_A_Chapelle_de_Ste_Anne_B_Masure_de_Rotberg_//g;
    $newFilename =~ s/CHÂTEAU_DE_THIERSTEIN_Dans_le_Canton_de_Soleure_du_Côté_du_Sptentrion_A_Lisel_Riwiere_B_Erschweil_//g;
    $newFilename =~ s/_Vorsteherin_des_Convents_der_barmherzigen_Schwestern_im_Brgerspital_zu_Solothurn_geboren_den_25ten_May_1783_trat_in_den_Spital_zum_Krankendienst_den_5ten_Januar_1799//g;
    $newFilename =~ s/_19_Zeilen_Solothurn_den_26_Merz_1777_Laurenz_Joseph_Wirz_Notarius_dieser_Zeit_Schaffner//s;
    $newFilename =~ s/On_decouvre_dans_le_lointain_le_château_de_Blauenstein_ainsi_que_la_Cluse_et_partie_du_village_de_ce_non_défilé_célèbre_et_très_étroit_au_travers_du_Jura_qui_termine_la_Vallée_de_Ballsthall_et_par_ou_passe_la_grande_route_de_Basle_à_Soleure_Berne_c_//s;
    $newFilename =~ s/_à_Monsieur_le_Baron_de_Besenval_grand_Croix_de_lordre_Royal_et_militaire_de_S_Louis_Lieutenant_général_des_Armées_du_Roi_et_Lieutenant_Colonel_du_Regiment_des_Gardes_Susses_de_sa_majesté_A_P_D_R//s;

    printLog("New filename for ".$metadata{'sysid'}." is ".$newFilename);

    # Preparing description
    my $template = HTML::Template->new(scalarref => \$templateCode);
    $template->param(TITLE=>$metadata{'title'});
    $template->param(AUTHOR=>$metadata{'author'});
    $template->param(DESCRIPTION=>$metadata{'description'});
    $template->param(DATE=>$metadata{'date'});
    $template->param(SYSID=>$metadata{'sysid'});
    $template->param(MEDIUM=>$metadata{'medium'});
    $template->param(DIMENSIONS=>$metadata{'dimensions'});
    $template->param(OTHER_FIELD_1=>$metadata{'other_field_1'});
    $template->param(OTHER_FIELD_2=>$metadata{'other_field_2'});
    my $description = $template->output();

    # local check if already done
    my $doneFile = $filename.".done";
    if (-f $doneFile) {
	if ( !$overwrite && !$overwriteDescriptionOnly ) {
	    printLog("'File:$newFilename' already exists in Wikimedia Commons, it was ignores. Use --overwrite to force the re-upload.");
	    next;
	}
    }

    # Connect to Wikimedia Commons
    my $commons = connectToCommons();
    printLog("Successfuly connected to Wikimedia Commons.");

    my $doesExist = $commons->exists("File:$newFilename");
    if (!$doesExist || $overwrite || $overwriteDescriptionOnly) {

	my $status;
	my $content = readFile($filename);

	if (!$doesExist) {
	    printLog("'$newFilename' uploading...");
	    $status = $commons->uploadImage($newFilename, $content, $description, "GLAM Solothurn central library picture' ".$metadata{'sysid'}."' (WMCH)", 0);
	} elsif ($doesExist && $overwrite) {
	    printLog("'$newFilename' already uploaded but will be overwritten...");
	    $status = $commons->uploadImage($newFilename, $content, $description, "GLAM Solothurn central library picture' ".$metadata{'sysid'}."' (WMCH)");
	} elsif ($doesExist && $overwriteDescriptionOnly) {
	    printLog("'$newFilename' already uploaded but will description will be overwritten...");
	    $status = $commons->uploadPage("File:".$newFilename, $description, "Description update...");
	}
	
	print $status."\n";

	if ($status) {
	    printLog("'$newFilename' was successfuly uploaded to Wikimedia Commons.");
	    writeFile($doneFile, "");
	} else {
	    die "'$newFilename' failed to be uploaded to Wikimedia Commons.\n";
	}
    } else {
	printLog("'File:$newFilename' already exists in Wikimedia Commons, it was ignores. Use --overwrite to force the re-upload.");
	writeFile($doneFile, "");
    }
    
    # Wait a few seconds
    if ($delay) {
	printLog("Waiting $delay s...");
	sleep($delay);
    }
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    utf8::encode($data);
    utf8::encode($file);
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    utf8::encode($file);
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    utf8::decode($data);
    return $buf;
}

# Setup the connection to Mediawiki
sub connectToCommons {
    my $site = Mediawiki::Mediawiki->new();
    $site->hostname($commonsHost);
    $site->path("w");
    $site->user($username);
    $site->password($password);

    my $connected = $site->setup();
    unless ($connected) {
	die "Unable to connect with this username/password to $commonsHost.";
    }

    return $site;
}

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	utf8::encode($message);
	print "$message\n";
    }
}
