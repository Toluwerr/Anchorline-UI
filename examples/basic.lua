local Anchorline = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Anchorline-UI/refs/heads/main/main.lua"))()

local Window = Anchorline:CreateWindow({
    Title = "Anchorline UI",
    Subtitle = "Basic Example",
    Theme = "Workbench",
    ToggleKey = Enum.KeyCode.RightShift
})

local MainTab = Window:CreateTab("Main", "home", "Main controls")

MainTab:CreateSection("Simple Controls")

MainTab:CreateLabel("This is a small example using Anchorline UI.")

MainTab:CreateButton({
    Name = "Say Hello",
    Description = "Prints a message in the console.",
    ButtonText = "Click",
    Callback = function()
        print("Hello from Anchorline UI")
    end
})

MainTab:CreateToggle({
    Name = "Example Toggle",
    Description = "Turns a test value on or off.",
    CurrentValue = false,
    Flag = "ExampleToggle",
    Callback = function(value)
        print("Toggle value:", value)
    end
})

MainTab:CreateSlider({
    Name = "Example Slider",
    Description = "Changes a test number.",
    Range = {0, 100},
    CurrentValue = 50,
    Increment = 1,
    Suffix = "%",
    Flag = "ExampleSlider",
    Callback = function(value)
        print("Slider value:", value)
    end
})

Window:Notify({
    Title = "Ready",
    Content = "Anchorline UI loaded.",
    Duration = 4
})
