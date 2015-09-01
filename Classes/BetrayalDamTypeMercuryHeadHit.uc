//=============================================================================
// DamTypeMercuryDirectHit
// Copyright 2003-2011 by Wormbo <wormbo@online.de>
//
// Damage type for mercury missile hitting the head and blowing up.
//=============================================================================


class BetrayalDamTypeMercuryHeadHit extends BetrayalDamTypeMercuryDirectHit abstract;


//=============================================================================
// IncrementKills
//
// Play a headshot announcement and count the number of headshots
//=============================================================================

static function IncrementKills(Controller Killer)
{
	local xPlayerReplicationInfo xPRI;

	if (PlayerController(Killer) != None)
		PlayerController(Killer).ReceiveLocalizedMessage(class'DamTypeSniperHeadShot'.default.KillerMessage);

	xPRI = xPlayerReplicationInfo(Killer.PlayerReplicationInfo);
	if (xPRI != None) {
		xPRI.HeadCount++;
		if (xPRI.HeadCount == 15 && UnrealPlayer(Killer) != None)
			UnrealPlayer(Killer).ClientDelayedAnnouncementNamed('HeadHunter', 15);
	}
}


//=============================================================================
// Default properties
//=============================================================================

defaultproperties
{
	DeathString   = "%k drove a mercury missile into %o's head."
	FemaleSuicide = "%o somehow managed to take off her head with her own mercury missile."
	MaleSuicide   = "%o somehow managed to take off his head with his own mercury missile."
	bSpecial      = True
	bAlwaysSevers = True
}
