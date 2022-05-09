# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerUser::CustomerUserAdd;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerUser::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerUser::CustomerUserAdd - GenericInterface CustomerUserAdd Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerUserAdd');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'CustomerUserAdd';

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

            IncludeCustomerUserData => 1,                                       # optional (default: 0)

            Source => 'CustomerUser',

            CustomerUser => {
                UserFirstname  => 'Huber',
                UserLastname   => 'Manfred',
                UserCustomerID => 'A124',
                UserLogin      => 'mhuber',
                UserPassword   => 'some-pass', # not required
                UserEmail      => 'email@example.com',
                ValidID        => 1,
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerUserID => 123,
            Error => {                              # should not return errors
                    ErrorCode    => 'CustomerUserAdd.ErrorCode'
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

    if ( !$Param{Data}->{CustomerUser} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUser is required!",
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
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't add customer users",
        );
    }


    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": User could not be authenticated!",
        );
    }

    # check needed array/hashes
    for my $Needed (qw(CustomerUser)) {
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

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $UserLogin = $CustomerUserObject->CustomerUserAdd(
        %{ $Param{Data}->{CustomerUser} || {} },
        Source => $Param{Data}->{Source} || 'CustomerUser',
        UserID => $UserID,
    );

    if ( !$UserLogin ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Operation failed',
            ErrorMessage => $Self->{DebugPrefix} . ": Could not add customer user",
        );
    }

    if ( $Param{Data}->{DynamicField} ) {
        $Self->SaveDynamicFields(
            %Param,
            CustomerUserID => $UserLogin,
            UserID         => $UserID,
        );
    }

    my %CustomerUser = $CustomerUserObject->CustomerUserDataGet(
        User   => $UserLogin,
        UserID => $UserID,
    );

    delete $CustomerUser{Config};
    delete $CustomerUser{CompanyConfig};

    # return customer user data
    return {
        Success => 1,
        Data    => {
            CustomerUser => \%CustomerUser,
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
