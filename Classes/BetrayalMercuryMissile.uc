//=============================================================================
// MercuryMissile
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// High speed rocket.
//=============================================================================


class BetrayalMercuryMissile extends Projectile;


//=============================================================================
// Imports
//=============================================================================

// general package imports
#exec obj load file=XGameShaders.utx
#exec obj load file=XEffectMat.utx
#exec obj load file=VMWeaponsSM.usx

// preconstructed resource package with textures and staticmeshes
#exec obj load file=BetrayalMercuryMissileResources.usx package=BetrayalV1

#exec audio import file=Sounds\MercFly.wav
#exec audio import file=Sounds\MercHitArmor.wav
#exec audio import file=Sounds\MercPunchThrough.wav


//=============================================================================
// Structs
//=============================================================================

struct TVictimInfo {
	var Actor Actor;
	var vector HL, HN;
};

struct TExplosionEffectInfo {
	var Actor Other;
	var vector HitLocation;
	var vector HitNormal;
};


//=============================================================================
// Properties
//=============================================================================

var class<WeaponDamageType> SplashDamageType;
var float SplashMomentum;
var float TransferDamageAmount, ImpactDamageAmount;

var class<WeaponDamageType> HeadHitDamage, DirectHitDamage, PunchThroughDamage, ThroughHeadDamage;
var class<WeaponDamageType> AirHeadHitDamage, AirHitDamage, AirPunchThroughDamage, AirThroughHeadDamage;
var float AccelRate;
var float HeadShotSizeAdjust;
var float PunchThroughSpeed, PunchThroughVelocityLossPercent;
var float RocketJumpBoost;
var Sound ExplodeOnPlayerSound;

var array<ParticleEmitter.ParticleColorScale> BetrayalThrusterColorScale;
var rangevector TrailLineColor;
var float DopplerStrength, DopplerBaseSpeed;

var bool bSameTeamShot;


//=============================================================================
// Variables
//=============================================================================

/**
Replicated direction of flight to get around inaccurate rotator replication.
*/
var int Direction;

var BetrayalMercuryMissileTrail Trail;

/** Hit count for multi-hit messages. */
var int EnemyHitCount;

/** Spawn location for determining nice air hits. */
var vector SpawnLocation, PrevTouchLocation;

var transient vector TouchLocation, TouchNormal;
var transient vector WallLocation, WallNormal;
var transient Actor PrevTouched;

var TExplosionEffectInfo ExplosionEffectInfo;

var bool bFakeDestroyed, bCanHitOwner, bWasHeadshot, bWasAirHit;


//=============================================================================
// Replication
//=============================================================================

replication
{
	reliable if (bNetInitial)
		Direction, bFakeDestroyed, PunchThroughSpeed;

	reliable if (bNetDirty)
		ExplosionEffectInfo;
}


simulated function BeginPlay()
{
	SpawnLocation = Location;

	Velocity = Speed * vector(Rotation);
	if (Role == ROLE_Authority) // replicate rotation with maximum precision
		Direction = (Rotation.Yaw & 0xffff) | (Rotation.Pitch << 16);

	Acceleration = AccelRate * vector(Rotation);

	Super.BeginPlay();
}


simulated function PostBeginPlay()
{
	if (!bSameTeamShot && BetrayalGame(Level.Game) != None && BetrayalGame(Level.Game).bBeamMultiHit)
		PunchThroughSpeed *= 0.75;

	if (PhysicsVolume.bWaterVolume)
		Velocity *= 0.6;

	if (Level.NetMode != NM_DedicatedServer)
		Trail = Spawn(class'BetrayalMercuryMissileTrail', self,, Location, Rotation);

	Super.PostBeginPlay();

	PlaySound(SpawnSound, SLOT_Misc);
}

