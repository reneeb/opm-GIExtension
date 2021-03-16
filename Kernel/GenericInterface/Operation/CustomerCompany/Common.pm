# --
# Copyright (C) 2021 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::CustomerCompany::Common;

use strict;
use warnings;

use MIME::Base64();
use Mail::Address;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::CustomerCompany::Common

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

    # get the dynamic fields
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => [ 'CustomerCompany' ],
    );

    # create a Dynamic Fields lookup table (by name)
    DYNAMICFIELD:
    for my $DynamicField ( @{$DynamicField} ) {
        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicField);
        next DYNAMICFIELD if !$DynamicField->{Name};
        $Self->{DynamicFieldLookup}->{ $DynamicField->{Name} } = $DynamicField;
    }

    return {
        Success => 1,
    };
}

=head2 ValidateDynamicFieldName()

checks if the given dynamic field name is valid.

    my $Success = $CommonObject->ValidateDynamicFieldName(
        Name => 'some name',
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateDynamicFieldName {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    return 1;
}

=head2 ValidateDynamicFieldValue()

checks if the given dynamic field value is valid.

    my $Success = $CommonObject->ValidateDynamicFieldValue(
        Name  => 'some name',
        Value => 'some value',          # String or Integer or DateTime format
    );

    my $Success = $CommonObject->ValidateDynamicFieldValue(
        Value => [                      # Only for fields that can handle multiple values like
            'some value',               #   Multiselect
            'some other value',
        ],
    );

    returns
    $Success = 1                        # or 0

=cut

sub ValidateDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

    # possible structures are string and array, no data inside is needed
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return;
    }

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    # Validate value.
    my $ValidateValue = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->FieldValueValidate(
        DynamicFieldConfig => $DynamicFieldConfig,
        Value              => $Param{Value},
        UserID             => 1,
    );

    return $ValidateValue;
}

=head2 ValidateDynamicFieldObjectType()

checks if the given dynamic field name is valid.

    my $Success = $CommonObject->ValidateDynamicFieldObjectType(
        Name    => 'some name',
        Article => 1,               # if article exists
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidateDynamicFieldObjectType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    return 1;
}

=head2 SetDynamicFieldValue()

sets the value of a dynamic field.

    my $Result = $CommonObject->SetDynamicFieldValue(
        Name           => 'some name',           # the name of the dynamic field
        Value          => 'some value',          # String or Integer or DateTime format
        CustomerUserID => 132,
        UserID         => 123,
    );

    my $Result = $CommonObject->SetDynamicFieldValue(
        Name   => 'some name',           # the name of the dynamic field
        Value => [
            'some value',
            'some other value',
        ],
        UserID => 123,
    );

    returns
    $Result = {
        Success => 1,                        # if everything is ok
    }

    $Result = {
        Success      => 0,
        ErrorMessage => 'Error description'
    }

=cut

sub SetDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name UserID)) {
        if ( !IsString( $Param{$Needed} ) ) {
            return {
                Success      => 0,
                ErrorMessage => "SetDynamicFieldValue() Invalid value for $Needed, just string is allowed!"
            };
        }
    }

    # check value structure
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return {
            Success      => 0,
            ErrorMessage => "SetDynamicFieldValue() Invalid value for Value, just string and array are allowed!"
        };
    }

    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    my $ObjectID = $Param{CustomerID};

    if ( !$ObjectID ) {
        return {
            Success      => 0,
            ErrorMessage => "SetDynamicFieldValue() Could not set $ObjectID!",
        };
    }

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectName         => $ObjectID,
        Value              => $Param{Value},
        UserID             => $Param{UserID},
    );

    return {
        Success => $Success,
    };
}


1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
