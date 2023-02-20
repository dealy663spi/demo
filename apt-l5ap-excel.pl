#!/usr/bin/perl
use strict;
use lib "/local/perllib/libs";
use lib "/local/jirautil/libs";

use Local::HTMLUtil;
use Local::Encode;
use LWP::UserAgent;
use IO::Socket::SSL;
use Local::AuthSrv;
use JSON;
use Sys::Hostname;
use Text::CSV;
use Excel::Writer::XLSX;
use Text::Wrap;
use Image::Magick;
use Digest::SHA qw(sha1_hex);
use Local::ADSObject;

use Local::AppTemplate;
use JIRAUtil;

my $html = new Local::AppTemplate();

&HTMLContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
&HTMLGetRequest();

my $json     = new JSON;
my $jirautil = new JIRAUtil;
my $jirahost = $jirautil->jirahost();

my $url = "https://${jirahost}/rest/api/2/field";
my $ua  = $jirautil->ua();

my $req = HTTP::Request->new( GET => $url );
$jirautil->jira_authorization($req);

my $res = $ua->request($req);
if ( !$res->is_success ) {
    $html->ErrorExit("Failed to load JIRA field info");
    exit;
}
my $info = decode_json( $res->content );

my %field_name2id = ();
my %field_id2name = ();
foreach my $fref ( @{$info} ) {
    my $id   = $fref->{id};
    my $name = $fref->{name};
    $field_name2id{$name} = $id;
    $field_id2name{$id}   = $name;
}

#
# Get subcomponent tree
#
my $req = HTTP::Request->new(
    GET => "https://${jirahost}/rest/api/com.deniz.jira.mapping/latest/componentHierarchy?projectKey=INT" );
$jirautil->jira_authorization($req);

my $res = $ua->request($req);
if ( !$res->is_success ) {
    print "<h3>Query Failure</h3><pre>", $res->as_string, "</pre>\n";
    exit;
}

my $content = $res->content;
my $data    = decode_json($content);

my @comp_cols   = ();
my %comp_to_col = ();
foreach my $top_comp ( @{ $data->[0]->{children} } ) {
    my $name = $top_comp->{name};
    push( @comp_cols, $name );

    foreach my $cref ( @{ $top_comp->{children} } ) {
        my $cname = $cref->{name};
        $comp_to_col{$cname} = $name;
    }
}

#
# Cache dir - needs to be created ahead of time
#
my $img_cache = "/spirent/primary/jirautil/image-cache";

#
# Build up query filter
#

# Default hardcoded - was same as 70990 at one point
my $filter = qq{
project = "INT" AND fixVersion in (8.4.0, "5GC R2", "5GC R3") AND issuetype in (story) AND priority in (0-ASAP)
};

my $filter_id = int( $rqpairs{filter} ) || 70990;
if ($filter_id) {
    $filter = "project=\"INT\" AND filter in (" . int($filter_id) . ")";
}
$filter .= " order by fixVersion";

my $cf_fix = $field_name2id{"Fix"};

my $url = "https://${jirahost}/rest/api/2/search?startAt=0&jql=";
$url .= &Encode_URLEncode($filter);
$url .= "&maxResults=1000";
$url .= "&fields=issuetype,priority,summary,status,fixVersions,description,attachment,components,$cf_fix";

my $req = HTTP::Request->new( GET => $url );
$jirautil->jira_authorization($req);

my $res = $ua->request($req);
if ( !$res->is_success ) {
    print "<h3>Query Failure</h3><pre>", $res->as_string, "</pre>\n";
    exit;
}

my $content = $res->content;
my $data    = decode_json($content);

binmode(STDOUT);
my $excel = Excel::Writer::XLSX->new( \*STDOUT );
my $ws    = $excel->add_worksheet();

my @out_cols = ( "Fix Version/s", "Summary", "Description", "Test Diagram", "SUT", "Category" );
foreach my $col (@comp_cols) {
    push( @out_cols, $col );
}

my $ridx = 0;

my %widths = (
    "_default"                           => 20,
    "Fix Version/s"                      => 15,
    "Summary"                            => 40,
    "Description"                        => 50,
    "SUT"                                => 10,
    "Category"                           => 15,
    "Test Type"                          => 15,
    "Mode"                               => 15,
    "DMF"                                => "",
    "TDF"                                => "",
    "POLQA"                              => "",
    "MultiNodal"                         => "",
    "Topology"                           => 40,
    "Landslide Test Server Requirements" => 15,
    "Landslide Application License"      => 15,
    "Landslide Feature License"          => 15,
    "Test Diagram"                       => 60,
);

my $hdrfmt = $excel->add_format();
$hdrfmt->set_bold();
$hdrfmt->set_bg_color('silver');

my $infofmt = $excel->add_format();
$infofmt->set_valign('top');

my $wrapinfofmt = $excel->add_format();
$wrapinfofmt->set_valign('top');
$wrapinfofmt->set_text_wrap(1);

$ws->freeze_panes( 1, 2 );

foreach my $cidx ( 0 .. $#out_cols ) {

    my $lbl = $out_cols[$cidx];
    $lbl =~ s/ /\n/sgmo;

    $ws->write( $ridx, $cidx, $lbl, $hdrfmt );
    my $wid = $widths{ $out_cols[$cidx] } || $widths{"_default"};
    $ws->set_column( $cidx, $cidx, $wid );
}
$ws->set_row( $ridx, 45 );