simulated function PostNetBeginPlay()
{
	local rotator DirRot;

	if (Role < ROLE_Authority && Direction != -1) {
		// adjust direction of flight accordingly to prevent replication-related inaccuracies
		DirRot.Yaw = Direction & 0xffff;
		DirRot.Pitch = Direction >> 16;
		Acceleration = AccelRate * vector(DirRot);
		Velocity = VSize(Velocity) * vector(DirRot);
	}
	if (Trail != None) {
		if (bSameTeamShot) {
			Trail.Emitters[0].ColorScale = BetrayalThrusterColorScale;
			Trail.Emitters[2].ColorScale = BetrayalThrusterColorScale;
		}
		Trail.Emitters[1].ColorMultiplierRange = TrailLineColor;
		Trail.Emitters[1].Disabled = false;
	}
	if (bFakeDestroyed && Level.NetMode == NM_Client) {
		bFakeDestroyed = False;
		TornOff();
	}
}


/**
Sets the projectile in a "would-be destroyed" state.
Doesn't differ from calling Destroy() if the prjectile has RemoteRole < ROLE_SimulatedProxy.
NOTE: This function may not have the desired results if projectile is bNetTemporary!
*/
simulated function FakeDestroy()
{
	if (Level.NetMode == NM_Standalone || Level.NetMode == NM_Client || RemoteRole < ROLE_SimulatedProxy) {
		Destroy();
	}
	else {
		GotoState('WasFakeDestroyed');
	}
}

/**
Called after the projectile is FakeDestroy()ed.
Do not rely on the projectile continuing to exist after this function call since FakeDestroy() may call Destroy() right after calling this function!
*/
simulated function FakeDestroyed()
{
	local BetrayalPRI PRI;

	if (Trail != None) {
		Trail.Kill();
		Trail = None;
	}

	if (InstigatorController == None || Role < ROLE_Authority)
		return;

	PRI = BetrayalPRI(InstigatorController.PlayerReplicationInfo);
	if (PRI != None) {
		if (EnemyHitCount > 0)
			PRI.Hits++;
		if (EnemyHitCount > 1)
			PRI.MultiHits++;
		if (EnemyHitCount > PRI.BestMultiHit)
			PRI.BestMultiHit = EnemyHitCount;
		if (bWasAirHit)
			PRI.EagleEyes++;
	}
	if (EnemyHitCount > 1 && PlayerController(InstigatorController) != None)
		PlayerController(InstigatorController).ReceiveLocalizedMessage(class'BetrayalSpecialKillMessage', EnemyHitCount);
	if (EnemyHitCount > 1 || bWasHeadshot || bWasAirHit) {
		if (BetrayalGame(Level.Game) != None)
			BetrayalGame(Level.Game).ScoreSpecialKill(InstigatorController);
	}
}


/**
Called by the engine on clients after bTearOff was set to True, i.e. also when the projectile was FakeDestroy()ed.
*/
simulated function TornOff()
{
	ProcessContact(false, ExplosionEffectInfo.Other, ExplosionEffectInfo.HitLocation, Normal(ExplosionEffectInfo.HitNormal));
	Destroy();
}


/**
Wait a bit before allowing owner hits.
Adjust ambient sound to fake doppler effect.
*/
auto simulated state Flying
{
	/**
	Fake doppler effect.
	*/
	simulated event Tick(float DeltaTime)
	{
		local PlayerController LocalPlayer;
		local float ApproachSpeed;

		if (Level.NetMode != NM_DedicatedServer) {
			LocalPlayer = Level.GetLocalPlayerController();
			if (LocalPlayer != None) {
				ApproachSpeed = (Velocity + LocalPlayer.ViewTarget.Velocity) dot Normal(LocalPlayer.ViewTarget.Location - Location);
				SoundPitch = default.SoundPitch * (DopplerStrength ** (ApproachSpeed / DopplerBaseSpeed));
			}
		}
	}

Begin:
	do {
		Sleep(0.1);
	} until (Instigator != None && VSize(Instigator.Location - Location) < 10.0 * (Instigator.CollisionRadius + Instigator.CollisionHeight));

	SetOwner(None);
	bCanHitOwner = True;
}


