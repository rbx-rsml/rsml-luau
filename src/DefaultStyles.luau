local LexRsml = require(script.Parent.Lexer)
local ParseRsml = require(script.Parent.Parser)
local ConvertRsml = require(script.Parent.Converter)

-- We have to create an identical Rsml function from 
-- init.luau to prevent circular dependency issues.
local function Rsml(content: string, derives: { StyleSheet }?)
    return ConvertRsml(ParseRsml(LexRsml(content)), derives)
end

--[[
The defaults below were taken from Fusion's source code. License here:
    MIT License

    Copyright (c) 2024 Daniel P H Fox

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

return Rsml [[!rsml
    @name "DefaultStyles";

    ScreenGui {
        @priority -1;
		ResetOnSpawn = false;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	}

	BillboardGui {
        @priority -1;
		ResetOnSpawn = false;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		Active = true
	}

	SurfaceGui {
        @priority -1;
		ResetOnSpawn = false;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud;
		PixelsPerStud = 50
	}

	Frame {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0
	}

	ScrollingFrame {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0;

		ScrollBarImageColor3 = color3 (0, 0, 0)
	}

	TextLabel {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0;

		FontFace = font ("SourceSansPro");
		Text = "";
		TextColor3 = color3 (0, 0, 0);
		TextSize = 14
	}

	TextButton {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0;

		AutoButtonColor = false;

		FontFace = font ("SourceSansPro");
		Text = "";
		TextColor3 = color3 (0, 0, 0);
		TextSize = 14
	}

	TextBox {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0;

		ClearTextOnFocus = false;

		FontFace = font ("SourceSansPro");
		Text = "";
		TextColor3 = color3 (0, 0, 0);
		TextSize = 14
	}

	ImageLabel {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0
	}

	ImageButton {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0;

		AutoButtonColor = false
	}

	ViewportFrame {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0
	}

	VideoFrame {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0
	}
	
	CanvasGroup {
        @priority -1;
		BackgroundColor3 = color3 (1, 1, 1);
		BorderColor3 = color3 (0, 0, 0);
		BorderSizePixel = 0
	}

	SpawnLocation {
        @priority -1;
		Duration = 0
	}

	BoxHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	ConeHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	CylinderHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	ImageHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	LineHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	SphereHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	WireframeHandleAdornment {
        @priority -1;
		ZIndex = 0
	}
	
	Part {
        @priority -1;
		Anchored = true;
		Size = vec3 (1);
		FrontSurface = Enum.SurfaceType.Smooth;
		BackSurface = Enum.SurfaceType.Smooth;
		LeftSurface = Enum.SurfaceType.Smooth;
		RightSurface = Enum.SurfaceType.Smooth;
		TopSurface = Enum.SurfaceType.Smooth;
		BottomSurface = Enum.SurfaceType.Smooth;
	}
	
	TrussPart {
        @priority -1;
		Anchored = true;
		Size = vec3 (2);
		FrontSurface = Enum.SurfaceType.Smooth;
		BackSurface = Enum.SurfaceType.Smooth;
		LeftSurface = Enum.SurfaceType.Smooth;
		RightSurface = Enum.SurfaceType.Smooth;
		TopSurface = Enum.SurfaceType.Smooth;
		BottomSurface = Enum.SurfaceType.Smooth;
	}

	MeshPart {
        @priority -1;
		Anchored = true;
		Size = vec3 (1);
		FrontSurface = Enum.SurfaceType.Smooth;
		BackSurface = Enum.SurfaceType.Smooth;
		LeftSurface = Enum.SurfaceType.Smooth;
		RightSurface = Enum.SurfaceType.Smooth;
		TopSurface = Enum.SurfaceType.Smooth;
		BottomSurface = Enum.SurfaceType.Smooth;
	}

	CornerWedgePart {
        @priority -1;
		Anchored = true;
		Size = vec3 (1);
		FrontSurface = Enum.SurfaceType.Smooth;
		BackSurface = Enum.SurfaceType.Smooth;
		LeftSurface = Enum.SurfaceType.Smooth;
		RightSurface = Enum.SurfaceType.Smooth;
		TopSurface = Enum.SurfaceType.Smooth;
		BottomSurface = Enum.SurfaceType.Smooth;
	}

	VehicleSeat {
        @priority -1;
		Anchored = true;
		Size = vec3 (1);
		FrontSurface = Enum.SurfaceType.Smooth;
		BackSurface = Enum.SurfaceType.Smooth;
		LeftSurface = Enum.SurfaceType.Smooth;
		RightSurface = Enum.SurfaceType.Smooth;
		TopSurface = Enum.SurfaceType.Smooth;
		BottomSurface = Enum.SurfaceType.Smooth;
	}
]]