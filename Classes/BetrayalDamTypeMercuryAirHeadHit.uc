//=============================================================================
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for mercury missile hitting the head in mid-air and blowing up.
//=============================================================================


class BetrayalDamTypeMercuryAirHeadHit extends BetrayalDamTypeMercuryHeadHit abstract;


//=============================================================================
// IncrementKills
//
// Play a headshot announcement and count the number of headshots
//=============================================================================

static function IncrementKills(Controller Killer)
{
	Super.IncrementKills(Killer);
	class'BetrayalDamTypeMercuryAirHit'.static.IncrementKills(Killer);
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	DeathString = "%k picked off %o's head in mid-air with a mercury missile."
}
