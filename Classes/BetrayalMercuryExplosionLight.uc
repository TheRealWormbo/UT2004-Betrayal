//=============================================================================
// MercuryExplosionLight
// Copyright 2007-2011 by Wormbo <wormbo@online.de>
//
// Light effect for mercury missile explosions.
//=============================================================================


class BetrayalMercuryExplosionLight extends Effects;


simulated function PostNetBeginPlay()
{
	if (Level.bDropDetail)
		LightRadius = 5;
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	bHidden         = True
	LifeSpan        = 0.5
	CullDistance    = 5000.0
	bDynamicLight   = true
	LightEffect     = LE_QuadraticNonIncidence
	LightType       = LT_FadeOut
	LightBrightness = 200
	LightHue        = 20
	LightSaturation = 90
	LightRadius     = 7
	LightPeriod     = 32
	LightCone       = 128
}