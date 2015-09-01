//=============================================================================
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for direct mercury missile air hit without missile blowing up.
//=============================================================================


class BetrayalDamTypeMercuryAirPunchThrough extends BetrayalDamTypeMercuryAirHit abstract;


/**
No flame effects for punch through.
*/
static function GetHitEffects(out class<xEmitter> HitEffects[4], int VictimHealth);


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	DeathString     = "%k drove a mercury missile through %o in mid-air."
	KDeathVel       = 400.0
	GibPerterbation = 0.5
	GibModifier     = 2.0
	bFlaming        = False
}
