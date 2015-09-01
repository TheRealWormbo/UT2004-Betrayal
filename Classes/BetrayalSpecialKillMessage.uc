/******************************************************************************
BetrayalSpecialKillMessage

Creation date: 2011-03-13 18:08
Last change: $Id$
Copyright (c) 2011, Wormbo
******************************************************************************/

class BetrayalSpecialKillMessage extends SpecialKillMessage abstract;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\Impressive.wav


//=============================================================================
// Localization
//=============================================================================

var localized string DecapitationByString;
var localized string ImpressiveString;
var localized string EagleEyeString;


//=============================================================================
// Properties
//=============================================================================

var Sound ImpressiveAnnouncement;


/**
Return special kill message string.
*/
static function string GetString(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	switch (MessageSwitch) {
	case 0:
		if (RelatedPRI_1 != None)
			return Repl(default.DecapitationByString, "%k", RelatedPRI_1.PlayerName, true);

		return default.DecapitationString;

	case 1:
		return default.EagleEyeString;

	default:
		return Repl(default.ImpressiveString, "%n", MessageSwitch, true);
	}
}


/**
Play corresponding announcement.
*/
static function ClientReceive(PlayerController P, optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	Super(LocalMessage).ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

	switch (MessageSwitch) {
	case 0:
		P.PlayRewardAnnouncement('HeadShot', 1);
		break;

	case 1:
		P.PlayRewardAnnouncement('EagleEye', 1);
		break;

	default:
		P.PlayAnnouncement(default.ImpressiveAnnouncement, 1);
	}
}


/**
Increased font size for multi hits on 3 or more players.
*/
static function int GetFontSize(int MessageSwitch, PlayerReplicationInfo RelatedPRI1, PlayerReplicationInfo RelatedPRI2, PlayerReplicationInfo LocalPlayer)
{
	if (MessageSwitch > 2)
		return 1;
	return 0;
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	bFadeMessage       = True
	bIsSpecial         = True
	bIsUnique          = True
	bIsPartiallyUnique = True
	Lifetime           = 3
	bBeep              = False
	DrawColor          = (R=255,G=0,B=0,A=255)
	StackMode          = SM_Down
	PosY               = 0.10

	DecapitationByString = "Head Shot by %k !!"
	ImpressiveString     = "%n Hits, Impressive!"
	EagleEyeString       = "Eagle Eye!"
}