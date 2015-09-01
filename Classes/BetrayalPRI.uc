/******************************************************************************
BetrayalPRI

Creation date: 2010-05-19 12:52
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalPRI extends xPlayerReplicationInfo config(User);


//=============================================================================
// Imports
//=============================================================================

#exec obj load file=..\Sounds\2K4MenuSounds.uax


//=============================================================================
// Configuration
//=============================================================================

/** Make enemies blue instead of red. */
var globalconfig bool bSwapTeamColors;
var globalconfig bool bWantUnlagging;
var globalconfig byte PingSmoothing;


//=============================================================================
// Properties
//=============================================================================

var int RogueTimePenalty, RogueValue;
var Sound CountdownSound;


//=============================================================================
// Variables
//=============================================================================

var BetrayalTeam CurrentTeam, BetrayedTeam;
var BetrayalPRI Betrayer, Betrayed;
var bool bIsRogue, bWasOnTeam;
var int RemainingRogueTime, BetrayalCount;

var BetrayalTeam LastTeam;
var BetrayalPawn Pawn;
var float LastPostRenderTraceTime;
var bool bPostRenderTraceSucceeded;

var bool bReactivating;
var string ClientID;

var bool bUseUnlagging;
var int Shots, Hits, RepKills;
var int PaybackCount, RetributionCount, BetrayedCount;
var int TotalPotStolen;
var int EagleEyes, MultiHits, BestMultiHit;
var int BestMultiKillLevel;

// bot multikill handling
var int MultiKillLevel;
var float LastKillTime;

// stats screen rotated name stuff
var ScriptedTexture NameTexture;
var TexRotator RotatedName;
var FinalBlend RotatedFinal, UprightFinal;
var Font NameFont;
var float MaxNameWidth;
var int ActualNameWidth, ActualNameHeight;
var string LastPlayerName;

// better ping calculation
var deprecated array<float> LastPings;
var float RealPing;
var float GamePing;
var float LastPingTimeStamp;
var byte RepPing, RepPingDeviation;
var float RealPingDeviation;


//=============================================================================
// Replication
//=============================================================================

replication
{
	reliable if (True)
		CurrentTeam, Betrayer, BetrayalCount, bIsRogue, RemainingRogueTime, bUseUnlagging, Shots, Hits, RepKills, PaybackCount, RetributionCount, BetrayedCount, TotalPotStolen, EagleEyes, MultiHits, BestMultiHit, BestMultiKillLevel;

	reliable if (!bNetOwner && bNetDirty)
		RepPing, RepPingDeviation;

	unreliable if (Role == ROLE_Authority)
		ClientReplyPing;

	unreliable if (Role < ROLE_Authority)
		ServerRequestPing, ServerUpdatePing;
}


simulated function Material GetStatsNameTexture(Font Font, float MaxWidth, bool bVertical)
{
	local int Bits;
	const DivByLn2 = 1.44269504; // 1 / ln 2

	if (bPendingDelete || bDeleteMe)
		return None;

	if (NameTexture == None) {
		NameTexture = ScriptedTexture(Level.ObjectPool.AllocateObject(class'ScriptedTexture'));
		NameTexture.Client = Self;
		NameTexture.FallbackMaterial = None;
		NameTexture.UClampMode = TC_Wrap;
		NameTexture.VClampMode = TC_Wrap;

		RotatedName = TexRotator(Level.ObjectPool.AllocateObject(class'TexRotator'));
		RotatedName.Material = NameTexture;
		RotatedName.TexRotationType = TR_FixedRotation;
		RotatedName.Rotation = rot(0,-16384,0);
		RotatedName.FallbackMaterial = None;

		RotatedFinal = FinalBlend(Level.ObjectPool.AllocateObject(class'FinalBlend'));
		RotatedFinal.Material = RotatedName;
		RotatedFinal.FrameBufferBlending = FB_AlphaBlend;
		RotatedFinal.ZWrite = True;
		RotatedFinal.ZTest = True;
		RotatedFinal.AlphaTest = False;
		RotatedFinal.AlphaRef = 0;
		RotatedFinal.FallbackMaterial = None;

		UprightFinal = FinalBlend(Level.ObjectPool.AllocateObject(class'FinalBlend'));
		UprightFinal.Material = NameTexture;
		UprightFinal.FrameBufferBlending = FB_AlphaBlend;
		UprightFinal.ZWrite = True;
		UprightFinal.ZTest = True;
		UprightFinal.AlphaTest = False;
		UprightFinal.AlphaRef = 0;
		UprightFinal.FallbackMaterial = None;
	}
	if (MaxWidth > NameTexture.MaterialUSize()) {
		Bits = Ceil(Loge(MaxWidth) * DivByLn2); // corresponds to Ceil(Log2(MaxNameWidth))
		NameTexture.SetSize(1 << Bits, 1 << Bits); // includes Revision++
	}
	else if (LastPlayerName != PlayerName || NameFont != Font || MaxNameWidth != MaxWidth)
		NameTexture.Revision++; // also needs redrawing

	NameFont = Font;
	MaxNameWidth = MaxWidth;
	LastPlayerName = PlayerName;

	if (bVertical)
		return RotatedFinal;

	return UprightFinal;
}


