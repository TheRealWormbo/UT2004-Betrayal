/******************************************************************************
BetrayalSuperShockRiflePickup

Creation date: 2011-03-18 17:22
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalSuperShockRiflePickup extends ShockRiflePickup abstract;


//=============================================================================
// Imports
//=============================================================================

#exec obj load file=UT2004Weapons.utx


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	Skins(1)      = FinalBlend'RedShockFinal'
	InventoryType = class'BetrayalSuperShockRifle'
}

