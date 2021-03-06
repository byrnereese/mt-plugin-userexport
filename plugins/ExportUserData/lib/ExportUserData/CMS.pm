package ExportUserData::CMS;

use strict;
use warnings;
use MT 4;
use MT::Util qw( format_ts );
use CGI;

use Text::CSV;
my $csv = Text::CSV->new({ eol    => "\n",
                           binary => 1, });

sub start {
    my $app = shift;
    my $plugin = MT->component('exportuserdata');
    my $param = {};
    
    # First, the user can create a simple filter to whittle down the results.
    # The blog and status filters don't need any help to be created; only the Roles do.
    use MT::Role;
    my @all_roles = MT->model('role')->load( undef, { sort => 'name' });
    my @role_loop;
    foreach my $r (@all_roles) {
        push @role_loop, { role_id => $r->id, role_name => $r->name };
    }
    $param->{role_loop} = \@role_loop;

    my $tmpl = $plugin->load_tmpl('filter.mtml');
    return $app->build_page( $tmpl, $param );
}

sub sort {
    my $app = shift;
    my $q = $app->param;
    my $plugin = MT->component('exportuserdata');
    my $param = {};
    
    # Grab the values from the filter form so that we have them ready to use.
    my @blogs = $q->param('blogs');
    my @roles = $q->param('roles');
    $param->{authmethod} = $q->param('authmethod');
    $param->{status} = $q->param('status');

    # If "all" was selected from the blog or role selector, trash any other
    # option that may have been selected.
    if (@blogs[0] == 'all') {
        $param->{blogs} = '';
    }
    else {
        $param->{blogs} = join(',', @blogs);
    }

    if (@roles[0] == 'all') {
        $param->{roles} = '';
    }
    else {
        $param->{roles} = join(',', @roles);
    }
    
    # We need to create the custom field pieces ourself, because MT's custom
    # field tags don't make the basename available.
    my @fields = MT->model('field')->load({ obj_type => 'author', });
    my @cf_loop;
    foreach my $field (@fields) {
        push @cf_loop, { basename => $field->basename,
                         name     => $field->name,
                         description => $field->description,
                       };
    }
    $param->{cf_loop} = \@cf_loop;

    my $tmpl = $plugin->load_tmpl('sort-fields.mtml');
    return $app->build_page( $tmpl, $param );
}

