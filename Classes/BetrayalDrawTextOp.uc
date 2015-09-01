/******************************************************************************
BetrayalDrawTextOp

Creation date: 2011-03-13 12:28
Last change: $Id$
Copyright © 2011, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class BetrayalDrawTextOp extends DrawOpText;


var DrawOpText Source;


function Draw(Canvas Canvas)
{
	local Font Fnt;
	local float X, Y, XL, YL, StrHeight, StrWidth;

	if (Source != None)
		Text = Source.Text;

	Super(DrawOpBase).Draw(Canvas);

	if (FontName != "") {
		Fnt = GetFont(FontName, Canvas.SizeX);
		if (Fnt != None)
			Canvas.Font = Fnt;
	}

	Canvas.FontScaleX = 0.9;
	Canvas.FontScaleY = 0.9;

	X = Lft * Canvas.SizeX;
	Y = Top * Canvas.SizeY;
	XL = Width * Canvas.SizeX;
	YL = Height * Canvas.SizeY;

	Canvas.SetOrigin(X, 0);
	Canvas.SetClip(XL, Canvas.SizeY);

	Canvas.StrLen(Text, StrWidth, StrHeight);

	switch (VertAlign) {
	case 1: // Center
		Y += (YL - StrHeight) / 2;
		break;

	case 2: // Bottom
		Y += YL - StrHeight;
		break;
	}

	switch (Justification) {
	case 0: // left
		X = 0;
		break;

	case 1: // center
		X = (XL - StrWidth) / 2;
		break;

	case 2: // right
		X = XL - StrWidth;
		break;
	}
	Canvas.SetPos(X, Y);
	Canvas.DrawText(Text);

	Canvas.SetOrigin(0, 0);
	Canvas.SetClip(Canvas.SizeX, Canvas.SizeY);
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}

