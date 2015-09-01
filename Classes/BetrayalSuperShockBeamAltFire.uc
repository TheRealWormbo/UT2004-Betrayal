/******************************************************************************
BetrayalSuperShockBeamAltFire

Creation date: 2011-03-08 23:33
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalSuperShockBeamAltFire extends BetrayalSuperShockBeamFire;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\BetrayalFireSound.wav

//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bSameTeamShot = True
	FireSound = BetrayalFireSound
	BeamEffectclass = class'BlueSuperShockBeam'
}

