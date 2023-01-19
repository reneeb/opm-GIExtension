# --
# Copyright (C) 2021 - 2023 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::Session::SessionDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsStringWithData IsHashRefWithData);

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::Session::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Session::SessionGet - GenericInterface Session Get Operation backend

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
    for my $Needed (
        qw(DebuggerObject WebserviceID)
        )
    {
        if ( !$Param{$Needed} ) {

            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=head2 Run()

Get session information.

    my $Result = $OperationObject->Run(
        Data => {
            SessionID => '1234567890123456',
        },
    );
    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            SessionValid => 1,
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( $Param{Data} ) ) {

        return $Self->ReturnError(
            ErrorCode    => 'SessionGet.MissingParameter',
            ErrorMessage => "SessionGet: The request is empty!",
        );
    }

    if ( !$Param{Data}->{SessionID} ) {
        return $Self->ReturnError(
            ErrorCode    => 'SessionGet.MissingParameter',
            ErrorMessage => "SessionGet: SessionID is missing!",
        );
    }

    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    # Honor SessionCheckRemoteIP, SessionMaxIdleTime, etc.
    my $Valid = $SessionObject->CheckSessionID(
        SessionID => $Param{Data}->{SessionID},
    );
    if ( !$Valid ) {
        return $Self->ReturnError(
            ErrorCode    => 'SessionGet.SessionInvalid',
            ErrorMessage => 'SessionGet: SessionID is Invalid!',
        );
    }

    $SessionObject->RemoveSessionID(
        SessionID => $Param{Data}->{SessionID},
    );

    return {
        Success => 1,
        Data    => {
            SessionDeleted => 1,
        },
    };
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