/**
The fake-destroyed state. The server enters this state after FakeDestroy() was called.
*/
state WasFakeDestroyed
{
	ignores Touch, Bump, HitWall, TakeDamage, EncroachingOn, Timer;

	/**
	Hides the projectile and disables its collision and movement upon entering the fake-destroyed state.
	*/
	simulated function BeginState()
	{
		Assert(Level.NetMode != NM_Client && Level.NetMode != NM_Standalone);
		bFakeDestroyed = True;
		FakeDestroyed();
		LifeSpan = 0.5;
		bHidden = True;
		SetPhysics(PHYS_None);
		SetCollision(False, False, False);
		bCollideWorld = False;
		LightType = LT_None;
		AmbientSound = None;
	}

Begin:
	Sleep(0.0);
	bTearOff = True;
}


/**
Unregister from any projectile modifiers and potential parent projectiles.
*/
simulated function Destroyed()
{
	if (!bFakeDestroyed) {
		FakeDestroyed();
	}
}


/**
Returns how a contact with another object affects this projectile's movement.
*/
simulated function bool ShouldPenetrate(Actor Other, vector HitNormal)
{
	return UnrealPawn(Other) != None && !Other.IsInState('Frozen') && VSize(Velocity) - Normal(Velocity) dot Other.Velocity > PunchThroughSpeed && UnrealPawn(Other).GetShieldStrength() == 0;
}

/**
Called when the projectile hits a wall. This just sets HurtWall, the actual magic is in ProcessContact().
*/
simulated singular function HitWall(vector HitNormal, Actor Wall)
{
	HurtWall = Wall;
	WallLocation = Location;
	WallNormal = HitNormal;
	ProcessContact(ShouldPenetrate(Wall, HitNormal), Wall, Location, HitNormal);
	HurtWall = None;
}


/**
Called when the projectile touches something. This just sets LastTouched, the actual magic is in ProcessContact().
*/
simulated singular function Touch(Actor Other)
{
	if (bTearOff || Other == None || PrevTouched == Other && VSize(Location - PrevTouchLocation) < 250.0 || Other == Instigator && !bCanHitOwner)
		return;

	if (Other.bProjTarget || Other.bBlockActors) {
		PrevTouched = Other;
		LastTouched = Other;
		if (Velocity == vect(0,0,0))
			Velocity = vector(Rotation);

		if (Other.TraceThisActor(TouchLocation, TouchNormal, Location, Location - 0.5 * Velocity)) {
			TouchLocation = Location;
			TouchNormal = -Normal(Velocity);
		}
		PrevTouchLocation = TouchLocation;
		ProcessContact(ShouldPenetrate(Other, TouchNormal), Other, TouchLocation, TouchNormal);
		LastTouched = None;
	}
}


/**
Obsolete. Use ProcessContact() instead.
*/
simulated function ClientSideTouch(Actor Other, vector HitLocation)
{
	Assert(false);
}

/**
Obsolete. Use ProcessContact() instead.
*/
simulated function ProcessTouch(Actor Other, vector HitLocation)
{
	Assert(false);
}

/**
Obsolete. Use ProcessContact() and related functions instead.
*/
simulated function BlowUp(vector HitLocation)
{
	Assert(false);
}

/**
Called by ONSPowerCoreShield.Touch(), detects actual hit location/normal and calls ProcessContact without penetration.
*/
simulated function Explode(vector HitLocation, vector HitNormal)
{
	ProcessContact(False, Trace(HitLocation, HitNormal, HitLocation + 10 * HitNormal, HitLocation - 10 * HitNormal, True), HitLocation, HitNormal);
}