simulated function Destroyed()
{
	Super.Destroyed();

	// release allocated stats screen materials
	if (UprightFinal != None) {
		UprightFinal.Material = None;
		Level.ObjectPool.FreeObject(UprightFinal);
		UprightFinal = None;
	}
	if (RotatedFinal != None) {
		RotatedFinal.Material = None;
		Level.ObjectPool.FreeObject(RotatedFinal);
		RotatedFinal = None;
	}
	if (RotatedName != None) {
		RotatedName.Material = None;
		Level.ObjectPool.FreeObject(RotatedName);
		RotatedName = None;
	}
	if (NameTexture != None) {
		NameTexture.Client = None;
		Level.ObjectPool.FreeObject(NameTexture);
		NameTexture = None;
	}
}


simulated function RenderTexture(ScriptedTexture Tex)
{
	local int NameLen;
	local string ShortenedName;

	if (Tex != NameTexture || NameFont == None)
		return;

	ShortenedName = PlayerName;
	Tex.TextSize(ShortenedName, NameFont, ActualNameWidth, ActualNameHeight);
	if (ActualNameWidth > MaxNameWidth) {
		// shrink name appropriately (simply leave out the middle part)
		NameLen = Len(ShortenedName) * MaxNameWidth / ActualNameWidth - 3;
		ShortenedName = Left(ShortenedName, NameLen / 2) $ "..." $ Right(ShortenedName, NameLen / 2);
		Tex.TextSize(ShortenedName, NameFont, ActualNameWidth, ActualNameHeight);
	}
	Tex.DrawText(0, 0, ShortenedName, NameFont, class'Hud'.default.WhiteColor);

	// adjust TexRotator, in case font or texture size changed
	RotatedName.UOffset = 0;
	RotatedName.VOffset = ActualNameHeight;
}

simulated function DrawNameTexture(Canvas C, float Scale, Font Font, float MaxWidth, float MaxActualWidth, bool bVertical)
{
	if (ActualNameWidth * Scale > MaxActualWidth)
		Scale *= MaxActualWidth / (ActualNameWidth * Scale);

	if (bVertical) {
		C.CurX = Round(C.CurX - 0.5 * ActualNameHeight * Scale);
		C.CurY = Round(C.CurY - ActualNameWidth * Scale);
		C.DrawTile(GetStatsNameTexture(Font, MaxWidth, bVertical), ActualNameHeight * Scale, ActualNameWidth * Scale, 0, ActualNameHeight, ActualNameHeight, ActualNameWidth);
	}
	else {
		C.CurY = Round(C.CurY - 0.5 * ActualNameHeight * Scale);
		C.CurX = Round(C.CurX - ActualNameWidth * Scale);
		C.DrawTile(GetStatsNameTexture(Font, MaxWidth, bVertical), ActualNameWidth * Scale, ActualNameHeight * Scale, 0, 0, ActualNameWidth, ActualNameHeight);
	}
}


simulated function PostNetBeginPlay()
{
	Super.PostNetBeginPlay();

	if (Level.NetMode == NM_Client) {
		SetTimer(FRand(), True);
	}
}


function Reset()
{
	Super.Reset();

	if (bReactivating) {
		if (BetrayalGame(Level.Game).RestorePRIData(Self))
			PlayerController(Owner).ReceiveLocalizedMessage(class'BetrayalMessage', -1);
	}
	else {
		if (CurrentTeam != None)
			CurrentTeam.LoseTeammate(Self);
		BetrayedTeam       = None;
		Betrayer           = None;
		bIsRogue           = False;
		RemainingRogueTime = 0;
		BetrayalCount      = 0;

		// accuracy stats intentionally not cleared
	}
	bReactivating = False;

}