$ridx++;

# Skip first row to make watermark not overwrite
$ws->set_row( $ridx, 250 );
$ridx++;

foreach my $issue ( @{ $data->{issues} } ) {

    my $id   = $issue->{key};
    my $type = $issue->{fields}->{issuetype}->{name};
    my $summ = $issue->{fields}->{summary};
    my $fix  = $issue->{fields}->{$cf_fix};
    my $desc = $issue->{fields}->{description};
    my $prio = $issue->{fields}->{priority}->{name};

    my %comps_by_col = ();
    foreach my $cref ( @{ $issue->{fields}->{components} } ) {
        my $name = $cref->{name};
        my $col  = $comp_to_col{$name};
        if ($col) {
            push( @{ $comps_by_col{$col} }, $name );
        }
    }

    my @fixver;
    foreach my $fver ( @{ $issue->{fields}->{fixVersions} } ) {
        push( @fixver, $fver->{name} );
    }

    my $cat;
    my $sut;
    if ( $summ =~ /^([IAE])-(.*)-.*?-(PF|CO|CP)[-_]/ ) {
        $cat = $1;
        if ( $cat eq "I" ) {
            $cat = "Nodal";
        }
        elsif ( $cat eq "A" ) {
            $cat = "Adjacent";
        }
        elsif ( $cat eq "E" ) {
            $cat = "End-to-End";
        }
        $sut = $2;
    }

    my $img_name;
    my $img_ref;
    my $img_url;
    my $img_ext;
    my $img_hash;
    my $img_prefix = $id;
    foreach my $aref ( @{ $issue->{fields}->{attachment} } ) {
        my $fname   = $aref->{filename};
        my $img_ref = "!" . $fname . "!";

        if ( $fname =~ /\.(png|jpg)$/i ) {
            $img_ext = lc $1;
        }
        else {
            next;
        }

        my $refpat = quotemeta($img_ref);
        if ( $desc =~ /$refpat/sgm ) {
            $desc =~ s/$refpat//sgm;
            $img_name = $fname;
            $img_url  = $aref->{content};
            my $img_ctime = $aref->{created};

            $img_hash = sha1_hex( $img_url . $img_ctime . $img_name );
            last;
        }
    }

    $desc =~ s/\r\n/\n/sgmio;

    $desc =~ s/[^[:ascii:]]//g;

    $desc =~ s/\|\s*$//sgmo;
    $desc =~ s/^\s*\|//sgmo;

    #$desc = wrap( '', '  ', $desc );

    # Diagnostic only
    #$summ = $id . ": " . $summ;

    my @row = ( join( " \n", sort @fixver ), $summ, $desc, "", $sut, $cat );
    foreach my $col (@comp_cols) {
        my @comps;
        eval { @comps = sort @{ $comps_by_col{$col} }; };
        push( @row, join( " \n", @comps ) );
    }
    foreach my $cidx ( 0 .. $#row ) {
        $ws->write( $ridx, $cidx, $row[$cidx], $wrapinfofmt );
    }

    # Img = Col 3
    if ($img_url) {
        my $img_geometry = "400x300";
        my $content;

        my $cache_fn   = "$img_cache/$img_prefix-$img_hash.$img_ext";
        my $resized_fn = "$img_cache/$img_prefix-$img_hash.resized_${img_geometry}.$img_ext";
        if ( !-e $cache_fn ) {
            my $img_req = HTTP::Request->new( GET => $img_url );
            $jirautil->jira_authorization($img_req);

            my $res = $ua->request($img_req);
            if ( !$res->is_success ) {
                print "<h3>Query Failure</h3><pre>", $res->as_string, "</pre>\n";
                exit;
            }

            $content = $res->content;
            open( my $out, ">$cache_fn" );
            print $out $content;
            close($out);
        }

        if ( !-e $resized_fn ) {
            my $image = Image::Magick->new();
            $image->Read($cache_fn);
            $image->Resize( geometry => $img_geometry );
            $image->Write($resized_fn);
        }

        $ws->insert_image( $ridx, 3, $resized_fn, 5, 5, 1, 1 );
    }

    my @desclines = split( /[\n\r]/, $desc );
    my $lines     = scalar(@desclines);
    if ( $lines < 2 ) { $lines = 2; }

    my $height = 15 * $lines;
    if ( $img_url && $height < 250 ) {
        $height = 250;
    }

    $ws->set_row( $ridx, $height );
    $ridx++;
}

# Look up name of generator

my $ads = new Local::ADSObject(
    server => "spczoadc01.ad.spirentcom.com",
    domain => "ad.spirentcom.com",
    user   => "jira",
    ssl    => 1
);
my $info      = $ads->GetAttributes( $ENV{REMOTE_USER} );
my $user_name = $ENV{REMOTE_USER};
eval { $user_name = $info->{displayName}->[0]; };

$ws->write( 1, 1, "Generated at: " . scalar( gmtime(time) ) . " UTC \nby: ${user_name}", $wrapinfofmt );

# Make sure on top
$ws->insert_image( 0, 2, "/local/jirautil/html/nda-watermark.png", 50, 50, 5, 5 );

$ws->autofilter( 0, 0, $ridx, scalar(@out_cols) - 1 );

$excel->close();