simulated function ProcessContact(bool bPenetrate, Actor Other, vector HitLocation, vector HitNormal)
{
	local vector HN, HL, VDiff;
	local float HeightMult;
	local bool bAirHit, bNoDamage, bHeadshot;
	local PlayerController PC;
	local class<WeaponDamageType> DamageType;
	local Pawn HeadshotPawn, HitPawn;
	local BetrayalGame Game;
	local BetrayalPRI PRI, OtherPRI;

	// check for headshot
	if (Vehicle(Other) != None) {
		HeadShotPawn = Vehicle(Other).CheckForHeadShot(HitLocation, Normal(Velocity), HeadShotSizeAdjust);
	}
	if (HeadShotPawn != None) {
		if (LastTouched == Other)
			LastTouched = HeadShotPawn;
		bPenetrate = ShouldPenetrate(HeadShotPawn, HitNormal);
		Other = HeadShotPawn;
	}
	else if (Pawn(Other) != None && Pawn(Other).IsHeadShot(HitLocation, Normal(Velocity), HeadShotSizeAdjust)) {
		HeadShotPawn = Pawn(Other);
	}
	HitPawn = Pawn(Other);

	// check for nice air hit
	HeightMult = class'PhysicsVolume'.default.Gravity.Z / Other.PhysicsVolume.Gravity.Z;
	if (UnrealPawn(Other) != None && UnrealPawn(Other).Health > 0 && Other.Physics == PHYS_Falling && VSize(Other.Location - SpawnLocation) > 500 * HeightMult && Other.Trace(HL, HN, Other.Location - vect(0,0,200) * HeightMult, Other.Location, False, Other.GetCollisionExtent()) == None) {
		// far enough away and high enough in air
		if (Other.Velocity.Z > 100 / HeightMult) {
			Other.Trace(HL, HN, Other.Location - Normal(Other.Velocity) * (200 * HeightMult), Other.Location, False, Other.GetCollisionExtent());
		}
		else if (Other.Velocity.Z < -100 / HeightMult) {
			Other.Trace(HL, HN, Other.Location + Normal(Other.Velocity) * (100 * HeightMult), Other.Location, False, Other.GetCollisionExtent());
		}
		bAirHit = HN.Z < 0.7;
	}

	VDiff = Velocity - Normal(Velocity) * (Normal(Velocity) dot Other.Velocity);
	if (bPenetrate) {
		VDiff *= PunchThroughVelocityLossPercent;
		if (HeadShotPawn != None) {
			if (bAirHit)
				DamageType = AirThroughHeadDamage;
			else
				DamageType = ThroughHeadDamage;
		}
		else {
			if (bAirHit)
				DamageType = AirPunchThroughDamage;
			else
				DamageType = PunchThroughDamage;
		}
	}
	else {
		if (HeadShotPawn != None) {
			if (bAirHit)
				DamageType = AirHeadHitDamage;
			else
				DamageType = HeadHitDamage;
		}
		else {
			if (bAirHit)
				DamageType = AirHitDamage;
			else
				DamageType = DirectHitDamage;
		}
	}
	if (Role == ROLE_Authority) {
		Game = BetrayalGame(Level.Game);
		PRI = BetrayalPRI(Instigator.PlayerReplicationInfo);
		if (Pawn(Other) != None && PRI != None) {
			OtherPRI = BetrayalPRI(Pawn(Other).PlayerReplicationInfo);
			if (OtherPRI != None && OtherPRI.bIsRogue && PRI.Betrayer == OtherPRI && OtherPRI.RemainingRogueTime == OtherPRI.RogueTimePenalty) {
				// hit right after he betrayed the instigator, allow instant retribution
				bSameTeamShot = False;
			}
		}
		if (Game == None || Pawn(Other) != None && Game.OnSameTeam(Instigator, Pawn(Other)) == bSameTeamShot) {
			if (Game != None && Pawn(Other) != None && bSameTeamShot) {
				Game.ShotTeammate(PRI, OtherPRI, Instigator, Pawn(Other));
			}
			if (Pawn(Other) != None) {
				CountHit(Pawn(Other));
			}
		}
		else {
			bNoDamage = True;
		}

		if (HeadshotPawn != None) {
			bHeadshot = True;
			PC = PlayerController(HeadShotPawn.Controller);
		}
	}

	if (Role == ROLE_Authority && Level.NetMode == NM_Client) {
		// already torn off, do nothing
		return;
	}
	if (Role == ROLE_Authority) {
		MakeNoise(1.0);
	}
	ApplyDamage(HitLocation, VDiff, bPenetrate, DamageType, HeadshotPawn, bNoDamage);
	if (!bPenetrate) {
		SpawnExplosionEffects(Other, HitLocation, HitNormal);
	}
	if (bHeadshot && (HeadshotPawn == None || HeadshotPawn.bDeleteMe || HeadshotPawn.Health <= 0)) {
		if (PC != None)
			PC.ReceiveLocalizedMessage(class'BetrayalSpecialKillMessage',, InstigatorController.PlayerReplicationInfo);
		bWasHeadshot = True;
	}
	if (bAirHit && (HitPawn == None || HitPawn.bDeleteMe || HitPawn.Health <= 0)) {
		bWasAirHit = True;
	}
	if (Role == ROLE_Authority || Other == None || Other.Role < ROLE_Authority) {
		if (bPenetrate) {
			Velocity -= VDiff;
			SpawnPenetrationEffects(Other, HitLocation, HitNormal);
		}
		else {
			if (Role == ROLE_Authority) {
				ExplosionEffectInfo.Other = Other;
				ExplosionEffectInfo.HitLocation = HitLocation;
				ExplosionEffectInfo.HitNormal = HitNormal * 1000;
				ExplosionEffectInfo = ExplosionEffectInfo;
				SetLocation(HitLocation);
				FakeDestroy();
			}
			else {
				Destroy();
			}
			return;
		}
	}
}