simulated function bool IsOnLocalTeam()
{
	local PlayerController PC;
	local BetrayalPRI LocalPRI;

	PC = Level.GetLocalPlayerController();
	if (PC != None) {
		if (BetrayalPawn(PC.ViewTarget) != None)
			LocalPRI = BetrayalPawn(PC.ViewTarget).BPRI;
		if (LocalPRI == None && Pawn(PC.ViewTarget) != None)
			LocalPRI = BetrayalPRI(Pawn(PC.ViewTarget).PlayerReplicationInfo);
		if (LocalPRI == None)
			LocalPRI = BetrayalPRI(PC.PlayerReplicationInfo);
	}
	if (LocalPRI != None && !LocalPRI.bOnlySpectator)
		return CurrentTeam != None && CurrentTeam == LocalPRI.CurrentTeam;
}


simulated function bool BetrayedLocalPlayer()
{
	local PlayerController PC;
	local BetrayalPRI LocalPRI;

	if (!bIsRogue || PlayerController(Owner) != None && Viewport(PlayerController(Owner).Player) != None)
		return false; // either the local player or not a rogue

	PC = Level.GetLocalPlayerController();
	if (PC != None)
		LocalPRI = BetrayalPRI(PC.PlayerReplicationInfo);
	return LocalPRI != None && LocalPRI.Betrayer == Self;
}


/**
Called by the client on the server to request a ping.
*/
function ServerRequestPing(float Timestamp) // must stay float for compatibility reasons
{
	ClientReplyPing(TimeStamp);
	//LastPingTimeStamp = TimeStamp;
}
/*
/**
Simulate some latency - regular input reply doesn't happen immediately either.
*/
function Tick(float DeltaTime)
{
	if (LastPingTimeStamp != 0) {
		ClientReplyPing(LastPingTimeStamp);
		LastPingTimeStamp = 0;
	}
}
*/

/**
Called on the client when the server replied to a ping request.
*/
simulated function ClientReplyPing(float Timestamp) // must stay float for compatibility reasons
{
	local float NewPing, Smoothing;

	NewPing = 0.001 * (GetTimeStamp() - Timestamp);
	if (NewPing >= 0.0) {
		if (RealPing < 0) {
			RealPing = NewPing;
			RealPingDeviation = 0.0;
		}
		else {
			Smoothing = 1.0 / (1 + default.PingSmoothing);
			RealPing = (1.0 - Smoothing) * RealPing + Smoothing * NewPing;
			RealPingDeviation = (1.0 - Smoothing) * RealPingDeviation + Smoothing * Abs(RealPing - NewPing);
		}
		GamePing = RealPing * Level.TimeDilation;
		ServerUpdatePing(GamePing);
		RepPing = Sqrt(FClamp(RealPing, 0, 1)) * 255;
		RepPingDeviation = FClamp(RealPingDeviation, 0, 0.255) * 1000;
	}

	//Level.GetLocalPlayerController().ClientMessage("Ping:"@1000*NewPing@1000*GamePing);
}

function ServerUpdatePing(float NewPing)
{
	GamePing = NewPing;
	RepPing = Sqrt(FClamp(GamePing / Level.TimeDilation, 0, 1)) * 255;
}

simulated function int GetTimeStamp()
{
	return Level.Millisecond + 1000 * (Level.Second + 60 * Level.Minute); // requires 22 binary digits, i.e. fits into float
}


simulated function Timer()
{
	local Controller C;

	if (Level.NetMode == NM_Client) {
		C = Level.GetLocalPlayerController();
		if (C != None && C.PlayerReplicationInfo == Self) {
			if (Owner == None)
				SetOwner(C);
			ServerRequestPing(GetTimeStamp());
		}
		SetTimer(0.1 + 0.1 * FRand(), True);
		return;
	}

	UpdatePlayerLocation();
	if (bIsRogue && !bOnlySpectator)
		RogueTimer();
	else
		SetTimer(1.5 + FRand(), true);

	if (FRand() < 0.65)
		return;

	if (!bBot) {
		C = Controller(Owner);
		if (!bReceivedPing)
			Ping = Min(int(0.25 * float(C.ConsoleCommand("GETPING"))), 255);
	}
}


function SetRogueTimer(bool bAdditionalPenalty)
{
	RemainingRogueTime = RogueTimePenalty + int(bAdditionalPenalty) * RogueTimePenalty;
	NetUpdateTime = Level.TimeSeconds - 1;
	bIsRogue = true;
	SetTimer(1.0, true);
}


function RogueTimer()
{
	RemainingRogueTime--;
	if (RemainingRogueTime < 0 || Level.Game.bGameEnded) {
		RogueExpired();
		if (!bOnlySpectator && PlayerController(Owner) != None) {
			PlayerController(Owner).ReceiveLocalizedMessage(class'BetrayalMessage', 5);
		}
	}
	else if (!bOnlySpectator && RemainingRogueTime < 3 && PlayerController(Owner) != None) {
		PlayerController(Owner).ClientPlaySound(CountdownSound);
	}
}


