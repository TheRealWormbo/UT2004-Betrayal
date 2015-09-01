//=============================================================================
// MercuryFire
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// WeaponFire class for mercury missiles.
//=============================================================================


class BetrayalMercuryFire extends ProjectileFire;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\MercIgnite.wav


//=============================================================================
// Variables
//=============================================================================

var vector KickMomentum;


/**
@ignore
*/
function PlayFireEnd();


/**
Spawn and attach the flash emitter.
*/
function InitEffects()
{
	Super.InitEffects();
	if (FlashEmitter != None)
		Weapon.AttachToBone(FlashEmitter, 'tip');
}


/**
Play the firing animation.
*/
function PlayFiring()
{
	Super.PlayFiring();
	BetrayalMercuryLauncher(Weapon).PlayFiring(true);
}


/**
Spawns a mercury missile and disables its splash damage if neccessary.
*/
function Projectile SpawnProjectile(vector Start, rotator Dir)
{
	local Projectile p;
	local vector End, HitLocation, HitNormal, Kick;
	local BetrayalPRI PRI;

	// accuracy stats tracking
	PRI = BetrayalPRI(Instigator.PlayerReplicationInfo);
	if (PRI != None)
		PRI.Shots++;

	End = Instigator.Location + Instigator.EyePosition() + 80000 * vector(Dir);
	if (Instigator.Trace(HitLocation, HitNormal, End, Instigator.Location + Instigator.EyePosition(), false) != None) {
		Dir = rotator(HitLocation - Start);
	}

	if (ProjectileClass != None) {
		p = Weapon.Spawn(ProjectileClass,,, Start, Dir);
	}
	if (p != None) {
		p.Damage *= DamageAtten;
	}
	if (BetrayalMercuryMissile(p) != None) {
		if (BetrayalMercuryLauncher(Weapon) != None) {
			BetrayalMercuryMissile(p).RocketJumpBoost  = BetrayalMercuryLauncher(Weapon).RocketJumpBoost;
		}
		BetrayalMercuryMissile(p).TransferDamageAmount *= DamageAtten;
		BetrayalMercuryMissile(p).ImpactDamageAmount   *= DamageAtten;
	}
	else {
		log("No Mercury Missile:" @ p @ Instigator);
	}
	Kick = Normal(KickMomentum) * (ProjectileClass.default.Speed * ProjectileClass.default.Mass / Instigator.Mass);

	if (Instigator.Physics != PHYS_Walking)
		Instigator.AddVelocity(Kick >> Dir);

	return p;
}


/**
Set up for Berserk adrenaline combo. Increases firerate and raw damage by
about 15.5% each, resulting in about 33% more damage output per time.
*/
function StartBerserk()
{
	FireRate = default.FireRate * 0.866;         // roughly equals Sqrt(3/4)
	FireAnimRate = default.FireAnimRate * 1.154; // roughly equals Sqrt(4/3)
	ReloadAnimRate = default.ReloadAnimRate * 1.154;
	DamageAtten = default.DamageAtten * 1.154;
}


/**
Revert Berserk combo effects.
*/
function StopBerserk()
{
	FireRate = default.FireRate;
	FireAnimRate = default.FireAnimRate;
	ReloadAnimRate = default.ReloadAnimRate;
	DamageAtten = default.DamageAtten;
}


/**
Set up for Super Berserk mutator. Splits the berserk strength across firerate
and raw damage output.
*/
function StartSuperBerserk()
{
	FireRate = default.FireRate / Sqrt(Level.GRI.WeaponBerserk);
	FireAnimRate = default.FireAnimRate * Sqrt(Level.GRI.WeaponBerserk);
	ReloadAnimRate = default.ReloadAnimRate * Sqrt(Level.GRI.WeaponBerserk);
	DamageAtten = default.DamageAtten * Sqrt(Level.GRI.WeaponBerserk);
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	FireAnim     = Fire
	FireAnimRate = 1.0
	FireRate     = 0.9
	TweenTime    = 0.0
	FireSound    = Sound'MercIgnite'
	FireForce    = "RocketLauncherFire"
	TransientSoundVolume = 0.3

	ProjectileClass   = class'BetrayalMercuryMissile'
	ProjSpawnOffset   = (X=25,Y=6,Z=-6)
	FlashEmitterClass = class'XEffects.RocketMuzFlash1st'
	KickMomentum      = (X=-50.0,Z=5.0)

	bSplashDamage          = false
	bRecommendSplashDamage = false
	bSplashJump            = true
	BotRefireRate          = 0.5
	WarnTargetPct          = 0.9

	ShakeOffsetMag  = (X=-20.0,Y=0.00,Z=0.00)
	ShakeOffsetRate = (X=-1000.0,Y=0.0,Z=0.0)
	ShakeOffsetTime = 2
	ShakeRotMag     = (X=0.0,Y=0.0,Z=0.0)
	ShakeRotRate    = (X=0.0,Y=0.0,Z=0.0)
	ShakeRotTime    = 2
}
