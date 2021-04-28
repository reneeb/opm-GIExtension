# --
# Copyright (C) 2021 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::User::Common;

use strict;
use warnings;

use MIME::Base64();
use Mail::Address;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::User::Common

=head1 PUBLIC INTERFACE

=head2 Init()

initialize the operation by checking the web service configuration and gather of the dynamic fields

    my $Return = $CommonObject->Init(
        WebserviceID => 1,
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        ErrorMessage => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # check needed
    if ( !$Param{WebserviceID} ) {
        return {
            Success      => 0,
            ErrorMessage => "Got no WebserviceID!",
        };
    }

    # get web service configuration
    my $Webservice = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return {
            Success => 0,
            ErrorMessage =>
                'Could not determine Web service configuration'
                . ' in ' . __PACKAGE__ . '::new()',
        };
    }

    return {
        Success => 1,
    };
}

=head2 _CheckUser()

checks if the given user parameter is valid.

    my $UserCheck = $OperationObject->_CheckUser(
        User => $User,              # all dynamic field parameters
    );

    returns:

    $UserCheck = {
        Success => 1,                               # if everything is OK
    }

    $UserCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckUser {
    my ( $Self, %Param ) = @_;

    my $User = $Param{User};

    # check User item internally
    for my $Needed (qw(UserFirstname UserLastname UserLogin UserEmail ValidID)) {
        if ( !defined $User->{$Needed} || !IsString( $User->{$Needed} ) ) {
            return {
                ErrorCode    => $Self->{DebugPrefix} . '.MissingParameter',
                ErrorMessage => $Self->{DebugPrefix} . ": User->$Needed parameter is missing!",
            };
        }
    }

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # check if a user with this login (username) already exits
    if ( $UserObject->UserLoginExistsCheck( UserLogin => $Param{UserLogin} ) ) {
        return {
            ErrorCode    => $Self->{DebugPrefix} . '.UserLogin invalid',
            ErrorMessage => "A user with the username '$Param{UserLogin}' already exists.",
        };
    }

    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');
    my $ValidObject     = $Kernel::OM->Get('Kernel::System::Valid');

    # check email address
    if (
        !$CheckItemObject->CheckEmail( Address => $Param{UserEmail} )
        && grep { $_ eq $Param{ValidID} } $ValidObject->ValidIDsGet()
        )
    {
        return {
            ErrorCode    => $Self->{DebugPrefix} . '.UserEmail invalid',
            ErrorMessage => "Email address ($Param{UserEmail}) not valid",
        };
    }

    # if everything is OK then return Success
    return {
        Success => 1,
    };
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
