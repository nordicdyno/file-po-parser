package File::PO::Parser;

use 5.006;
use strict;
use warnings;

=head1 NAME

File::PO::Parser - simple stream (line by line) parser for PO files

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 DESCRIPTION

This simple module providies subroutines to parse PO files (gettext format).
Files are be read in utf8 (filehandles are also being expected in utf8 mode).

Parse process was been adopted to the desired behaviour.

=head1 SYNOPSIS

    use YxWeb::I18N::PO::Reader;

    my $hash_ref;
    # parse PO file (common usage)
    $hash_ref = YxWeb::I18N::PO::Reader::po2hash($po_file_path);

    # another way to parse PO
    $hash_ref = YxWeb::I18N::PO::Reader::fh2hash($po_file_handle);

    # parse PO & collect some statistic data
    my $stat = {};
    YxWeb::I18N::PO::Reader::po2hash_with_stat($po_file_path, $stat);


=head1 SUBROUTINES/METHODS
=cut

use utf8;
use Encode;
use strict;
use warnings;

######## util's subs ####
sub print_debug {
    my $s = shift;
    print STDERR " (debug) $s\n";
}

sub remove_context {
    ${$_[0]} =~ s/^context\([^)]+\)://g;
}

sub chomp_str {
    local $_ = shift;
    s/^"//;
    s/"\s*$//;
    s/\\"/"/g;
    return $_;
}
##########################

my $count_stat = 1;
# result
my $r = {};

# PO-parser (state machine)
# Context for state machine
#   flags:
my ($state, $start, $is_plural, $store_it);
# tmp storages
my ($acc, $id, $value);
my ($plural_values, $plural_idx);
my $default_plural;
# permanent storage
my ($header);
my $line_n;
#  stat data
my ($items_cnt, $keys_length, $values_length);
my ($keys_blength, $values_blength);

# refs to helpers subroutines 
################################
sub reset_value_sub {
    $store_it = 0;
    $acc = "";
    $plural_idx = undef;
};

sub reset_item_sub {
    $start = 0;
    $id = undef;
    $value = undef;
    $is_plural  = 0;
    $plural_values = [];
    $default_plural = '';
    reset_value_sub();
};

sub add_value_sub {
    return unless $store_it; # 

    my $add_value = $acc eq 'DONT_TRANSLATE' ? $id : $acc;
    remove_context(\$add_value); 

    if ($is_plural) {
        if (not length $add_value && length $default_plural) {
            $add_value = $default_plural; 
        }
        $plural_values->[$plural_idx] = $add_value;
        $value = $plural_values;
    }
    else {
        $value = $add_value;
    }
    reset_value_sub();
};

sub set_id_sub {
    return if not defined $id;

    if (!length $id) {
        $header = $acc if $start;
        return;
    }

    add_value_sub();
    $r->{$id} = $value;

    if ($count_stat) {
        $keys_length  += length $id;
        $keys_blength += length encode('utf-8', $id);
        
        my $v_ref = [ref $value ? @{$value} : $value ];
        for my $v (@$v_ref) {
            $values_length += length $v;
            $values_blength += length encode('utf-8', $v);
        }
    }
    
    $items_cnt++;
};

sub continue_sub {
    my $s = shift;
    if($s =~ /^"/) {
        my $s_chomp   .= chomp_str($s);
        $acc .= $s_chomp;
        return 0;
    }
    return 1;
};

