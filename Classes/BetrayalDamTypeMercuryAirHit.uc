//=============================================================================
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for direct mercury missile air hit with missile blowing up.
//=============================================================================


class BetrayalDamTypeMercuryAirHit extends BetrayalDamTypeMercuryDirectHit abstract;


//=============================================================================
// IncrementKills
//
// Play a headshot announcement and count the number of headshots
//=============================================================================

static function IncrementKills(Controller Killer)
{
	if (BetrayalPRI(Killer.PlayerReplicationInfo) != None)
		BetrayalPRI(Killer.PlayerReplicationInfo).FlakCount++;

	if (PlayerController(Killer) == None)
		return;

	PlayerController(Killer).ReceiveLocalizedMessage(class'BetrayalSpecialKillMessage', 1);
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	DeathString   = "%k picked off %o in mid-air with a mercury missile."
}
