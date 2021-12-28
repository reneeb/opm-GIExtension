# --
# Copyright (C) 2021 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::User::UserUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::User::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::User::UserUpdate - GenericInterface UserUpdate Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::UserUpdate');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'UserUpdate';

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

            UserID => 13,
            User => {
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
            UserID => 123,
            Error => {                              # should not return errors
                    ErrorCode    => 'UserUpdate.ErrorCode'
                    ErrorMessage => 'Error Description'
            },

            User => {
                    # user data like UserEmail, UserFirstname, ...
            },
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

    if ( !$Param{Data}->{User} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
            ErrorMessage => $Self->{DebugPrefix} . ": User is required!",
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
    my ( $ChangeUserID, $UserType ) = $Self->Auth(%Param);

    if ( $UserType eq 'Customer' ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't update users",
        );
    }


    if ( !$ChangeUserID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": User could not be authenticated!",
        );
    }

    my $CanUpdateUsers = 0;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config'); 
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group'); 
    my $AdminUser    = $ConfigObject->Get('Frontend::Module')->{AdminUser};

    GROUPNAME:
    for my $GroupName ( @{ $AdminUser->{Group} || [] } ) {
        my $HasPermission = $GroupObject->PermissionCheck(
            UserID    => $ChangeUserID,
            GroupName => $GroupName,
            Type      => 'rw',
        );

        if ( $HasPermission ) {
            $CanUpdateUsers = 1;
            last GROUPNAME;
        }
    }

    if ( !$CanUpdateUsers ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": User could not be authenticated!",
        );
    }

    # check needed array/hashes
    for my $Needed (qw(User)) {
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

    # check DynamicField attribute values
    my $UserCheck = $Self->_CheckUser(
        User => $Param{Data}->{User},
    );

    if ( !$UserCheck->{Success} ) {
        return $Self->ReturnError( %{$UserCheck} );
    }

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $UserID = $UserObject->UserUpdate(
        %{ $Param{Data}->{User} || {} },
        UserID       => $Param{Data}->{UserID},
        ChangeUserID => $ChangeUserID,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Operation failed',
            ErrorMessage => $Self->{DebugPrefix} . ": Could not update user",
        );
    }

    my %User = $UserObject->GetUserData(
        UserID => $Param{Data}->{UserID},
    );

    delete $User{UserPw};

    # return customer user data
    return {
        Success => 1,
        Data    => {
            User => \%User,
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
