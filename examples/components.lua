local Anchorline = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Anchorline-UI/refs/heads/main/main.lua"))()

local Window = Anchorline:CreateWindow({
    Title = "Anchorline UI",
    Subtitle = "Components Example",
    Theme = "Workbench",
    ToggleKey = Enum.KeyCode.RightShift
})

local ControlsTab = Window:CreateTab("Controls", "sliders", "Common controls")
local TextTab = Window:CreateTab("Text", "file-text", "Text and info")

ControlsTab:CreateSection("Buttons")

ControlsTab:CreateButton({
    Name = "Run Action",
    Description = "Runs a simple callback.",
    ButtonText = "Run",
    Callback = function()
        print("Action ran")
    end
})

ControlsTab:CreateSection("Values")

ControlsTab:CreateToggle({
    Name = "Enabled",
    Description = "Example on and off value.",
    CurrentValue = true,
    Flag = "EnabledValue",
    Callback = function(value)
        print("Enabled:", value)
    end
})

ControlsTab:CreateSlider({
    Name = "Amount",
    Description = "Example number value.",
    Range = {1, 10},
    CurrentValue = 5,
    Increment = 1,
    Flag = "AmountValue",
    Callback = function(value)
        print("Amount:", value)
    end
})

ControlsTab:CreateDropdown({
    Name = "Mode",
    Description = "Choose a simple mode.",
    Options = {"Normal", "Fast", "Safe"},
    CurrentOption = "Normal",
    Flag = "ModeValue",
    Callback = function(value)
        print("Mode:", value)
    end
})

ControlsTab:CreateInput({
    Name = "Name Input",
    Description = "Type a value.",
    PlaceholderText = "Type here",
    CurrentValue = "",
    Flag = "NameInput",
    Callback = function(value)
        print("Input:", value)
    end
})

ControlsTab:CreateKeybind({
    Name = "Print Keybind",
    Description = "Press the key to print a message.",
    CurrentKeybind = Enum.KeyCode.F,
    Flag = "PrintKeybind",
    Callback = function()
        print("Keybind pressed")
    end
})

ControlsTab:CreateColorPicker({
    Name = "Accent Color",
    Description = "Pick a color value.",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "AccentColor",
    Callback = function(color)
        print("Color:", color)
    end
})

TextTab:CreateSection("Text")

TextTab:CreateLabel("Labels are good for short notes.")

TextTab:CreateParagraph({
    Title = "Paragraph",
    Content = "Paragraphs are better when you need to explain something with more detail."
})

TextTab:CreateDivider()

TextTab:CreateInfoBox({
    Title = "Info Box",
    Content = "Use info boxes for important messages.",
    Type = "Info"
})

Window:Notify({
    Title = "Example Loaded",
    Content = "The components example is ready.",
    Duration = 4
})
