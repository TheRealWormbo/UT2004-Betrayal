/******************************************************************************
BetrayalStatsScreen

Creation date: 2011-03-20 10:12
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalStatsScreen extends ScoreBoard;


//=============================================================================
// Localization
//=============================================================================

var localized string TimePlayedString, PPHString, EfficiencyString, AccuracyString;
var localized string RetributionString, PaybackString, PotStolenString;
var localized string MultiHitString, BestPrefixString;
var localized string KilledCaption, BetrayedCaption;


//=============================================================================
// Properties
//=============================================================================

var float VsStatsAreaLeft, VsStatsAreaTop, VsStatsAreaSpacing, VsStatsAreaMaxHeight, VsStatsNameMaxScale;
var float IndividualStatsAreaRight, IndividualStatsAreaTop, IndividualStatsAreaMaxWidth, IndividualStatsAreaMaxHeight;

var Material BGMaterial;
var color AreaBGColor, ItemBGColor, HeaderTextColor, ItemTextColor, SelectedTextColor, LocalTextColor, InactiveTextColor;
var float AreaBGScale, ItemBGScale, ItemSpacing;
var float AreaPadding, ItemPadding;

var Material DaggerIcon;
var IntBox DaggerIconCoords;

var Material CaptionArrowIcon;
var IntBox CaptionArrowIconCoords;


//=============================================================================
// Variables
//=============================================================================

var int CurrentPlayerID, CurrentListID, LastNumPlayers;
var transient array<BetrayalPRI> PRIs;
var transient int CurrentPlayerIndex, CurrentListIndex, LocalPlayerIndex, NumDrawnRows, NumDrawnColumns, FirstRowIndex, FirstColumnIndex, MaxNameLength;

var float NextUpdateRequestTime;
var int LastUpdateRequestID;

var Font VsFont, IndividualCaptionFont, IndividualItemFont;
var transient float VsStatsLeft, VsStatsTop, VsStatsWidth, VsStatsHeight, VsStatsCellWidth, VsStatsCellHeight, VsStatsCellSpacing, VsStatsNameSize;
var transient float IndividualStatsLeft, IndividualStatsTop, IndividualStatsWidth, IndividualStatsHeight, IndividualCaptionHeight, IndividualDetailHeight;
var transient bool bCanShowBetrayals;

/** Only valid during UpdateScoreboard(). */
var transient Canvas Canvas;
var float ResScale;

// tilted table caption
var ScriptedTexture CaptionTexture;
var TexRotator RotatedCaption;
var FinalBlend RotatedFinal;
var Font CaptionFont;
var float MaxCaptionWidth;
var string TableCaption;
var int ActualCaptionWidth, ActualCaptionHeight;


function Material GetStatsCaptionTexture(Font Font, float MaxWidth, string CaptionString)
{
	local int Bits;
	const DivByLn2 = 1.44269504; // 1 / ln 2

	if (bPendingDelete || bDeleteMe)
		return None;

	if (CaptionTexture == None) {
		CaptionTexture = ScriptedTexture(Level.ObjectPool.AllocateObject(class'ScriptedTexture'));
		CaptionTexture.Client = Self;
		CaptionTexture.FallbackMaterial = None;
		CaptionTexture.UClampMode = TC_Wrap;
		CaptionTexture.VClampMode = TC_Wrap;

		RotatedCaption = TexRotator(Level.ObjectPool.AllocateObject(class'TexRotator'));
		RotatedCaption.Material = CaptionTexture;
		RotatedCaption.TexRotationType = TR_FixedRotation;
		RotatedCaption.Rotation = rot(0,8192,0);
		RotatedCaption.FallbackMaterial = None;

		RotatedFinal = FinalBlend(Level.ObjectPool.AllocateObject(class'FinalBlend'));
		RotatedFinal.Material = RotatedCaption;
		RotatedFinal.FrameBufferBlending = FB_AlphaBlend;
		RotatedFinal.ZWrite = True;
		RotatedFinal.ZTest = True;
		RotatedFinal.AlphaTest = False;
		RotatedFinal.AlphaRef = 0;
		RotatedFinal.FallbackMaterial = None;
	}
	if (MaxWidth > CaptionTexture.MaterialUSize()) {
		Bits = Ceil(Loge(MaxWidth) * DivByLn2); // corresponds to Ceil(Log2(MaxNameWidth))
		CaptionTexture.SetSize(1 << Bits, 1 << Bits); // includes Revision++
	}
	else if (TableCaption != CaptionString || CaptionFont != Font || MaxCaptionWidth != MaxWidth)
		CaptionTexture.Revision++; // also needs redrawing

	CaptionFont = Font;
	MaxCaptionWidth = MaxWidth;
	TableCaption = CaptionString;

	return RotatedFinal;
}

