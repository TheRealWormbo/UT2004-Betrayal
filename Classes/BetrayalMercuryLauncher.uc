//=============================================================================
// MercuryLauncher
// Copyright 2003-2010 by Wormbo <wormbo@online.de>
//
// Modified rocket launcher.
//=============================================================================


class BetrayalMercuryLauncher extends Weapon hidedropdown config(User);


//=============================================================================
// Variables
//=============================================================================

var float RocketJumpBoost;


simulated function PostBeginPlay()
{
	// sanity check: are we actually running Betrayal?
	if (Level.GRI != None && BetrayalGRI(Level.GRI) == None)
		FireModeClass[1] = FireModeClass[0];
	Super.PostBeginPlay();
}


simulated function bool ConsumeAmmo(int Mode, float Load, optional bool bAmountNeededIsMax)
{
	return true;
}

simulated function CheckOutOfAmmo()
{
}

simulated function bool HasAmmo()
{
	return true;
}

simulated function PlayIdle()
{
	LoopAnim(IdleAnim, IdleAnimRate, 0.25);
}

simulated function PlayFiring(bool plunge)
{
	if (plunge)
		GotoState('AnimateLoad', 'Begin');
}

simulated function AnimEnd(int Channel)
{
	if (Channel == 0 && ClientState == WS_ReadyToFire) {
		PlayIdle();
		if (Role < ROLE_Authority && !HasAmmo())
			DoAutoSwitch(); //FIXME HACK
	}
}

simulated function Plunge()
{
	PlayAnim('load', 0.8, 0.0, 1);
	PlayAnim('load', 0.8, 0.0, 2);
}

simulated function BringUp(optional Weapon PrevWeapon)
{
	if (Instigator.IsLocallyControlled()) {
		AnimBlendParams(1, 1.0, 0.0, 0.0, 'bone_shell');
		AnimBlendParams(2, 1.0, 0.0, 0.0, 'bone_feed');
		SetBoneRotation('Bone_Barrel', Rot(0,0,0), 0, 1);
	}
	Super.BringUp(PrevWeapon);
}

simulated state AnimateLoad
{
Begin:
	Sleep(0.07);
	PlaySound(Sound'WeaponSounds.RocketLauncher.RocketLauncherLoad', SLOT_None,,,,,false);
	ClientPlayForceFeedback("RocketLauncherLoad");  // jdf
	Sleep(0.28);
	Plunge();
	PlaySound(Sound'WeaponSounds.RocketLauncher.RocketLauncherPlunger', SLOT_None,,,,,false);
	ClientPlayForceFeedback("RocketLauncherPlunger");  // jdf
	Sleep(0.29);
	GotoState('');
}

// AI Interface
function float SuggestAttackStyle()
{
	local float EnemyDist;

	// recommend backing off if target is too close
	EnemyDist = VSize(Instigator.Controller.Enemy.Location - Instigator.Location);
	if (EnemyDist < 750) {
		if (EnemyDist < 500)
			return -1.5;
		else
			return -0.7;
	}
	else if (EnemyDist > 1600)
		return 0.0;
	else
		return -0.1;
}

// tell bot how valuable this weapon would be to use, based on the bot's combat situation
// also suggest whether to use regular or alternate fire mode
function float GetAIRating()
{
	local Bot B;
	local float EnemyDist, Rating, ZDiff;
	local vector EnemyDir;

	B = Bot(Instigator.Controller);
	if (B == None || B.Enemy == None)
		return AIRating;

	EnemyDir = B.Enemy.Location - Instigator.Location;
	EnemyDist = VSize(EnemyDir);
	Rating = AIRating;

	Rating += FMin(2000 / EnemyDist - 0.5, 0.3);

	// rockets are good if higher than target, bad if lower than target

	ZDiff = Instigator.Location.Z - B.Enemy.Location.Z;
	if (ZDiff > 120) {
		Rating += 0.25;
	}
	return Rating;
}

/* BestMode()
choose between regular or alt-fire
*/
function byte BestMode()
{
	local Bot B;
	local BetrayalGame Game;

	Game = BetrayalGame(Level.Game);
	B = Bot(Instigator.Controller);
	if (B != None && Game != None && Game.OnSameTeam(Instigator, B.Enemy))
		return 1;

	return 0;
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	RocketJumpBoost = 3.0

	FireModeClass(0) = Class'BetrayalMercuryFire'
	FireModeClass(1) = Class'BetrayalMercuryAltFire'

	SelectAnim   = "Pickup"
	PutDownAnim  = "PutDown"
	IdleAnimRate = 0.5
	SelectSound  = Sound'WeaponSounds.RocketLauncher.SwitchToRocketLauncher'
	SelectForce  = "SwitchToRocketLauncher"

	//PickupClass     = Class'BetrayalMercuryLauncherPickup'
	AttachmentClass = Class'BetrayalMercuryLauncherAttachment'

	AIRating      = 0.8
	CurrentRating = 0.8

	Priority        = 10
	DefaultPriority = 9
	InventoryGroup  = 8
	GroupOffset     = 2

	EffectOffset      = (X=50.0,Y=1.0,Z=10.0)
	DisplayFOV        = 60.0
	PlayerViewOffset  = (Y=8.0)
	PlayerViewPivot   = (Yaw=500,Roll=1000)
	BobDamping        = 1.5
	Mesh              = SkeletalMesh'Weapons.RocketLauncher_1st'
	Skins(0)          = Texture'MercuryLauncherTex'
	HighDetailOverlay = FinalBlend'MercuryLauncherShiny'

	IconMaterial = Texture'HUDContent.Generic.HUD'
	IconCoords   = (X1=253,Y1=146,X2=333,Y2=181)
	ItemName     = "Betrayal Mercury Launcher"
	Description  = "The Mercury Missile Launcher is a modification to the Trident rocket launcher that is capable of firing high-speed rockets.||This version comes with special ammunition that is usually 100% deadly against infantry, but only on direct impact."
	PickupClass  = class'BetrayalMercuryLauncherPickup'
}