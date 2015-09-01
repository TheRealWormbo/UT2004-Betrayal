/******************************************************************************
BetrayalMultiKillMessage

Creation date: 2011-07-18 09:46
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalMultiKillMessage extends MultiKillMessage;


static function string GetString(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	local int MaxSwitch;


	if (class'PlayerController'.default.bNoMatureLanguage)
		MaxSwitch = 6;
	else
		MaxSwitch = 7;

	if (MessageSwitch > MaxSwitch)
		return default.KillString[MaxSwitch - 1] @ "+" $ MessageSwitch - MaxSwitch;
	return Default.KillString[Min(MessageSwitch, MaxSwitch) - 1];
}

//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}

