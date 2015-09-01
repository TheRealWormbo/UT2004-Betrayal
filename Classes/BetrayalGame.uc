/******************************************************************************
BetrayalGame

Creation date: 2010-01-31 15:25
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class BetrayalGame extends xDeathMatch;


//=============================================================================
// Imports
//=============================================================================

#exec obj load file=AssaultSounds.uax
#exec obj load file=GameSounds.uax
#exec obj load file=InterfaceContent.utx


//=============================================================================
// Localization
//=============================================================================

var localized array<string> BetrayalHints;
var localized array<int> RelevantDMLoadingHints;

var localized string lblMaxUnlagTime, descMaxUnlagTime;
var localized string lblBeamMultiHit, descBeamMultiHit;
var localized string lblSpecialKillRewards, descSpecialKillRewards;
var localized string lblRestorePlayerStats, descRestorePlayerStats;
var localized string lblBrighterPlayerSkins, descBrighterPlayerSkins;
var localized string lblImprovedSlopeDodging, descImprovedSlopeDodging;

var localized string LoadingScreenByNameText;
var localized string LoadingScreenAtTimeText;


//=============================================================================
// Configuration
//=============================================================================

var config float MaxUnlagTime;
var config bool bBeamMultiHit;
var config bool bSpecialKillRewards;
var config bool bRestorePlayerStats;
var config bool bBrighterPlayerSkins;
var config bool bImprovedSlopeDodging;


//=============================================================================
// Properties
//=============================================================================

var() const editconst string Build;
var() const editconst string Copyright;

var class<LocalMessage> AnnouncerMessageClass;
var Sound BetrayedSound;

struct TDrawOp {
	/**
	Available image operations are:
	`bgmapimage
	`bggameimage
	`mapimage
	`gameimage
	`image:package.group.material,u,v,ul,vl
	`random:p1.g1.m1,u1,v1,ul1,vl1;p2.g2.m2,u2,v2,ul2,vl2;...
	The U, V, UL and VL properties are optional.
	You can specify any number of random images you want.

	Available text operations are:
	`mapname
	`maptitle
	`mapauthor
	`gamename
	`gamehint
	`localize:file.section.property
	Any other text is displayed unmodified.
	Localized text is looked up in file.int [section] property=...
	(The file extension depends on your UT2004 language.)
	*/
	var string Content;

	/** The drawing area of this operation. */
	var float Top, Left, Height, Width;

	/** The render style. 1 = normal, 5 = alphablend */
	var byte RenderStyle;

	/**
	Alignment options.
	0 = left/top, 1 = center, 2 = right/bottom
	*/
	var byte AlignH, AlignV;

	/**
	Image style.
	0 = normal, 1 = full image stretched, 2 = clipped, 3 = partially stretched
	*/
	var byte ImageStyle;

	var color DrawColor;
	var string FontName;
	var bool WrapText;
};

var array<TDrawOp> GameDrawOps, DemoDrawOps;


//=============================================================================
// Variables
//=============================================================================

var array<BetrayalTeam> Teams;
var bool bPlayedTenKills, bPlayedFiveKills, bPlayedOneKill;

var BetrayalUnlaggedCollision FirstCollision;
var float LastLocationUpdateTime;
var bool bUnlaggingDisabled;

struct TSavedPRIData {
	// identification
	var string ClientID;
	var int PlayerID;

	// betrayal properties
	var float Score, Deaths;
	var int Hits, Shots, Kills;
	var int PaybackCount, RetributionCount;
	var int BetrayalCount, BetrayedCount;
	var int RemainingRogueTime;
	var array<BetrayalPRI> BetrayedPlayers;
	var int EagleEyes, MultiHits, BestMultiHit, HeadCount;

	// useful general properties
	var bool bFirstBlood;
	var array<TeamPlayerReplicationInfo.WeaponStats> WeaponStatsArray;
	var array<TeamPlayerReplicationInfo.VehicleStats> VehicleStatsArray;
	var byte Spree[6];
	var byte MultiKills[7];
	var int Suicides;
	var int TimePlayed;
};

var array<TSavedPRIData> SavedPRIData;
var array<string> DuplicateClientIDs;

var float VisibilityCheckRange;
var bool bTestBlocked;


event InitGame(string Options, out string Error)
{
	Super.InitGame(Options, Error);
	bForceRespawn = True;
	bAllowTrans   = False;
	MaxLives      = 0;
	if (MaxUnlagTime ~= 0 || Level.NetMode == NM_Standalone)
		bUnlaggingDisabled = True;
}

function InitGameReplicationInfo()
{
	Super.InitGameReplicationInfo();
	if (!bUnlaggingDisabled)
		BetrayalGRI(GameReplicationInfo).MaxUnlagTime = MaxUnlagTime;
	BetrayalGRI(GameReplicationInfo).bPlayersMustBeReady = bPlayersMustBeReady || bTournament;
	BetrayalGRI(GameReplicationInfo).bImprovedSlopeDodging = bImprovedSlopeDodging;
}

function GetServerDetails(out ServerResponseLine ServerState)
{
	Super.GetServerDetails(ServerState);
	AddServerDetail(ServerState, "MultiHit", bBeamMultiHit);
	AddServerDetail(ServerState, "SpecialKillRewards", bSpecialKillRewards);
	AddServerDetail(ServerState, "MaxUnlagTime", BetrayalGRI(GameReplicationInfo).MaxUnlagTime);
}

function bool OnSameTeam(Pawn A, Pawn B)
{
	local BetrayalPRI PRI1, PRI2;

	if (A == None || B == None)
		return false;

	PRI1 = BetrayalPRI(A.PlayerReplicationInfo);
	PRI2 = BetrayalPRI(B.PlayerReplicationInfo);

	return PRI1 != None && PRI2 != None && PRI1.CurrentTeam != None && PRI1.CurrentTeam == PRI2.CurrentTeam;
}

function Logout(Controller Exiting)
{
	local BetrayalPRI PRI;

	PRI = BetrayalPRI(Exiting.PlayerReplicationInfo);
	if (PRI != None) {
		SavePRIData(PRI, False);
		RemoveFromTeam(PRI);
	}

	Super.Logout(Exiting);
}

function Reset()
{
	Super.Reset();
	SavedPRIData.Length = 0;
	bPlayedTenKills  = False;
	bPlayedFiveKills = False;
	bPlayedOneKill   = False;
}

event PostLogin(PlayerController NewPlayer)
{
	local BetrayalPRI PRI;

	Super.PostLogin(NewPlayer);

	PRI = BetrayalPRI(NewPlayer.PlayerReplicationInfo);
	if (PRI != None) {
		PRI.ClientID = Super(GameStats).GetStatsIdentifier(NewPlayer);
		if (RestorePRIData(PRI))
			NewPlayer.ReceiveLocalizedMessage(class'BetrayalMessage', -2);
	}
}


function bool HasDuplicateClientID(BetrayalPRI PRI)
{
	local int i, Low, Middle, High;
	local string ClientID;

	if (PRI == None || PRI.ClientID == "")
		return PRI != None;

	ClientID = PRI.ClientID;

	if (DuplicateClientIDs.Length > 0) {
		// check known duplicates first
		High = DuplicateClientIDs.Length;
		do {
			Middle = (High + Low) / 2;
			if (DuplicateClientIDs[i] < ClientID)
				Low = Middle + 1;
			else
				High = Middle;
		} until (Low >= High);
		if (Low < DuplicateClientIDs.Length && DuplicateClientIDs[i] == ClientID)
			return true;
	}

	// check other players
	for (i = 0; i < GameReplicationInfo.PRIArray.Length; i++) {
		if (GameReplicationInfo.PRIArray[i] != PRI && BetrayalPRI(GameReplicationInfo.PRIArray[i]) != None && BetrayalPRI(GameReplicationInfo.PRIArray[i]).ClientID == ClientID) {
			// found duplicate, remember this one
			DuplicateClientIDs.Insert(Low, 1);
			DuplicateClientIDs[Low] = ClientID;
			return true;
		}
	}
	return false;
}


