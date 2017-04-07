package Paperwork::Schema::Result::Document;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('documents');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    doc_date => {
        data_type => 'datetime',
    },
    expire_date => {
        data_type => 'datetime',
        is_nullable => 1,
    },
    category => {
        data_type => 'varchar',
        size => 255,
    }
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('pages' => 'Paperwork::Schema::Result::Page', 'document_id');

1;