/**
Hurt all actors within the specified radius.
*/
simulated function ApplyDamage(vector HitLocation, vector VDiff, bool bPenetrate, class<WeaponDamageType> DamageType, Pawn HeadshotPawn, bool bNoDamage)
{
	local array<TVictimInfo> Victims;
	local TVictimInfo VictimInfo;
	local float dist;
	local int i;
	local float DamageAmount;
	local vector Momentum;
	local bool bSplashHit;

	if (bHurtEntry) return;

	bHurtEntry = true;

	if (!bPenetrate) {
		foreach VisibleCollidingActors(class'Actor', VictimInfo.Actor, DamageRadius + 300, HitLocation) {
			if (VictimInfo.Actor.Role == ROLE_Authority && VictimInfo.Actor != LastTouched && VictimInfo.Actor != HurtWall && VictimInfo.Actor != Self && FluidSurfaceInfo(VictimInfo.Actor) == None && !VictimInfo.Actor.TraceThisActor(VictimInfo.HL, VictimInfo.HN, HitLocation + Normal(VictimInfo.Actor.Location - HitLocation) * DamageRadius, HitLocation)) {
				Victims[Victims.Length] = VictimInfo;
			}
		}
	}

	if (LastTouched != None) {
		VictimInfo.HL = TouchLocation;
		VictimInfo.HN = TouchNormal;
		VictimInfo.Actor = LastTouched;
		Victims[Victims.Length] = VictimInfo;
	}
	if (HurtWall != None) {
		VictimInfo.HL = WallLocation;
		VictimInfo.HN = WallNormal;
		VictimInfo.Actor = HurtWall;
		Victims[Victims.Length] = VictimInfo;
	}

	for (i = 0; i < Victims.Length; i++) {
		if (Victims[i].Actor != None) {
			bSplashHit = Victims[i].Actor != LastTouched && Victims[i].Actor != HurtWall;
			dist = VSize(Victims[i].HL - HitLocation);

			// splash momentum
			if (dist < DamageRadius && !bPenetrate) {
				Momentum = Normal(Victims[i].Actor.Location - HitLocation) * SplashMomentum * (1 - dist / DamageRadius);
				if (Victims[i].Actor == Instigator) {
					Momentum *= RocketJumpBoost;
				}
			}
			else {
				Momentum = vect(0,0,0);
			}

			if (bSplashHit || bNoDamage) {
				// no impact damage
				DamageAmount = 0;
			}
			else {
				// impact damage
				DamageAmount = Damage;

				// add impact momentum
				Momentum += VDiff * MomentumTransfer;
			}

			if (int(DamageAmount) > 0 || VSize(Momentum) > 0) {
				Victims[i].Actor.SetDelayedDamageInstigatorController(InstigatorController);
				if (bSplashHit)
					Victims[i].Actor.TakeDamage(DamageAmount, Instigator, Victims[i].HL, Momentum, SplashDamageType);
				else
					Victims[i].Actor.TakeDamage(DamageAmount, Instigator, Victims[i].HL, Momentum, DamageType);
			}
		}
	}

	bHurtEntry = false;
}


