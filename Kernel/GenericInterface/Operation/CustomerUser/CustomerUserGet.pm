# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://perl-services.de
# Copyright (C) 2021 mo-azfar, https://github.com/mo-azfar/otrs-GIExtension
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerUser::CustomerUserGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerUser::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerUser::CustomerUserGet - GenericInterface CustomerUserGet Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerUserGet');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'CustomerUserGet';

    return $Self;
}

=head2 Run()

webservice REST configuration

    NAME => CustomerUserGet
    OPERATION BACKEND => CustomerUser::CustomerUserGet
    
    ROUTE MAPPING => /CustomerUser/:CustomerUserID
    REQUEST METHOD => GET


perform CustomerUserGet Operation based on customer user username.
        
     my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID is
                                                                                #   required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then
                                                                                #   Password is required            
    
            CustomerUserID     => 'example',                                    # customer user login required  
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
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't search customer users details",
        );
    }

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.AuthFail",
            ErrorMessage => "$Self->{DebugPrefix}: User could not be authenticated!",
        );
    }


    if ( !$Param{Data}->{CustomerUserID} )
    {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.MissingParameter",
            ErrorMessage => "$Self->{DebugPrefix}: CustomerUserID is required!",
        );
    }
    
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    
    my @CustomerUserIDs = split( /,/, $Param{Data}->{CustomerUserID} );
    my @CustomerUser;
        
    for my $CustomerUserID (@CustomerUserIDs) 
    {
        
        my %CU = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserID,
        );
        
        next if !$CU{UserLogin};
        delete $CU{Config};
        delete $CU{CompanyConfig};
        delete $CU{UserPassword};
    
        push @CustomerUser, \%CU;
    }
    
    if ( !scalar @CustomerUser ) {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.Operation failed",
            ErrorMessage => "$Self->{DebugPrefix}: CustomerUser Not Found",
        );
    }
    
    # return customer user data
    return {
        Success => 1,
        Data    => {
            CustomerUser => \@CustomerUser,
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
