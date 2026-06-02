local Anchorline = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Anchorline-UI/refs/heads/main/main.lua"))()

local Window = Anchorline:CreateWindow({
    Title = "Anchorline UI",
    Subtitle = "Dashboard Example",
    Theme = "Workbench",
    ToggleKey = Enum.KeyCode.RightShift
})

local DashboardTab = Window:CreateTab("Dashboard", "activity", "Overview")
local SettingsTab = Window:CreateTab("Settings", "settings", "Options")

DashboardTab:CreateSection("Status")

DashboardTab:CreateBadge({
    Name = "Library Status",
    Value = "Loaded",
    Description = "Current state"
})

DashboardTab:CreateStatCard({
    Name = "Controls Added",
    Value = "8",
    Caption = "Example controls in this demo",
    Badge = "Demo"
})

DashboardTab:CreateInfoBox({
    Title = "Welcome",
    Content = "This example shows how a simple dashboard can be built with Anchorline UI.",
    Type = "Success"
})

DashboardTab:CreateSection("Actions")

DashboardTab:CreateActionGrid({
    Name = "Quick Actions",
    Description = "Small actions grouped together.",
    Actions = {
        {
            Name = "Print Ready",
            Callback = function()
                print("Ready")
            end
        },
        {
            Name = "Print Time",
            Callback = function()
                print("Current time:", os.time())
            end
        },
        {
            Name = "Notify",
            Callback = function()
                Window:Notify({
                    Title = "Dashboard",
                    Content = "Action clicked.",
                    Duration = 3
                })
            end
        }
    }
})

SettingsTab:CreateSection("Menu Settings")

SettingsTab:CreateToggle({
    Name = "Show Extra Details",
    Description = "Example setting for a dashboard.",
    CurrentValue = true,
    Flag = "ShowExtraDetails",
    Callback = function(value)
        print("Show extra details:", value)
    end
})

SettingsTab:CreateDropdown({
    Name = "Theme Mode",
    Description = "Choose a sample mode.",
    Options = {"Clean", "Compact", "Detailed"},
    CurrentOption = "Clean",
    Flag = "ThemeMode",
    Callback = function(value)
        print("Theme mode:", value)
    end
})

SettingsTab:CreateSlider({
    Name = "Panel Size",
    Description = "Example size value.",
    Range = {50, 150},
    CurrentValue = 100,
    Increment = 5,
    Suffix = "%",
    Flag = "PanelSize",
    Callback = function(value)
        print("Panel size:", value)
    end
})

Window:Notify({
    Title = "Dashboard Ready",
    Content = "The dashboard example loaded.",
    Duration = 4
})