function bool RestorePRIData(BetrayalPRI PRI)
{
	local int i, j;

	if (!bRestorePlayerStats || PRI == None || PRI.bOnlySpectator || HasDuplicateClientID(PRI)) {
		//log("Can't restore data for " $ PRI.PlayerName);
		return false;
	}

	for (i = 0; i < SavedPRIData.Length; i++) {
		if (SavedPRIData[i].ClientID == PRI.ClientID) {
			//log("Restoring data for " $ PRI.PlayerName@PRI.ClientID);
			PRI.PlayerID          = SavedPRIData[i].PlayerID;
			PRI.Score             = SavedPRIData[i].Score;
			PRI.StartTime         = ElapsedTime - SavedPRIData[i].TimePlayed;
			PRI.Deaths            = SavedPRIData[i].Deaths;
			PRI.Hits              = SavedPRIData[i].Hits;
			PRI.Shots             = SavedPRIData[i].Shots;
			PRI.PaybackCount      = SavedPRIData[i].PaybackCount;
			PRI.RetributionCount  = SavedPRIData[i].RetributionCount;
			PRI.BetrayalCount     = SavedPRIData[i].BetrayalCount;
			PRI.BetrayedCount     = SavedPRIData[i].BetrayedCount;
			PRI.EagleEyes         = SavedPRIData[i].EagleEyes;
			PRI.MultiHits         = SavedPRIData[i].MultiHits;
			PRI.BestMultiHit      = SavedPRIData[i].BestMultiHit;
			PRI.HeadCount         = SavedPRIData[i].HeadCount;
			if (SavedPRIData[0].RemainingRogueTime > 0) {
				PRI.SetRogueTimer(False);
				RemoveFromTeam(PRI);
				PRI.RemainingRogueTime = SavedPRIData[i].RemainingRogueTime;
				for (j = 0; j < SavedPRIData[i].BetrayedPlayers.Length; j++) {
					if (SavedPRIData[i].BetrayedPlayers[j] != None && SavedPRIData[i].BetrayedPlayers[j].Betrayer == None)
						SavedPRIData[i].BetrayedPlayers[j].Betrayer = PRI;
				}
			}
			PRI.Kills             = SavedPRIData[i].Kills;
			PRI.RepKills          = SavedPRIData[i].Kills;
			PRI.bFirstBlood       = SavedPRIData[i].bFirstBlood;
			PRI.WeaponStatsArray  = SavedPRIData[i].WeaponStatsArray;
			PRI.VehicleStatsArray = SavedPRIData[i].VehicleStatsArray;
			PRI.Suicides          = SavedPRIData[i].Suicides;
			for (j = 0; j < ArrayCount(PRI.Spree); j++)
				PRI.Spree[j]      = SavedPRIData[i].Spree[j];
			for (j = 0; j < ArrayCount(PRI.MultiKills); j++)
				PRI.MultiKills[j] = SavedPRIData[i].MultiKills[j];
			SavedPRIData.Remove(i, 1);
			return true;
		}
	}
	//log("No data to restore for " $ PRI.PlayerName@PRI.ClientID);
}

function SavePRIData(BetrayalPRI PRI, bool bBecomingSpectator)
{
	local int j;
	local BetrayalPRI OtherPRI;

	if (!bRestorePlayerStats || PRI == None || !bBecomingSpectator && PRI.bOnlySpectator || HasDuplicateClientID(PRI)) {
		//log("Can't save data for " $ PRI.PlayerName);
		return;
	}

	//log("Saving data for " $ PRI.PlayerName@PRI.ClientID);
	SavedPRIData.Insert(0, 1);
	SavedPRIData[0].ClientID          = PRI.ClientID;
	SavedPRIData[0].PlayerID          = PRI.PlayerID;
	SavedPRIData[0].TimePlayed        = ElapsedTime - PRI.StartTime;
	SavedPRIData[0].Score             = PRI.Score;
	SavedPRIData[0].Deaths            = PRI.Deaths;
	SavedPRIData[0].Hits              = PRI.Hits;
	SavedPRIData[0].Shots             = PRI.Shots;
	SavedPRIData[0].PaybackCount      = PRI.PaybackCount;
	SavedPRIData[0].RetributionCount  = PRI.RetributionCount;
	SavedPRIData[0].BetrayalCount     = PRI.BetrayalCount;
	SavedPRIData[0].BetrayedCount     = PRI.BetrayedCount;
	SavedPRIData[0].EagleEyes         = PRI.EagleEyes;
	SavedPRIData[0].MultiHits         = PRI.MultiHits;
	SavedPRIData[0].BestMultiHit      = PRI.BestMultiHit;
	SavedPRIData[0].HeadCount         = PRI.HeadCount;
	if (PRI.bIsRogue && PRI.RemainingRogueTime > 0) {
		SavedPRIData[0].RemainingRogueTime = PRI.RemainingRogueTime;
		for (j = 0; j < GameReplicationInfo.PRIArray.Length; j++) {
			OtherPRI = BetrayalPRI(GameReplicationInfo.PRIArray[j]);
			if (OtherPRI != None && OtherPRI.Betrayer == PRI)
				SavedPRIData[0].BetrayedPlayers[SavedPRIData[0].BetrayedPlayers.Length] = OtherPRI;
		}
	}
	SavedPRIData[0].Kills             = PRI.Kills;
	SavedPRIData[0].bFirstBlood       = PRI.bFirstBlood;
	SavedPRIData[0].WeaponStatsArray  = PRI.WeaponStatsArray;
	SavedPRIData[0].VehicleStatsArray = PRI.VehicleStatsArray;
	SavedPRIData[0].Suicides          = PRI.Suicides;
	for (j = 0; j < ArrayCount(PRI.Spree); j++)
		SavedPRIData[0].Spree[j]      = PRI.Spree[j];
	for (j = 0; j < ArrayCount(PRI.MultiKills); j++)
		SavedPRIData[0].MultiKills[j] = PRI.MultiKills[j];
}

function bool BecomeSpectator(PlayerController P)
{
	if (!P.PlayerReplicationInfo.bOnlySpectator && Super.BecomeSpectator(P)) {
		SavePRIData(BetrayalPRI(P.PlayerReplicationInfo), True);
		RemoveFromTeam(BetrayalPRI(P.PlayerReplicationInfo));
		return true;
	}
	return false;
}

function bool AllowBecomeActivePlayer(PlayerController P)
{
	if (P.PlayerReplicationInfo.bOnlySpectator && Super.AllowBecomeActivePlayer(P)) {
		if (BetrayalPRI(P.PlayerReplicationInfo) != None)
			BetrayalPRI(P.PlayerReplicationInfo).bReactivating = True;
		return true;
	}
	return false;
}


function RemoveFromTeam(BetrayalPRI PRI)
{
	local BetrayalTeam Team;
	local int i, NumTeammates;

	if (PRI == None || PRI.CurrentTeam == None)
		return;

	//Drop the PRI from the team
	Team = PRI.CurrentTeam;
	NumTeammates = Team.LoseTeammate(PRI);

	if (NumTeammates == 1 ) {
		for (i = 0; i < ArrayCount(Team.Teammates); i++) {
			if (Team.Teammates[i] != None) {
				Team.Teammates[i].Score += Team.TeamPot;
				//Increment pot stat
				//Team.Teammates[i].AddToEventStat('EVENT_POOLPOINTS', Team.TeamPot);

				//Disband the team
				NumTeammates = Team.LoseTeammate(Team.Teammates[i]);
				break;
			}
		}
	}

	//Destroy the team completely
	if (NumTeammates == 0) {
		RemoveTeam(Team);
		Team.Destroy();
	}
}


function RemoveTeam(BetrayalTeam Team)
{
	local int i;

	for (i = 0; i < Teams.length; i++) {
		//Remove the team we're looking for
		if (Teams[i] == Team) {
			Teams.Remove(i, 1);
			break;
		}
	}
}

function bool InOrder(PlayerReplicationInfo P1, PlayerReplicationInfo P2)
{
	if (P1.bOnlySpectator)
		return P2.bOnlySpectator;
	else if (P2.bOnlySpectator)
		return true;

	if (P1.Score < P2.Score)
		return false;
	if (P1.Score == P2.Score) {
		if (P1.Deaths > P2.Deaths)
			return false;
		if (P1.Deaths == P2.Deaths && P1.Kills < P2.Kills)
			return false;
	}
	return true;
}


function SortPRIArray()
{
	local int i;
	local int Low, Middle, High;

	for (i = 1; i < GameReplicationInfo.PRIArray.Length; i++) {
		High = i;
		do {
			Middle = (High + Low) / 2;
			if (InOrder(GameReplicationInfo.PRIArray[Low], GameReplicationInfo.PRIArray[i]))
				Low = Middle + 1;
			else
				High = Middle;
		} until (Low >= High);
		if (Low < i) {
			GameReplicationInfo.PRIArray.Insert(Low, 1);
			GameReplicationInfo.PRIArray[Low] = GameReplicationInfo.PRIArray[i+1];
			GameReplicationInfo.PRIArray.Remove(i+1, 1);
		}
	}
}

function ScoreSpecialKill(Controller Killer)
{
	local PlayerReplicationInfo PRI;

	if (bGameEnded || !bSpecialKillRewards || Killer == None || Killer.PlayerReplicationInfo == None)
		return;

	PRI = Killer.PlayerReplicationInfo;
	PRI.Score += 1;
	PRI.NetUpdateTime = Level.TimeSeconds - 1;
	ScoreEvent(PRI, 1, "special_kill");
	CheckScore(PRI);
}


