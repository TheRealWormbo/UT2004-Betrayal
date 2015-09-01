//=============================================================================
// DamTypeMercuryDirectHit
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for direct mercury missile hit with missile blowing up.
//=============================================================================


class BetrayalDamTypeMercuryDirectHit extends WeaponDamageType abstract;


/**
Flame effects.
*/
static function GetHitEffects(out class<xEmitter> HitEffects[4], int VictimHealth)
{
	HitEffects[0] = class'HitSmoke';

	if (VictimHealth <= 0 && FRand() < 0.5)
		HitEffects[1] = class'HitFlameBig';
	else if (FRand() < 0.5)
		HitEffects[1] = class'HitFlame';
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	WeaponClass       = Class'BetrayalMercuryLauncher'
	DeathString       = "%k drove a mercury missile into %o."
	FemaleSuicide     = "%o somehow managed to get hit by her own mercury missile."
	MaleSuicide       = "%o somehow managed to get hit by his own mercury missile."
	bDetonatesGoop    = True
	bKUseOwnDeathVel  = True
	KDamageImpulse    = 20000.0
	KDeathVel         = 550.0
	KDeathUpKick      = 100.0
	bDelayedDamage    = True
	bRagdollBullet    = True
	bBulletHit        = True
	GibPerterbation   = 0.35
	bAlwaysSevers     = True
	bLocationalHit    = False
}