function Destroyed()
{
	Super.Destroyed();

	// release allocated stats screen materials
	if (RotatedFinal != None) {
		RotatedFinal.Material = None;
		Level.ObjectPool.FreeObject(RotatedFinal);
		RotatedFinal = None;
	}
	if (RotatedCaption != None) {
		RotatedCaption.Material = None;
		Level.ObjectPool.FreeObject(RotatedCaption);
		RotatedCaption = None;
	}
	if (CaptionTexture != None) {
		CaptionTexture.Client = None;
		Level.ObjectPool.FreeObject(CaptionTexture);
		CaptionTexture = None;
	}
}

function RenderTexture(ScriptedTexture Tex)
{
	local float ArrowWidth, ArrowHeight;

	if (Tex != CaptionTexture || CaptionFont == None)
		return;

	Tex.TextSize(TableCaption, CaptionFont, ActualCaptionWidth, ActualCaptionHeight);
	Tex.DrawText(0.5 * (Tex.USize - ActualCaptionWidth), 0.5 * Tex.VSize - ActualCaptionHeight, TableCaption, CaptionFont, class'Hud'.default.WhiteColor);

	ArrowHeight = ActualCaptionHeight;
	ArrowWidth = ArrowHeight * (CaptionArrowIconCoords.X2 - CaptionArrowIconCoords.X1) / (CaptionArrowIconCoords.Y2 - CaptionArrowIconCoords.Y1);
	Tex.DrawTile(
		0.5 * (Tex.USize - ArrowWidth), 0.5 * Tex.VSize,
		ArrowWidth, ArrowHeight,
		CaptionArrowIconCoords.X1, CaptionArrowIconCoords.Y1,
		CaptionArrowIconCoords.X2 - CaptionArrowIconCoords.X1, CaptionArrowIconCoords.Y2 - CaptionArrowIconCoords.Y1,
		CaptionArrowIcon, class'Hud'.default.WhiteColor);

	ActualCaptionHeight *= 2;
	ActualCaptionWidth = Max(ActualCaptionWidth, Ceil(ArrowWidth));

	// adjust TexRotator, in case texture size changed
	RotatedCaption.UOffset = 0.5 * Tex.USize;
	RotatedCaption.VOffset = 0.5 * Tex.VSize;
}

function DrawCaptionTexture(float Scale, Font Font, float MaxWidth, float MaxActualWidth, string CaptionString)
{
	local float ActualSize;

	ActualSize = Sqrt(Square(ActualCaptionWidth) + Square(ActualCaptionHeight));
	if (ActualSize * Scale > MaxActualWidth)
		Scale *= MaxActualWidth / (ActualSize * Scale);

	Canvas.CurY -= 0.5 * (ActualSize - 0.7071 * ActualCaptionHeight) * Scale;
	Canvas.CurX -= 0.5 * (ActualSize - 0.7071 * ActualCaptionHeight) * Scale;
	Canvas.DrawTile(GetStatsCaptionTexture(Font, MaxWidth, CaptionString), ActualSize * Scale, ActualSize * Scale, 0.5 * (CaptionTexture.USize - ActualSize), 0.5 * (CaptionTexture.VSize - ActualSize), ActualSize, ActualSize);
}

function bool InOrder(PlayerReplicationInfo P1, PlayerReplicationInfo P2)
{
	// spectators go to the end of the list (not necessarily in alphabetical order)
	if (P1.bOnlySpectator)
		return P2.bOnlySpectator;
	else if (P2.bOnlySpectator)
		return true;

	// to achieve permanently stable sorting, only PlayerIDs are used
	return P1.PlayerID <= P2.PlayerID;
}


function NextStats()
{
	CurrentPlayerID++;
}


function Init()
{
	SetTimer(Level.TimeDilation, True);
}

function Timer()
{
	SetTimer(Level.TimeDilation, True);
	CurrentListID++;
}