function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
	local bool bEnemyKill;
	local int Score;
	local string KillInfo;

	bEnemyKill = Killer != Killed;

	if (KilledPawn != None && KilledPawn.GetSpree() > 4) {
		if (bEnemyKill && Killer != None)
			Killer.AwardAdrenaline(ADR_MajorKill);
		EndSpree(Killer, Killed);
	}
	if (Killer != None && Killer.bIsPlayer && Killed != None && Killed.bIsPlayer) {
		if (BetrayalPRI(Killer.PlayerReplicationInfo) != None)
			BetrayalPRI(Killer.PlayerReplicationInfo).LogMultiKills(ADR_MajorKill, bEnemyKill);
		else if (UnrealPlayer(Killer) != None)
			UnrealPlayer(Killer).LogMultiKills(ADR_MajorKill, bEnemyKill);

		if (bEnemyKill)
			DamageType.static.ScoreKill(Killer, Killed);

		if (!bFirstBlood && Killer != Killed && bEnemyKill) {
			Killer.AwardAdrenaline(ADR_MajorKill);
			bFirstBlood = True;
			if (TeamPlayerReplicationInfo(Killer.PlayerReplicationInfo) != None)
				TeamPlayerReplicationInfo(Killer.PlayerReplicationInfo).bFirstBlood = true;
			BroadcastLocalizedMessage(class'FirstBloodMessage', 0, Killer.PlayerReplicationInfo);
			SpecialEvent(Killer.PlayerReplicationInfo, "first_blood");
		}
		if (Killer == Killed)
			Killer.AwardAdrenaline(ADR_MinorError);
		else if (bTeamGame && Killed.PlayerReplicationInfo.Team == Killer.PlayerReplicationInfo.Team)
			Killer.AwardAdrenaline(ADR_KillTeamMate);
		else {
			Killer.AwardAdrenaline(ADR_Kill);
			if (Killer.Pawn != None) {
				Killer.Pawn.IncrementSpree();
				if (Killer.Pawn.GetSpree() > 4)
					NotifySpree(Killer, Killer.Pawn.GetSpree());
			}
		}
	}

	// Vehicle Score Kill
	if (Killer != None && Killer.bIsPlayer && Killer.PlayerReplicationInfo != None && Vehicle(KilledPawn) != None && (Killed != None || Vehicle(KilledPawn).bEjectDriver) && Vehicle(KilledPawn).IndependentVehicle()) {
		Score = VehicleScoreKill(Killer, Killed, Vehicle(KilledPawn), KillInfo);
		if (Score > 0) {
			/* if driver(s) have been ejected from vehicle, Killed == None */
			if (!bEnemyKill && Killed != None && Killed.PlayerReplicationInfo != None) {
				Score = -Score; // substract score if team kill.
				KillInfo = "TeamKill_" $ KillInfo;
			}

			if (Score != 0) {
				Killer.PlayerReplicationInfo.Score += Score;
				Killer.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;
				ScoreEvent(Killer.PlayerReplicationInfo, Score, KillInfo);
			}
		}
	}

	Super(UnrealMPGameInfo).Killed(Killer, Killed, KilledPawn, damageType);
}



function ScoreKill(Controller Killer, Controller Other)
{
	local BetrayalPRI KillerPRI, OtherPRI;
	local Bot B;
	local int i, ScoreValue;
	local float BetrayalValue;

	if (PlayerController(Other) != None)
		PlayerController(Other).WaitDelay = Level.TimeSeconds + 0.75;

	if (Killer != None)
		KillerPRI = BetrayalPRI(Killer.PlayerReplicationInfo);

	OtherPRI = BetrayalPRI(Other.PlayerReplicationInfo);
	if (Killer == Other || Killer == None) {
		// self kill by suicide or environment
		if (Other != None && Other.PlayerReplicationInfo != None) {
			if (OtherPRI != None)
				OtherPRI.AddKillBy(OtherPRI.PlayerID);
			Other.PlayerReplicationInfo.Score -= 1;
			Other.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;
			ScoreEvent(Other.PlayerReplicationInfo, -1, "self_frag");
		}
	}
	else if (KillerPRI != None) {
		if (OtherPRI != None) {
			OtherPRI.AddKillBy(KillerPRI.PlayerID);

			ScoreValue = OtherPRI.ScoreValueFor(KillerPRI);
			KillerPRI.Score += ScoreValue;
			ScoreEvent(Killer.PlayerReplicationInfo, ScoreValue, "frag");
			if (OtherPRI.bIsRogue && OtherPRI == KillerPRI.Betrayer) {
				// betrayer was busted, rogue value is handed over to the killer
				OtherPRI.Score -= OtherPRI.RogueValue;
				ScoreEvent(OtherPRI, -OtherPRI.RogueValue, "payback");

				if (PlayerController(KillerPRI.Owner) != None)
					PlayerController(KillerPRI.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 2);
				if (PlayerController(OtherPRI.Owner) != None)
					PlayerController(OtherPRI.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 3);

				//Retribution stat
				KillerPRI.RetributionCount++;
				OtherPRI.PaybackCount++;

				Killer.AwardAdrenaline(ADR_MinorBonus);
				Other.AwardAdrenaline(ADR_MinorError);
				OtherPRI.RogueExpired();
			}
			KillerPRI.NetUpdateTime = Level.TimeSeconds - 1;
			KillerPRI.Kills++;
			KillerPRI.RepKills++;
			if (KillerPRI.CurrentTeam != None) {
				KillerPRI.CurrentTeam.TeamPot++;

				if (KillerPRI.CurrentTeam.TeamPot > 2) {
					for (i = 0; i < ArrayCount(KillerPRI.CurrentTeam.Teammates); i++) {
						if (KillerPRI.CurrentTeam.Teammates[i] != None) {
							B = Bot(KillerPRI.CurrentTeam.Teammates[i].Owner);
							if (B != None && BetrayalSquadAI(B.Squad) != None && !BetrayalSquadAI(B.Squad).bBetrayTeam) {
								BetrayalValue = KillerPRI.CurrentTeam.TeamPot + 0.3 * BetrayalPRI(B.PlayerReplicationInfo).ScoreValueFor(KillerPRI);
								if (BetrayalValue > 1.5 + KillerPRI.RogueValue - B.Aggressiveness + BetrayalPRI(B.PlayerReplicationInfo).GetTrustworthiness() && FRand() < 0.25 || GoalScore > 0 && KillerPRI.Score + BetrayalValue >= GoalScore) {
									// log(Instigator.Controller.ShotTarget.Controller.PlayerReplicationInfo.PlayerName$" betrayal value "$BetrayalValue$" vs "$(1.5 + RogueValue - B.Aggressiveness + UTBetrayalPRI(B.PlayerReplicationInfo).GetTrustWorthiness()));
									BetrayalSquadAI(B.Squad).bBetrayTeam = true;
								}
							}
						}
					}
				}
			}
			if (bAllowTaunts && Killer != None && Killer != Other && Killer.AutoTaunt() && Killer.PlayerReplicationInfo != None && Killer.PlayerReplicationInfo.VoiceType != None) {
				Killer.SendMessage(OtherPRI, 'AUTOTAUNT', Killer.PlayerReplicationInfo.VoiceType.static.PickRandomTauntFor(Killer, false, PlayerController(Killer) == None), 10, 'GLOBAL');
			}
		}
	}

	if (GameRulesModifiers != None)
		GameRulesModifiers.ScoreKill(Killer, Other);

	if (Killer != None || bOvertime) {
		CheckScore(Killer.PlayerReplicationInfo);
	}

	if (bAdjustSkill && (PlayerController(Killer) != None || PlayerController(Other) != None)) {
		if (AIController(Killer) != None)
			AdjustSkill(AIController(Killer), PlayerController(Other),true);
		if (AIController(Other) != None)
			AdjustSkill(AIController(Other), PlayerController(Killer),false);
	}
}

function ShotTeammate(BetrayalPRI InstigatorPRI, BetrayalPRI HitPRI, Pawn ShotInstigator, Pawn HitPawn)
{
	local BetrayalTeam Team;
	local BetrayalPRI PRI;
	local int i;
	local Bot B;

	if (Level.TimeSeconds - HitPawn.SpawnTime < SpawnProtectionTime)
		return;

	HitPRI.AddBetrayalBy(InstigatorPRI.PlayerID);
	Team = InstigatorPRI.CurrentTeam;
	InstigatorPRI.Score += Team.TeamPot;
	ScoreEvent(InstigatorPRI, Team.TeamPot, "team_frag");
	InstigatorPRI.TotalPotStolen += Team.TeamPot;
	InstigatorPRI.SetRogueTimer(InstigatorPRI.RogueValue / 2 >= Team.TeamPot);
	Team.TeamPot = 0;

	InstigatorPRI.BetrayalCount++;
	InstigatorPRI.BetrayedTeam = Team;
	InstigatorPRI.Betrayed = HitPRI;
	HitPRI.Betrayer = InstigatorPRI;
	HitPRI.BetrayedCount++;
	//InstigatorPRI.PlaySound(BetrayingSound);
	ShotInstigator.Controller.AwardAdrenaline(ADR_MajorKill);

	for (i = 0; i < GameReplicationInfo.PRIArray.Length; i++) {
		PRI = BetrayalPRI(GameReplicationInfo.PRIArray[i]);
		if (PRI != None && PlayerController(PRI.Owner) != None) {
			if (PRI.CurrentTeam == Team) {
				// big, with "assassin"
				PlayerController(PRI.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 0, InstigatorPRI, HitPRI, Team);
			}
			else {
				// smaller, no announcement
				PlayerController(PRI.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 4, InstigatorPRI, HitPRI, Team);
			}
		}
	}

	RemoveFromTeam(InstigatorPRI);

	if (Team != None) {
		// give betrayer to other teammate
		for (i = 0; i < ArrayCount(Team.Teammates); i++) {
			if (Team.Teammates[i] != None) {
				if (Team.Teammates[i] != HitPRI)
					Team.Teammates[i].BetrayedCount++;
				Team.Teammates[i].Betrayer = InstigatorPRI;
				if (PlayerController(Team.Teammates[i].Owner) != None)
					PlayerController(Team.Teammates[i].Owner).ClientPlaySound(BetrayedSound);
				else {
					B = Bot(Team.Teammates[i].Owner);
					if (B != None) {
						if (BetrayalSquadAI(B.Squad) != None)
							BetrayalSquadAI(B.Squad).bBetrayTeam = False; // no point trying, the pot is gone
						if (B.Pawn != None)
							B.AssignSquadResponsibility(); // ensure the bot looks for a target other than remaining teammates
					}
				}
			}
		}
	}
}

