//=============================================================================
// MercuryExplosionSnow
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Emitter that creates an explosion effect.
//=============================================================================


class BetrayalMercuryExplosionSnow extends BetrayalMercuryExplosion;


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	Begin Object Class=SpriteEmitter Name=ExplosionChunks
		Acceleration=(Z=-600.000000)
		UseColorScale=True
		FadeOutFactor=(X=0.000000,Y=0.000000,Z=0.000000)
		FadeOutStartTime=1.0
		FadeOut=True
		MaxParticles=25
		RespawnDeadParticles=False
		StartLocationShape=PTLS_Sphere
		SphereRadiusRange=(Min=10.000000,Max=10.000000)
		StartSizeRange=(X=(Min=2.000000,Max=6.000000),Y=(Min=2.000000,Max=6.000000),Z=(Min=2.000000,Max=6.000000))
		UniformSize=True
		InitialParticlesPerSecond=1000.000000
		AutomaticInitialSpawning=False
		Texture=Texture'EmitterTextures.MultiFrame.smoke_a'
		TextureUSubdivisions=4
		TextureVSubdivisions=4
		UseRandomSubdivision=True
		LifetimeRange=(Min=2.000000,Max=3.400000)
		StartVelocityRadialRange=(Min=-200.000000,Max=-500.000000)
		GetVelocityDirectionFrom=PTVD_AddRadial
		SecondsBeforeInactive=0
	End Object
	Emitters(2) = SpriteEmitter'ExplosionChunks'

	LifeSpan = 3.1
}