function bool UpdateGRI()
{
	local int i, NumPlayers;
	local UnrealPlayer LocalPlayer;

	if (!Super.UpdateGRI())
		return false;
	// PRIs now sorted by PlayerID and spects grouped at the end

	LocalPlayer = UnrealPlayer(Level.GetLocalPlayerController());

	// initialize PRIs list and current player index
	CurrentPlayerIndex = -1;
	CurrentListIndex   = -1;
	LocalPlayerIndex   = -1;
	LastNumPlayers     = PRIs.Length;
	bCanShowBetrayals  = False;
	MaxNameLength      = 0;

	for (i = 0; i < GRI.PRIArray.Length && !GRI.PRIArray[i].bOnlySpectator; i++) {
		if (BetrayalPRI(GRI.PRIArray[i]) != None) {
			PRIs[NumPlayers] = BetrayalPRI(GRI.PRIArray[i]);
			if (CurrentPlayerIndex == -1 && PRIs[NumPlayers].PlayerID >= CurrentPlayerID) {
				CurrentPlayerIndex = NumPlayers;
				CurrentPlayerID    = PRIs[NumPlayers].PlayerID;
			}
			if (CurrentListIndex == -1 && PRIs[NumPlayers].PlayerID >= CurrentListID) {
				CurrentListIndex = NumPlayers;
				CurrentListID    = PRIs[NumPlayers].PlayerID;
			}
			if (LocalPlayer != None && PRIs[NumPlayers] == LocalPlayer.PlayerReplicationInfo) {
				LocalPlayerIndex = NumPlayers;
			}
			MaxNameLength = Max(MaxNameLength, Len(PRIs[NumPlayers].PlayerName));
			if (PRIs[NumPlayers].BetrayalCount > 0) {
				bCanShowBetrayals = True;
			}
			NumPlayers++;
		}
	}
	MaxNameLength = Min(MaxNameLength, 10);
	PRIs.Length = NumPlayers; // in case any players left

	if (NumPlayers > 0 && CurrentPlayerIndex == -1) {
		// pick first player after reaching end of PRIs list
		CurrentPlayerIndex = 0;
		CurrentPlayerID    = PRIs[0].PlayerID;
	}

	if (NumPlayers > 0 && CurrentListIndex == -1) {
		// pick first player after reaching end of PRIs list
		CurrentListIndex = 0;
		CurrentListID    = PRIs[0].PlayerID;
	}

	if (Level.NetMode == NM_Client && NumPlayers > 0 && Level.TimeSeconds > NextUpdateRequestTime && LocalPlayer != None) {
		// request updates regularly
		for (i = 0; i < PRIs.Length && PRIs[i].PlayerID <= LastUpdateRequestID; i++);
		if (i == PRIs.Length) {
			i = 0;
		}
		LastUpdateRequestID = PRIs[i].PlayerID;
		if (i == CurrentPlayerIndex || LocalPlayer.bDisplayWinner || LocalPlayer.bDisplayLoser) {
			// all stats for sleelcted player and at end of match
			LocalPlayer.ServerUpdateStats(PRIs[i]);
			NextUpdateRequestTime = Level.TimeSeconds + 1.0;
		}
		else {
			// just the kill stats
			LocalPlayer.ServerGetNextVehicleStats(PRIs[i], 0);
			NextUpdateRequestTime = Level.TimeSeconds + 0.5;
		}
	}

	return NumPlayers > 0;
}


function UpdateScoreBoard(Canvas C)
{
	local Hud LocalHud;

	if (PlayerController(Owner) != None) {
		LocalHud = PlayerController(Owner).MyHud;

		// draw crosshair, because can still see enough through the stats table
		if (LocalHud != None && LocalHud.PlayerOwner != None && LocalHud.PawnOwner != None && LocalHud.PawnOwnerPRI != None && !LocalHud.PlayerOwner.IsSpectating() && !LocalHud.PlayerOwner.bBehindView && !LocalHud.PawnOwner.bHideRegularHUD)
			LocalHud.DrawCrosshair(C);
	}

	Canvas = C;
	Canvas.Reset();
	Canvas.Style = 5;
	ResScale     = (Canvas.ClipX + Canvas.ClipY) / 1800;

	if (PRIs.Length == 0) {
		DrawNoPlayersMessage();
		Canvas = None;
		return;
	}

	LayoutStatsScreen();

	DrawVsStats();
	DrawIndividualStats();

	Canvas = None;
}

function DrawNoPlayersMessage()
{
	local float TextXL, TextYL, X, Y;
	local string Msg;

	Msg = " " $ class'StartupMessage'.default.Stage[0] $ " "; // additional padding left and right because it looks weird otherwise
	Canvas.Font = HudClass.static.GetMediumFontFor(Canvas);
	Canvas.StrLen(Msg, TextXL, TextYL);
	X = 0.5 * (Canvas.ClipX - TextXL);
	Y = 0.5 * (Canvas.ClipY - TextYL);

	Canvas.DrawColor = AreaBGColor;
	class'BetrayalHud'.static.DrawBox(Canvas, BGMaterial, X - (AreaPadding + ItemPadding) * ResScale, Y - (AreaPadding + ItemPadding) * ResScale, TextXL + 2 * (AreaPadding + ItemPadding) * ResScale, TextYL + 2 * (AreaPadding + ItemPadding) * ResScale, AreaBGScale * ResScale, AreaBGScale * ResScale);

	Canvas.DrawColor = ItemBGColor;
	class'BetrayalHud'.static.DrawBox(Canvas, BGMaterial, X - ItemPadding * ResScale, Y - ItemPadding * ResScale, TextXL + 2 * ItemPadding * ResScale, TextYL + 2 * ItemPadding * ResScale, ItemBGScale * ResScale, ItemBGScale * ResScale);

	Canvas.DrawColor = HeaderTextColor;
	Canvas.SetPos(X, Y);
	Canvas.DrawTextClipped(Msg);
}


