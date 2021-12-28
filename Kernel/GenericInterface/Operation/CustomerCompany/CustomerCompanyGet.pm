# --
# Copyright (C) 2021 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerCompany::CustomerCompanyGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerCompany::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerCompany::CustomerCompanyGet - GenericInterface CustomerCompanyGet Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerCompanyGet');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'CustomerCompanyGet';

    return $Self;
}

=head2 Run()

webservice REST configuration

    NAME => CustomerCompanyGet
    OPERATION BACKEND => CustomerCompany::CustomerCompanyGet
    
    ROUTE MAPPING => /CustomerCompany/:CustomerID
    REQUEST METHOD => GET


perform CustomerCompanyGet Operation based on customer user username.
        
     my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID is
                                                                                #   required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then
                                                                                #   Password is required            
    
            CustomerID     => 'example',                                    # customer id required  
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


    if ( !$Param{Data}->{CustomerID} )
    {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.MissingParameter",
            ErrorMessage => "$Self->{DebugPrefix}: CustomerID is required!",
        );
    }
    
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    
    my @CustomerIDs = split( /,/, $Param{Data}->{CustomerID} );
    my @CustomerCompany;
        
    for my $CustomerID (@CustomerIDs) 
    {
        
        my %Company = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );
        
        next if !$Company{CustomerID};
        delete $Company{Config};
    
        push @CustomerCompany, \%Company;
    }
    
    if ( !scalar @CustomerCompany ) {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.Operation failed",
            ErrorMessage => "$Self->{DebugPrefix}: CustomerCompany Not Found",
        );
    }
    
    # return customer user data
    return {
        Success => 1,
        Data    => {
            CustomerCompany => \@CustomerCompany,
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
