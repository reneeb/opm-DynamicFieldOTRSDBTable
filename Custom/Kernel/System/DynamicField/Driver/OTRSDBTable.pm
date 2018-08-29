# --
# Copyright (C) 2018 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::OTRSDBTable;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Main',
    'Kernel::System::User',
    'Kernel::System::Cache',
);

=head1 NAME

Kernel::System::DynamicField::Driver::OTRSAgents

=head1 SYNOPSIS

DynamicFields OTRSAgents Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    ($Self->{CacheType} = __PACKAGE__) =~ s{::}{}g;

    # set field behaviors
    $Self->{Behaviors} = {
        'IsACLReducible'               => 1,
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Extension::Driver::OTRSAgents');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Kernel::System::Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more behabiors
        if ( IsHashRefWithData( $Extension->{Behaviors} ) ) {

            %{ $Self->{Behaviors} } = (
                %{ $Self->{Behaviors} },
                %{ $Extension->{Behaviors} }
            );
        }
    }

    $Self->{CacheType} = 'DynamicFieldValues';

    return $Self;
}

sub ValueSet {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::ValueSet( %Param );
}

sub EditFieldValueValidate {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::EditFieldValueValidate( %Param );
}

sub DisplayValueRender {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::DisplayValueRender( %Param );
}

sub SearchFieldRender {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::SearchFieldRender( %Param );
}

sub SearchFieldParameterBuild {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::SearchFieldParameterBuild( %Param );
}

sub StatsFieldParameterBuild {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::StatsFieldParameterBuild( %Param );
}

sub ValueLookup {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::ValueLookup( %Param );
}

sub ColumnFilterValuesGet {
    my ($Self, %Param) = @_;

    $Param{DynamicFieldConfig}->{Config}->{PossibleValues} = $Self->PossibleValuesGet( %Param );

    return $Self->SUPER::ColumnFilterValuesGet( %Param );
}

sub PossibleValuesGet {
    my ($Self, %Param) = @_;

    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    my $Config = $Param{DynamicFieldConfig}->{Config} || {};
    my $CacheKey = join '::', $Param{DynamicFieldConfig}->{Name}, $Param{Like} // '';

    my $Values = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return $Values if $Values;

    my %List = ('' => '-');

    return \%List if !$Config->{TableName};
    return \%List if !$Config->{KeyField};

    $Config->{ValueField} ||= $Config->{KeyField};

    my $SQL = sprintf 'SELECT %s, %s FROM %s', @{ $Config }{qw/KeyField ValueField TableName/};

    my @Binds;
    if ( defined $Param{Like} ) {
        $SQL .= sprintf ' WHERE %s LIKE ?', $Config->{KeyField};
        push @Binds, \"$Param{Like}%";
    }

    my %Opts;
    if ( $Config->{Limit} ) {
        $Opts{Limit} = $Config->{Limit};
    }

    return \%List if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Binds,
        %Opts,
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $List{ $Row[0] } = $Row[1];
    }

    $CacheObject->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%List,
        TTL   => 60 * 60 * 24 * 1,
    );

    return \%List;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
