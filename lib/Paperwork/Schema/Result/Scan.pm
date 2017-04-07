package Paperwork::Schema::Result::Scan;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('scans');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    path => {
        data_type => 'varchar',
        size => 255,
    },
    started_date => {
        data_type => 'date',
    },
    status => {
        data_type => 'varchar',
        size => 20,
    }
);

__PACKAGE__->set_primary_key('id');


__PACKAGE__->has_many('pages' => 'Paperwork::Schema::Result::Page', 'scan_id');

1;