function LayoutStatsScreen()
{
	local int i, FontReduction;
	local float NumFitting, XL, YL;

	// determine individual stats area dimensions
	IndividualStatsWidth  = Canvas.ClipY * IndividualStatsAreaMaxWidth  - 2 * AreaPadding * ResScale; // relative to height!
	IndividualStatsHeight = Canvas.ClipY * IndividualStatsAreaMaxHeight - 2 * AreaPadding * ResScale;
	IndividualStatsLeft   = Canvas.ClipX * IndividualStatsAreaRight - IndividualStatsWidth + AreaPadding * ResScale;
	IndividualStatsTop    = Canvas.ClipY * IndividualStatsAreaTop  + AreaPadding * ResScale;

	FontReduction = 0;
	Canvas.Font = HudClass.static.GetMediumFontFor(Canvas);
	Canvas.StrLen(PRIs[CurrentPlayerIndex].PlayerName, XL, IndividualCaptionHeight);
	for (i = 0; i < 4 && XL > IndividualStatsWidth; i++) {
		Canvas.Font = GetSmallerFontFor(Canvas, ++FontReduction);
		Canvas.StrLen(PRIs[CurrentPlayerIndex].PlayerName, XL, YL);
	}
	IndividualCaptionFont = Canvas.Font;
	IndividualItemFont = GetSmallFontFor(Canvas.ClipX, 1);

	// determine vs stats area dimensions
	VsStatsLeft   = Canvas.ClipX * VsStatsAreaLeft + AreaPadding * ResScale;
	VsStatsTop    = Canvas.ClipY * VsStatsAreaTop  + AreaPadding * ResScale;
	VsStatsWidth  = IndividualStatsLeft - VsStatsLeft - Canvas.ClipX * VsStatsAreaspacing - 2 * AreaPadding * ResScale;
	VsStatsHeight = Canvas.ClipY * VsStatsAreaMaxHeight - 2 * AreaPadding * ResScale;

	// determine player font size
	FontReduction = 0;
	Canvas.Font = HudClass.static.GetMediumFontFor(Canvas);
	Canvas.StrLen("000", XL, YL);
	VsStatsNameSize = MaxNameLength * XL / 3;
	while (FontReduction < 5 && (PRIs.Length * (XL + (2 * ItemPadding + ItemSpacing) * ResScale) > VsStatsWidth - VsStatsNameSize || PRIs.Length * (YL + (2 * ItemPadding + ItemSpacing) * ResScale) > VsStatsHeight - VsStatsNameSize)) {
		Canvas.Font = GetSmallerFontFor(Canvas, ++FontReduction);
		Canvas.StrLen("000", XL, YL);
		VsStatsNameSize = MaxNameLength * XL / 3;
	}
	VsFont = Canvas.Font;

	VsStatsCellWidth   = XL + 2 * ItemPadding * ResScale;
	VsStatsCellHeight  = YL + 2 * ItemPadding * ResScale;
	VsStatsCellSpacing = ItemSpacing * ResScale;

	// determine actual vs stats area height and number of drawn rows
	NumFitting = (VsStatsHeight - VsStatsNameSize) / (VsStatsCellHeight + VsStatsCellSpacing);
	if (NumFitting >= PRIs.Length) {
		NumDrawnRows = PRIs.Length;
		NumFitting   = NumDrawnRows;
	}
	else {
		NumDrawnRows = NumFitting; // rounded down
		NumFitting   = NumDrawnRows;
	}
	VsStatsHeight = VsStatsNameSize + VsStatsCellHeight * NumFitting + VsStatsCellSpacing * NumFitting;

	// determine actual vs stats area width and number of drawn columns
	NumFitting = (VsStatsWidth - VsStatsNameSize) / (VsStatsCellWidth + VsStatsCellSpacing);
	if (NumFitting >= PRIs.Length) {
		NumDrawnColumns = PRIs.Length;
		NumFitting      = NumDrawnColumns;
	}
	else {
		NumDrawnColumns = NumFitting; // rounded down
		NumFitting      = NumDrawnColumns;
	}
	VsStatsWidth = VsStatsNameSize + VsStatsCellWidth * NumFitting + VsStatsCellSpacing * NumFitting;

	// figure out first row index
	if (NumDrawnRows == PRIs.Length)
		FirstRowIndex = 0;
	else
		FirstRowIndex = (PRIs.Length + CurrentPlayerIndex - (NumDrawnRows + 1) / 2) % PRIs.Length;

	// figure out first column index
	if (NumDrawnColumns == PRIs.Length)
		FirstColumnIndex = 0;
	else
		FirstColumnIndex = (PRIs.Length + CurrentListIndex - (NumDrawnColumns + 1) / 2) % PRIs.Length;
}


