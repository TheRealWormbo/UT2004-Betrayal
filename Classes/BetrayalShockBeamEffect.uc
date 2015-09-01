/******************************************************************************
BetrayalShockBeamEffect

Creation date: 2011-03-13 10:08
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalShockBeamEffect extends ShockBeamEffect;


var class<ShockBeamCoil> CoilClassColors[2];
var class<ShockMuzFlash> MuzFlashClassColors[2];
var class<ShockMuzFlash3rd> MuzFlash3ClassColors[2];
var class<ShockBeamEffect> ExtraBeamClassColors[2];
var Material SkinColors[2];
var byte LightHueColors[2];


simulated function PostBeginPlay()
{
	local int PickedColor;

	PickedColor    = PickColor();
	CoilClass      = CoilClassColors[PickedColor];
	MuzFlashClass  = MuzFlashClassColors[PickedColor];
	MuzFlash3Class = MuzFlash3ClassColors[PickedColor];
	Skins[0]       = SkinColors[PickedColor];
	LightHue       = LightHueColors[PickedColor];
}

simulated function SpawnEffects()
{
	local ShockBeamEffect E;

	Super.SpawnEffects();
	E = Spawn(ExtraBeamClassColors[PickColor()]);
	if (E != None)
		E.AimAt(mSpawnVecA, HitNormal);
}

simulated function int PickColor()
{
	return int(class'BetrayalPRI'.default.bSwapTeamColors);
}

simulated function SpawnImpactEffects(rotator HitRot, vector EffectLoc)
{
	if (PickColor() == 1) {
		Super.SpawnImpactEffects(HitRot, EffectLoc);
	}
	else {
		Spawn(class'ShockImpactFlareB',,, EffectLoc, HitRot);
		Spawn(class'ShockImpactRingB',,, EffectLoc, HitRot);
		Spawn(class'ShockImpactScorch',,, EffectLoc, Rotator(-HitNormal));
		Spawn(class'ShockExplosionCoreB',,, EffectLoc, HitRot);
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bNetTemporary = false

	CoilClassColors[0]      = class'ShockBeamCoilB'
	MuzFlashClassColors[0]  = class'ShockMuzFlashB'
	MuzFlash3ClassColors[0] = class'ShockMuzFlashB3rd'
	ExtraBeamClassColors[0] = class'ExtraRedBeam'
	SkinColors[0]           = Material'InstagibEffects.RedSuperShockBeam'
	LightHueColors[0]       = 0

	CoilClassColors[1]      = class'ShockBeamCoilBlue'
	MuzFlashClassColors[1]  = class'ShockMuzFlash'
	MuzFlash3ClassColors[1] = class'ShockMuzFlash3rd'
	ExtraBeamClassColors[1] = class'ExtraBlueBeam'
	SkinColors[1]           = Material'InstagibEffects.BlueSuperShockTex'
	LightHueColors[1]       = 230
}

