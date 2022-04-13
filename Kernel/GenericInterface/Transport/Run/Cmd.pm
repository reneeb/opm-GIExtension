# --
# Copyright (C) 2022 - 2022 Perl-Services.de, https://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Transport::Run::Cmd;

use strict;
use warnings;

use IPC::Run;

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Transport::Run::Cmd

=head1 PUBLIC INTERFACE

=head2 new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Transport->new();

    use Kernel::GenericInterface::Transport;

    my $TransportObject = Kernel::GenericInterface::Transport->new(

        TransportConfig => {
            Type => 'Run::Cmd',
            Config => {
                Fail => 0,  # 0 or 1
            },
        },
    );

In the config parameter 'Fail' you can tell the transport to simulate
failed network requests. If 'Fail' is set to 0, the transport will return
the query string of the requests as return data (see L</RequesterPerformRequest()>
for an example);

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    for my $Needed (qw( DebuggerObject TransportConfig)) {
        $Self->{$Needed} = $Param{$Needed} || return {
            Success      => 0,
            ErrorMessage => "Got no $Needed!"
        };
    }

    return $Self;
}

=head2 ProviderProcessRequest()

=cut

sub ProviderProcessRequest {
    my ( $Self, %Param ) = @_;

    return {
        Success      => 0,
        ErrorMessage => "Not implemented for Providers",
        Data         => {},
    };
}

=head2 ProviderGenerateResponse()

this will generate a query string from the passed data hash
and generate an HTTP response with this string as the body.
This response will be printed so that the web server will
send it to the client.

=cut

sub ProviderGenerateResponse {
    my ( $Self, %Param ) = @_;

    return {
        Success      => 0,
        ErrorMessage => "Not implemented for Providers",
        Data         => {},
    };
}

=head2 RequesterPerformRequest()

in Fail mode, returns error status. Otherwise, returns the
query string generated out of the data for the HTTP response.

    my $Result = $TransportObject->RequesterPerformRequest(
        Data => {
            A => 'A',
            b => 'b',
        },
    );

Returns

    $Result = {
        Success => 1,
        Data => {
            ResponseData => 'A=A&b=b',
        },
    };

=cut

sub RequesterPerformRequest {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    my @First;
    my @Last;
    my @CmdParams;

    PARAMTAG:
    for my $ParamTag ( keys %{ $Param{Data} || {} } ) {
        my $CmdParam = $Param{Data}->{$ParamTag};

        if ( !ref $CmdParam ) {
            push @CmdParams, $CmdParam;
        }
        else {
            my $Name  = $CmdParam->{name};
            my $Value = $CmdParam->{value};

            my $Pos   = $CmdParam->{position} || '';

            if ( $Pos eq 'last' ) {
                push @Last, $Name, $Value;
            }
            elsif ( $Pos eq 'first' ) {
                push @First, $Name, $Value;
            }
        }
    }

    unshift @CmdParams, @First if $First;
    push @CmdParams, @Last     if $Last;

    my $Config  = $Param{Webservice}->{Requester}->{Transport}->{Config};
    my $Cmd     = $Config->{Cmd};
    my $Timeout = $Config->{Timeout};

    my $ReturnString = qx{ $Cmd @CmdParams };

    my $ReturnData = $JSONObject->Decode( Data => $ReturnString );

    # try to parse JSON. If that doesn't work, return the string

    return {
        Success => 1,
        Data    => $ReturnData || $ResturnString,
    };
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
