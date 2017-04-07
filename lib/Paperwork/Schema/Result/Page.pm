package Paperwork::Schema::Result::Page;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('pages');
__PACKAGE__->add_columns(
    scan_id => {
        data_type => 'integer',
    },
    document_id => {
        data_type => 'integer',
        is_nullable => 1,
    },
    image_path => {
        data_type => 'varchar',
        size => 255,
    },
    status => {
        data_type => 'varchar',
        size => 20,
        is_nullable => 1,
    }
);

__PACKAGE__->set_primary_key('scan_id', 'image_path');
__PACKAGE__->belongs_to('scan' => 'Paperwork::Schema::Result::Scan', 'scan_id');
__PACKAGE__->belongs_to('document' => 'Paperwork::Schema::Result::Document', 'document_id');

1;