/**
Count direct hits against enemies and team mates for multi-hit messages.
*/
function CountHit(Pawn Other)
{
	if (InstigatorController == None || Other == None || Other.Health <= 0 || Other.Controller == None || Other.Controller == InstigatorController)
		return;

	EnemyHitCount++;
}


/**
Spawns explosion/punch-through effects.
*/
simulated function SpawnExplosionEffects(Actor Other, vector HitLocation, vector HitNormal)
{
	local PlayerController PC;
	local class<BetrayalMercuryExplosion> ExplosionClass;
	local rotator EffectRotationOffset;

	if (UnrealPawn(Other) != None && !Other.IsInState('Frozen')) {
		PlayBroadcastedSound(Other, ExplodeOnPlayerSound);
	}
	ExplosionClass = GetExplosionClass(Other, HitLocation, HitNormal, EffectRotationOffset);
	if (ExplosionClass != None) {
		Spawn(ExplosionClass,,, HitLocation, rotator(-HitNormal) + EffectRotationOffset).bWaterExplosion = PhysicsVolume.bWaterVolume;
	}
	if (ExplosionDecal != None && Level.NetMode != NM_DedicatedServer)	{
		// spawn explosion decal with random Roll, if within view range
		PC = Level.GetLocalPlayerController();
		if (!PC.BeyondViewDistance(Location, ExplosionDecal.Default.CullDistance))
			Spawn(ExplosionDecal, self,, Location, rotator(-HitNormal) + rot(0,0,1) * Rand(0x10000));
		else if (InstigatorController != None && PC == InstigatorController && !PC.BeyondViewDistance(Location, 2 * ExplosionDecal.Default.CullDistance))
			Spawn(ExplosionDecal, self,, Location, rotator(-HitNormal) + rot(0,0,1) * Rand(0x10000));
	}
}


/**
Play penetration sound and spawn a lot of blood after penetrating an unprotected player.
*/
simulated function SpawnPenetrationEffects(Actor Other, vector HitLocation, vector HitNormal)
{
	if (Other != None) {
		PlayBroadcastedSound(Other, ImpactSound);
		if (!class'GameInfo'.static.UseLowGore() && xPawn(Other) != None && xPawn(Other).GibGroupClass != None) {
			if ((HitLocation - Other.Location) dot Velocity < 0)
				HitLocation += Normal(Velocity) * Other.CollisionRadius;
			Spawn(xPawn(Other).GibGroupClass.default.BloodGibClass, Other,, HitLocation);
		}
	}
}


/**
Called from simulated functions to trick PlaySound() into broadcasting the sound instead of playing it locally.
*/
function PlayBroadcastedSound(Actor SoundOwner, Sound Sound)
{
	if (Level.NetMode != NM_Client && SoundOwner != None && Sound != None) {
		SoundOwner.PlaySound(Sound, SLOT_Misc, TransientSoundVolume, false, TransientSoundRadius);
	}
}


