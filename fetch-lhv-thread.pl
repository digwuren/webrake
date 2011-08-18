#! /usr/bin/perl -w

# Rough.

use strict;
use LWP::UserAgent;
use Encode;
use HTML::TreeBuilder;

my $ua = new LWP::UserAgent;

our $datadir = 'lhv-data';
our $posts_per_page = 50;
our $threadid = 121915; # The Canonical Jaikthread

sub fetch_page ($$) {
    my ($threadid, $pageno) = @_;
    my $url = "https://fp.lhv.ee/forum/threadView?listEventId=jumpToPage&listEventParam=$pageno&topic=forum_topic.free&threadId=$threadid&ajax=&containerId=";

    my $response = $ua->get($url);
    die $response->status_line unless $response->is_success;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($response->decoded_content);
    $tree->eof;

    my @posts = $tree->look_down('_tag' => 'div', 'id' => qr/^post_\d+$/);

    for my $i (0 .. $#posts) {
        my $postno = 1 + $pageno * $posts_per_page + $i;
        my $post = $posts[$i];
        my $fh;
        my $fnr = sprintf "%i-%05i", $threadid, $postno;
        open $fh, '>', "$datadir/$fnr.htmlf"
            or die "$datadir/$fnr.htmlf: open for writing: $!";
        print $fh Encode::encode('utf-8', $post->as_HTML);
        close $fh;
        my $author = $post->parent->look_down('_tag' => 'a', 'href' => qr{^/forum/userPreference\?});
        open $fh, '>', "$datadir/$fnr.author"
            or die "$datadir/$fnr.author: open for writing: $!";
        print $fh Encode::encode('utf-8', $author->as_text);
        close $fh;
    }

    my $post_count = @posts;
    $tree->delete;
    return $post_count;
}

for my $pageno (0 .. 162) {
    my $page_present = 1;
    for my $i (0 .. $posts_per_page - 1) {
        my $postno = 1 + $pageno * $posts_per_page + $i;
        my $fnr = sprintf "%i-%05i", $threadid, $postno;
        unless (-e "$datadir/$fnr.author") {
            $page_present = 0;
            last;
        }
    }
    if ($page_present) {
        print "Page #$pageno has already been fetched\n";
    } else {
        my $post_count = fetch_page $threadid, $pageno;
        print "Fetched page #$pageno; got $post_count post(s)\n";
    }
}
