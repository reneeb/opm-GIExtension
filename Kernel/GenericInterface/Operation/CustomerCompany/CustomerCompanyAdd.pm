# --
# Copyright (C) 2021 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerCompany::CustomerCompanyAdd;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerCompany::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerCompany::CustomerCompanyAdd - GenericInterface CustomerCompanyAdd Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerCompanyAdd');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'CustomerCompanyAdd';

    return $Self;
}

=head2 Run()

perform TicketUpdate Operation. This will return the updated TicketID and
if applicable the created ArticleID.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID is
                                                                                #   required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then
                                                                                #   Password is required

            IncludeCustomerCompanyData => 1,                                       # optional (default: 0)

            Source => 'CustomerCompany',

            CustomerCompany => {
                CustomerID => 13235,
                CustomerCompanyStreet => 'A street 13',
                # many more fields, depends on your config
                ValidID        => 1,
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerCompanyID => 123,
            Error => {                              # should not return errors
                    ErrorCode    => 'CustomerCompanyAdd.ErrorCode'
                    ErrorMessage => 'Error Description'
            },

            # If IncludeCustomerCompanyData is enabled
            CustomerCompany => [
                {
                    # customer company data like UserEmail, UserFirstname, ...

                    DynamicField => [
                        {
                            Name  => 'some name',
                            Value => 'some value',
                        },
                    ],
                },
            ],
        },
    };

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
    if ( !IsHashRefWithData( $Param{Data} ) ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.EmptyRequest',
            ErrorMessage => $Self->{DebugPrefix} . ": The request data is invalid!",
        );
    }

    if ( !$Param{Data}->{CustomerCompany} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerCompany is required!",
        );
    }

    if ( !$Param{Data}->{UserLogin} && !$Param{Data}->{SessionID} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": UserLogin or SessionID is required!",
        );
    }

    if ( $Param{Data}->{UserLogin} && !$Param{Data}->{Password} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": Password or SessionID is required!",
        );
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(%Param);

    if ( $UserType eq 'Customer' ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerCompanys can't add customer users",
        );
    }


    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": User could not be authenticated!",
        );
    }

    # check needed array/hashes
    for my $Needed (qw(CustomerCompany)) {
        if (
            !defined $Param{Data}->{$Needed}
            || !IsHashRefWithData( $Param{Data}->{$Needed} )
            )
        {
            return $Self->ReturnError(
                ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
                ErrorMessage => $Self->{DebugPrefix} . ": $Needed parameter is missing or not valid!",
            );
        }
    }

    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my $CustomerID = $CustomerCompanyObject->CustomerCompanyAdd(
        %{ $Param{Data}->{CustomerCompany} || {} },
        Source => $Param{Data}->{Source} || 'CustomerCompany',
        UserID => $UserID,
    );

    if ( !$CustomerID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Operation failed',
            ErrorMessage => $Self->{DebugPrefix} . ": Could not add customer company",
        );
    }

    if ( $Param{Data}->{DynamicField} ) {
        $Self->SaveDynamicFields(
            %Param,
            CustomerID => $CustomerID,
            UserID     => $UserID,
        );
    }

    my %CustomerCompany = $CustomerCompanyObject->CustomerCompanyGet(
        CustomerID => $CustomerID,
    );

    delete $CustomerCompany{Config};

    # return customer user data
    return {
        Success => 1,
        Data    => {
            CustomerCompany => \%CustomerCompany,
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