function RogueExpired()
{
	local BetrayalPRI PRI;
	local int i;

	RemainingRogueTime = -100.0;
	bIsRogue = false;
	NetUpdateTime = Level.TimeSeconds - 1;

	for (i = 0; i < Level.GRI.PRIArray.Length; i++) {
		PRI = BetrayalPRI(Level.GRI.PRIArray[i]);
		if (PRI != None && PRI.Betrayer == Self) {
			PRI.Betrayer = None;
		}
	}
}


simulated function int ScoreValueFor(BetrayalPRI OtherPRI)
{
	local int ScoreValue;

	ScoreValue = 1;
	if (!OtherPRI.bIsRogue && (CurrentTeam == None || CurrentTeam != OtherPRI.CurrentTeam)) {
		ScoreValue += Clamp((Score - OtherPRI.Score) / 4, 0, 9);
	}
	if (bIsRogue && OtherPRI.Betrayer == self) {
		ScoreValue += RogueValue;
	}
	return ScoreValue;
}


function float GetTrustWorthiness()
{
	return float(rec.Tactics) + float(rec.CombatStyle);
}

function LogMultiKills(float Reward, bool bEnemyKill)
{
	local int BoundedLevel;

	if (Controller(Owner) == None)
		return;

	if (bEnemyKill && Level.TimeSeconds - LastKillTime < 4) {
		Controller(Owner).AwardAdrenaline(Reward);
		BoundedLevel = Min(MultiKillLevel, 6);
		if (BoundedLevel == MultiKillLevel) { // don't count consecutive holy shits as individual multikills
			MultiKills[BoundedLevel]++;
			if (MultiKillLevel > 0)
				MultiKills[BoundedLevel - 1]--;
		}
		MultiKillLevel++;
		if (BestMultiKillLevel < MultiKillLevel)
			BestMultiKillLevel = MultiKillLevel; // keep track of longest multi kill instead
		if (UnrealPlayer(Owner) != None)
			UnrealPlayer(Owner).MultiKillLevel++;
		UnrealMPGameInfo(Level.Game).SpecialEvent(Self, "multikill_" $ MultiKillLevel);
	}
	else {
		MultiKillLevel = 0;
		if (UnrealPlayer(Owner) != None)
			UnrealPlayer(Owner).MultiKillLevel = 0;
	}
	if (bEnemyKill) {
		LastKillTime = Level.TimeSeconds;
		if (UnrealPlayer(Owner) != None)
			UnrealPlayer(Owner).LastKillTime = Level.TimeSeconds;
	}
}

simulated function int FindStatIndex(int PlayerID)
{
	local int Low, Middle, High;

	if (VehicleStatsArray.Length > 0) {
		High = VehicleStatsArray.Length;
		do {
			Middle = (High + Low) / 2;
			if (VehicleStatsArray[Middle].VehicleClass == None && VehicleStatsArray[Middle].DeathsDriving < PlayerID)
				Low = Middle + 1;
			else
				High = Middle;
		} until (Low >= High);
	}
	if (Low == VehicleStatsArray.Length || VehicleStatsArray[Low].VehicleClass != None || VehicleStatsArray[Low].DeathsDriving != PlayerID) {
		VehicleStatsArray.Insert(Low, 1);
		VehicleStatsArray[Low].DeathsDriving = PlayerID;
	}
	return Low;
}


function AddKillBy(int PlayerID)
{
	local int Index;

	Index = FindStatIndex(PlayerID);
	VehicleStatsArray[Index].Kills++;
}


function AddBetrayalBy(int PlayerID)
{
	local int Index;

	Index = FindStatIndex(PlayerID);
	VehicleStatsArray[Index].Deaths++;
}


simulated function UpdateVehicleStats(TeamPlayerReplicationInfo PRI, class<Vehicle> V, int newKills, int newDeaths, int newDeathsDriving)
{
	local int Index;

	//log(PRI.PlayerName@V@newKills@NewDeaths@newDeathsDriving);

	if (V != None) {
		Super.UpdateVehicleStats(PRI, V, newKills, newDeaths, newDeathsDriving);
		return;
	}

	Index = FindStatIndex(newDeathsDriving);
	VehicleStatsArray[Index].Kills = newKills;
	VehicleStatsArray[Index].Deaths = newDeaths;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	RemainingRogueTime = -1000
	RogueTimePenalty   = 30
	RogueValue         = 6
	CountdownSound     = Sound'2K4MenuSounds.Generic.msfxDown'

	bUseUnlagging  = True
	bWantUnlagging = True
	PingSmoothing  = 1

	RealPing = -1
	RealPingDeviation = 0.0
}

