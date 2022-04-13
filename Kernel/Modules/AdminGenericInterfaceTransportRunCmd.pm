# --
# Copyright (C) 2022 - 2022 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminGenericInterfaceTransportRunCmd;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    # Set possible values handling strings.
    $Self->{EmptyString}     = '_AdditionalHeaders_EmptyString_Dont_Use_It_String_Please';
    $Self->{DuplicateString} = '_AdditionalHeaders_DuplicatedString_Dont_Use_It_String_Please';
    $Self->{DeletedString}   = '_AdditionalHeaders_DeletedString_Dont_Use_It_String_Please';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $WebserviceObject = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');

    my $WebserviceID      = $ParamObject->GetParam( Param => 'WebserviceID' )      || '';
    my $CommunicationType = $ParamObject->GetParam( Param => 'CommunicationType' ) || '';

    # ------------------------------------------------------------ #
    # sub-action Change: load web service and show edit screen
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Add' || $Self->{Subaction} eq 'Change' ) {

        # Check for WebserviceID.
        if ( !$WebserviceID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need WebserviceID!'),
            );
        }

        # Get web service configuration.
        my $WebserviceData = $WebserviceObject->WebserviceGet( ID => $WebserviceID );

        # Check for valid web service configuration.
        if ( !IsHashRefWithData($WebserviceData) ) {
            return $LayoutObject->ErrorScreen(
                Message =>
                    $LayoutObject->{LanguageObject}
                    ->Translate( 'Could not get data for WebserviceID %s', $WebserviceID ),
            );
        }

        return $Self->_ShowEdit(
            %Param,
            WebserviceID      => $WebserviceID,
            WebserviceData    => $WebserviceData,
            CommunicationType => $CommunicationType,
            Action            => 'Change',
        );
    }

    # ------------------------------------------------------------ #
    # invalid sub-action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} ne 'ChangeAction' ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Need valid Subaction!'),
        );
    }

    # ------------------------------------------------------------ #
    # sub-action ChangeAction: write config and return to overview
    # ------------------------------------------------------------ #

    # Challenge token check for write action.
    $LayoutObject->ChallengeTokenCheck();

    # Check for WebserviceID.
    if ( !$WebserviceID ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Need WebserviceID!'),
        );
    }

    # Get web service configuration.
    my $WebserviceData = $WebserviceObject->WebserviceGet(
        ID => $WebserviceID,
    );

    # Check for valid web service configuration.
    if ( !IsHashRefWithData($WebserviceData) ) {
        return $LayoutObject->ErrorScreen(
            Message =>
                $LayoutObject->{LanguageObject}->Translate( 'Could not get data for WebserviceID %s', $WebserviceID ),
        );
    }

    # Get parameter from web browser.
    my $GetParam = $Self->_GetParams();

    # Check required parameters.
    my %Error;
    for my $ParamName (qw( Cmd Timeout )) {
        if ( !$GetParam->{$ParamName} ) {

            # Add server error error class.
            $Error{ $ParamName . 'ServerError' }        = 'ServerError';
            $Error{ $ParamName . 'ServerErrorMessage' } = Translatable('This field is required');
        }
    }

    # To store the clean new configuration locally.
    my $TransportConfig;

    # Get common settings.
    for my $Param ( qw(Cmd Timeout) ) {
        $TransportConfig->{$Param} = $GetParam->{$Param};
    }

    # Get requester specific settings.
    if ( $CommunicationType eq 'Requester' ) {

        $TransportConfig->{Encoding} = $GetParam->{Encoding};

        NEEDED:
        for my $Needed (qw( Cmd Timeout )) {
            $TransportConfig->{$Needed} = $GetParam->{$Needed};
            next NEEDED if defined $GetParam->{$Needed};

            $Error{ $Needed . 'ServerError' }        = 'ServerError';
            $Error{ $Needed . 'ServerErrorMessage' } = Translatable('This field is required');
        }

        # Set error for non integer content.
        if ( $GetParam->{Timeout} && !IsInteger( $GetParam->{Timeout} ) ) {
            $Error{TimeoutServerError}        = 'ServerError';
            $Error{TimeoutServerErrorMessage} = Translatable('This field should be an integer.');
        }
    }

    # Get provider specific settings.
    else {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Currently there is no support for Run::Cmd as a provider'),
        );
    }

    # Set new configuration.
    $WebserviceData->{Config}->{$CommunicationType}->{Transport}->{Config} = $TransportConfig;

    # If there is an error return to edit screen.
    if ( IsHashRefWithData( \%Error ) ) {
        return $Self->_ShowEdit(
            %Error,
            %Param,
            WebserviceID      => $WebserviceID,
            WebserviceData    => $WebserviceData,
            CommunicationType => $CommunicationType,
            Action            => 'Change',
        );
    }

    # Otherwise save configuration and return to overview screen.
    my $Success = $WebserviceObject->WebserviceUpdate(
        ID      => $WebserviceID,
        Name    => $WebserviceData->{Name},
        Config  => $WebserviceData->{Config},
        ValidID => $WebserviceData->{ValidID},
        UserID  => $Self->{UserID},
    );

    # If the user would like to continue editing the transport config, just redirect to the edit screen.
    if (
        defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
        && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
        )
    {
        return $LayoutObject->Redirect(
            OP =>
                "Action=$Self->{Action};Subaction=Change;WebserviceID=$WebserviceID;CommunicationType=$CommunicationType;",
        );
    }
    else {

        # Otherwise return to overview.
        return $LayoutObject->Redirect(
            OP => "Action=AdminGenericInterfaceWebservice;Subaction=Change;WebserviceID=$WebserviceID;",
        );
    }
}

sub _ShowEdit {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    $Param{Type}           = 'Run::Cmd';
    $Param{WebserviceName} = $Param{WebserviceData}->{Name};
    my $TransportConfig = $Param{WebserviceData}->{Config}->{ $Param{CommunicationType} }->{Transport}->{Config};

    # Extract display parameters from transport config.
    for my $ParamName ( qw(Cmd) ) {
        $Param{$ParamName} = $TransportConfig->{$ParamName};
    }

    # Check if communication type is requester.
    if ( $Param{CommunicationType} eq 'Requester' ) {

        # Create Timeout select.
        $Param{TimeoutStrg} = $LayoutObject->BuildSelection(
            Data          => [ '30', '60', '90', '120', '150', '180', '210', '240', '270', '300' ],
            Name          => 'Timeout',
            SelectedValue => $Param{Timeout} || '120',
            Sort          => 'NumericValue',
            Class         => 'Modernize',
        );
    }

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminGenericInterfaceTransportRunCmd',
        Data         => { %Param, },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _GetParams {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $GetParam;

    # Get parameters from web browser.
    for my $ParamName ( qw(Cmd Timeout) ) {
        $GetParam->{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';
    }

    return $GetParam;
}

1;