function float SpawnWait(AIController B)
{
	local BetrayalPRI PRI;

	if (B.PlayerReplicationInfo.bOutOfLives)
		return 999;

	PRI = BetrayalPRI(B.PlayerReplicationInfo);
	if (PRI != None && PRI.bIsRogue)
		return FRand(); // respawn rogues immediately

	return FRand() * Sqrt(NumBots); // don't wait too long; player wants action? - player gets action!
}

function bool WantsPickups(Bot B)
{
	return false; // there are none anyway
}

function bool ShouldSpawnNearby(BetrayalPRI SpawningPRI, BetrayalPRI OtherPRI)
{
	return SpawningPRI != None && OtherPRI != None && (
		SpawningPRI.CurrentTeam != None && SpawningPRI.CurrentTeam == OtherPRI.CurrentTeam ||
		OtherPRI.bIsRogue && SpawningPRI.Betrayer == OtherPRI ||
		SpawningPRI.bIsRogue && OtherPRI.Betrayer == SpawningPRI);
}

function bool ValidateStartSpot(NavigationPoint StartSpot, out PlayerStart ClosestPlayerStart)
{
	local Inventory Inv;
	local NavPointRatingInfo NPRI;

	if (bScriptInitialized) {
		Inv = StartSpot.Inventory;
		if (Inv != None) {
			// yay, inventory chain abuse :)
			do {
				NPRI = NavPointRatingInfo(Inv);
				Inv = Inv.Inventory;
			} until (NPRI != None || Inv == None);
		}
		if (NPRI == None) {
			NPRI = StartSpot.Spawn(class'NavPointRatingInfo', StartSpot,, StartSpot.Location);
			if (NPRI != None) {
				NPRI.Inventory = StartSpot.Inventory;
				StartSpot.Inventory = NPRI;
			}
			else {
				NPRI = StartSpot.Spawn(class'NavPointRatingInfoBlocked', StartSpot,, StartSpot.Location);
				if (NPRI != None) {
					NPRI.Inventory = StartSpot.Inventory;
					StartSpot.Inventory = NPRI;
				}
			}
		}
		if (NPRI != None) {
			ClosestPlayerStart = NPRI.GetClosestPlayerStart();
			return ClosestPlayerStart != None && NPRI.Touching.Length == 0;
		}
	}
	ClosestPlayerStart = PlayerStart(StartSpot);

	return ClosestPlayerStart != None;
}

function float RatePlayerStart(NavigationPoint N, byte Team, Controller Player)
{
	local PlayerStart P;
	local float Score, NextDist;
	local Controller OtherPlayer;

	if (Player != None)
		Team = Player.GetTeamNum();

	Score = 3000 * FRand(); //randomize
	if (PlayerStart(N) == None)
		Score -= 10000;

	// find nearby PlayerStart (only for selected types of navigation points)
	if (!ValidateStartSpot(N, P) || !P.bEnabled || N.PhysicsVolume.bWaterVolume)
		return Score - 10000000;

	//assess candidate
	if (P.bPrimaryStart)
		Score += 10000000;
	else
		Score += 5000000;

	if (N == LastStartSpot || N == LastPlayerStartSpot)
		Score -= 10000.0;

	for (OtherPlayer = Level.ControllerList; OtherPlayer != None; OtherPlayer = OtherPlayer.NextController) {
		if (OtherPlayer.bIsPlayer && OtherPlayer.Pawn != None) {
			NextDist = VSize(OtherPlayer.Pawn.Location - N.Location);
			//if (NextDist < OtherPlayer.Pawn.CollisionRadius + OtherPlayer.Pawn.CollisionHeight)
			//	return -10000.0;
			// limit the visibility checks if there are many players on the server
			if (NextDist < VisibilityCheckRange && FastTrace(N.Location, OtherPlayer.Pawn.Location)) {
				Score -= Square(300.0 - 0.1 * NextDist);
			}
			else if (Player != None && ShouldSpawnNearby(BetrayalPRI(Player.PlayerReplicationInfo), BetrayalPRI(OtherPlayer.PlayerReplicationInfo))) {
				Score -= 5 * NextDist;
			}
			else {
				Score += NextDist;
			}
		}
	}
	return FMax(Score, 5);
}

function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string incomingName)
{
	local NavigationPoint N, BestStart;
	local float BestRating, NewRating;
	local byte Team;

	if (Player != None && Player.StartSpot != None)
		LastPlayerStartSpot = Player.StartSpot;

	// always pick StartSpot at start of match
	if (Player != None && Player.StartSpot != None && Level.NetMode == NM_Standalone && (bWaitingToStartMatch || Player.PlayerReplicationInfo != None && Player.PlayerReplicationInfo.bWaitingPlayer))
		return Player.StartSpot;

	if (GameRulesModifiers != None) {
		N = GameRulesModifiers.FindPlayerStart(Player, InTeam, incomingName);
		if ( N != None )
			return N;
	}

	// original code would check for incoming teleporter here, but uhh - this isn't a single player story

	// use InTeam if player doesn't have a team yet
	if (Player != None && Player.PlayerReplicationInfo != None) {
		if (Player.PlayerReplicationInfo.Team != None)
			Team = Player.PlayerReplicationInfo.Team.TeamIndex;
		else
			Team = InTeam;
	}
	else
		Team = InTeam;

	// find start with positive rating
	VisibilityCheckRange = FMin(10000.0 / Sqrt(1 + NumPlayers + NumBots), 3000.0);
	for (N = Level.NavigationPointList; N != None; N = N.NextNavigationPoint) {
		NewRating = RatePlayerStart(N, Team, Player);
		if (NewRating > BestRating) {
			BestRating = NewRating;
			BestStart = N;
		}
	}

	if (BestStart == None /* || who cares? ((PlayerStart(BestStart) == None) && (Player != None) && Player.bIsPlayer)*/ ) {
		log("Warning - PATHS NOT DEFINED or NO PLAYERSTART with positive rating");
		BestRating = -100000000;
		foreach AllActors(class'NavigationPoint', N) {
			NewRating = RatePlayerStart(N, 0, Player);
			if (InventorySpot(N) != None)
				NewRating -= 50;
			NewRating += 20 * FRand();
			if (NewRating > BestRating) {
				BestRating = NewRating;
				BestStart = N;
			}
		}
	}

	if (BestStart != None)
		LastStartSpot = BestStart;

	return BestStart;
}

function rotator FindBestDirectionFor(vector StartLocation, rotator StartRotation, float CheckDist)
{
	local vector X, Y, Z, HL, HN;
	local vector BestDir;

	GetAxes(StartRotation, X, Y, Z);

	BestDir = 0.1 * vector(StartRotation);

	if (Trace(HL, HN, StartLocation + CheckDist * X, StartLocation) != None) {
		BestDir += (VSize(HL - StartLocation) / CheckDist) * HN * vect(1,1,0);
	}
	else {
		BestDir += X;
	}

	if (Trace(HL, HN, StartLocation - CheckDist * X, StartLocation) != None) {
		BestDir += (VSize(HL - StartLocation) / CheckDist) * HN * vect(1,1,0);
	}
	else {
		BestDir -= X;
	}

	if (Trace(HL, HN, StartLocation + CheckDist * Y, StartLocation) != None) {
		BestDir += (VSize(HL - StartLocation) / CheckDist) * HN * vect(1,1,0);
	}
	else {
		BestDir += Y;
	}

	if (Trace(HL, HN, StartLocation - CheckDist * Y, StartLocation) != None) {
		BestDir += (VSize(HL - StartLocation) / CheckDist) * HN * vect(1,1,0);
	}
	else {
		BestDir -= Y;
	}

	return rotator(BestDir);
}

