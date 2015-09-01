/******************************************************************************
BetrayalMessage

Creation date: 2011-03-08 21:57
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalMessage extends CriticalEventPlus abstract;


//=============================================================================
// Imports
//=============================================================================

//#exec obj load file=..\Sounds\GameSounds.uax
#exec audio import file=Sounds\Assassin.wav
#exec audio import file=Sounds\Retribution.wav
#exec audio import file=Sounds\Payback.wav
#exec audio import file=Sounds\YouAreOnRed.wav
#exec audio import file=Sounds\YouAreOnBlue.wav
#exec audio import file=Sounds\Excellent.wav
#exec audio import file=Sounds\10KillsRemain.wav
#exec audio import file=Sounds\5KillsRemain.wav
#exec audio import file=Sounds\1KillRemains.wav


//=============================================================================
// Properties
//=============================================================================

var localized string StatsRestoredString, BetrayalString, BetrayalJoinTeam, RetributionString, PaybackString, RogueTimerExpiredString;

var Sound AssassinSound;
var Sound RetributionSound;
var Sound PaybackSound;
var Sound JoinTeamSound[2];
var Sound PaybackAvoidedSound/*, PaybackAvoidedRiff*/;
var Sound KillsRemainingSound[3];

var color BlueColor;


static simulated function ClientReceive(PlayerController P, optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	if (MessageSwitch >= 10 && MessageSwitch < 13) {
		P.PlayAnnouncement(default.KillsRemainingSound[MessageSwitch - 10], 1, true);
		return;
	}
	Super.ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

	switch (MessageSwitch) {
	case -2:
	case -1:
		P.PlayStatusAnnouncement('loaded', 2, true);
		break;

	case 0:
		P.PlayAnnouncement(default.AssassinSound, 1, true);
		break;

	case 1:
		P.PlayAnnouncement(default.JoinTeamSound[1 - int(class'BetrayalPRI'.default.bSwapTeamColors)], 1, false);
		break;

	case 2:
		P.PlayAnnouncement(default.RetributionSound, 1, true);
		break;

	case 3:
		P.PlayAnnouncement(default.PaybackSound, 1, true);
		break;

	case 5:
		P.PlayAnnouncement(default.PaybackAvoidedSound, 1, true);
		break;
	}
}


static function string GetString(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	switch (MessageSwitch) {
	case -2:
	case -1:
		return default.StatsRestoredString;
	case 1:
		return default.BetrayalJoinTeam;
	case 2:
		return default.RetributionString;
	case 3:
		return default.PaybackString;
	case 4:
	case 0:
		return Repl(Repl(default.BetrayalString, "%k", RelatedPRI_1.PlayerName, True), "%o", RelatedPRI_2.PlayerName, True);
	default:
		return default.RogueTimerExpiredString;
	}
}


static function int GetFontSize(int MessageSwitch, PlayerReplicationInfo RelatedPRI1, PlayerReplicationInfo RelatedPRI2, PlayerReplicationInfo LocalPlayer)
{
	if (MessageSwitch < 0 || MessageSwitch == 4)
		return default.FontSize - 1;
	return default.FontSize;
}

static function float GetLifeTime(int MessageSwitch)
{
	if (MessageSwitch < -1)
		return 2 * default.LifeTime;
	return default.LifeTime;
}


static function color GetColor(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2)
{
	if (MessageSwitch < 0 || MessageSwitch == 1 || MessageSwitch == 5)
		return default.BlueColor;
	return default.DrawColor;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bIsUnique = True
	Lifetime  = 6
	DrawColor = (R=255,G=0,B=0,A=255)
	BlueColor = (R=0,G=160,B=255,A=255)
	FontSize  = 2
	bBeep     = False
	StackMode = SM_Down
	PosY      = 0.242

	StatsRestoredString     = "Your stats have been restored"
	BetrayalString          = "%k BETRAYED %o!"
	BetrayalJoinTeam        = "JOINING NEW TEAM"
	RetributionString       = "RETRIBUTION!"
	PaybackString           = "PAYBACK!"
	RogueTimerExpiredString = "Payback Avoided"

	AssassinSound       = Sound'Assassin'
	RetributionSound    = Sound'Retribution'
	PaybackSound        = Sound'Payback'
	JoinTeamSound[0]    = Sound'YouAreOnRed'
	JoinTeamSound[1]    = Sound'YouAreOnBlue'
	PaybackAvoidedSound = Sound'Excellent'
	//PaybackAvoidedRiff  = Sound'GameSounds.Fanfares.UT2K3Fanfare08'

	KillsRemainingSound[0] = Sound'10KillsRemain'
	KillsRemainingSound[1] = Sound'5KillsRemain'
	KillsRemainingSound[2] = Sound'1KillRemains'
}