sub export {
    my $app = shift;
    my $q = $app->param;
    my $plugin = MT->component('exportuserdata');
    my $param = {};

    # Collect all of the submitted values.
    my @blog_ids = split( /,/, $q->param('blogs') );
    my @role_ids    = split( /,/, $q->param('roles') );
    my $status   = $q->param('status');
    my @selected_fields = $q->param('field');

    # Fields are collected, but they are out of order. use the field-order to
    # resort them. But first, clean up field-order.
    my @sorted_fields = split(/\&?user-fields\[\]\=/, $q->param('field-order'));
    # This is the list of sorted, selected fields to export
    my @fields; 
    foreach my $field (@sorted_fields) {
        if ($field ne '') {
            if ( grep(/$field/, @selected_fields) ) {
                push @fields, $field;
            }
        }
    }

    #MT::log("Selected: @selected_fields");
    #MT::log("Sorted: @sorted_fields");
    #MT::log("And the insersection of sorted and selected: @fields");

    # Create the header row
    my @fields_copy = @fields;
    my @header;
    foreach my $field (@fields_copy) {
        # Remove the "customfield_" or "author_" precedent from the field name,
        # because it isn't important 
        $field =~ s/^customfield_(.*?)$/$1/;
        $field =~ s/^author_(.*?)$/$1/;
        push @header, $field;
    }
    my $data_header = _csv_row(@header);
    my $data; # Used (and reset) later, but if there is no data to export,
              # we need this definition.

    my $terms = {};
    if ($status) {
        $terms->{status} = $status;
    }
    
    my $start_header; # A boolean to know whether or not to send the "start download" header.

    my $iter = MT->model('author')->load_iter($terms);
    while ( my $author = $iter->() ) {
        my $data; # Used later, for the exported data
        # Associations are used for both the role and blog options. No need to
        # look them up for each request, so just do it once here.
        my @assoc = MT->model('association')->load({ author_id => $author->id, });

        my ($author_filter, $role_filter, $blog_filter);
        
        # There are no MT::Association records if this is a 3rd-party
        # authenticated or anonymous commenter. But, we want to export them, too.
        if ( $q->param('authmethod') eq '1' ) {
            $author_filter = 1;
            $role_filter = 1;
            $blog_filter = 1;
        }
        # If the status is "pending" or "disabled"  allow the author.
        if ( ($status == 3) || ($status == 2) ) {
            $author_filter = 1;
            $role_filter = 1;
            $blog_filter = 1;
        }
        elsif ( $status == '' ) { # "All" was selected for the status
            if ($author->type == 1) { # This is an MT author, so include them.
                $author_filter = 1;
            }
            $role_filter = 1;
            $blog_filter = 1;
        }

        foreach my $assoc (@assoc) {
            # Because there is an association record, we know this is an MT-native author.
            $author_filter = 1;

            # If specific roles were selected, compare them against this author's perms.
            if (@role_ids) { # @role_ids is true only if individual roles were selected (not "all")
                my $roleid = $assoc->role_id;
                if ( grep(/$roleid/, @role_ids) ) {
                    $role_filter = 1;
                }
                else {
                    $role_filter = 0;
                }
            }
            else { # "All" roles were selected, so the filter is true!
                $role_filter = 1;
            }
            
            # If specific blogs were selected, compare them against this author's perms.
            if (@blog_ids) { # @blog_ids is true only if individual blogs were selected (not "all")
                my $blogid = $assoc->blog_id;
                if ( grep(/$blogid/, @blog_ids) ) {
                    $blog_filter = 1;
                }
                else {
                    $blog_filter = 0;
                }
            }
            else { # "All" blogs were selected, so the filter is true!
                $blog_filter = 1;
            }
        }
        # System administrators don't necessarily have roles attached to them,
        # but since they have total control, then need to be exported.
        my @perms = MT->model('permission')->load({ author_id => $author->id, });
        PERMISSIONS:foreach my $perm (@perms) {
            if ($perm->permissions =~ /'administer'/) {
                $role_filter = 1;
                $blog_filter = 1;
                last PERMISSIONS; # This lets us exit the foreach as soon as
                                  # the "administer" permission is found. No
                                  # need to keep checking rows.
            }
        }

        my ($field, @detail);
        if ($author_filter && $role_filter && $blog_filter) {
            foreach $field (@fields) {
                # Reset variables just in case there isn't any result to match this $field.
                my ($val, $basename, $ts, $assoc, @roles, $role, $perm, @blogs, $blog);

                if ($field =~ /^customfield_(.*?)$/) {
                    #MT::log("This is a custom field: $field");
                        $basename = 'field.' . $1;
                        $val = $author->$basename;
                }
                elsif ($field eq 'author_userpic_asset_id') {
                    # This is the userpic. Check that there is an ID in the userpic_asset_id field
                    # for this user before trying to grab the asset.
                    if ($author->userpic_asset_id) {
                        my $asset = MT->model('asset')->load( $author->userpic_asset_id );
                        # Just return the userpic URL.
                        $val = $asset->url;
                    }
                }
                elsif ($field eq 'author_status') {
                    # Rather than returning a meaningless number, return meaningful text!
                    $val = $author->status;
                    if ($val == 1) {
                        $val = 'Enabled';
                    }
                    elsif ($val == 2) {
                        $val = 'Disabled';
                    }
                    elsif ($val == 3) {
                        $val = 'Pending';
                    }
                }
                elsif ($field eq 'author_created_on_date') {
                    # The date/time needs to be easily readable.
                    $ts = $author->created_on;
                    $val = format_ts( 
                                "%Y-%m-%d", $ts, undef,
                                $app->user ? $app->user->preferred_language : undef );
                }
                elsif ($field eq 'author_created_on_time') {
                    # The date/time needs to be easily readable.
                    $ts = $author->created_on;
                    $val = format_ts( 
                                "%H:%M:%S", $ts, undef,
                                $app->user ? $app->user->preferred_language : undef );
                }
                elsif ($field eq 'author_role') {
                    # System administrators don't necessarily have roles attached to them,
                    # but they should be noted in export. So, they need to be looked-up.
                    #@perms = MT::Permission->load({ author_id => $author->id, });
                    # The MT::Permission load was done at the top of this foreach.
                    PERMISSIONS:foreach $perm (@perms) {
                        if ($perm->permissions =~ /'administer'/) {
                            push @roles, 'System Administrator';
                            last PERMISSIONS; # This lets us exit the foreach as soon as
                                              # the "administer" permission is found. No
                                              # need to keep checking rows.
                        }
                    }
                    # Now, onto the regular roles.
                    # The MT::Association load was done at the top of this foreach, so
                    # no need to re-do it here.
                    foreach $assoc (@assoc) {
                        $role = MT->model('role')->load($assoc->role_id);
                        $blog = MT->model('blog')->load($assoc->blog_id);
                        push @roles, $role->name.': '.$blog->name.' ('.$blog->id.')';
                    }
                    $val = join(', ', @roles);
                }
                elsif ($field =~ /^author_(.*?)$/) {
                    # These are the simple author fields to work with,
                    # so don't need any special handling to get their results.
                    $val = $author->$1;
                }
                push @detail, $val;
            }
            $data = _csv_row(@detail);
        } # end of the $role_filter && $blog_filter check

        # Start the download process so the user can get the results
        if ($data) {
            if (!$start_header) {
                $app->{no_print_body} = 1;
                $app->set_header(
                    "Content-Disposition" => "attachment; filename=export.csv" );
                $app->send_http_header('application/octet-stream');
                $app->print($data_header); # This is the header row, with the field names
                $start_header = 'done'; # The header has been sent, so set a 
                                        # variable so that it can't be resent.
            }
            $app->print($data);
        }
    }
    if (!$data) { # No result match the filter criteria!
        my $tmpl = $plugin->load_tmpl('no-data.mtml');
        return $app->build_page( $tmpl );
    }
    else {
        return; # The download has started!
    }
}

sub _csv_row {
    my @data = @_;
    my $status = $csv->combine(@data);
    if ($status) {
        return $csv->string();
    }
}

1;

__END__