function RestartPlayer(Controller aPlayer)
{
	local NavigationPoint StartSpot;
	local int TeamNum;
	local class<Pawn> DefaultPlayerClass;
	local rotator StartSpotRotation;

	if (bMustJoinBeforeStart && UnrealPlayer(aPlayer) != None && UnrealPlayer(aPlayer).bLatecomer)
		return;

	if (aPlayer.PlayerReplicationInfo.bOutOfLives)
		return;

	if (aPlayer.IsA('Bot') && TooManyBots(aPlayer)) {
		aPlayer.Destroy();
		return;
	}
	if (bRestartLevel && Level.NetMode != NM_DedicatedServer && Level.NetMode != NM_ListenServer)
		return;

	if (aPlayer.PlayerReplicationInfo == None || aPlayer.PlayerReplicationInfo.Team == None)
		TeamNum = 255;
	else
		TeamNum = aPlayer.PlayerReplicationInfo.Team.TeamIndex;

	StartSpot = FindPlayerStart(aPlayer, TeamNum);
	if (StartSpot == None) {
		log(" Player start not found!!!");
		return;
	}
	StartSpotRotation = StartSpot.Rotation;
	StartSpotRotation.Roll = 0;
	StartSpotRotation.Pitch = 0;

	if (aPlayer.PreviousPawnClass != None && aPlayer.PawnClass != aPlayer.PreviousPawnClass) {
		BaseMutator.PlayerChangedClass(aPlayer);
	}
	if (PlayerStart(StartSpot) == None) {
		// mappers don't usually pay attention to NavPoint rotations, so figure out better spawn rotation for them
		StartSpotRotation = FindBestDirectionFor(StartSpot.Location, StartSpotRotation, 250);
	}
	if (aPlayer.PawnClass != None)
		aPlayer.Pawn = Spawn(aPlayer.PawnClass,,, StartSpot.Location, StartSpotRotation);

	if (aPlayer.Pawn == None) {
		DefaultPlayerClass = GetDefaultPlayerClass(aPlayer);
		aPlayer.Pawn = Spawn(DefaultPlayerClass,,, StartSpot.Location, StartSpotRotation);
	}
	if (aPlayer.Pawn == None) {
		log("Couldn't spawn player of type "$aPlayer.PawnClass$" at "$StartSpot);
		aPlayer.GotoState('Dead');
		if (PlayerController(aPlayer) != None)
			PlayerController(aPlayer).ClientGotoState('Dead', 'Begin');
		return;
	}
	if (PlayerController(aPlayer) != None)
		PlayerController(aPlayer).TimeMargin = -0.1;
	aPlayer.Pawn.Anchor = startSpot;
	aPlayer.Pawn.LastStartSpot = PlayerStart(startSpot);
	aPlayer.Pawn.LastStartTime = Level.TimeSeconds;
	aPlayer.PreviousPawnClass = aPlayer.Pawn.Class;

	aPlayer.Possess(aPlayer.Pawn);
	aPlayer.PawnClass = aPlayer.Pawn.Class;

	aPlayer.Pawn.PlayTeleportEffect(true, true);
	aPlayer.ClientSetRotation(aPlayer.Pawn.Rotation);
	AddDefaultInventory(aPlayer.Pawn);
	TriggerEvent(StartSpot.Event, StartSpot, aPlayer.Pawn);
}


function bool PlayerCanRestart(PlayerController aPlayer)
{
	return Level.TimeSeconds >= aPlayer.WaitDelay;
}

function CheckScore(PlayerReplicationInfo Scorer)
{
	local Controller C;

	if (CheckMaxLives(Scorer))
		return;

	if (GameRulesModifiers != None && GameRulesModifiers.CheckScore(Scorer))
		return;

	if (Scorer != None) {
		if (GoalScore > 0 && Scorer.Score < GoalScore) {
			if (Scorer.Score == GoalScore - 1 && !bPlayedOneKill) {
				SortPRIArray();
				if (Scorer == GameReplicationInfo.PRIArray[0]) {
					bPlayedOneKill = true;
					bPlayedFiveKills = true;
					bPlayedTenKills = true;
					BroadcastLocalized(Self, AnnouncerMessageClass, 12);
				}
			}
			else if (Scorer.Score >= GoalScore - 5) {
				if (!bPlayedFiveKills && GoalScore > 9) {
					SortPRIArray();
					if (Scorer == GameReplicationInfo.PRIArray[0]) {
						bPlayedFiveKills = true;
						bPlayedTenKills = true;
						BroadcastLocalized(Self, AnnouncerMessageClass, 11);
					}
				}
			}
			else if (Scorer.Score >= GoalScore - 10) {
				if (!bPlayedTenKills && GoalScore > 19) {
					SortPRIArray();
					if (Scorer == GameReplicationInfo.PRIArray[0]) {
						bPlayedTenKills = true;
						BroadcastLocalized(Self, AnnouncerMessageClass, 10);
					}
				}
			}
		}
		if (GoalScore > 0 && Scorer.Score >= GoalScore) {
			EndGame(Scorer, "fraglimit");
		}
		else if (bOverTime) {
			// end game only if scorer has highest score
			for (C = Level.ControllerList; C != None; C = C.NextController) {
				if (C.PlayerReplicationInfo != None && C.PlayerReplicationInfo != Scorer && C.PlayerReplicationInfo.Score >= Scorer.Score)
					return;
			}
			EndGame(Scorer, "fraglimit");
		}
	}
}

function UpdateUnlagLocations()
{
	local BetrayalUnlaggedCollision UnlaggedCollision, NextCollision;

	LastLocationUpdateTime = Level.TimeSeconds;
	for (UnlaggedCollision = FirstCollision; UnlaggedCollision != None; UnlaggedCollision = NextCollision) {
		NextCollision = UnlaggedCollision.NextCollision; // collision could get destroyed, so remember next one
		UnlaggedCollision.UpdateUnlagLocation();
	}
}

function EnableUnlag(Pawn Attacker, vector FireStart, vector FireDir)
{
	local BetrayalUnlaggedCollision UnlaggedCollision;
	local float UnlagTime;
	local BetrayalPRI BPRI;

	if (Attacker != None)
		BPRI = BetrayalPRI(Attacker.PlayerReplicationInfo);

	if (Attacker == None || PlayerController(Attacker.Controller) == None || NetConnection(PlayerController(Attacker.Controller).Player) == None || BPRI != None && !BPRI.bUseUnlagging)
		return; // not controlled by a remote player

	if (LastLocationUpdateTime != Level.TimeSeconds) {
		UpdateUnlagLocations();
	}

	if (BPRI != None)
		UnlagTime = BPRI.GamePing;
	else
		UnlagTime = PlayerController(Attacker.Controller).ExactPing;

	for (UnlaggedCollision = FirstCollision; UnlaggedCollision != None; UnlaggedCollision = UnlaggedCollision.NextCollision) {
		UnlaggedCollision.EnableUnlag(UnlagTime, FireStart, FireDir);
	}
}

function DisableUnlag()
{
	local BetrayalUnlaggedCollision UnlaggedCollision;

	for (UnlaggedCollision = FirstCollision; UnlaggedCollision != None; UnlaggedCollision = UnlaggedCollision.NextCollision) {
		UnlaggedCollision.DisableUnlag();
	}
}


state MatchInprogress
{
	function Timer()
	{
		local int i, j, NumBetrayers, MaxTeamSize;
		local BetrayalPRI PRI, Teammate;
		local BetrayalTeam NewTeam;
		local array<BetrayalPRI> Freelancers;

		Super.Timer();

		if (bGameEnded)
			return;

		if (NumPlayers + NumBots > 6)
			MaxTeamSize = 3;
		else
			MaxTeamSize = 2;

		// find all freelancers
		for (i= 0; i < GameReplicationInfo.PRIArray.Length; i++) {
			PRI = BetrayalPRI(GameReplicationInfo.PRIArray[i]);
			if (PRI != None && PRI.CurrentTeam == None && !PRI.bIsRogue && !PRI.bIsSpectator && !PRI.bOnlySpectator) {
				// shuffle them to make things less boring, but put "innocent" players first
				if (PRI.Betrayed != None) {
					j = Rand(NumBetrayers + 1) + Freelancers.Length - NumBetrayers;
					NumBetrayers++;
				}
				else {
					j = Rand(Freelancers.Length + 1 - NumBetrayers);
				}
				Freelancers.Insert(j, 1);
				Freelancers[j] = PRI;
			}
		}

		// first try to place on existing team - but not the one you've betrayed before, or one that has too big a pot
		for (i = 0; i < Freelancers.Length; i++) {
			PRI = Freelancers[i];
			for (j = 0; j < Teams.Length; j++) {
				if (!Teams[j].MemberWasBetrayedBy(PRI) && Teams[j].AddTeammate(PRI, MaxTeamSize)) {
					//Successfully added to a team
					if (PlayerController(PRI.Owner) != None)
						PlayerController(PRI.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 1);

					PRI.Betrayed = None;
					return;
				}
			}
		}

		// maybe form team from freelancers who didn't betray each other recently, but only if enough players are on the server
		if (NumPlayers + NumBots > 3) {
			for (i = 0; i < Freelancers.Length - 1; i++) {
				PRI = Freelancers[i];
				for (j = i + 1; j < Freelancers.Length; j++) {
					if (PRI.Betrayed != Freelancers[j] && Freelancers[j].Betrayed != PRI) {
						Teammate = Freelancers[j];
						break;
					}
				}
			}
			if (Teammate != None) {
				// can form a new team
				NewTeam = Spawn(class'BetrayalTeam');
				if (NewTeam != None) {
					Teams[Teams.Length] = NewTeam;
					if (!NewTeam.AddTeammate(PRI, MaxTeamSize) || !NewTeam.AddTeammate(Teammate, MaxTeamSize)) {
						NewTeam.Reset();
						return;
					}
					if (PlayerController(PRI.Owner) != None) {
						PlayerController(PRI.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 1);
					}
					if (PlayerController(Teammate.Owner) != None) {
						PlayerController(Teammate.Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 1);
					}

					if (MaxTeamSize > 2) {
						// see if we can find a third teammate
						for (i = j + 1; i < Freelancers.Length; i++) {
							if (PRI.Betrayed != Freelancers[i] && Freelancers[i].Betrayed != PRI && Teammate.Betrayed != Freelancers[i] && Freelancers[i].Betrayed != Teammate && NewTeam.AddTeammate(Freelancers[i], MaxTeamSize)) {
								//Successfully added to a team
								if (PlayerController(Freelancers[i].Owner) != None) {
									PlayerController(Freelancers[i].Owner).ReceiveLocalizedMessage(AnnouncerMessageClass, 1);
								}
								Freelancers[i].Betrayed = None;
								break;
							}
						}
					}
					PRI.Betrayed = None;
					Teammate.Betrayed = None;
				}
			}
		}
	}

	function Tick(float DeltaTime)
	{
		if (LastLocationUpdateTime != Level.TimeSeconds) {
			UpdateUnlagLocations();
		}
	}
}