/**
Return an explosion effect class with dirt or snow particles if a corresponding surface was hit.
Non-simulated so effect is only spawned on server.
*/
simulated function class<BetrayalMercuryExplosion> GetExplosionClass(Actor HitActor, vector HitLocation, vector HitNormal, out rotator EffectRotationOffset)
{
	local Material HitMaterial;
	local vector HL, HN;

	EffectRotationOffset = rot(16384,0,16384);

	if (PhysicsVolume.bWaterVolume) {
		return class'BetrayalMercuryExplosion';
	}

	if (HitActor == None || HitActor.bWorldGeometry) {
		HitActor = Trace(HL, HN, HitLocation - 16 * HitNormal, HitLocation + HitNormal, True,, HitMaterial);
	}
	if (HitMaterial != None) {
		switch (HitMaterial.SurfaceType) {
			case EST_Rock:
			case EST_Dirt:
			case EST_Wood:
			case EST_Plant:
				return class'BetrayalMercuryExplosionDirt';
			case EST_Ice:
			case EST_Snow:
				return class'BetrayalMercuryExplosionSnow';
		}
	}
	else if (HitActor != None) {
		switch (HitActor.SurfaceType) {
			case EST_Rock:
			case EST_Dirt:
			case EST_Wood:
			case EST_Plant:
				return class'BetrayalMercuryExplosionDirt';
			case EST_Ice:
			case EST_Snow:
				return class'BetrayalMercuryExplosionSnow';
		}
	}
	return class'BetrayalMercuryExplosion';
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	bBounce           = True
	bFixedRotationDir = True
	RotationRate      = (Roll=0)
	DesiredRotation   = (Roll=0)
	ForceType         = FT_Constant
	ForceRadius       =   100.0
	ForceScale        =     5.0
	Mass              =     4.0
	LifeSpan          =     6.0
	Speed             =  3000.0
	MaxSpeed          = 25000.0
	AccelRate         = 10000.0
	PunchThroughSpeed =  7000.0
	PunchThroughVelocityLossPercent = 0.4

	ImpactSound          = Sound'MercPunchThrough'
	ExplodeOnPlayerSound = Sound'MercHitArmor'

	AmbientSound = Sound'MercFly'
	SoundRadius  = 300.0
	SoundVolume  = 160
	SoundPitch   =  64

	DopplerBaseSpeed = 3000.0
	DopplerStrength  = 1.5

	TransientSoundRadius = 500.0
	TransientSoundVolume =   1.0

	RocketJumpBoost      = 3.0
	HeadShotSizeAdjust   = 1.2

	Damage               =  1000.0
	DamageRadius         =   150.0
	SplashMomentum       = 10000.0
	MomentumTransfer     =     4.0
	ExplosionDecal       = Class'BetrayalMercuryImpactMark'

	SplashDamageType = Class'BetrayalDamTypeMercurySplashDamage'
	MyDamageType     = Class'BetrayalDamTypeMercuryDirectHit'

	HeadHitDamage         = Class'BetrayalDamTypeMercuryHeadHit'
	DirectHitDamage       = Class'BetrayalDamTypeMercuryDirectHit'
	ThroughHeadDamage     = Class'BetrayalDamTypeMercuryPunchThroughHead'
	PunchThroughDamage    = Class'BetrayalDamTypeMercuryPunchThrough'
	AirHeadHitDamage      = Class'BetrayalDamTypeMercuryAirHeadHit'
	AirHitDamage          = Class'BetrayalDamTypeMercuryAirHit'
	AirThroughHeadDamage  = Class'BetrayalDamTypeMercuryAirPunchThroughHead'
	AirPunchThroughDamage = Class'BetrayalDamTypeMercuryAirPunchThrough'

	Direction = -1

	LightType       = LT_Steady
	LightEffect     = LE_QuadraticNonIncidence
	LightBrightness = 255.0
	LightRadius     =   5.0
	LightHue        =  20
	bDynamicLight   = True

	Skins(0)     = TexScaler'MercuryMissileTexRed'

	AmbientGlow = 96
	DrawType    = DT_StaticMesh
	StaticMesh  = StaticMesh'VMWeaponsSM.AVRiLGroup.AVRiLprojectileSM'
	DrawScale   = 0.2
	DrawScale3D = (X=1.1,Y=0.5,Z=0.5)
	SurfaceType = EST_Metal

	BetrayalThrusterColorScale = ((Color=(R=96,G=128,B=255,A=255)),(RelativeTime=1.0,Color=(R=0,G=32,B=128)))
	TrailLineColor = (X=(Min=1.0,Max=1.0),Y=(Min=0.3,Max=0.3),Z=(Min=0.3,Max=0.3))

	bReplicateInstigator = True
}
