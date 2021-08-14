# --
# Copyright (C) 2021 Perl-Services.de, https://perl-services.de
# Copyright (C) 2021 mo-azfar, https://github.com/mo-azfar/otrs-GIExtension
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerUser::CustomerUserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use parent qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::CustomerUser::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerUser::CustomerUserSearch - GenericInterface CustomerUserSearch Operation backend

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

    $Self->{Config}    = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerUserSearch');
    $Self->{Operation} = $Param{Operation};

    $Self->{DebugPrefix} = 'CustomerUserSearch';

    return $Self;
}

=head2 Run()

webservice REST configuration

	NAME => CustomerUserSearch
	OPERATION BACKEND => CustomerUser::CustomerUserSearch
	
	ROUTE MAPPING => /CustomerUserSearch
	REQUEST METHOD => POST


perform CustomerUserSearch Operation based on customer user profile.
		
	 my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID is
                                                                                #   required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then
                                                                                #   Password is required
            CustomerUser => {
                
				# all search fields possible which are defined in CustomerUser::EnhancedSearchFields
				UserLogin     => 'example*',                                    # (optional)
				UserFirstname => 'Firstn*',                                     # (optional)
		
				# special parameters
				CustomerCompanySearchCustomerIDs => [ 'example.com' ],          # (optional)
				ExcludeUserLogins                => [ 'example', 'doejohn' ],   # (optional)
		
				# array parameters are used with logical OR operator (all values are possible which
				are defined in the config selection hash for the field)
				UserCountry              => [ 'Austria', 'Germany', ],          # (optional)
		
				# DynamicFields
				#   At least one operator must be specified. Operators will be connected with AND,
				#       values in an operator with OR.
				#   You can also pass more than one argument to an operator: ['value1', 'value2']
				DynamicField_FieldNameX => {
					Equals            => 123,
					Like              => 'value*',                # "equals" operator with wildcard support
					GreaterThan       => '2001-01-01 01:01:01',
					GreaterThanEquals => '2001-01-01 01:01:01',
					SmallerThan       => '2002-02-02 02:02:02',
					SmallerThanEquals => '2002-02-02 02:02:02',
				}
		
				OrderBy => [ 'UserLogin', 'UserCustomerID' ],                   # (optional)
				# ignored if the result type is 'COUNT'
				# default: [ 'UserLogin' ]
				# (all search fields possible which are defined in
				CustomerUser::EnhancedSearchFields)
		
				# Additional information for OrderBy:
				# The OrderByDirection can be specified for each OrderBy attribute.
				# The pairing is made by the array indices.
		
				OrderByDirection => [ 'Down', 'Up' ],                          # (optional)
				# ignored if the result type is 'COUNT'
				# (Down | Up) Default: [ 'Down' ]
		
				Result => 'ARRAY' || 'COUNT',                                  # (optional)
				# default: ARRAY, returns an array of change ids
				# COUNT returns a scalar with the number of found changes
		
				Limit => 100,                                                  # (optional)
				# ignored if the result type is 'COUNT'
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
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers can't search customer users details",
        );
    }

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => "$Self->{DebugPrefix}.AuthFail",
            ErrorMessage => "$Self->{DebugPrefix}: User could not be authenticated!",
        );
    }


    # check needed hashes
    for my $Needed (qw(CustomerUser)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->ReturnError(
                ErrorCode => "$Self->{DebugPrefix}.MissingParameter",
                ErrorMessage =>
                    "$Self->{DebugPrefix}: $Needed parameter is missing or not valid!",
            );
        }
    }

	# isolate customer user parameter
    my $CustomerUser = $Param{Data}->{CustomerUser};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$CustomerUser} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $CustomerUser->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $CustomerUser->{$Attribute} =~ s{\s+\z}{};
        }
    }
		
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
	
	#validation for searchable customeruserfield 
	my @SeachFields = $CustomerUserObject->CustomerUserSearchFields(
        Source => 'CustomerUser', 
    );
	
	my @FieldName;
	for my $SeachField ( @SeachFields )
	{
		push @FieldName, $SeachField->{Name};	
	}
	
	for my $ParamCU ( keys %{$CustomerUser} )
	{	
		next if grep(/^$ParamCU/i, @FieldName);
		
		return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Wrong Paremeter',
            ErrorMessage => $Self->{DebugPrefix} . ": CustomerUsers cant accept this $ParamCU paremeter ",
			);
		
	}
		
	#search customer user	
	my $CustomerUserIDsRef = $CustomerUserObject->CustomerSearchDetail(
        %{ $Param{Data}->{CustomerUser} || {} }
    );

    if ( !@{$CustomerUserIDsRef} ) {
        return $Self->ReturnError(
            ErrorCode    => $Self->{DebugPrefix} . '.Operation failed',
            ErrorMessage => $Self->{DebugPrefix} . ": Could not find customer user",
        );
    }		
	
	 # return customer user data
	return {
		Success => 1,
		Data    => {
			CustomerUser => $CustomerUserIDsRef,
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
