package Paperwork::Model;

use strict;
use warnings;
use IPC::Run 'start';
use Path::Class 'dir';
use Time::HiRes 'time', 'stat';

use Moo;
use DateTime;

use Paperwork::Schema;

has 'config' => (is => 'ro', lazy => 1);
has 'schema' => (is => 'ro', lazy => 1, builder => '_build_schema');

sub _build_schema {
    my ($self) = @_;

    # my $dsn = 'dbi:SQLite:' . $self->config->{db}{dbfile};
    my @dsn = ( $self->config->{db}{dsn},
                $self->config->{db}{pg_user},
                $self->config->{db}{pg_pass} );
    my $schema= Paperwork::Schema->connect(@dsn);
    $schema->deploy if(!-e "paperwork.db");
    return $schema;
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

    # mutate the datetime into a string.. (?!) else json convert barfs
    $scan->discard_changes;
    
    my $dir = dir($scan->path);
    if(-e $scan->path) {
        warn "$dir already exists!";
        return { error => "$dir already exists!" };
    }
    $dir->mkpath;
    
    my @command = @{ $self->config->{scan}{command} };
    print STDERR Data::Dumper::Dumper(\@command);
    # FIXME: This doesn't really provide a nice way of seeing errors,
    # keeping the user apprised of progress, etc.
    # start ['scanimage',
	#    '--verbose',
	#    '--mode' => 'Color', 
	#    '--device-name' => 'fujitsu:fi-5110Cdj:102493',
	#    '--progress',
	#    '--format' => 'tiff',
	#    '--batch',
	#    '--ald', # automatic length detection
	#    '--source' => 'ADF Duplex',
	#    '--sleeptimer' => 5],
    start([ @command ],
	  '<',  '/dev/null',               #stdin
          '>',  "".$dir->file('stdout.log'),  #stdout
          '2>', "".$dir->file('stderr.log'),  #stderr
          init => sub {
              chdir "$dir" or die $!;
          }
        );
    
    $scan->update({ status => 'running' });

    return $scan;
}

=head2 is_finished

Check if the scan has finished -- a well-finished scan will end with a
line telling us the feeder ran out of things to scan.  To stop
badly-ended scans from showing up as unfinished forever, the scan is
also considered finished if no files (including the log!) have changed
in the last minute-and-a-bit.

=cut

sub is_finished {
    my ($self, $scan) = @_;

    my $dir = dir($scan->path);

    if (-e $dir->file('stderr.log')) {
	open my $infh, '<', $dir->file('stderr.log') or die;
	my $lastline = (<$infh>)[-1];
	return 1 if $lastline eq "scanimage: sane_start: Document feeder out of documents\n";
    }
    
    my @files = $dir->children(no_hidden => 0);
    foreach my $file (@files) {
        my $stat = $file->stat;
	if (!$stat) {
	    # The file seemed to have vanished between our call to
	    # ->children and ->stat.  This is probably a .part file
	    # that has just been finished and renamed to be a real
	    # little boy.  In any case, it means it's not all finished
	    # quite yet.
	    return 0;
	}
	my $mtime = time() - $stat->mtime;
	print "File $file: $mtime sec old\n";
        return 0 if $mtime <= 65;
    }

    return 1;
}

=head2 get_status_and_pages

Look up a scan row based on the given id.. barf if not found.. else
return { status => 'xxx', pages => [] }

=cut

sub get_status_and_pages {
    my ($self, $scan_id) = @_;

    my $scan = $self->schema->resultset('Scan')->find({ id => $scan_id });

    ## !?
    return if !$scan;

    ## look for pages on disk in $scan->path
    ## add/update $scan->pages we found that are finished
    ## set status to 'done' if... process gone away?


    if($self->is_finished($scan)) {
        $scan->update({ status => 'done' });
    }
    
    my $dir = dir($scan->path);
    for my $file ($dir->children(no_hidden => 1)) {
	next unless $file->basename =~ m/^out\d+\.tif$/;
	$scan->pages->update_or_create({
	    status => 'new',
	    image_path => $file->stringify,
				       });
    }

    return { id => $scan->id, 
	     status => $scan->status, 
	     pages => [ map { +{ $_-> get_columns } } $scan->pages ]
    };
}

sub create_document {
}

1;
