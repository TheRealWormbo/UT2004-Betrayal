/******************************************************************************
BetrayalTraitorLight

Creation date: 2011-07-17 14:35
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalTraitorLight extends Light notplaceable;


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bStatic = False
	bNoDelete = False
	RemoteRole = ROLE_None
	bMovable = True
	Physics = PHYS_Trailer

	LightBrightness = 300
	LightHue        = 24
	LightSaturation = 20
	LightRadius     = 8
	LightEffect     = LE_QuadraticNonIncidence
	LightType       = LT_Steady
	bDynamicLight   = True
}

