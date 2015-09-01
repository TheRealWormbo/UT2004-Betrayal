/******************************************************************************
BetrayalAltShockBeamEffect

Creation date: 2011-03-13 10:21
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalAltShockBeamEffect extends BetrayalShockBeamEffect;


simulated function int PickColor()
{
	return 1 - int(class'BetrayalPRI'.default.bSwapTeamColors);
}

//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}

