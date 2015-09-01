//=============================================================================
// MercuryExplosion
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Emitter that creates an explosion effect with a smoke ring and small stuff
// flying around.
//=============================================================================


class BetrayalMercuryExplosion extends Emitter notplaceable;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\MercWaterImpact.wav
#exec audio import file=Sounds\MercImpact.wav


//=============================================================================
// Variables
//=============================================================================

var bool bWaterExplosion;


//=============================================================================
// Replication
//=============================================================================

replication
{
	reliable if (bNetInitial)
		bWaterExplosion;
}


//=============================================================================
// PostBeginPlay
//
// Handle low framerate conditions.
//=============================================================================

simulated event PostNetBeginPlay()
{
	local PlayerController PC;

	PC = Level.GetLocalPlayerController();
	if (Level.NetMode == NM_DedicatedServer || PC == None) {
		return;
	}
	if (!PC.BeyondViewDistance(Location, class'BetrayalMercuryExplosionLight'.default.CullDistance)) {
		Spawn(class'BetrayalMercuryExplosionLight');
	}

	if (Emitters.Length > 2) {
		if (Level.DetailMode == DM_Low || Level.DetailMode == DM_High && Level.bAggressiveLOD) {
			Emitters[2] = None;
		}
		else if (Emitters[2] != None && Level.bDropDetail) {
			Emitters[2].UseCollision = False;
			Emitters[2].LifetimeRange.Min = 1;
			Emitters[2].LifetimeRange.Max = 1.5;
		}
	}
}

auto simulated state Exploding
{
Begin:
	if (PhysicsVolume.bWaterVolume || bWaterExplosion)
		PlaySound(Sound'MercWaterImpact');
	else
		PlaySound(Sound'MercImpact');
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	Begin Object Class=SpriteEmitter Name=ExplosionRing
		UseColorScale=True
		ColorScale(0)=(Color=(B=128,G=255,R=255,A=255))
		ColorScale(1)=(RelativeTime=0.400000,Color=(B=64,G=192,R=255,A=96))
		ColorScale(2)=(RelativeTime=0.800000,Color=(G=96,R=255,A=16))
		ColorScale(3)=(RelativeTime=1.000000,Color=(R=255))
		CoordinateSystem=PTCS_Relative
		MaxParticles=50
		SpinParticles=True
		StartSpinRange=(Z=(Max=1.0))
		RespawnDeadParticles=False
		StartLocationShape=PTLS_Polar
		StartLocationPolarRange=(Y=(Max=65535.0),Z=(Min=5.0,Max=5.0))
		UseSizeScale=True
		UseRegularSizeScale=False
		SizeScale(0)=(RelativeSize=0.700000)
		SizeScale(1)=(RelativeTime=0.400000,RelativeSize=1.000000)
		SizeScale(2)=(RelativeTime=0.600000,RelativeSize=0.800000)
		SizeScale(3)=(RelativeTime=1.000000,RelativeSize=0.700000)
		StartSizeRange=(X=(Min=20.0,Max=25.0),Y=(Min=20.0,Max=25.0),Z=(Min=20.0,Max=25.0))
		UniformSize=True
		InitialParticlesPerSecond=1000.000000
		AutomaticInitialSpawning=False
		Texture=Texture'MercuryExplosionSprites'
		DrawStyle=PTDS_AlphaBlend
		TextureUSubdivisions=4
		TextureVSubdivisions=4
		UseRandomSubdivision=True
		LifetimeRange=(Min=0.3,Max=0.5)
		StartVelocityRadialRange=(Min=100.0,Max=170.0)
		VelocityLossRange=(X=(Min=1.5,Max=2.5),Y=(Min=1.5,Max=2.5),Z=(Min=1.5,Max=2.5))
		GetVelocityDirectionFrom=PTVD_AddRadial
		SecondsBeforeInactive=0
	End Object
	Emitters(0) = SpriteEmitter'ExplosionRing'

	Begin Object Class=SpriteEmitter Name=ExplosionSmokeRing
		FadeInEndTime=0.200000
		FadeIn=True
		FadeOutStartTime=0.200000
		FadeOut=True
		Opacity=0.5
		CoordinateSystem=PTCS_Relative
		MaxParticles=30
		RespawnDeadParticles=False
		StartLocationShape=PTLS_Polar
		StartLocationPolarRange=(Y=(Max=65535.000000),Z=(Min=20.000000,Max=20.000000))
		UseSizeScale=True
		UseRegularSizeScale=False
		SizeScale(0)=(RelativeSize=0.300000)
		SizeScale(1)=(RelativeTime=0.200000,RelativeSize=0.700000)
		SizeScale(2)=(RelativeTime=1.000000,RelativeSize=1.000000)
		StartSizeRange=(X=(Min=25.000000,Max=25.000000),Y=(Min=25.000000,Max=25.000000),Z=(Min=25.000000,Max=25.000000))
		UniformSize=True
		InitialParticlesPerSecond=1000.000000
		AutomaticInitialSpawning=False
		Texture=Texture'EmitterTextures.MultiFrame.smokelight_a'
		TextureUSubdivisions=4
		TextureVSubdivisions=4
		UseRandomSubdivision=True
		LifetimeRange=(Min=0.800000,Max=1.000000)
		StartVelocityRadialRange=(Min=60.000000,Max=60.000000)
		VelocityLossRange=(X=(Min=1.000000,Max=1.000000),Y=(Min=1.000000,Max=1.000000),Z=(Min=1.000000,Max=1.000000))
		GetVelocityDirectionFrom=PTVD_AddRadial
		SecondsBeforeInactive=0
	End Object
	Emitters(1) = SpriteEmitter'ExplosionSmokeRing'

	AutoDestroy   = True
	bNoDelete     = False
	RemoteRole    = ROLE_None
	bNetTemporary = True
	LifeSpan      = 1.1
	TransientSoundVolume = 0.5
}