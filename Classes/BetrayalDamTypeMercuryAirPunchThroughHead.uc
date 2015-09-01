//=============================================================================
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for mercury missile hitting head in mid-air without missile blowing up.
//=============================================================================


class BetrayalDamTypeMercuryAirPunchThroughHead extends BetrayalDamTypeMercuryAirHeadHit abstract;


/**
No flame effects for punch through.
*/
static function GetHitEffects(out class<xEmitter> HitEffects[4], int VictimHealth);


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	DeathString = "%k drove a mercury missile thorugh %o's head in mid-air."
	KDeathVel   = 400.0
	bFlaming    = False
}
