local Rsml = require(script.Parent.Packages.Rsml)

local AttributeStyles = Rsml [[!rsml
    @name "AttributeStyles";

    $FontFace = font ("BuilderSans", "SemiBold");
    $TextSize = 14;
    $ColorText = tw:slate:50;
    $ColorPrimary = tw:blue:700;
]]

local ButtonStyles = Rsml([[!rsml
    @defaults;
    @name "ButtonStyles";

    .Button {
        @priority 50;
        AutomaticSize = :XY;
        TextColor3 = $ColorText;
        FontFace = $FontFace;
        TextSize = $TextSize;

        .Primary {
            BackgroundColor3 = $ColorPrimary;
        }
        ::UIPadding {
            PaddingLeft = 10px;
            PaddingRight = 10px;
            PaddingTop = 10px;
            PaddingBottom = 10px;
        }

        ::UICorner {
            CornerRadius = 10px;
            CornerRadius = 50px;
        }
    }
]], { AttributeStyles })



local function CreateButton(
    variant: ("Primary" | "Secondary" | "Destructive")?,
    disabled: boolean?
)
    local button = Instance.new("TextButton")
    button:AddTag("Button")
    button:AddTag(variant or "Primary")
    if disabled then button:AddTag("Disabled") end

    local styleLink = Instance.new("StyleLink")
    styleLink.StyleSheet = ButtonStyles
    styleLink.Parent = button
    
    return button
end

local ScreenGui = Instance.new("ScreenGui")

local Button = CreateButton("Destructive")
Button.Text = "Delete!"
Button.Parent = ScreenGui

ScreenGui.Parent = game:GetService("StarterGui")