function DrawVsStats()
{
	local int i, j, StatIndex, RowIndex, ColumnIndex;
	local string VsStat;
	local float XL, YL, DaggerXL, DaggerYL;
	local bool bShowBetrayals;

	Canvas.DrawColor = AreaBGColor;
	class'BetrayalHud'.static.DrawBox(
		Canvas,
		BGMaterial,
		VsStatsLeft - AreaPadding * ResScale,
		VsStatsTop  - AreaPadding * ResScale,
		VsStatsWidth  + 2 * AreaPadding * ResScale,
		VsStatsHeight + 2 * AreaPadding * ResScale,
		AreaBGScale * ResScale,
		AreaBGScale * ResScale);

	Canvas.DrawColor = ItemBGColor;
	for (i = 0; i < NumDrawnRows; i++) {
		for (j = 0; j < NumDrawnColumns; j++) {
			RowIndex = (FirstRowIndex + i) % PRIs.Length;
			ColumnIndex = (FirstColumnIndex + j) % PRIs.Length;
			if (RowIndex != ColumnIndex) {
				class'BetrayalHud'.static.DrawBox(
					Canvas,
					BGMaterial,
					VsStatsLeft + VsStatsNameSize + j * (VsStatsCellWidth + VsStatsCellSpacing),
					VsStatsTop  + VsStatsNameSize + i * (VsStatsCellHeight + VsStatsCellSpacing),
					VsStatsCellWidth,
					VsStatsCellHeight,
					AreaBGScale * ResScale,
					AreaBGScale * ResScale);
			}
		}
	}

	bShowBetrayals = bCanShowBetrayals && Level.TimeSeconds % 10.0 > 5;
	Canvas.Font = VsFont;
	Canvas.DrawColor = ItemTextColor;
	Canvas.SetPos(VsStatsLeft + 0.5 * VsStatsNameSize, VsStatsTop + 0.5 * VsStatsNameSize);
	DrawCaptionTexture(1.0, Canvas.Font, VsStatsNameSize * 1.41421, VsStatsNameSize, Eval(bShowBetrayals, BetrayedCaption, KilledCaption));
	for (i = 0; i < NumDrawnRows; i++) {
		RowIndex = (FirstRowIndex + i) % PRIs.Length;
		if (RowIndex == CurrentPlayerIndex)
			Canvas.DrawColor = SelectedTextColor;
		else
			Canvas.DrawColor = ItemTextColor;
		Canvas.SetPos(VsStatsLeft + VsStatsNameSize - ItemPadding * ResScale, VsStatsTop + VsStatsNameSize + i * (VsStatsCellHeight + VsStatsCellSpacing) + 0.5 * VsStatsCellHeight - ItemPadding * ResScale);
		PRIs[(FirstRowIndex + i) % PRIs.Length].DrawNameTexture(Canvas, 1.0, Canvas.Font, VsStatsNameSize * VsStatsNameMaxScale, VsStatsNameSize - ItemPadding * ResScale, False);
	}
	for (i = 0; i < NumDrawnColumns; i++) {
		ColumnIndex = (FirstColumnIndex + i) % PRIs.Length;
		if (ColumnIndex == CurrentPlayerIndex)
			Canvas.DrawColor = SelectedTextColor;
		else
			Canvas.DrawColor = ItemTextColor;
		Canvas.SetPos(VsStatsLeft + VsStatsNameSize + i * (VsStatsCellWidth + VsStatsCellSpacing) + 0.5 * VsStatsCellWidth - ItemPadding * ResScale, VsStatsTop + VsStatsNameSize - ItemPadding * ResScale);
		PRIs[(FirstColumnIndex + i) % PRIs.Length].DrawNameTexture(Canvas, 1.0, Canvas.Font, VsStatsNameSize * VsStatsNameMaxScale, VsStatsNameSize - ItemPadding * ResScale, True);
	}

	DaggerXL = VsStatsCellHeight * (DaggerIconCoords.X2 - DaggerIconCoords.X1) / (DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
	DaggerYL = VsStatsCellHeight;
	for (i = 0; i < NumDrawnRows; i++) {
		for (j = 0; j < NumDrawnColumns; j++) {
			RowIndex = (FirstRowIndex + i) % PRIs.Length;
			ColumnIndex = (FirstColumnIndex + j) % PRIs.Length;

			StatIndex = PRIs[ColumnIndex].FindStatIndex(PRIs[RowIndex].PlayerID);

			if (bShowBetrayals)
				VsStat = string(PRIs[ColumnIndex].VehicleStatsArray[StatIndex].Deaths);
			else
				VsStat = string(PRIs[ColumnIndex].VehicleStatsArray[StatIndex].Kills);

			if (bShowBetrayals && VsStat != "0") {
				Canvas.DrawColor = class'Hud'.default.WhiteColor;
				Canvas.SetPos(VsStatsLeft + VsStatsNameSize + j * (VsStatsCellWidth + VsStatsCellSpacing),
					VsStatsTop + VsStatsNameSize + i * (VsStatsCellHeight + VsStatsCellSpacing));
				Canvas.DrawTile(DaggerIcon,
					DaggerXL, DaggerYL,
					DaggerIconCoords.X1, DaggerIconCoords.Y1,
					DaggerIconCoords.X2 - DaggerIconCoords.X1, DaggerIconCoords.Y2 - DaggerIconCoords.Y1);
			}
			if (VsStat == "0") {
				VsStat = Eval(bShowBetrayals && RowIndex == ColumnIndex, "", "-");
				Canvas.DrawColor = InactiveTextColor;
			}
			else {
				Canvas.DrawColor = ItemTextColor;
			}
			if (ColumnIndex == CurrentPlayerIndex || RowIndex == CurrentPlayerIndex) {
				Canvas.DrawColor = SelectedTextColor;
			}
			if (bShowBetrayals && VsStat != "0") {
				Canvas.StrLen(VsStat, XL, YL);
				Canvas.SetPos(VsStatsLeft + VsStatsNameSize + j * (VsStatsCellWidth + VsStatsCellSpacing) + 0.5 * (VsStatsCellWidth + DaggerXL - XL),
					VsStatsTop + VsStatsNameSize + i * (VsStatsCellHeight + VsStatsCellSpacing) + 0.5 * (VsStatsCellHeight - YL));
			}
			else {
				Canvas.StrLen(VsStat, XL, YL);
				Canvas.SetPos(VsStatsLeft + VsStatsNameSize + j * (VsStatsCellWidth + VsStatsCellSpacing) + 0.5 * (VsStatsCellWidth - XL),
					VsStatsTop + VsStatsNameSize + i * (VsStatsCellHeight + VsStatsCellSpacing) + 0.5 * (VsStatsCellHeight - YL));
			}
			Canvas.DrawText(VsStat);
		}
	}
}

function DrawIndividualStats()
{
	local float XL, YL, XPos, XPosRight, YPos, AreaHeight;
	local BetrayalGRI BGRI;
	local BetrayalPRI PRI;
	local string StatString;
	local int i, NumSprees, NumMultiKills, MultiKills;
	local bool bAnyAwards;

	PRI = PRIs[CurrentPlayerIndex];
	BGRI = BetrayalGRI(GRI);

	Canvas.Font = IndividualItemFont;
	Canvas.TextSize("X", XL, YL);

	AreaHeight = IndividualCaptionHeight + ItemSpacing * ResScale + 2 * AreaPadding * ResScale;
	AreaHeight += 6 * (YL + 2 * ItemPadding * ResScale);

	if (PRI.bFirstBlood) {
		bAnyAwards = True;
		AreaHeight += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	for (i = 0; i < ArrayCount(PRI.Spree); i++) {
		if (PRI.Spree[i] > 0)
			NumSprees++;
	}
	if (NumSprees > 0) {
		bAnyAwards = True;
		AreaHeight += NumSprees * YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	for (i = 0; i < ArrayCount(PRI.MultiKills) - int(class'PlayerController'.default.bNoMatureLanguage); i++) {
		if (PRI.MultiKills[i] > 0 || class'PlayerController'.default.bNoMatureLanguage && i == ArrayCount(PRI.MultiKills) - 2 && PRI.MultiKills[i + 1] > 0)
			NumMultiKills++;
	}
	if (PRI.BestMultiKillLevel > 7 - int(class'PlayerController'.default.bNoMatureLanguage)) {
		NumMultiKills++; // reserve one for "Best: HOLY SHIT!! +x"
	}
	if (NumMultiKills > 0) {
		bAnyAwards = True;
		AreaHeight += NumMultiKills * YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.MultiHits > 0) {
		bAnyAwards = True;
		AreaHeight += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.HeadCount >= 15) {
		bAnyAwards = True;
		AreaHeight += 2 * YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}
	else if (PRI.HeadCount > 0) {
		bAnyAwards = True;
		AreaHeight += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.EagleEyes > 0) {
		bAnyAwards = True;
		AreaHeight += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (bAnyAwards)
		AreaHeight += YL;

	Canvas.DrawColor = AreaBGColor;
	class'BetrayalHud'.static.DrawBox(
		Canvas, BGMaterial,
		IndividualStatsLeft - AreaPadding * ResScale, IndividualStatsTop - AreaPadding * ResScale,
		IndividualStatsWidth + 2 * AreaPadding * ResScale, AreaHeight,
		AreaBGScale * ResScale, AreaBGScale * ResScale);

	Canvas.DrawColor = ItemBGColor;
	YPos = IndividualStatsTop + IndividualCaptionHeight + ItemSpacing * ResScale;

	for (i = 0; i < 6; i++) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += YL + 2 * ItemPadding * ResScale;
	}
	YPos += YL;

	if (PRI.bFirstBlood) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (NumSprees > 0) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, NumSprees * YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += NumSprees * YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (NumMultiKills > 0) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, NumMultiKills * YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += NumMultiKills * YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.MultiHits > 0) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.HeadCount >= 15) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, 2 * YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += 2 * YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}
	else if (PRI.HeadCount > 0) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.EagleEyes > 0) {
		class'BetrayalHud'.static.DrawBox(
			Canvas, BGMaterial,
			IndividualStatsLeft, YPos,
			IndividualStatsWidth, YL + 2 * ItemPadding * ResScale,
			ItemBGScale * ResScale, ItemBGScale * ResScale);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	Canvas.DrawColor = HeaderTextColor;
	Canvas.Font = IndividualCaptionFont;
	Canvas.TextSize(PRI.PlayerName, XL, YL);
	Canvas.SetPos(IndividualStatsLeft + 0.5 * (IndividualStatsWidth - XL), IndividualStatsTop + 0.5 * (IndividualCaptionHeight - YL));
	Canvas.DrawText(PRI.PlayerName);

	Canvas.DrawColor = ItemTextColor;
	Canvas.Font = IndividualItemFont;
	Canvas.TextSize("X", XL, YL);

	XPos = IndividualStatsLeft + ItemPadding * ResScale;
	YPos = IndividualStatsTop + IndividualCaptionHeight + (ItemSpacing + ItemPadding) * ResScale;
	XPosRight = IndividualStatsLeft + IndividualStatsWidth - ItemPadding * ResScale;


	Canvas.SetPos(XPos, YPos);
	if (GRI.ElapsedTime - PRI.StartTime > 0) {
		StatString = (GRI.ElapsedTime - PRI.StartTime) / 60 $ ":" $ Right(100 + (GRI.ElapsedTime - PRI.StartTime) % 60, 2)
				@ "(" $ PPHString @ int(PRI.Score) * 3600 / (GRI.ElapsedTime - PRI.StartTime) $ ")";
	}
	else {
		StatString = "0:00 (" $ PPHString @ "---)";
	}
	Canvas.TextSize(StatString, XL, YL);
	Canvas.DrawText(TimePlayedString);
	Canvas.SetPos(XPosRight - XL, YPos);
	Canvas.DrawText(StatString);
	YPos += YL + 2 * ItemPadding * ResScale;

	Canvas.SetPos(XPos, YPos);
	if (PRI.RepKills + PRI.Deaths > 0) {
		StatString = 100 * PRI.RepKills / (PRI.RepKills + int(PRI.Deaths)) $ "% (" $ PRI.RepKills $ "/" $ int(PRI.Deaths) $ ")";
	}
	else {
		StatString = "--- (0/0)";
	}
	Canvas.TextSize(StatString, XL, YL);
	Canvas.DrawText(EfficiencyString);
	Canvas.SetPos(XPosRight - XL, YPos);
	Canvas.DrawText(StatString);
	YPos += YL + 2 * ItemPadding * ResScale;

	Canvas.SetPos(XPos, YPos);
	if (PRI.Shots > 0) {
		StatString = 100 * PRI.Hits / PRI.Shots $ "% (" $ PRI.Hits $ "/" $ PRI.Shots $ ")";
	}
	else {
		StatString = "--- (0/0)";
	}
	Canvas.TextSize(StatString, XL, YL);
	Canvas.DrawText(AccuracyString);
	Canvas.SetPos(XPosRight - XL, YPos);
	Canvas.DrawText(StatString);
	YPos += YL + 2 * ItemPadding * ResScale;

	Canvas.SetPos(XPos, YPos);
	StatString = string(PRI.TotalPotStolen);
	Canvas.TextSize(StatString, XL, YL);
	Canvas.DrawText(PotStolenString);
	Canvas.SetPos(XPosRight - XL, YPos);
	Canvas.DrawText(StatString);
	YPos += YL + 2 * ItemPadding * ResScale;

	Canvas.SetPos(XPos, YPos);
	StatString = PRI.RetributionCount $ "/" $ PRI.BetrayedCount;
	Canvas.TextSize(StatString, XL, YL);
	Canvas.DrawText(RetributionString);
	Canvas.SetPos(XPosRight - XL, YPos);
	Canvas.DrawText(StatString);
	YPos += YL + 2 * ItemPadding * ResScale;

	Canvas.SetPos(XPos, YPos);
	StatString = PRI.PaybackCount $ "/" $ PRI.BetrayalCount;
	Canvas.TextSize(StatString, XL, YL);
	Canvas.DrawText(PaybackString);
	Canvas.SetPos(XPosRight - XL, YPos);
	Canvas.DrawText(StatString);
	YPos += YL + 2 * ItemPadding * ResScale;

	// spacer before awards
	YPos += YL;

	if (PRI.bFirstBlood) {
		Canvas.SetPos(XPos, YPos);
		Canvas.DrawText(class'DMStatsScreen'.default.FirstBloodString);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (NumSprees > 0) {
		for (i = 0; i < ArrayCount(PRI.Spree); i++) {
			if (PRI.Spree[i] > 0) {
				StatString = class'KillingSpreeMessage'.default.SelfSpreeNote[i];
				if (PRI.Spree[i] > 1)
					StatString @= "x" $ PRI.Spree[i];
				Canvas.SetPos(XPos, YPos);
				Canvas.DrawText(StatString);
				YPos += YL;
			}
		}
		YPos += (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (NumMultiKills > 0) {
		for (i = 0; i < ArrayCount(PRI.MultiKills) - int(class'PlayerController'.default.bNoMatureLanguage); i++) {
			MultiKills = PRI.MultiKills[i];
			if (class'PlayerController'.default.bNoMatureLanguage && i == ArrayCount(PRI.MultiKills) - 2) {
				MultiKills += PRI.MultiKills[i + 1]; // holy shit disabled, merge into ludicrous kill
			}
			if (MultiKills > 0) {
				StatString = class'DMStatsScreen'.default.KillString[i];
				if (MultiKills > 1)
					StatString @= "x" $ MultiKills;
				Canvas.SetPos(XPos, YPos);
				Canvas.DrawText(StatString);
				YPos += YL;
			}
		}
		if (PRI.BestMultiKillLevel > 7 - int(class'PlayerController'.default.bNoMatureLanguage)) {
			// draw best multi kill level beyond holy shit
			i = ArrayCount(PRI.MultiKills) - 1 - int(class'PlayerController'.default.bNoMatureLanguage);
			StatString = BestPrefixString $ class'DMStatsScreen'.default.KillString[i] @ "+" $ PRI.BestMultiKillLevel - i - 1;

			Canvas.SetPos(XPos, YPos);
			Canvas.DrawText(StatString);
			YPos += YL;
		}
		YPos += (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.MultiHits > 0) {
		Canvas.SetPos(XPos, YPos);
		StatString = MultiHitString;
		if (PRI.MultiHits > 1) {
			StatString @= "x" $ PRI.MultiHits @ "(" $ BestPrefixString @ PRI.BestMultiHit $ ")";
		}
		else {
			StatString @= "(" $ PRI.BestMultiHit $ ")";
		}
		Canvas.DrawText(StatString);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.HeadCount > 0) {
		Canvas.SetPos(XPos, YPos);
		StatString = class'SpecialKillMessage'.default.DecapitationString;
		if (PRI.HeadCount > 1)
			StatString @= "x" $ PRI.HeadCount;
		Canvas.DrawText(StatString);
		if (PRI.HeadCount >= 15) {
			YPos += YL;
			Canvas.SetPos(XPos, YPos);
			Canvas.DrawText(class'DMStatsScreen'.default.HeadHunter);
		}
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}

	if (PRI.EagleEyes > 0) {
		Canvas.SetPos(XPos, YPos);
		StatString = class'BetrayalSpecialKillMessage'.default.EagleEyeString;
		if (PRI.EagleEyes > 1)
			StatString @= "x" $ PRI.EagleEyes;
		Canvas.DrawText(StatString);
		YPos += YL + (ItemSpacing + 2 * ItemPadding) * ResScale;
	}
}


// because float % float = float may be inaccurate
static final operator(18) int % (int A, int B)
{
	return A - (A / B) * B;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	HUDClass = class'BetrayalHud'
	bDisplayMessages = True
	bAlwaysTick = True

	TimePlayedString   = "Time played"
	PPHString          = "PPH"
	EfficiencyString   = "Efficiency"
	AccuracyString     = "Accuracy"
	RetributionString  = "Retribution"
	PaybackString      = "Payback"
	PotStolenString    = "Total pot stolen"
	MultiHitString     = "Multi Hit"
	BestPrefixString   = "Best: "
	KilledCaption      = "killed"
	BetrayedCaption    = "betrayed"

	VsStatsAreaLeft      = 0.03
	VsStatsAreaTop       = 0.05
	VsStatsAreaSpacing   = 0.02
	VsStatsAreaMaxHeight = 0.8
	VsStatsNameMaxScale  = 1.5

	IndividualStatsAreaRight     = 0.97
	IndividualStatsAreaTop       = 0.05
	IndividualStatsAreaMaxWidth  = 0.4 // of height!
	IndividualStatsAreaMaxHeight = 0.9

	BGMaterial  = Texture'RoundedBox'
	AreaBGColor = (R=32,G=32,B=32,A=128)
	AreaBGScale = 0.25
	AreaPadding = 4.0

	ItemBGColor = (R=0,G=0,B=0,A=128)
	ItemBGScale = 0.125
	ItemPadding = 2.0
	ItemSpacing = 1.0

	DaggerIcon       = Texture'BetrayalIcons'
	DaggerIconCoords = (X1=0,Y1=35,X2=15,Y2=62)

	CaptionArrowIcon       = Texture'BetrayalIcons'
	CaptionArrowIconCoords = (X1=16,Y1=36,X2=64,Y2=60)

	HeaderTextColor   = (R=255,G=255,B=255,A=255)
	ItemTextColor     = (R=192,G=192,B=192,A=255)
	SelectedTextColor = (R=255,G=255,B=128,A=255)
	LocalTextColor    = (R=192,G=192,B=96,A=255)
	InactiveTextColor = (R=128,G=128,B=128,A=128)
}

