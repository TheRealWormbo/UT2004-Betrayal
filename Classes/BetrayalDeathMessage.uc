/******************************************************************************
BetrayalDeathMessage

Creation date: 2011-07-18 08:57
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalDeathMessage extends xDeathMessage;


static function ClientReceive(PlayerController P, optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	if (MessageSwitch == 1) {
		if (!Default.bNoConsoleDeathMessages)
			Super(LocalMessage).ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
		return;
	}
	if (RelatedPRI_1 == P.PlayerReplicationInfo || P.PlayerReplicationInfo.bOnlySpectator && Pawn(P.ViewTarget) != None && Pawn(P.ViewTarget).PlayerReplicationInfo == RelatedPRI_1) {
		// Interdict and send the child message instead.
		P.myHUD.LocalizedMessage(Default.ChildMessage, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
		if (!Default.bNoConsoleDeathMessages)
			P.myHUD.LocalizedMessage(Default.Class, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

		// check multikills
		if (P.Role == ROLE_Authority) {
			// multikills checked already in LogMultiKills()
			if (UnrealPlayer(P).MultiKillLevel > 0)
				P.ReceiveLocalizedMessage(class'BetrayalMultiKillMessage', UnrealPlayer(P).MultiKillLevel);
		}
		else {
			if (RelatedPRI_1 != RelatedPRI_2 && RelatedPRI_2 != None && (RelatedPRI_2.Team == None || RelatedPRI_1.Team != RelatedPRI_2.Team)) {
				if (P.Level.TimeSeconds - UnrealPlayer(P).LastKillTime < 4 && MessageSwitch != 1) {
					UnrealPlayer(P).MultiKillLevel++;
					P.ReceiveLocalizedMessage(class'BetrayalMultiKillMessage', UnrealPlayer(P).MultiKillLevel);
				}
				else
					UnrealPlayer(P).MultiKillLevel = 0;
				UnrealPlayer(P).LastKillTime = P.Level.TimeSeconds;
			}
			else
				UnrealPlayer(P).MultiKillLevel = 0;
		}
	}
	else if (RelatedPRI_2 == P.PlayerReplicationInfo) {
		P.ReceiveLocalizedMessage(class'xVictimMessage', 0, RelatedPRI_1);
		if (!Default.bNoConsoleDeathMessages)
			Super(LocalMessage).ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
	}
	else if (!Default.bNoConsoleDeathMessages)
		Super(LocalMessage).ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bNoConsoleDeathMessages = True
}