static function string GetLoadingHint(PlayerController Ref, string MapName, color HintColor)
{
	local string DemoName, RecordedBy, Timestamp, MapTitle, MapAuthor, MapDescription, GameTypeName, Content, Parsed;
	local Material MapScreenshot, MapBackground, GameScreenshot, GameBackground;
	local TexScaler BGInterlaceScaler;
	local Combiner BGCombiner;
	local UT2K4ServerLoading LoadingScreen;
	local DrawOpText HintTextOp;
	local class<GameInfo> GameClass;
	local int i, ClientSide, Start, End;
	local BetrayalDrawImageOp Image;
	local BetrayalDrawTextOp Text;
	local array<string> Parts;
	local array<TDrawOp> DrawOps;
	local bool bWrapText;

	foreach Ref.AllObjects(class'UT2K4ServerLoading', LoadingScreen) {
		if (!LoadingScreen.bDeleteMe)
			break;
	}

	if (LoadingScreen != None) {
		HintTextOp = DrawOpText(LoadingScreen.Operations[3]);
		if (Right(MapName, 6) ~= ".demo4") {
			DemoName = MapName;
			LoadDemoData(Ref, DemoName, MapName, MapTitle, MapDescription, MapAuthor, MapScreenshot, RecordedBy, Timestamp, ClientSide);
			DrawOps = default.DemoDrawOps;
		}
		else {
			LoadMapData(MapName, MapTitle, MapDescription, MapAuthor, MapScreenshot);
			DrawOps = default.GameDrawOps;
		}
		GameClass = LoadingScreen.GameClass;
		if (GameClass != None) {
			GameTypeName = GameClass.default.GameName;
			GameScreenshot = Material(DynamicLoadObject(GameClass.default.GameName, class'Material', true));
		}

		if (MapScreenshot != None) {
			BGInterlaceScaler = new(None) class'TexScaler';
			BGInterlaceScaler.Material = Texture'InterfaceContent.Menu.InterlaceLines';
			BGInterlaceScaler.VScale   = 0.05;

			BGCombiner = new(None) class'Combiner';
			BGCombiner.Material1        = BGInterlaceScaler;
			BGCombiner.CombineOperation = CO_Multiply;
			MapBackground = BGCombiner;
			if (MaterialSequence(MapScreenshot) != None) {
				// pick random sequence items for background and smaller preview image
				BGCombiner.Material2 = MaterialSequence(MapScreenshot).SequenceItems[Rand(MaterialSequence(MapScreenshot).SequenceItems.Length)].Material;
				do {
					i = Rand(MaterialSequence(MapScreenshot).SequenceItems.Length);
				} until (Rand(5) == 0 || BGCombiner.Material2 != MaterialSequence(MapScreenshot).SequenceItems[i].Material);
				MapScreenshot = MaterialSequence(MapScreenshot).SequenceItems[i].Material;
			}
			else {
				BGCombiner.Material2 = MapScreenshot;
			}
		}

		if (GameScreenshot != None) {
			BGInterlaceScaler = new(None) class'TexScaler';
			BGInterlaceScaler.Material = Texture'InterfaceContent.Menu.InterlaceLines';
			BGInterlaceScaler.VScale   = 0.05;

			BGCombiner = new(None) class'Combiner';
			BGCombiner.Material1        = BGInterlaceScaler;
			BGCombiner.CombineOperation = CO_Multiply;
			GameBackground = BGCombiner;
			if (MaterialSequence(GameScreenshot) != None) {
				// pick random sequence items for background and smaller preview image
				BGCombiner.Material2 = MaterialSequence(GameScreenshot).SequenceItems[Rand(MaterialSequence(GameScreenshot).SequenceItems.Length)].Material;
				do {
					i = Rand(MaterialSequence(GameScreenshot).SequenceItems.Length);
				} until (Rand(5) == 0 || BGCombiner.Material2 != MaterialSequence(GameScreenshot).SequenceItems[i].Material);
				GameScreenshot = MaterialSequence(GameScreenshot).SequenceItems[i].Material;
			}
			else {
				BGCombiner.Material2 = GameScreenshot;
			}
		}

		// ensure interface quality
		FixQuality(MapScreenshot);
		FixQuality(MapBackground);

		// remove all draw operations
		LoadingScreen.Operations.Length = 0;

		// create new list of draw operations
		for (i = 0; i < DrawOps.Length; ++i) {
			switch (Locs(DrawOps[i].Content)) {
			case "`bgmapimage":
				if (MapBackground != None)
					Image = AddImage(LoadingScreen, MapBackground, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				else if (GameBackground != None)
					Image = AddImage(LoadingScreen, GameBackground, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				else
					Image = AddImage(LoadingScreen, Texture'BlackTexture', DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				Image.RenderStyle   = DrawOps[i].RenderStyle;
				Image.DrawColor     = DrawOps[i].DrawColor;
				Image.Justification = DrawOps[i].AlignH;
				break;

			case "`bggameimage":
				if (GameBackground != None)
					Image = AddImage(LoadingScreen, GameBackground, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				else if (MapBackground != None)
					Image = AddImage(LoadingScreen, MapBackground, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				else
					Image = AddImage(LoadingScreen, Texture'BlackTexture', DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				Image.RenderStyle   = DrawOps[i].RenderStyle;
				Image.DrawColor     = DrawOps[i].DrawColor;
				Image.Justification = DrawOps[i].AlignH;
				break;

			case "`mapimage":
				if (MapScreenshot != None)
					Image = AddImage(LoadingScreen, MapScreenshot, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				else
					Image = AddImage(LoadingScreen, Texture'InterfaceContent.Menu.NoLevelPreview', DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				Image.RenderStyle   = DrawOps[i].RenderStyle;
				Image.DrawColor     = DrawOps[i].DrawColor;
				Image.Justification = DrawOps[i].AlignH;
				break;

			case "`gameimage":
				if (GameScreenshot != None)
					Image = AddImage(LoadingScreen, GameScreenshot, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				else
					Image = AddImage(LoadingScreen, Texture'BlackTexture', DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
				Image.RenderStyle   = DrawOps[i].RenderStyle;
				Image.DrawColor     = DrawOps[i].DrawColor;
				Image.Justification = DrawOps[i].AlignH;
				break;

			case "`gamehint":
				Text = AddText(LoadingScreen, "", DrawOps[i].AlignH, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width, DrawOps[i].AlignV);
				Text.RenderStyle = DrawOps[i].RenderStyle;
				Text.DrawColor   = DrawOps[i].DrawColor;
				Text.FontName    = DrawOps[i].FontName;
				Text.bWrapText   = bWrapText;
				Text.Source      = HintTextOp;
				break;

			default:
				if (Left(DrawOps[i].Content, 7) ~= "`image:") {
					// an image
					switch (Split(Mid(DrawOps[i].Content, 7), ",", Parts)) {
					case 1:
						Parts[1] = "-1";
					case 2:
						Parts[2] = "-1";
					case 3:
						Parts[3] = "-1";
					case 4:
						Parts[4] = "-1";
					}
					Image = AddImage(LoadingScreen, Material(DynamicLoadObject(Parts[0], class'Material', true)), DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
					Image.RenderStyle   = DrawOps[i].RenderStyle;
					Image.DrawColor     = DrawOps[i].DrawColor;
					Image.Justification = DrawOps[i].AlignH;
					Image.ImageStyle    = DrawOps[i].ImageStyle;
					Image.SubX          = int(Parts[1]);
					Image.SubY          = int(Parts[2]);
					Image.SubXL         = int(Parts[3]);
					Image.SubYL         = int(Parts[4]);
				}
				else if (Left(DrawOps[i].Content, 8) ~= "`random:") {
					// a random image from a list
					Split(Mid(DrawOps[i].Content, 8), ";", Parts);
					switch (Split(Parts[Rand(Parts.Length)], ",", Parts)) {
					case 1:
						Parts[1] = "-1";
					case 2:
						Parts[2] = "-1";
					case 3:
						Parts[3] = "-1";
					case 4:
						Parts[4] = "-1";
					}
					Image = AddImage(LoadingScreen, Material(DynamicLoadObject(Parts[0], class'Material', true)), DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width);
					Image.RenderStyle   = DrawOps[i].RenderStyle;
					Image.DrawColor     = DrawOps[i].DrawColor;
					Image.Justification = DrawOps[i].AlignH;
					Image.ImageStyle    = DrawOps[i].ImageStyle;
					Image.SubX          = int(Parts[1]);
					Image.SubY          = int(Parts[2]);
					Image.SubXL         = int(Parts[3]);
					Image.SubYL         = int(Parts[4]);
				}
				else {
					if (Left(DrawOps[i].Content, 10) ~= "`localize:") {
						// a localized string
						Split(Mid(DrawOps[i].Content, 10), ".", Parts);
						while (Parts.Length > 3) {
							Parts[2] $= "." $ Parts[3];
							Parts.Remove(3, 1);
						}
						Content = Localize(Parts[1], Parts[2], Parts[0]);
					}
					else {
						// plain text
						Content = DrawOps[i].Content;
					}
					Parsed = "";
					bWrapText = DrawOps[i].WrapText;
					do {
						Start = InStr(Content, "\`{"); // nevermind the backslash, I'm just working around my highlighter's bug
						if (Start == -1) {
							Parsed $= Content;
							break;
						}
						Parsed $= Left(Content, Start);
						Content = Mid(Content, Start+2);
						End = InStr(Content, "}");
						if (End == -1)
							End = Len(Content);

						switch (Left(Content, End)) {
						case "maptitle":
							Parsed $= MapTitle;
							break;

						case "mapname":
							Parsed $= LoadingScreen.StripMap(MapName);
							break;

						case "demoname":
							Parsed $= DemoName;
							break;

						case "demotype":
							Parsed $= Eval(ClientSide != 0, class'UT2K4Demos'.default.ltClientSide, class'UT2K4Demos'.default.ltServerSide);
							break;

						case "recordedby":
							Parsed $= RecordedBy;
							break;

						case "timestamp":
							Parsed $= Timestamp;
							break;

						case "byplayer":
							Parsed $= Repl(default.LoadingScreenByNameText, "`name", RecordedBy);
							break;

						case "attime":
							Parsed $= Repl(default.LoadingScreenAtTimeText, "`time", Timestamp);
							break;

						case "gamename":
							Parsed $= GameTypeName;
							break;

						case "lf":
							Parsed $= Chr(10);
							bWrapText = True;
							break;
						}
						Content = Mid(Content, End + 1);
					}
					Text = AddText(LoadingScreen, Parsed, DrawOps[i].AlignH, DrawOps[i].Top, DrawOps[i].Left, DrawOps[i].Height, DrawOps[i].Width, DrawOps[i].AlignV);
					Text.RenderStyle = DrawOps[i].RenderStyle;
					Text.DrawColor   = DrawOps[i].DrawColor;
					Text.FontName    = DrawOps[i].FontName;
					Text.bWrapText   = bWrapText;
				}
			}
		}
	}
	return Super.GetLoadingHint(Ref, MapName, HintColor);
}

static function array<string> GetAllLoadHints(optional bool bThisClassOnly)
{
	local int i;
	local array<string> Hints, DMHints;

	if (!bThisClassOnly || default.BetrayalHints.Length == 0) {
		DMHints = Super.GetAllLoadhints(bThisClassOnly);
		for (i = 0; i < default.RelevantDMLoadingHints.Length; i++)
			Hints[Hints.Length] = DMHints[default.RelevantDMLoadingHints[i]];
	}
	for (i = 0; i < default.BetrayalHints.Length; i++)
		Hints[Hints.Length] = default.BetrayalHints[i];

	return Hints;
}

static function BetrayalDrawImageOp AddImage(UT2K4LoadingPageBase LoadingScreen, Material Image, float Top, float Left, float Height, float Width)
{
	local BetrayalDrawImageOp NewImage;

	NewImage = new(None) class'BetrayalDrawImageOp';
	LoadingScreen.Operations[LoadingScreen.Operations.Length] = NewImage;

	NewImage.Image = Image;
	NewImage.SetPos(Top, Left);
	NewImage.SetSize(Height, Width);
	return NewImage;
}

static function BetrayalDrawTextOp AddText(UT2K4LoadingPageBase LoadingScreen, string Text, byte Just, float Top, float Left, float Height, float Width, optional byte VAlign)
{
	local BetrayalDrawTextOp NewText;

	NewText = new(None) class'BetrayalDrawTextOp';
	LoadingScreen.Operations[LoadingScreen.Operations.Length] = NewText;

	NewText.SetPos(Top, Left);
	NewText.Text = Text;
	NewText.SetSize(Height, Width);
	NewText.Justification = Just;
	NewText.VertAlign = VAlign;
	return NewText;

}

static function bool LoadDemoData(PlayerController Ref, string DemoName, out string MapName, out string MapTitle, out string MapDescription, out string MapAuthor, out Material MapScreenshot, out string RecordedBy, out string Timestamp, out int ClientSide)
{
	local string GameType, ReqPackages;
	local int ScoreLimit, TimeLimit;

	if (Ref == None || Ref.Player == None || GUIController(Ref.Player.GUIController) == None || !GUIController(Ref.Player.GUIController).GetDEMHeader(DemoName, MapName, GameType, ScoreLimit, TimeLimit, ClientSide, RecordedBy, Timestamp, ReqPackages))
		return false;

	return LoadMapData(MapName, MapTitle, MapDescription, MapAuthor, MapScreenshot);
}

static function bool LoadMapData(string MapName, out string MapTitle, out string MapDescription, out string MapAuthor, out Material MapScreenshot)
{
	local array<CacheManager.MapRecord> MapRecords;
	local int i;
	local LevelSummary MapSummary;
	local string MapDecoText, DecoTextPackage, DecoTextName;
	local DecoText DecoText;

	class'CacheManager'.static.GetMapList(MapRecords);
	for (i = 0; i < MapRecords.Length; ++i) {
		if (MapRecords[i].MapName ~= MapName) {
			MapTitle       = MapRecords[i].FriendlyName;
			MapDescription = MapRecords[i].Description;
			MapAuthor      = MapRecords[i].Author;
			MapDecoText    = MapRecords[i].TextName;
			if (MapRecords[i].ScreenshotRef != "")
				MapScreenshot = Material(DynamicLoadObject(MapRecords[i].ScreenshotRef, class'Material', True));
			break;
		}
	}

	// try loading from map summary if cache doesn't provide title and screenshot
	if (MapTitle == "" || MapScreenshot == None) {
		MapSummary = LevelSummary(DynamicLoadObject(MapName $ ".LevelSummary", class'LevelSummary', True));
		if (MapSummary != None) {
			MapTitle       = MapSummary.Title;
			MapDescription = MapSummary.Description;
			MapAuthor      = MapSummary.Author;
			MapDecoText    = MapSummary.DecoTextName;
			MapScreenshot  = MapSummary.Screenshot;
		}
		return false;
	}

	// try loading deco text if no description
	if (MapDescription == "" && Divide(MapDecoText, ".", DecoTextPackage, DecoTextName)) {
		DecoText = class'XUtil'.static.LoadDecoText(DecoTextPackage, DecoTextName);
		for (i = 0; i < DecoText.Rows.Length; i++) {
			if (MapDescription != "")
				MapDescription $= "|";
			MapDescription $= DecoText.Rows[i];
		}
	}

	// fallback values for title
	if (MapTitle == "" || MapTitle == class'LevelInfo'.default.Title)
		MapTitle = Mid(MapName, InStr(MapName, "-") + 1);

	return true;
}


static function FixQuality(Material Mat)
{
	local Texture T;
	local Combiner C;
	local Shader S;
	local Modifier M;

	if (Mat == None)
		return;

	FixQuality(Mat.FallbackMaterial);

	T = Texture(Mat);
	if (T != None) {
		if (T.LODSet != LODSET_None)
			T.LODSet = LODSET_Interface;
		FixQuality(T.Detail);
		return;
	}

	M = Modifier(Mat);
	if (M != None) {
		FixQuality(M.Material);
		return;
	}

	S = Shader(Mat);
	if (S != None) {
		FixQuality(S.Diffuse);
		FixQuality(S.Opacity);
		FixQuality(S.Specular);
		FixQuality(S.SpecularityMask);
		FixQuality(S.SelfIllumination);
		FixQuality(S.SelfIlluminationMask);
		FixQuality(S.Detail);
		return;
	}

	C = Combiner(Mat);
	if (C != None) {
		FixQuality(C.Material1);
		FixQuality(C.Material2);
		FixQuality(C.Mask);
		return;
	}
}


static function FillPlayInfo(PlayInfo PlayInfo)
{
	Super.FillPlayInfo(PlayInfo);

	PlayInfo.AddSetting(default.RulesGroup, "bBeamMultiHit", default.lblBeamMultiHit, 0, 0, "Check");
	PlayInfo.AddSetting(default.RulesGroup, "MaxUnlagTime", default.lblMaxUnlagTime, 0, 0, "Text", "5;0.0:1.0",, True);
	PlayInfo.AddSetting(default.RulesGroup, "bSpecialKillRewards", default.lblSpecialKillRewards, 0, 0, "Check");
	PlayInfo.AddSetting(default.RulesGroup, "bRestorePlayerStats", default.lblRestorePlayerStats, 0, 0, "Check");
	PlayInfo.AddSetting(default.RulesGroup, "bBrighterPlayerSkins", default.lblBrighterPlayerSkins, 0, 0, "Check");
	PlayInfo.AddSetting(default.RulesGroup, "bImprovedSlopeDodging", default.lblImprovedSlopeDodging, 0, 0, "Check");
}


static event bool AcceptPlayInfoProperty(string PropertyName)
{
	switch (PropertyName) {
	case "bAllowTrans":
	case "bForceRespawn":
	case "bAllowWeaponThrowing":
	case "bWeaponStay":
		return false;
	default:
		return Super.AcceptPlayInfoProperty(PropertyName);
	}
}


/**
Returns the description text for a configurable property.
*/
static event string GetDescriptionText(string PropName)
{
	switch (PropName) {
		case "bBeamMultiHit":
			return default.descBeamMultiHit;
		case "MaxUnlagTime":
			return default.descMaxUnlagTime;
		case "bSpecialKillRewards":
			return default.descSpecialKillRewards;
		case "bRestorePlayerStats":
			return default.descRestorePlayerStats;
		case "bBrighterPlayerSkins":
			return default.descBrighterPlayerSkins;
		case "bImprovedSlopeDodging":
			return default.descImprovedSlopeDodging;
		default:
			return Super.GetDescriptionText(PropName);
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	GameName    = "Betrayal"
	Description = "Cooperate to get bonus points.  Betray your team to keep them."
	Acronym     = "BET"
	GoalScore   = 100

	Build     = "%%%%-%%-%% %%:%%"
	Copyright = "Copyright 2003-2013 by Wormbo"

	bBeamMultiHit = False
	MaxUnlagTime  = 0.25
	bSpecialKillRewards = False
	bRestorePlayerStats = True
	bImprovedSlopeDodging = True

	MutatorClass           = "BetrayalV1.BetrayalMutator"
	HUDType                = "BetrayalV1.BetrayalHud"
	ScoreBoardType         = "BetrayalV1.BetrayalScoreboard"
	DefaultPlayerClassName = "BetrayalV1.BetrayalPawn"
	HUDSettingsMenu        = "BetrayalV1.BetrayalClientSettingsMenu"
	LocalStatsScreenClass  = class'BetrayalStatsScreen'
	LoginMenuClass         = "GUI2K4.UT2K4PlayerLoginMenu"

	BetrayedSound = Sound'GameSounds.DDAverted'

	DMSquadClass             = class'BetrayalSquadAI'
	GameReplicationInfoClass = class'BetrayalGRI'
	AnnouncerMessageClass    = class'BetrayalMessage'
	DeathMessageClass        = class'BetrayalDeathMessage'

	lblMaxUnlagTime          = "Max. Unlag Time"
	descMaxUnlagTime         = "Maximum shot unlag time."
	lblBeamMultiHit          = "Instagib Beam Multi-Hit"
	descBeamMultiHit         = "Whether the Instagib rifle shoots through players."
	lblSpecialKillRewards    = "Special Kill Rewards"
	descSpecialKillRewards   = "Adds an additional point for special kills, such as multiple hits per shot, head shots or nice mid-air hits."
	lblRestorePlayerStats    = "Restore Player Stats"
	descRestorePlayerStats   = "Save the player's stats of he/she becomes spectator or leaves the server and restore them on rejoin in the same match."
	lblBrighterPlayerSkins   = "Brighter Player Skins"
	descBrighterPlayerSkins  = "Slightly increases player skin brightness. (For the TAM-/UTComp-impaired players.)"
	lblImprovedSlopeDodging  = "Improved slope dodging"
	descImprovedSlopeDodging = "Adjusts the dodging direction when dodging up a (walkable) slope."

	RelevantDMLoadingHints = (1,2,3,7,9,11,12,13)
	BetrayalHints[0] = "Shoot with %FIRE% to kill enemies, shoot with %ALTFIRE% to kill your teammates and take the team pot."
	BetrayalHints[1] = "Try getting retribution on a former teammate who betrayed you. Doing so within 30 seconds after betrayal will award you additional points."
	BetrayalHints[2] = "Make sure you hit with the first shot when trying to betray your team. Betraying shots have a different color, so your teammate will notice your intentions if you miss."
	BetrayalHints[3] = "Don't betray your team right away. The few points in the team pot might not be worth the trouble of avoiding payback. Later betraying at the right time can decide the match very quickly, though."
	BetrayalHints[4] = "The player beacons reflect your relation to that player and tell how much points you will get for killing him/her. Blue is for teammates, red is for a former teammate who betrayed you, green is for the former teammates who are seeking payback on you."
	BetrayalHints[5] = "Be aware of your teammates' scores when they get closer to the goal score. You may need to betray them to prevent them from taking the pot to win the match."
	BetrayalHints[6] = "You can access client-side Betrayal options via %MYMENU%."
	BetrayalHints[7] = "You can access client-side Betrayal options via %MENU3SPN%."
	BetrayalHints[8] = "You can access client-side Betrayal options via the standard HUD settings page."
	// ^-- stupid hint parsing algorithm
	BetrayalHints[9] = "After you betrayed your team, try to not give them a chance for retribution. When they succeed your score will decrease!"

	LoadingScreenByNameText = "by `name"
	LoadingScreenAtTimeText = "at `time"

	GameDrawOps(0) = (Content="`bgmapimage",Height=1.0,Width=1.0,RenderStyle=1,DrawColor=(R=200,G=200,B=200,A=255))
	GameDrawOps(1) = (Content="`random:2k4Menus.MainMenu.Char01,0,0,1024,768;2k4Menus.MainMenu.Char02,0,0,1024,768;2k4Menus.MainMenu.Char03,0,0,1024,768",Top=0.0,Left=0.0,Height=1.0,Width=1.0,RenderStyle=5,DrawColor=(R=255,G=255,B=255,A=255))
	GameDrawOps(2) = (Content="`image:2k4Menus.MainMenu.2k4Logo",Top=0.0,Left=0.325,Height=0.25,Width=0.35,RenderStyle=5,DrawColor=(R=224,G=224,B=224,A=255))
	GameDrawOps(3) = (Content="`mapimage",Top=0.25,Left=0.1,Height=0.4,Width=0.4,RenderStyle=1,DrawColor=(R=255,G=255,B=255,A=255))
	GameDrawOps(4) = (Content="`image:2k4Menus.Controls.outlinesquare",Top=0.25,Left=0.1,Height=0.4,Width=0.4,RenderStyle=5,ImageStyle=3,DrawColor=(R=128,G=128,B=128,A=255))
	GameDrawOps(5) = (Content="`{gamename}",Top=0.05,Left=0.0,Height=0.2,Width=0.6,RenderStyle=1,AlignH=1,AlignV=2,FontName="XInterface.UT2LargeFont",DrawColor=(R=255,G=255,B=255,A=255))
	GameDrawOps(6) = (Content="`{maptitle}",Top=0.65,Left=0.0,Height=0.15,Width=0.6,RenderStyle=1,AlignH=1,FontName="XInterface.UT2LargeFont",DrawColor=(R=255,G=255,B=255,A=255))
	GameDrawOps(7) = (Content="`gamehint",Top=0.8,Left=0.05,Height=0.18,Width=0.9,RenderStyle=1,AlignV=2,WrapText=True,FontName="GUI2K4.fntUT2k4SmallHeader",DrawColor=(R=255,G=255,B=255,A=255))

	DemoDrawOps(0) = (Content="`bgmapimage",Height=1.0,Width=1.0,RenderStyle=1,DrawColor=(R=200,G=200,B=200,A=255))
	DemoDrawOps(1) = (Content="`random:2k4Menus.MainMenu.Char01,0,0,1024,768;2k4Menus.MainMenu.Char02,0,0,1024,768;2k4Menus.MainMenu.Char03,0,0,1024,768",Top=0.0,Left=0.0,Height=1.0,Width=1.0,RenderStyle=5,DrawColor=(R=255,G=255,B=255,A=255))
	DemoDrawOps(2) = (Content="`image:2k4Menus.MainMenu.2k4Logo",Top=0.0,Left=0.325,Height=0.25,Width=0.35,RenderStyle=5,DrawColor=(R=224,G=224,B=224,A=255))
	DemoDrawOps(3) = (Content="`mapimage",Top=0.25,Left=0.1,Height=0.4,Width=0.4,RenderStyle=1,DrawColor=(R=255,G=255,B=255,A=255))
	DemoDrawOps(4) = (Content="`image:2k4Menus.Controls.outlinesquare",Top=0.25,Left=0.1,Height=0.4,Width=0.4,RenderStyle=5,ImageStyle=3,DrawColor=(R=128,G=128,B=128,A=255))
	DemoDrawOps(5) = (Content="`{gamename}`{lf}`{maptitle}",Top=0.05,Left=0.0,Height=0.2,Width=0.6,RenderStyle=1,AlignH=1,AlignV=2,FontName="XInterface.UT2LargeFont",DrawColor=(R=255,G=255,B=255,A=255))
	DemoDrawOps(6) = (Content="`{demotype}`{lf}`{byplayer}`{lf}`{attime}",Top=0.65,Left=0.0,Height=0.3,Width=0.6,RenderStyle=1,AlignH=1,FontName="XInterface.UT2LargeFont",DrawColor=(R=255,G=255,B=255,A=255))
}
