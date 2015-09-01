//=============================================================================
// MercuryMissileTrail
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Smoke trail for mercury missiles.
//=============================================================================


class BetrayalMercuryMissileTrail extends Emitter notplaceable;


/**
Make sure the trail emitter really reaches the explosion location and fade out
the thruster flame, then kill the emitter.
*/
function Kill()
{
	TrailEmitter(Emitters[1]).DistanceThreshold = 1;
	Emitters[2].FadeOut = True;
	GotoState('Killed');
}

/**
Make sure the trailer no longer moves while it dies. Wait a tick first, so
TrailEmitter can reach the explosion location.
*/
state Killed
{
	ignores Tick;

Begin:
	Sleep(0.0);
	SetPhysics(PHYS_None);
	SetBase(None);
	SetOwner(None);
	Sleep(0.0);
	Super.Kill();
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	Physics               = PHYS_Trailer
	bNoDelete             = False
	RemoteRole            = ROLE_None
	AmbientGlow           = 128
	bUnlit                = True
	AutoDestroy           = True
	bTrailerSameRotation  = True

	Begin Object Class=SpriteEmitter Name=ThrusterSmoke
		Acceleration=(X=-2000)
		UseColorScale=True
		ColorScale=((Color=(R=255,G=255,B=0,A=255)),(RelativeTime=0.5,Color=(R=192,G=0,B=0,A=160)),(RelativeTime=1.0))
		CoordinateSystem=PTCS_Relative
		MaxParticles=50
		Opacity=0.8
		UseSizeScale=True
		UseRegularSizeScale=False
		SizeScale(0)=(RelativeSize=0.5)
		SizeScale(1)=(RelativeTime=0.5,RelativeSize=1.5)
		SizeScale(2)=(RelativeTime=1.0)
		StartSizeRange=(X=(Min=8.0,Max=8.0),Y=(Min=8.0,Max=8.0),Z=(Min=8.0,Max=8.0))
		UniformSize=True
		SpinParticles=True
		StartSpinRange=(Z=(Max=1.0))
		DrawStyle=PTDS_AlphaBlend
		Texture=Texture'MercuryExplosionSprites'
		TextureUSubdivisions=4
		TextureVSubdivisions=4
		UseRandomSubdivision=True
		LifetimeRange=(Min=0.3,Max=0.3)
		LowDetailFactor=0.5
		SecondsBeforeInactive=0
		StartVelocityRange=(X=(Min=-500.0,Max=-500.0))
		WarmupTicksPerSecond=20.0
		RelativeWarmupTime=0.5
	End Object
	Emitters(0)=SpriteEmitter'ThrusterSmoke'

	Begin Object Class=TrailEmitter Name=MissileTrail
		TrailLocation=PTTL_FollowEmitter
		MaxPointsPerTrail=400
		DistanceThreshold=10.0
		PointLifeTime=0.6
		ColorMultiplierRange=(X=(Min=1.0,Max=1.0),Y=(Min=0.6,Max=0.6),Z=(Min=0.3,Max=0.3))
		MaxParticles=1
		StartSizeRange=(X=(Min=9.0,Max=9.0))
		InitialParticlesPerSecond=2000.0
		AutomaticInitialSpawning=false
		RespawnDeadParticles=False
		SecondsBeforeInactive=0.0
		Texture=Texture'MercurySmokeLine'
		LifetimeRange=(Min=10,Max=10)
		TrailShadeType=PTTST_PointLife
		DrawStyle=PTDS_AlphaBlend
		Disabled=True
	End Object
	Emitters(1)=TrailEmitter'MissileTrail'

	Begin Object Class=MeshEmitter Name=ThrusterFlame
		StaticMesh=StaticMesh'MercuryThrusterMesh'
		UseParticleColor=True
		UseColorScale=True
		ColorScale(0)=(Color=(R=255,G=255,B=96,A=255))
		ColorScale(1)=(RelativeTime=0.5,Color=(R=255,G=128,B=96,A=160))
		ColorScale(2)=(RelativeTime=1.0)
		CoordinateSystem=PTCS_Relative
		MaxParticles=3
		StartLocationOffset=(X=11.0)
		SpinParticles=True
		StartSpinRange=(X=(Min=0.5,Max=0.5),Z=(Max=1.0))
		UseSizeScale=True
		SizeScale(0)=(RelativeSize=0.5)
		SizeScale(1)=(RelativeTime=1.2,RelativeSize=1.2)
		StartSizeRange=(X=(Min=0.4,Max=0.4),Y=(Min=0.2,Max=0.2),Z=(Min=0.2,Max=0.2))
		SecondsBeforeInactive=0.0
		LifetimeRange=(Min=0.15,Max=0.15)
		WarmupTicksPerSecond=20.0
		RelativeWarmupTime=1.0
	End Object
	Emitters(2)=MeshEmitter'ThrusterFlame'
}
