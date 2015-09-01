/******************************************************************************
BetrayalMercuryBetrayMissile

Creation date: 2011-03-13 16:17
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalMercuryBetrayMissile extends BetrayalMercuryMissile;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\MercBetrayalFly.wav


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bSameTeamShot  = True
	TrailLineColor = (X=(Min=0.5,Max=0.5),Y=(Min=0.5,Max=0.5),Z=(Min=1.0,Max=1.0))
	Skins(0)       = TexScaler'MercuryMissileTexBlue'
	AmbientSound   = Sound'MercBetrayalFly'
	SoundVolume    = 255
	SoundRadius    = 350.0
}

