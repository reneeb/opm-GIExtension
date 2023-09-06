# --
# Copyright (C) 2021 - 2023 Perl-Services.de, https://perl-services.de
# Copyright (C) 2023 mo-azfar, https://github.com/mo-azfar/otrs-GIExtension
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::User::UserSearch;

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::UserSearch');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'UserSearch';

    return $Self;
}

=head2 Run()

webservice REST configuration

    NAME => UserSearch
    OPERATION BACKEND => User::UserSearch
    
    ROUTE MAPPING => /UserSearch
    REQUEST METHOD => POST
    PARSER BACKEND => JSON

perform UserSearch Operation. This will return the UserID and Login Pair /  UserID and Email pair.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID is
                                                                                #   required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then
                                                                                #   Password is required,
            
            #either one of this. can be userlogin, firstname, lastname
            User => {
                Search  => '*some*',
                Valid   => '1, # not required
            }

            #either one of this. based on login name
            User => {
                UserLogin => '*some*',
                Limit     => 50,
                Valid     => 1, # not required
            }

            #either one of this. based on email address
            User => {
                PostMasterSearch => 'email@example.com',
                Valid            => 1, # not required
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
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't search users",
        );
    }


    if ( !$ChangeUserID ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.AuthFail',
            ErrorMessage => $Self->{DebugPrefix} . ": User could not be authenticated!",
        );
    }

    my $CanSearchUsers = 0;

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
            $CanSearchUsers = 1;
            last GROUPNAME;
        }
    }

    if ( !$CanSearchUsers ) {
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

    # isolate user parameter
    my $User = $Param{Data}->{User};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$User} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $User->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $User->{$Attribute} =~ s{\s+\z}{};
        }
    }

    #check possible search field
    my @FieldName = ('Search', 'UserLogin', 'Limit', 'PostMasterSearch' , 'Valid');

    for my $ParamUser ( keys %{$User} )
    {   
        next if grep(/^$ParamUser/i, @FieldName);
        
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Wrong Parameter',
            ErrorMessage => $Self->{DebugPrefix} . ": Search can't accept this $ParamUser parameter ",
        );
    }

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

     my %List = $UserObject->UserSearch(
        %{ $Param{Data}->{User} || {} },
    );

    if ( !%List ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Operation failed',
            ErrorMessage => $Self->{DebugPrefix} . ": Could not search user",
        );
    }

    # return user data
    return {
        Success => 1,
        Data    => {
            User => \%List,
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