################################
# state commands
################################
my $states = {};
$states = {
    start =>  sub {
        $r = {};
        reset_item_sub(); 
        $start = 1;
        ($header, $items_cnt) = ('', 0);
        ($keys_length, $values_length)   = (0, 0);
        ($keys_blength, $values_blength) = (0, 0);
        return 'scan';
    },
    continue_id => sub {
        my $s = shift;
        my $continue_is_over = continue_sub($s);
        if ($continue_is_over) {
            $id = $acc;
            return $states->{'after_id'}->($s);
        }
        return 'continue_id';
    },
    continue_str => sub {
        my $s = shift;
        my $continue_is_over = continue_sub($s);
        if ($continue_is_over) {
            return $states->{'after_id'}->($s);
        }

        return 'continue_str';
    },
    'scan' => sub {
        local $_ = $_[0];
        return 'scan' if /^\s*$/;
        
        if(/^msgid\s+(.*+)/) {
            $acc = chomp_str($1);
            return 'continue_id' unless length $acc; 

            #str_rm_extra(\$acc); 
            $id = $acc;
            return 'after_id'; 
        }
        
        warn "[state: scan, line: $line_n] wrong line format '$_'";
        return 'scan';
        #die "state: scan [$line_n] wrong line format: '$_'";
    },
    'after_id' => sub {

        local $_ = $_[0];
        if(/^\s*$/) {
            set_id_sub() if $store_it;
            reset_item_sub();
            return "scan";
        }
        
        my $next_state ="after_id"; 
        if(/^msg(?<cmd>txt|id_plural|str(?:\[(?<idx>\d+)\])?)\s+(?<val>.*)/) 
        {
            return 'after_id' if ($+{cmd} eq 'txt'); 
            
            add_value_sub() if $store_it;

            if ($+{cmd} eq 'id_plural') {
                $store_it  = 0;
                $is_plural = 1;
                # for imitatte Gettext
                $default_plural = chomp_str($+{val});
            }
            elsif (substr($+{cmd}, 0, 3) eq 'str') {
                $store_it = 1;
                if ($is_plural) {
                    die "[$line_n] not found index for plural form" if not defined $+{idx};
                    $plural_idx = $+{idx};
                }
            }

            $acc = chomp_str($+{val});
            remove_context(\$acc);
            if (not length $acc) {
                $next_state = 'continue_str';
            }
        }
        else {
            warn "[state: after_id, line: $line_n] wrong line format '$_'";
            reset_item_sub();
            $next_state = 'scan';
        }
        return $next_state; # skip context info
    },
    finish => sub {
        set_id_sub() if $store_it;
    }
};



=head2 fh2hash($file_handle)

Parse data from filehandle. Return hash ref with parsed data.

=cut

sub fh2hash {
    my $fh     = shift;
    ################################
    #   run state machine
    $state = $states->{'start'}->();

    $line_n = 0;
    while (my $line = readline $fh) {
        $line_n++; 
        next if $line =~ /^#/;

        $state = $states->{$state}->($line);
    }
    # stop machine!
    $states->{'finish'}->();
    return $r;
}

=head2 po2hash($file_path)

Parse data from file. Return hash ref with parsed data.

=cut

sub po2hash {
    my $file = shift;
    open my $fh, '<:utf8', $file or die "can't read file $file: $!";
    return fh2hash($fh);
}

=head po2hash_with_stat($file_path, $stat_hash_ref)

Same as po2hash(). Second parameter is hash reference for parse statistic collecting

    $stat_hash_ref = {
        items_count    => # items succesfully parsed
        keys_length    => # all id strings symbols count
        keys_blength   => # all id strings bytes count
        values_length  => # all value strings symbols count
        values_blength => # all value strings bytes count
    }

=cut

sub po2hash_with_stat {
    my $file = shift;
    my $stat_ref = shift;

    $count_stat = 1;
    my $r = po2hash($file);

    %{$stat_ref} = (
        items_count    => $items_cnt,
        keys_length    => $keys_length,
        keys_blength   => $keys_blength,
        values_length  => $values_length,
        values_blength => $values_blength,
    );

    return $r;
}


=head1 AUTHOR

Orlovskiy Alexander, C<< <nordicdyno at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to 
L<https://github.com/nordicdyno/file-po-parser/issues>.  
I will be notified, and then you'll automatically be notified of progress 
on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::PO::Parser

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Orlovskiy Alexander.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of File::PO::Parser
