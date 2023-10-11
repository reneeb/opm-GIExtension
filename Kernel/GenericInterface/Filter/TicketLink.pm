# --
# Copyright (C) 2023 OTRS AG, https://github.com/mo-azfar
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Filter::TicketLink;

use strict;
use warnings;

our @ObjectDependencies = qw(
        Kernel::System::Log
    );
	
sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
	
	my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');
	
	my %LinkKeyListParent = $LinkObject->LinkKeyListWithData(
        Object1   => 'Ticket',
        Key1      => $Param{Ticket}->{TicketID},
        Object2   => 'Ticket',
        State     => 'Valid',
        Type      => 'ParentChild',
        Direction => 'Source',
        UserID    => 1,
    );
	
	my %LinkKeyListChild = $LinkObject->LinkKeyListWithData(
        Object1   => 'Ticket',
        Key1      => $Param{Ticket}->{TicketID},
        Object2   => 'Ticket',
        State     => 'Valid',
        Type      => 'ParentChild',
        Direction => 'Target',
        UserID    => 1,
    );
	
	my %LinkKeyListNormal = $LinkObject->LinkKeyListWithData(
        Object1   => 'Ticket',
        Key1      => $Param{Ticket}->{TicketID},
        Object2   => 'Ticket',
        State     => 'Valid',
        Type      => 'Normal',
        Direction => 'Both',
        UserID    => 1,
    );
	
	my @ParentData;
	my @ChildData;
	my @NormalData;
	
	if ( %LinkKeyListParent )
	{
		foreach my $ParentTicketID ( keys %LinkKeyListParent )
		{
			my %ParentAttributes;
			foreach my $Attributes ( sort keys %{$LinkKeyListParent{$ParentTicketID}} )
			{
				$ParentAttributes{$Attributes} = $LinkKeyListParent{$ParentTicketID}{$Attributes}
			}
			
			push @ParentData, \%ParentAttributes;
		}
		$Param{Ticket}{LinkParent} = \@ParentData;
	}
	
	if ( %LinkKeyListChild )
	{
		foreach my $ChildTicketID ( keys %LinkKeyListChild )
		{
			my %ChildAttributes;
			foreach my $Attributes ( sort keys %{$LinkKeyListChild{$ChildTicketID}} )
			{
				$ChildAttributes{$Attributes} = $LinkKeyListChild{$ChildTicketID}{$Attributes}
			}
			
			push @ChildData, \%ChildAttributes;
		}
		$Param{Ticket}{LinkChild} = \@ChildData;
	}
	
	if ( %LinkKeyListNormal )
	{
		foreach my $NormalTicketID ( keys %LinkKeyListNormal )
		{
			my %NormalAttributes;
			foreach my $Attributes ( sort keys %{$LinkKeyListNormal{$NormalTicketID}} )
			{
				$NormalAttributes{$Attributes} = $LinkKeyListNormal{$NormalTicketID}{$Attributes}
			}
			
			push @NormalData, \%NormalAttributes;
		}
		$Param{Ticket}{LinkNormal} = \@NormalData;
	}
	
    return $Param{Ticket};
	
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
