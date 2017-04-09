#!/usr/bin/env perl

package Paperwork::Web;

use strict;
use warnings;

use Web::Simple;
use Template;
use JSON;
use Data::Dumper;
use Path::Class;
use lib 'lib';

use Paperwork::Model;

has 'app_cwd' => ( is => 'ro', default => sub {'/usr/src/perl/paperwork/'});
has 'tt' => (is => 'ro', lazy => 1, builder => '_build_tt');
has 'config' => (is => 'ro',
                 lazy => 1,
                 default => sub {
                     my ($self) = @_;
                     +{Config::General->new($self->app_cwd."/paperwork.conf")->getall};
                 });
has 'model' => ( is => 'ro',
                 lazy => 1,
                 default => sub {
                     my ($self) = @_;
                     return Paperwork::Model->new({ config => $self->config });
                 }
    );

sub _build_tt {
    my ($self) = @_;

    return Template->new({ 
        INCLUDE_PATH => dir($self->app_cwd)->subdir('templates')->stringify,
                         });
}

sub dispatch_request {
    my ($self, $env) = @_;

    ## Scan-some-things display page - clicky button to start new scan, list scans?
    sub (GET + /scan) {
        my ($self) = @_;

        return [ 200, ['Content-type', 'text/html' ], [ $self->tt_process('scanpage.tt') ] ];
    },
    ## Post here to start new scan:
    sub (POST + /scan/) {
        my ($self) = @_;

        my $scan = $self->model->start_scan();
        return [ 200, ['Content-type', 'application/json' ], [ encode_json({ $scan->get_columns } ) ] ];
    },
    ## Post here to query scan status, returns if running and list of scanned pages
    sub (POST + /scan/ + %id=) {
        my ($self, $scan_id) = @_;

        my $result = $self->model->get_status_and_pages($scan_id);

        return [ 200, ['Content-type', 'application/json' ], [ encode_json($result) ] ];
    },
    ## Post here to create document
    sub (POST + /documents/ + %doc_date=&category=) {
        my ($self, $doc_date, $category) = @_;

        my $new_doc = $self->model->create_document($doc_date, $category);
        return [ 200, ['Content-type', 'application/json' ], [ encode_json({ $new_doc->get_columns } ) ] ];
        
    }

}

sub tt_process {
    my ($self, $page, %vars) = @_;

    my $nav = [
        {name => 'Scan', link => '/scan'},
        {name => 'Documents', link => '/documents'},
    ];
    
    my $output;
    $self->tt->process($page, {
#        static_uri => $self->static_url,
#        host       => $self->host,
#        base_uri   => $self->base_uri,
        nav_menu   => $nav,
        %vars,
                       }, \$output) || die $self->tt->error;

#    print STDERR "Homepage: $output\n";
    return $output;    
}


Paperwork::Web->run_if_script;
