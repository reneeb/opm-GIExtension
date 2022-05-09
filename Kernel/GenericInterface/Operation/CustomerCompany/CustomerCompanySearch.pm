# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerCompany::CustomerCompanySearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerCompany::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerCompany::CustomerCompanySearch - GenericInterface CustomerCompanySearch Operation backend

=head1 PUBLIC INTERFACE

=head2 new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerCompanySearch');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'CustomerCompanySearch';

    return $Self;
}

=head2 Run()

webservice REST configuration

    NAME => CustomerCompanySearch
    OPERATION BACKEND => CustomerCompany::CustomerCompanySearch
    
    ROUTE MAPPING => /CustomerCompanySearch
    REQUEST METHOD => POST


perform CustomerCompanySearch Operation based on customer user profile.
        
     my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID is
                                                                                #   required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then
                                                                                #   Password is required
            Search => {
               # all search fields possible which are defined in CustomerCompany::EnhancedSearchFields
                CustomerID          => 'example*',                                  # (optional)
                CustomerCompanyName => 'Name*',                                     # (optional)

                # array parameters are used with logical OR operator (all values are possible which
                are defined in the config selection hash for the field)
                CustomerCompanyCountry => [ 'Austria', 'Germany', ],                # (optional)

                # DynamicFields
                #   At least one operator must be specified. Operators will be connected with AND,
                #       values in an operator with OR.
                #   You can also pass more than one argument to an operator: ['value1', 'value2']
                DynamicField_FieldNameX => {
                    Equals            => 123,
                    Like              => 'value*',                # "equals" operator with wildcard support
                    GreaterThan       => '2001-01-01 01:01:01',
                }
            }
        },
    );
    
    
=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }


    # check needed stuff
    if (
        !$Param{Data}->{UserLogin}
        && !$Param{Data}->{SessionID}
        )
    {
        return $Self->ReturnError(
            ErrorCode => "$Self->{DebugPrefix}.MissingParameter",
            ErrorMessage =>
                "$Self->{DebugPrefix}: UserLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} ) {

        if ( !$Param{Data}->{Password} )
        {
            return $Self->ReturnError(
                ErrorCode    => "$Self->{DebugPrefix}.MissingParameter",
                ErrorMessage => "$Self->{DebugPrefix}: Password or SessionID is required!",
            );
        }
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(%Param);
    
    if ( $UserType eq 'Customer' ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't search customer company details",
        );
    }

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.AuthFail",
            ErrorMessage => "$Self->{DebugPrefix}: User could not be authenticated!",
        );
    }


    # check needed hashes
    if ( !IsHashRefWithData( $Param{Data}->{Search} ) ) {
        return $Self->ReturnError(
            ErrorCode => "$Self->{DebugPrefix}.MissingParameter",
            ErrorMessage =>
                "$Self->{DebugPrefix}: Search parameter is missing or not valid!",
        );
    }

    # isolate customer user parameter
    my $CustomerCompany = $Param{Data}->{Search};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$CustomerCompany} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $CustomerCompany->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $CustomerCompany->{$Attribute} =~ s{\s+\z}{};
        }
    }
        
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    
    #validation for searchable customeruserfield 
    my @SearchFields = $CustomerCompanyObject->CustomerCompanySearchFields();
    
    my @FieldName;

    for my $SearchField ( @SearchFields ) {
        my $Name = $SearchField->{Name};
        push @FieldName, $Name;

        if ( $SearchField->{Type} eq 'Selection' ) {
            next if !exists $CustomerCompany->{$Name};
            next if 'ARRAY' eq ref $CustomerCompany->{$Name};
            $CustomerCompany->{$Name} = [ $CustomerCompany->{$Name} ];
        }
    }
    
    for my $ParamCU ( keys %{$CustomerCompany} ) {
        next if grep(/^$ParamCU/i, @FieldName);
        
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Wrong Parameter',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerCompany search can't accept this $ParamCU parameter ",
        );
        
    }

    #search customer user   
    my $CustomerCompanyIDsRef = $CustomerCompanyObject->CustomerCompanySearchDetail(
        %{ $CustomerCompany || {} }
    );

    if ( !@{$CustomerCompanyIDsRef} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Operation failed',
            ErrorMessage => $Self->{DebugPrefix} . ": Could not find customer company",
        );
    }       
    
     # return customer user data
    return {
        Success => 1,
        Data    => {
            CustomerCompany => $CustomerCompanyIDsRef,
        },
    };
        
}

1;

=end Internal:

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
