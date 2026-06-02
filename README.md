# Anchorline UI

Anchorline UI is a clean Roblox interface library for making script menus that look organized and easy to use.

It gives you a simple way to create windows, tabs, buttons, toggles, sliders, dropdowns, text boxes, keybinds, color pickers, labels, paragraphs, sections, dividers, prompts, notifications, and more.

The main goal is to help your Roblox tools look finished instead of messy. You create a window, add tabs, place your controls, and connect each control to your own code.

Use Anchorline UI in your own Roblox projects, test places, or places where you have permission to run custom scripts.

## Load the library

```lua
local Anchorline = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Anchorline-UI/refs/heads/main/main.lua"))()
```

## Create a window

```lua
local Window = Anchorline:CreateWindow({
    Title = "Anchorline UI",
    Subtitle = "Example Interface",
    Theme = "Workbench",
    ToggleKey = Enum.KeyCode.RightShift
})
```

The toggle key hides and shows the window.

## Create a tab

```lua
local MainTab = Window:CreateTab("Main", "home", "Main controls")
```

Tabs help you keep your menu organized. You can make one tab for main controls, one tab for settings, one tab for visuals, and so on.

## Add a section

```lua
MainTab:CreateSection("Main Controls")
```

Sections are useful when you want to group controls together.

## Add a button

```lua
MainTab:CreateButton({
    Name = "Run Action",
    Description = "Runs a simple test action.",
    ButtonText = "Run",
    Callback = function()
        print("Button clicked")
    end
})
```

Buttons are best for actions that happen once.

## Add a toggle

```lua
MainTab:CreateToggle({
    Name = "Enable Feature",
    Description = "Turns a feature on or off.",
    CurrentValue = false,
    Flag = "FeatureEnabled",
    Callback = function(value)
        print("Feature enabled:", value)
    end
})
```

Toggles are best for settings that stay on or off.

## Add a slider

```lua
MainTab:CreateSlider({
    Name = "Speed",
    Description = "Changes a number value.",
    Range = {0, 100},
    CurrentValue = 25,
    Increment = 1,
    Suffix = "%",
    Flag = "SpeedValue",
    Callback = function(value)
        print("Speed:", value)
    end
})
```

Sliders are best for number values.

## Add a dropdown

```lua
MainTab:CreateDropdown({
    Name = "Mode",
    Description = "Choose one option.",
    Options = {"Normal", "Fast", "Safe"},
    CurrentOption = "Normal",
    Flag = "SelectedMode",
    Callback = function(option)
        print("Selected mode:", option)
    end
})
```

Dropdowns are best when the user needs to pick from a list.

## Add a text box

```lua
MainTab:CreateInput({
    Name = "Username",
    Description = "Type a name or value.",
    PlaceholderText = "Enter text here",
    CurrentValue = "",
    Flag = "UsernameInput",
    Callback = function(text)
        print("Text entered:", text)
    end
})
```

Text boxes are best for custom text values.

## Add a keybind

```lua
MainTab:CreateKeybind({
    Name = "Quick Action",
    Description = "Press the selected key to run an action.",
    CurrentKeybind = Enum.KeyCode.F,
    Flag = "QuickActionKey",
    Callback = function()
        print("Keybind pressed")
    end
})
```

Keybinds let the user run something from the keyboard.

## Add a color picker

```lua
MainTab:CreateColorPicker({
    Name = "Accent Color",
    Description = "Choose a color.",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "AccentColor",
    Callback = function(color)
        print("Color changed:", color)
    end
})
```

Color pickers are useful when your tool needs a custom color.

## Add text

```lua
MainTab:CreateLabel("This is a simple label.")

MainTab:CreateParagraph({
    Title = "About this tab",
    Content = "This area explains what the controls are for."
})
```

Labels and paragraphs help explain your menu to the person using it.

## Add a notification

```lua
Window:Notify({
    Title = "Anchorline UI",
    Content = "The interface loaded successfully.",
    Duration = 4
})
```

Notifications are useful for small messages.

## Save and load settings

If you use flags on your controls, you can save and load the values later.

```lua
Window:SaveConfig("default")
Window:LoadConfig("default")
```

Not every Roblox environment supports local file saving. If saving is not available, the UI will still work, but saved settings may not be stored.

## Full basic example

```lua
local Anchorline = loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Anchorline-UI/refs/heads/main/main.lua"))()

local Window = Anchorline:CreateWindow({
    Title = "Anchorline UI",
    Subtitle = "Basic Example",
    Theme = "Workbench",
    ToggleKey = Enum.KeyCode.RightShift
})

local MainTab = Window:CreateTab("Main", "home", "Main controls")

MainTab:CreateSection("Controls")

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
    Description = "A simple on and off setting.",
    CurrentValue = false,
    Flag = "ExampleToggle",
    Callback = function(value)
        print("Toggle:", value)
    end
})

MainTab:CreateSlider({
    Name = "Example Slider",
    Range = {0, 100},
    CurrentValue = 50,
    Increment = 1,
    Flag = "ExampleSlider",
    Callback = function(value)
        print("Slider:", value)
    end
})

Window:Notify({
    Title = "Ready",
    Content = "Anchorline UI loaded.",
    Duration = 4
})
```

## Files in this repository

```txt
main.lua
examples/basic.lua
examples/components.lua
examples/dashboard.lua
examples/config.lua
examples/README.md
```

## Notes

Anchorline UI is still being improved. Some controls may change as the library gets updated.

Keep your code simple, name your tabs clearly, and do not put too many controls in one place. A clean menu is easier to use than a packed one.
