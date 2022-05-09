# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerUser::DynamicFieldUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerUser::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerUser::DynamicFieldUpdate - GenericInterface CustomerUser DynamicFieldUpdate Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::DynamicFieldUpdate');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'DynamicFieldUpdate';

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

            CustomerUserID => 123,                                              # required
            IncludeCustomerUserData => 1,                                       # optional (default: 0)

            DynamicField => [                                                  # optional
                {
                    Name   => 'some name',
                    Value  => $Value,                                          # value type depends on the dynamic field
                },
                # ...
            ],
            # or
            # DynamicField => {
            #    Name   => 'some name',
            #    Value  => $Value,
            #},
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerUserID => 123,
            Error => {                              # should not return errors
                    ErrorCode    => 'DynamicFieldUpdate.ErrorCode'
                    ErrorMessage => 'Error Description'
            },

            # If IncludeCustomerUserData is enabled
            CustomerUser => [
                {
                    # customer user data like UserEmail, UserFirstname, ...

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

    if ( !$Param{Data}->{CustomerUserID} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUserID is required!",
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
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't update dynamic fields",
        );
    }


    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": User could not be authenticated!",
        );
    }

    my $CustomerUserID = $Param{Data}->{CustomerUserID};

    # check needed values
    for my $Needed (qw(CustomerUserID)) {
        if ( !defined $Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
                ErrorMessage => $Self->{DebugPrefix} . ": $Needed parameter is missing!",
            );
        }
    }

    my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $CustomerUserID,
    );

    if ( !%CustomerUser ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.InvalidParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": Invalid customer user id!",
        );
    }

    # check needed array/hashes
    for my $Needed (qw(DynamicField)) {
        if (
            !defined $Param{Data}->{$Needed}
            || !IsArrayRefWithData( $Param{Data}->{$Needed} )
            )
        {
            return $Self->ReturnError(
                ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
                ErrorMessage => $Self->{DebugPrefix} . ": $Needed parameter is missing or not valid!",
            );
        }
    }

    my $DFReturn = $Self->SaveDynamicFields(
        %Param,
        CustomerUserID => $CustomerUserID,
        UserID         => $UserID,
    );

    return $DFReturn;
}

1;

=end Internal:

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
