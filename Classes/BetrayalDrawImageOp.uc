/******************************************************************************
BetrayalDrawImageOp

Creation date: 2011-03-10 01:33
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalDrawImageOp extends DrawOpImage;


function Draw(Canvas Canvas)
{
	local float X, Y, XL, YL, U, V, UL, VL;

	if (Image == None)
		return;

	Canvas.Style = RenderStyle;
	Canvas.DrawColor = DrawColor;

	X = Lft * Canvas.SizeX;
	Y = Top * Canvas.SizeY;

	if (Width < 0)
		XL = Image.MaterialUSize();
	else
		XL = Width * Canvas.SizeX;

	if (Height < 0)
		YL = Image.MaterialVSize();
	else
		YL = Height * Canvas.SizeY;

	U = FMax(0, SubX);
	V = FMax(0, SubY);

	if (SubXL < 0)
		UL = Image.MaterialUSize();
	else
		UL = SubXL;

	if (SubYL < 0)
		VL = Image.MaterialVSize();
	else
		VL = SubYL;

	if (Justification == 1) {
		X -= XL / 2;
		Y -= YL / 2;
	}
	else if (Justification == 2) {
		X -= XL;
		Y -= YL;
	}

	Canvas.SetPos(X,Y);

	switch (ImageStyle) {
	case 0: // Normal (scaled to fit)
		Canvas.DrawTile(Image, XL, YL, U, V, UL, VL);
		break;

	case 1: // Stretched
		Canvas.DrawTileStretched(Image, XL, YL);
		break;

	case 2: // Bound
		Canvas.DrawTileClipped(Image, XL, YL, U, V, UL, VL);
		break;

	case 3: // partially stretched
		Canvas.DrawTilePartialStretched(Image, XL, YL);
		break;
	}

	//Log("DrawOpImage.Draw Called");
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}

