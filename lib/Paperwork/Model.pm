package Paperwork::Model;

use strict;
use warnings;
use IPC::Run 'start';

use Moo;
use DateTime;

use Paperwork::Schema;

has 'config' => (is => 'ro', lazy => 1);
has 'schema' => (is => 'ro', lazy => 1, builder => '_build_schema');

sub _build_schema {
    my ($self) = @_;

    # my $dsn = 'dbi:SQLite:' . $self->config->{Setup}{dbfile};
    my @dsn = ( $self->config->{Setup}{dsn},
                $self->config->{Setup}{pg_user},
                $self->config->{Setup}{pg_pass} );
    Paperwork::Schema->connect(@dsn);
}

=head2 start_scan

Register a new scan process in the db, actually kick off the scan,
return the db obj.

=cut

sub start_scan {
    my ($self) = @_;

    my $next_scan = $self->schema->resultset('Scan')->get_column('id')->max + 1;

    ## verify $next_scan path doesnt exist already?
    my $scan = $self->schema->resultset('Scan')->create({
        started_date => DateTime->now(),
        path => $self->config->{scan}{path} . $next_scan,
        status => 'starting',
    });


    # FIXME: This doesn't really provide a nice way of seeing errors,
    # keeping the user apprised of progress, etc.
    start ['scanimage',
	   '--verbose',
	   '--mode' => 'Color', 
	   '--device-name' => 'fujitsu:fi-5110Cdj:102493',
	   '--progress',
	   '--format' => 'tiff',
	   '--batch',
	   '--ald', # automatic length detection
	   '--source' => 'ADF Duplex',
	   '--sleeptimer' => 5],
	undef,  # stdin
	'>', 'stdout.log', #stdout
	'>', 'stderr.log'; #stderr
    
	
    ## actually start the scan using the path:

    $scan->update({ status => 'running' });

    return $scan;
}

=head2 get_status_and_pages

Look up a scan row based on the given id.. barf if not found.. else
return { status => 'xxx', pages => [] }

=cut

sub get_status_and_pages {
    my ($self, $scan_id) = @_;

    my $scan = $self->schema->resultet('Scan')->find({ id => $scan_id });

    ## !?
    return if !$scan;

    ## look for pages on disk in $scan->path
    ## add/update $scan->pages we found that are finished
    ## set status to 'done' if... process gone away?

    return { status => $scan->status, pages => $scan->pages };
}

sub create_document {
}

1;
