/******************************************************************************
BetrayalPawn

Creation date: 2010-05-19 13:01
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalPawn extends xPawn;


var BetrayalUnlaggedCollision UnlaggedCollision;
var BetrayalPRI BPRI;

// team skins
var Material BodySkin[2];
var Material FaceSkin[2];
var bool bWasOnLocalTeam;

var BetrayalTraitorLight TraitorLight;
var byte TraitorLightHues[3]; // 0 = red team, 1 = blue team, 2 = rogue color


simulated function Setup(xUtil.PlayerRecord rec, optional bool bLoadNow)
{
	if (rec.Species == None || ForceDefaultCharacter())
		rec = class'xUtil'.static.FindPlayerRecord(GetDefaultCharacter());

	if (BetrayalPRI(PlayerReplicationInfo) != None)
		BetrayalPRI(PlayerReplicationInfo).Pawn = Self;
	Species = rec.Species;
	RagdollOverride = rec.Ragdoll;
	if (!SpeciesSetup(rec)) {
		rec = class'xUtil'.static.FindPlayerRecord(GetDefaultCharacter());
		if (!SpeciesSetup(rec))
			return;
	}
	ResetPhysicsBasedAnim();
}


simulated function bool SpeciesSetup(xUtil.PlayerRecord rec)
{
	local mesh NewMesh, customskel;
	local string SkelName;
	local class<VoicePack> NewVoiceClass;
	local int i, j;

	if (bAlreadySetup) {
		// make sure correct teamskin
		if (Level.NetMode == NM_Client)
			SetTeamSkin(rec);

		return true;
	}
	NewMesh = Mesh(DynamicLoadObject(rec.MeshName, class'Mesh'));
	if (NewMesh == None) {
		log("Failed to load player mesh "$rec.MeshName);
		return false;
	}

	bAlreadySetup = true;
	LinkMesh(NewMesh);
	AssignInitialPose();

	bIsFemale = (rec.Sex ~= "Female");
	if (PlayerReplicationInfo != None)
		PlayerReplicationInfo.bIsFemale = bIsFemale;
	if (Level.NetMode != NM_DedicatedServer && rec.Skeleton != "")
		customskel = Mesh(DynamicLoadObject(rec.Skeleton, class'Mesh'));

	if (bIsFemale) {
		SkelName = Species.default.FemaleSkeleton;
		if (Level.bLowSoundDetail)
			SoundGroupClass = class<xPawnSoundGroup>(DynamicLoadObject("XGame.xJuggFemaleSoundGroup", class'Class'));
		else
			SoundGroupClass = class<xPawnSoundGroup>(DynamicLoadObject(Species.default.FemaleSoundGroup, class'Class'));
	}
	else {
		SkelName = Species.default.MaleSkeleton;
		if (Level.bLowSoundDetail)
			SoundGroupClass = class<xPawnSoundGroup>(DynamicLoadObject("XGame.xJuggMaleSoundGroup", class'Class'));
		else
			SoundGroupClass = class<xPawnSoundGroup>(DynamicLoadObject(Species.default.MaleSoundGroup, class'Class'));
	}

	if (Level.NetMode != NM_DedicatedServer) {
		if (CustomSkel != None)
			SkeletonMesh = CustomSkel;
		else if (SkelName != "")
			SkeletonMesh = Mesh(DynamicLoadObject(SkelName, class'Mesh'));

		SetTeamSkin(rec);

		if (rec.UseSpecular && Level.DetailMode!=DM_Low) {
			HighDetailOverlay = Material'UT2004Weapons.WeaponShader';
			// Xan hack
			if (Rec.BodySkinName ~= "UT2004PlayerSkins.XanMk3V2_Body")
				Skins[2] = Material(DynamicLoadObject("UT2004PlayerSkins.XanMk3V2_abdomen", class'Material'));
		}
	}
	GibGroupClass = class<xPawnGibGroup>(DynamicLoadObject(Species.default.GibGroup, class'Class'));

	if (Level.NetMode == NM_DedicatedServer) {
		if (bIsFemale)
			VoiceType = "XGame.JuggFemaleVoice";
		else
			VoiceType = "XGame.JuggMaleVoice";
		NewVoiceClass = class<VoicePack>(DynamicLoadObject(VoiceType, class'Class'));
		if (PlayerReplicationInfo != None)
			PlayerReplicationInfo.VoiceType = NewVoiceClass;
		VoiceClass = class<TeamVoicePack>(NewVoiceClass);
	}
	else {
		if (!Level.bLowSoundDetail) {
			if (PlayerReplicationInfo != None && PlayerReplicationInfo.VoiceTypeName != "")
				VoiceType = PlayerReplicationInfo.VoiceTypeName;
			else
				VoiceType = rec.VoiceClassName;
			if (VoiceType != "")
				NewVoiceClass = class<VoicePack>(DynamicLoadObject(VoiceType, class'Class'));
		}
		if (NewVoiceClass == None) {
			VoiceType = Species.static.GetVoiceType(bIsFemale, Level);
			NewVoiceClass = class<VoicePack>(DynamicLoadObject(VoiceType, class'Class'));
		}
		if (PlayerReplicationInfo != None)
			PlayerReplicationInfo.VoiceType = NewVoiceClass;
		VoiceClass = class<TeamVoicePack>(NewVoiceClass);
	}

	// add unique taunts
	for (i = 0; i < 16 && j < 15; i++) {
		if (Species.default.TauntAnims[i] != '') {
			j = TauntAnims.Length;
			TauntAnims[j]     = Species.default.TauntAnims[i];
			TauntAnimNames[j] = Species.default.TauntAnimNames[i];
		}
	}
	return true;
}


simulated function SetTeamSkin(xUtil.PlayerRecord rec)
{
	local Material NewBodySkin;
	local byte TeamNum;

	if (!bAlreadySetup)
		return; // need to set up first

	for (TeamNum = 0; TeamNum < 2; TeamNum++) {
		if (BodySkin[TeamNum] != None)
			continue;

		if (class'DMMutator'.Default.bBrightSkins && Left(rec.BodySkinName,12) ~= "PlayerSkins.")
			NewBodySkin = Material(DynamicLoadObject("Bright"$rec.BodySkinName$"_"$TeamNum$"B", class'Material', true));
		else
			NewBodySkin = None;

		if (NewBodySkin == None) {
			NewBodySkin = Material(DynamicLoadObject(rec.BodySkinName$"_"$TeamNum, class'Material'));
			if (rec.TeamFace)
				Faceskin[TeamNum] = Material(DynamicLoadObject(rec.FaceSkinName$"_"$TeamNum, class'Material'));
		}
		if (NewBodyskin == None) {
			NewBodySkin = Material(DynamicLoadObject(rec.BodySkinName, class'Material', true));
		}
		BodySkin[TeamNum] = NewBodySkin;
		if (Faceskin[TeamNum] == None)
			Faceskin[TeamNum] = Material(DynamicLoadObject(rec.FaceSkinName, class'Material'));
	}

	bClearWeaponOffsets = rec.ZeroWeaponOffsets;

	if (PlayerReplicationInfo != None)
		BPRI = BetrayalPRI(PlayerReplicationInfo);

	if (BPRI != None && BPRI.IsOnLocalTeam())
		TeamNum = 1;
	else
		TeamNum = 0;

	if (class'BetrayalPRI'.default.bSwapTeamColors)
		TeamNum = 1 - TeamNum;

	if (TeamNum == 0)
		Texture = Texture'RedMarker_t';
	else
		Texture = Texture'BlueMarker_t';

	TeamSkin = TeamNum;
	if (bInvis || bSkeletized) {
		RealSkins[0] = BodySkin[TeamSkin];
		RealSkins[1] = FaceSkin[TeamSkin];

		//log("Changing non-invis team skin for" @ BPRI.PlayerName @ "to" @ TeamNum);
	}
	else {
		Skins[0] = BodySkin[TeamSkin];
		Skins[1] = FaceSkin[TeamSkin];

		//log("Changing team skin for" @ BPRI.PlayerName @ "to" @ TeamNum);
	}
	if (Left(BodySkin[TeamSkin], 18) ~= "BrightPlayerSkins.")
		AmbientGlow = 0.75 * default.AmbientGlow;
	else
		AmbientGlow = default.AmbientGlow;

	if (BetrayalGRI(Level.GRI) != None && BetrayalGRI(Level.GRI).bBrighterPlayerSkins)
		AmbientGlow *= 1.5;
}


simulated function TickFX(float DeltaTime)
{
	local bool bIsOnLocalTeam;

	Super.TickFX(DeltaTime);

	if (PlayerReplicationInfo != None)
		BPRI = BetrayalPRI(PlayerReplicationInfo);

	if (BPRI != None) {
		bIsOnLocalTeam = BPRI.IsOnLocalTeam();

		if (bIsOnLocalTeam != bWasOnLocalTeam)
			SetTeamSkin(BPRI.Rec);

		if (Health > 0 && (bIsOnLocalTeam && Controller != Level.GetLocalPlayerController() || BPRI.BetrayedLocalPlayer())) {
			if (TraitorLight == None) {
				TraitorLight = Spawn(class'BetrayalTraitorLight', Self);
				TraitorLight.SetBase(Self);
			}
			if (bIsOnLocalTeam)
				TraitorLight.LightHue = TraitorLightHues[TeamSkin];
			else
				TraitorLight.LightHue = TraitorLightHues[2];
			TraitorLight.LightType = LT_Steady;
		}
		else if (TraitorLight != None)
			TraitorLight.LightType = LT_None;
	}

	bWasOnLocalTeam = bIsOnLocalTeam;
}


simulated function Destroyed()
{
	Super.Destroyed();

	if (TraitorLight != None)
		TraitorLight.Destroy();
}


/**
Perform a dodging move in the desired direction.
*/
function bool PerformDodge(eDoubleClickDir DoubleClickMove, vector X, vector Y)
{
	local vector HitLoc, HitNorm;
	local float VelocityZ;
	local name Anim;
	local BetrayalGRI BGRI;

	BGRI = BetrayalGRI(Level.GRI);
	if (Physics == PHYS_Falling) {
		if (DoubleClickMove == DCLICK_Forward)
			Anim = WallDodgeAnims[0];
		else if (DoubleClickMove == DCLICK_Back)
			Anim = WallDodgeAnims[1];
		else if (DoubleClickMove == DCLICK_Left)
			Anim = WallDodgeAnims[2];
		else if (DoubleClickMove == DCLICK_Right)
			Anim = WallDodgeAnims[3];

		if (PlayAnim(Anim, 1.0, 0.1))
			bWaitForAnim = true;
		AnimAction = Anim;

		TakeFallingDamage();
		if (Velocity.Z < -DodgeSpeedZ * 0.5)
			Velocity.Z += DodgeSpeedZ * 0.5;
		HitNorm = vect(0,0,1);
	}
	else if (BGRI != None && BGRI.bImprovedSlopeDodging) {
		// adjust dodge dir to make dodging more efficient on slopes
		if (Y != vect(0,0,0) && Base != None && Trace(HitLoc, HitNorm, Location - vect(0,0,1) * (CollisionHeight + 20), Location - vect(0,0,1) * (CollisionHeight - 10), False, vect(0.7,0.7,0) * CollisionRadius + vect(0,0,1)) != None && X Dot HitNorm < 0) {
			Y = vect(0,0,1) Cross X;  // fix the cross vector so it actually points 90° to the right, not the left
			X = Y Cross HitNorm;
		}
		else {
			HitNorm = vect(0,0,1);
		}
	}
	else {
		HitNorm = vect(0,0,1);
	}
	VelocityZ = Velocity Dot HitNorm;
	Velocity = DodgeSpeedFactor * GroundSpeed * X + (Velocity Dot Y) * Y + vect(0,0,1);

	if (!bCanDodgeDoubleJump)
		MultiJumpRemaining = 0;
	if (bCanBoostDodge || VelocityZ < -100)
		Velocity += HitNorm * (VelocityZ + DodgeSpeedZ);
	else
		Velocity += HitNorm * DodgeSpeedZ;

	CurrentDir = DoubleClickMove;
	SetPhysics(PHYS_Falling);
	PlayOwnedSound(GetSound(EST_Dodge), SLOT_Pain, GruntVolume,, 80);
	return true;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bScriptPostRender = True
	AmbientGlow = 50

	TraitorLightHues[0] = 0
	TraitorLightHues[1] = 150
	TraitorLightHues[2] = 40
}

