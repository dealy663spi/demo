#!/usr/bin/perl

use lib "/local/perllib/libs";
use lib "/local/jirautil/libs";

use Local::HTMLUtil;
use Local::Encode;
use LWP::UserAgent;
use IO::Socket::SSL;
use Local::AuthSrv;
use JSON;
use Sys::Hostname;

use Local::AppTemplate;
use JIRAUtil;

my $html = new Local::AppTemplate(
    title   => "APT Issue Changers",
    app_url => "/auth-cgi-bin/cgiwrap/jirautil/index.pl",
);

&HTMLContentType("text/html");
&HTMLGetRequest();

$html->PageHeader();

my $jirautil = new JIRAUtil;
my $jirahost = $jirautil->jirahost();

#
# SHOULD VALIDATE ACCESS TO APT PROJECTS
#

my $days = int( $rqpairs{days} );

if ( !$days ) {
    $days = 7;
    if ( $jirahost =~ /-qa/ ) {
        $days = 60;
    }
}

my $state = "PV Validation";

my $filter = qq{

project in ("Spirent iTest", "Resource Manager", "Integration Engineering") AND
type=Defect AND status changed from ("Open", "In Progress", "Code Review", "Reopened") to "${state}" after -${days}d

};

# This is technically unsafe, but controlled audience and limited access even if they
# did a injection into the search

my $add_filter = $rqpairs{filter};
if ($add_filter) {
    $filter .= " AND ($add_filter)";
}

&HTMLStartForm( &HTMLScriptURL, "GET" );
$html->StartBlockTable( "Customize Search", 500 );
print "Additional Search Filter (AND):\n";
&HTMLTextArea( "filter", $add_filter, 60, 5 );
print "<br>\n\n";
print "Days: ";
&HTMLInputText( "days", 10, $rqpairs{days} );
print " ";
&HTMLSubmit("Search");
$html->EndBlockTable();
&HTMLEndForm();
print "<p>\n";

my $url = "https://${jirahost}/rest/api/2/search?startAt=0&jql=";
$url .= &Encode_URLEncode($filter);
$url .= "&maxResults=$max";
$url .= "&expand=changelog";
$url .= "&fields=issuetype,summary,status,assignee,reporter";

my $ua = $jirautil->ua();

my $req = HTTP::Request->new( GET => $url );
$jirautil->jira_authorization($req);

my $res = $ua->request($req);
if ( !$res->is_success ) {
    print "<h3>Query Failure</h3><pre>", $res->as_string, "</pre>\n";
    exit;
}

my $content = $res->content;
my $data    = decode_json($content);

if ( $rqpairs{"debug"} eq "on" ) {
    my $json = new JSON;
    print "<pre>", $json->pretty->encode($data), "</pre>\n";
}

$html->StartBlockTable("Changed to State [$state] in Last $days Days");
$html->StartInnerTable( "Issue", "Summary", "Assignee", "Change", "Current", "Changed By", "Changed" );

my %change_counts = ();

foreach my $issue ( @{ $data->{issues} } ) {
    my $id       = $issue->{key};
    my $type     = $issue->{fields}->{issuetype}->{name};
    my $summ     = $issue->{fields}->{summary};
    my $assign   = $issue->{fields}->{assignee}->{displayName};
    my $reporter = $issue->{fields}->{reporter}->{displayName};
    my $status   = $issue->{fields}->{status}->{name};
    my ( $author, $cdate, $schange );

    foreach my $cref ( @{ $issue->{changelog}->{histories} } ) {
        foreach my $iref ( @{ $cref->{items} } ) {
            if ( $iref->{field} eq "status" && $iref->{toString} eq $state ) {

                # We only want the last one
                $author  = $cref->{author}->{displayName} || $cref->{author}->{name};
                $schange = $iref->{fromString} . " -&gt; " . $iref->{toString};
                $cdate   = $cref->{created};
                $cdate =~ s/T.*//go;
            }
        }

        next if ( !$schange );
    }

    if ($schange) {
        $html->StartInnerRow();

        print "<td><a href=\"", $jirautil->jira_link_id_to_issue($id), "\">$id</a></td>\n";
        print "<td width=300>", &Encode_HTMLEncode($summ), "</td>\n";
        print "<td>", $assign,  "</td>\n";
        print "<td>", $schange, "</td>\n";
        print "<td>", $status,  "</td>\n";
        print "<td>", $author,  "</td>\n";
        print "<td>", $cdate,   "</td>\n";
        $change_counts{$author}++;

        $html->EndInnerRow();
    }
}
$html->EndInnerTable();
$html->EndBlockTable();

print "<p>\n";

$html->StartBlockTable("Counts");
$html->StartInnerTable( "Changed by", "Count" );

foreach my $author ( sort( keys(%change_counts) ) ) {
    $html->StartInnerRow();
    print "<td>", $author, "</td>\n";
    print "<td align=right>", $change_counts{$author}, "</td>\n";
    $html->EndInnerRow();
}

$html->EndInnerTable();
$html->EndBlockTable();

$html->PageFooter();
