//=============================================================================
// DamTypeMercuryDirectHit
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for mercury missile splash damage.
//=============================================================================


class BetrayalDamTypeMercurySplashDamage extends WeaponDamageType abstract;


/**
Flame effects.
*/
static function GetHitEffects(out class<xEmitter> HitEffects[4], int VictimHealth)
{
	HitEffects[0] = class'HitSmoke';

	if (VictimHealth <= 0)
		HitEffects[1] = class'HitFlameBig';
	else if (FRand() < 0.5)
		HitEffects[1] = class'HitFlame';
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	WeaponClass      = Class'BetrayalMercuryLauncher'
	DeathString      = "%o was way too slow for %k's mercury missile."
	FemaleSuicide    = "%o checked if her Mercury Missile Launcher was loaded."
	MaleSuicide      = "%o checked if his Mercury Missile Launcher was loaded."
	bDetonatesGoop   = True
	bKUseOwnDeathVel = True
	KDeathVel        = 150.0
	KDeathUpKick     = 50.0
	bDelayedDamage   = True
	GibPerterbation  = 0.15
}
