local Anchorline = {}
Anchorline.__index = Anchorline
Anchorline.Name = "Anchorline UI"
Anchorline.Version = "2.8.0"
Anchorline.Flags = {}
Anchorline.Windows = {}
Anchorline.IconAliases = {
	["📊"] = "bar-chart",
	["📈"] = "bar-chart",
	["📉"] = "bar-chart",
	["⚙"] = "settings",
	["⚙️"] = "settings",
	["🏠"] = "home",
	["👁"] = "eye",
	["👁️"] = "eye",
	["🎯"] = "target",
	["🛡"] = "shield",
	["🛡️"] = "shield",
	["⚡"] = "bolt",
	["📁"] = "folder",
	["📂"] = "folder",
	["📚"] = "book",
	["📖"] = "book",
	["ℹ"] = "info",
	["ℹ️"] = "info",
	["✅"] = "check",
	["✓"] = "check",
	["❌"] = "x",
	["✕"] = "x",
	["⚠"] = "warning",
	["⚠️"] = "warning",
	["💻"] = "code",
	["⌨"] = "code",
	["⌨️"] = "code",
	["🔔"] = "bell",
	["🧪"] = "test",
	["🧰"] = "toolbox"
}
Anchorline.Motion = {
	Micro = 0.14,
	Fast = 0.24,
	Base = 0.38,
	Panel = 0.5,
	Exit = 0.3
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local function safeCall(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end
	local ok, result = pcall(callback, ...)
	if not ok then
		warn("Anchorline UI callback error: " .. tostring(result))
	end
	return result
end

local function new(className, properties, children)
	local ok, object = pcall(Instance.new, className)
	if not ok then
		if className == "CanvasGroup" then
			object = Instance.new("Frame")
		else
			error(object, 2)
		end
	end
	if properties then
		local assigned, err = pcall(function()
			for property, value in pairs(properties) do
				object[property] = value
			end
		end)
		if not assigned then
			warn("Anchorline UI property assignment failed on " .. tostring(className) .. ": " .. tostring(err))
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = object
		end
	end
	return object
end

local function tween(object, time, properties, easingStyle, easingDirection)
	if not object or object.Parent == nil then
		return nil
	end
	local info = TweenInfo.new(time or Anchorline.Motion.Base, easingStyle or Enum.EasingStyle.Quint, easingDirection or Enum.EasingDirection.Out)
	local ok, t = pcall(TweenService.Create, TweenService, object, info, properties)
	if ok and t then
		t:Play()
		return t
	end
	for property, value in pairs(properties) do
		pcall(function() object[property] = value end)
	end
	return nil
end

local function corner(radius)
	return new("UICorner", {CornerRadius = UDim.new(0, radius or 8)})
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Color3.fromRGB(60, 64, 72),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	})
end

local function padding(left, right, top, bottom)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or left or 0),
		PaddingTop = UDim.new(0, top or left or 0),
		PaddingBottom = UDim.new(0, bottom or top or left or 0)
	})
end

local function listLayout(direction, paddingAmount, alignment)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, paddingAmount or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left
	})
end

local function measureWrappedText(text, textSize, font, width)
	local safeText = tostring(text or "")
	local safeWidth = math.max(96, tonumber(width) or 260)
	local safeSize = tonumber(textSize) or 13
	local safeFont = font or Enum.Font.Gotham
	if safeText == "" then
		return math.ceil(safeSize * 1.15)
	end
	local ok, measured = pcall(function()
		return TextService:GetTextSize(safeText, safeSize, safeFont, Vector2.new(safeWidth, 100000))
	end)
	if ok and measured then
		return math.max(math.ceil(safeSize * 1.15), math.ceil(measured.Y))
	end
	local approximateLines = math.max(1, math.ceil(#safeText / math.max(20, math.floor(safeWidth / math.max(6, safeSize * 0.52)))))
	return math.ceil(approximateLines * safeSize * 1.35)
end

local function isTyping()
	local focused = UserInputService:GetFocusedTextBox()
	return focused ~= nil
end

local function normalizeKey(key)
	if typeof(key) == "EnumItem" then
		return key
	end
	if type(key) == "string" then
		local cleaned = key:gsub("Enum%.KeyCode%.", "")
		return Enum.KeyCode[cleaned] or Enum.KeyCode.RightShift
	end
	return Enum.KeyCode.RightShift
end

local function colorToTable(color)
	return {
		R = math.floor(color.R * 255 + 0.5),
		G = math.floor(color.G * 255 + 0.5),
		B = math.floor(color.B * 255 + 0.5)
	}
end

local function tableToColor(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "table" then
		local r = tonumber(value.R or value.r or value[1]) or 255
		local g = tonumber(value.G or value.g or value[2]) or 255
		local b = tonumber(value.B or value.b or value[3]) or 255
		return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
	end
	return fallback or Color3.fromRGB(255, 255, 255)
end

local function isRobloxImagePath(value)
	return type(value) == "string" and (
		value:find("^rbxassetid://") ~= nil or
		value:find("^rbxasset://") ~= nil or
		value:find("^rbxthumb://") ~= nil
	)
end

local function normalizeIconName(value)
	if type(value) ~= "string" then
		return ""
	end
	local raw = tostring(value)
	local alias = Anchorline.IconAliases[raw] or Anchorline.IconAliases[raw:lower()]
	if alias then
		return alias
	end
	return raw:lower():gsub("%s+", "-"):gsub("_", "-"):gsub("[^%w%-]", "")
end

local function isNumericAssetString(value)
	return type(value) == "string" and value:match("^%d+$") ~= nil
end

local function setCornerRadius(instance, radius)
	if not instance then return end
	local found = instance:FindFirstChildOfClass("UICorner")
	if found then
		found.CornerRadius = UDim.new(0, radius)
	end
end

local function resolveIconAssetFromTable(value)
	if type(value) ~= "table" then
		return nil
	end
	local image = value.Image or value.Url or value.Asset or value.AssetId or value.Id or value.image or value.asset or value.assetId or value.id
	if typeof(image) == "number" then
		image = "rbxassetid://" .. tostring(image)
	elseif isNumericAssetString(image) then
		image = "rbxassetid://" .. image
	end
	if type(image) ~= "string" or image == "" then
		return nil
	end
	local data = {Image = image}
	if typeof(value.ImageRectOffset) == "Vector2" then
		data.ImageRectOffset = value.ImageRectOffset
	elseif type(value.ImageRectOffset) == "table" then
		data.ImageRectOffset = Vector2.new(value.ImageRectOffset[1] or 0, value.ImageRectOffset[2] or 0)
	end
	if typeof(value.ImageRectSize) == "Vector2" then
		data.ImageRectSize = value.ImageRectSize
	elseif type(value.ImageRectSize) == "table" then
		data.ImageRectSize = Vector2.new(value.ImageRectSize[1] or 0, value.ImageRectSize[2] or 0)
	end
	return data
end

local function findLucideProvider(explicitProvider)
	if type(explicitProvider) == "table" and type(explicitProvider.GetAsset) == "function" then
		return explicitProvider
	end
	if type(Anchorline.IconProvider) == "table" and type(Anchorline.IconProvider.GetAsset) == "function" then
		return Anchorline.IconProvider
	end
	local candidates = {
		ReplicatedStorage:FindFirstChild("Lucide"),
		ReplicatedStorage:FindFirstChild("LucideIcons"),
		ReplicatedStorage:FindFirstChild("lucide-roblox")
	}
	for _, module in ipairs(candidates) do
		if module and module:IsA("ModuleScript") then
			local ok, provider = pcall(require, module)
			if ok and type(provider) == "table" and type(provider.GetAsset) == "function" then
				return provider
			end
		end
	end
	return nil
end

local function fileAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" and type(makefolder) == "function" and type(isfolder) == "function"
end

local function ensureFolder(path)
	if not fileAvailable() then
		return false
	end
	if not isfolder(path) then
		local ok = pcall(makefolder, path)
		return ok
	end
	return true
end

local function resolveParent()
	local gui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if gui then
		return gui
	end
	return CoreGui
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	if camera and typeof(camera.ViewportSize) == "Vector2" then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function clampVectorSize(width, height, minWidth, minHeight, maxWidth, maxHeight)
	local safeMaxWidth = math.max(minWidth, maxWidth)
	local safeMaxHeight = math.max(minHeight, maxHeight)
	return math.clamp(width, minWidth, safeMaxWidth), math.clamp(height, minHeight, safeMaxHeight)
end

Anchorline.Themes = {
	Workbench = {
		Background = Color3.fromRGB(238, 235, 229),
		Panel = Color3.fromRGB(252, 250, 246),
		PanelAlt = Color3.fromRGB(247, 245, 240),
		Surface = Color3.fromRGB(255, 253, 249),
		SurfaceHover = Color3.fromRGB(243, 240, 233),
		Input = Color3.fromRGB(255, 253, 249),
		Stroke = Color3.fromRGB(202, 195, 184),
		StrokeSoft = Color3.fromRGB(225, 219, 208),
		Text = Color3.fromRGB(37, 42, 39),
		TextMuted = Color3.fromRGB(87, 94, 88),
		TextFaint = Color3.fromRGB(132, 139, 131),
		Accent = Color3.fromRGB(92, 122, 108),
		AccentHover = Color3.fromRGB(77, 103, 91),
		AccentSoft = Color3.fromRGB(226, 235, 229),
		AccentText = Color3.fromRGB(255, 253, 249),
		ControlKnob = Color3.fromRGB(255, 253, 249),
		Success = Color3.fromRGB(83, 135, 96),
		Warning = Color3.fromRGB(165, 122, 63),
		Danger = Color3.fromRGB(168, 76, 70),
		Overlay = Color3.fromRGB(73, 68, 62),
		GlassHighlight = Color3.fromRGB(255, 255, 255),
		GlassShade = Color3.fromRGB(221, 216, 205)
	},
	Ledger = {
		Background = Color3.fromRGB(244, 242, 237),
		Panel = Color3.fromRGB(253, 252, 248),
		PanelAlt = Color3.fromRGB(248, 246, 241),
		Surface = Color3.fromRGB(255, 255, 252),
		SurfaceHover = Color3.fromRGB(238, 235, 228),
		Input = Color3.fromRGB(255, 255, 252),
		Stroke = Color3.fromRGB(207, 200, 189),
		StrokeSoft = Color3.fromRGB(226, 221, 213),
		Text = Color3.fromRGB(48, 43, 38),
		TextMuted = Color3.fromRGB(104, 96, 86),
		TextFaint = Color3.fromRGB(145, 136, 125),
		Accent = Color3.fromRGB(130, 94, 63),
		AccentHover = Color3.fromRGB(112, 80, 53),
		AccentSoft = Color3.fromRGB(238, 226, 214),
		AccentText = Color3.fromRGB(255, 252, 247),
		ControlKnob = Color3.fromRGB(255, 252, 247),
		Success = Color3.fromRGB(83, 134, 91),
		Warning = Color3.fromRGB(168, 124, 54),
		Danger = Color3.fromRGB(177, 69, 63),
		Overlay = Color3.fromRGB(68, 62, 55)
	},
	Field = {
		Background = Color3.fromRGB(239, 244, 238),
		Panel = Color3.fromRGB(250, 252, 249),
		PanelAlt = Color3.fromRGB(244, 249, 244),
		Surface = Color3.fromRGB(255, 255, 252),
		SurfaceHover = Color3.fromRGB(230, 239, 231),
		Input = Color3.fromRGB(255, 255, 253),
		Stroke = Color3.fromRGB(196, 210, 198),
		StrokeSoft = Color3.fromRGB(216, 226, 218),
		Text = Color3.fromRGB(34, 46, 38),
		TextMuted = Color3.fromRGB(88, 108, 95),
		TextFaint = Color3.fromRGB(128, 146, 135),
		Accent = Color3.fromRGB(77, 128, 86),
		AccentHover = Color3.fromRGB(64, 112, 74),
		AccentSoft = Color3.fromRGB(221, 236, 224),
		AccentText = Color3.fromRGB(255, 255, 252),
		ControlKnob = Color3.fromRGB(255, 255, 252),
		Success = Color3.fromRGB(67, 139, 88),
		Warning = Color3.fromRGB(162, 124, 54),
		Danger = Color3.fromRGB(174, 66, 60),
		Overlay = Color3.fromRGB(52, 67, 57)
	},
	Harbor = {
		Background = Color3.fromRGB(238, 243, 245),
		Panel = Color3.fromRGB(250, 252, 252),
		PanelAlt = Color3.fromRGB(244, 248, 249),
		Surface = Color3.fromRGB(255, 255, 252),
		SurfaceHover = Color3.fromRGB(228, 237, 241),
		Input = Color3.fromRGB(255, 255, 253),
		Stroke = Color3.fromRGB(194, 207, 213),
		StrokeSoft = Color3.fromRGB(216, 225, 229),
		Text = Color3.fromRGB(34, 42, 47),
		TextMuted = Color3.fromRGB(86, 101, 110),
		TextFaint = Color3.fromRGB(126, 142, 151),
		Accent = Color3.fromRGB(72, 112, 129),
		AccentHover = Color3.fromRGB(59, 97, 113),
		AccentSoft = Color3.fromRGB(219, 232, 237),
		AccentText = Color3.fromRGB(255, 255, 252),
		ControlKnob = Color3.fromRGB(255, 255, 252),
		Success = Color3.fromRGB(69, 137, 101),
		Warning = Color3.fromRGB(164, 122, 55),
		Danger = Color3.fromRGB(174, 66, 60),
		Overlay = Color3.fromRGB(52, 62, 67)
	},
	GraphiteLight = {
		Background = Color3.fromRGB(239, 240, 240),
		Panel = Color3.fromRGB(250, 250, 249),
		PanelAlt = Color3.fromRGB(245, 246, 245),
		Surface = Color3.fromRGB(255, 255, 253),
		SurfaceHover = Color3.fromRGB(234, 236, 235),
		Input = Color3.fromRGB(255, 255, 253),
		Stroke = Color3.fromRGB(201, 205, 204),
		StrokeSoft = Color3.fromRGB(219, 222, 221),
		Text = Color3.fromRGB(38, 42, 43),
		TextMuted = Color3.fromRGB(93, 101, 103),
		TextFaint = Color3.fromRGB(135, 143, 145),
		Accent = Color3.fromRGB(90, 107, 112),
		AccentHover = Color3.fromRGB(76, 93, 98),
		AccentSoft = Color3.fromRGB(226, 231, 232),
		AccentText = Color3.fromRGB(255, 255, 252),
		ControlKnob = Color3.fromRGB(255, 255, 252),
		Success = Color3.fromRGB(73, 139, 97),
		Warning = Color3.fromRGB(165, 122, 54),
		Danger = Color3.fromRGB(174, 66, 60),
		Overlay = Color3.fromRGB(58, 63, 64)
	}
}
local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local function getThemeValue(window, key)
	local theme = window.Theme or Anchorline.Themes.Workbench
	return theme[key] or Anchorline.Themes.Workbench[key] or Color3.fromRGB(255, 255, 255)
end

function Window:_track(instance, propertyMap)
	if not instance or type(propertyMap) ~= "table" then
		return instance
	end
	self._themed[instance] = propertyMap
	for property, themeKey in pairs(propertyMap) do
		if instance.Parent ~= nil then
			instance[property] = getThemeValue(self, themeKey)
		end
	end
	return instance
end

function Window:_untrack(instance)
	if self._themed and instance then
		self._themed[instance] = nil
	end
end

function Window:_applyTheme()
	for instance, propertyMap in pairs(self._themed) do
		if not instance or instance.Parent == nil then
			self._themed[instance] = nil
		else
			for property, themeKey in pairs(propertyMap) do
				instance[property] = getThemeValue(self, themeKey)
			end
		end
	end
	for _, tab in ipairs(self.Tabs) do
		self:_styleTabButton(tab)
	end
end

function Window:SetTheme(theme)
	if type(theme) == "string" then
		self.ThemeName = theme
		self.Theme = Anchorline.Themes[theme] or Anchorline.Themes.Workbench
	elseif type(theme) == "table" then
		self.ThemeName = "Custom"
		self.Theme = theme
	else
		self.ThemeName = "Workbench"
		self.Theme = Anchorline.Themes.Workbench
	end
	self:_applyTheme()
	return self
end

function Window:_resolveIcon(icon)
	if icon == nil or icon == "" then
		return nil
	end
	if typeof(icon) == "number" then
		return {Image = "rbxassetid://" .. tostring(icon)}
	end
	local tableIcon = resolveIconAssetFromTable(icon)
	if tableIcon then
		return tableIcon
	end
	if type(icon) == "string" then
		if isNumericAssetString(icon) then
			return {Image = "rbxassetid://" .. icon}
		end
		if isRobloxImagePath(icon) then
			return {Image = icon}
		end
		local provider = self.IconProvider
		if provider then
			local candidates = {icon, normalizeIconName(icon)}
			local function parseAsset(asset)
				if type(asset) == "string" then
					if isNumericAssetString(asset) then
						return {Image = "rbxassetid://" .. asset}
					elseif isRobloxImagePath(asset) then
						return {Image = asset}
					end
				end
				return resolveIconAssetFromTable(asset)
			end
			for _, candidate in ipairs(candidates) do
				if type(provider.GetAsset) == "function" then
					local ok, asset = pcall(provider.GetAsset, provider, candidate, 48)
					local parsed = ok and parseAsset(asset) or nil
					if parsed then return parsed end
					ok, asset = pcall(provider.GetAsset, candidate, 48)
					parsed = ok and parseAsset(asset) or nil
					if parsed then return parsed end
					ok, asset = pcall(provider.GetAsset, provider, candidate)
					parsed = ok and parseAsset(asset) or nil
					if parsed then return parsed end
					ok, asset = pcall(provider.GetAsset, candidate)
					parsed = ok and parseAsset(asset) or nil
					if parsed then return parsed end
				end
			end
		end
	end
	return nil
end

local function createVectorIcon(parent, iconName)
	local name = normalizeIconName(iconName)
	if name == "" then
		name = "toolbox"
	end
	local shapes = {}
	local function shape(className, props, children)
		props = props or {}
		props.BackgroundTransparency = props.BackgroundTransparency or 0
		props.BorderSizePixel = 0
		props.Parent = parent
		local object = new(className or "Frame", props, children)
		shapes[#shapes + 1] = object
		return object
	end
	local function line(x, y, w, h, rotation, r)
		return shape("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rotation or 0
		}, {corner(r or math.max(1, math.floor(h / 2)))})
	end
	local function dot(x, y, size)
		return shape("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size)
		}, {corner(math.floor(size / 2))})
	end
	local function rect(x, y, w, h, r)
		return shape("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h)
		}, {corner(r or 2)})
	end
	if name == "bar-chart" or name == "analytics" or name == "stats" or name == "results" or name == "chart" then
		rect(3, 11, 3, 6, 2)
		rect(8, 7, 3, 10, 2)
		rect(13, 4, 3, 13, 2)
		line(2, 17, 16, 2, 0, 1)
	elseif name == "info" or name == "help" then
		dot(8, 3, 4)
		line(9, 8, 2, 9, 0, 1)
		line(7, 9, 4, 2, 0, 1)
		line(7, 16, 6, 2, 0, 1)
	elseif name == "check" or name == "success" then
		line(4, 10, 6, 2, 45, 1)
		line(8, 11, 10, 2, -45, 1)
	elseif name == "x" or name == "close" or name == "error" then
		line(4, 4, 13, 2, 45, 1)
		line(4, 14, 13, 2, -45, 1)
	elseif name == "warning" or name == "alert" then
		line(10, 2, 2, 11, 0, 1)
		dot(9, 15, 4)
		line(5, 17, 12, 2, 0, 1)
		line(5, 17, 7, 2, -63, 1)
		line(10, 5, 7, 2, 63, 1)
	elseif name == "code" or name == "script" or name == "terminal" then
		line(3, 10, 6, 2, -35, 1)
		line(3, 10, 6, 2, 35, 1)
		line(12, 8, 6, 2, 35, 1)
		line(12, 12, 6, 2, -35, 1)
		line(9, 16, 5, 2, -70, 1)
	elseif name == "bell" or name == "notification" then
		rect(5, 7, 10, 9, 4)
		line(4, 15, 12, 2, 0, 1)
		dot(8, 17, 4)
		line(9, 3, 2, 4, 0, 1)
	elseif name == "toolbox" or name == "tools" then
		rect(3, 7, 14, 10, 3)
		line(7, 5, 6, 2, 0, 1)
		line(7, 5, 2, 4, 0, 1)
		line(12, 5, 2, 4, 0, 1)
		line(3, 10, 14, 2, 0, 1)
	elseif name == "test" or name == "flask" then
		line(7, 3, 6, 2, 0, 1)
		line(9, 5, 2, 6, 0, 1)
		rect(5, 11, 10, 6, 3)
	elseif name == "esp" or name == "eye" or name == "visuals" then
		line(2, 9, 16, 2, 0, 1)
		line(4, 5, 12, 2, 24, 1)
		line(4, 13, 12, 2, -24, 1)
		dot(8, 8, 4)
	elseif name == "home" or name == "main" then
		line(4, 9, 12, 2, 0, 1)
		line(5, 8, 8, 2, -40, 1)
		line(8, 8, 8, 2, 40, 1)
		line(5, 11, 2, 6, 0, 1)
		line(13, 11, 2, 6, 0, 1)
		line(5, 16, 10, 2, 0, 1)
	elseif name == "settings" or name == "gear" or name == "config" then
		dot(8, 8, 4)
		line(9, 1, 2, 5, 0, 1)
		line(9, 14, 2, 5, 0, 1)
		line(1, 9, 5, 2, 0, 1)
		line(14, 9, 5, 2, 0, 1)
		line(4, 4, 4, 2, 45, 1)
		line(12, 4, 4, 2, -45, 1)
		line(4, 14, 4, 2, -45, 1)
		line(12, 14, 4, 2, 45, 1)
	elseif name == "players" or name == "user" or name == "users" then
		dot(4, 4, 6)
		line(2, 12, 10, 5, 0, 3)
		dot(12, 6, 4)
		line(11, 13, 7, 4, 0, 2)
	elseif name == "target" or name == "aim" then
		line(9, 0, 2, 5, 0, 1)
		line(9, 15, 2, 5, 0, 1)
		line(0, 9, 5, 2, 0, 1)
		line(15, 9, 5, 2, 0, 1)
		dot(7, 7, 6)
	elseif name == "shield" or name == "security" then
		line(5, 3, 10, 2, 0, 1)
		line(5, 3, 2, 9, 0, 1)
		line(13, 3, 2, 9, 0, 1)
		line(7, 13, 6, 2, -20, 1)
		line(7, 13, 6, 2, 20, 1)
	elseif name == "bolt" or name == "power" then
		line(10, 1, 3, 10, 28, 1)
		line(6, 9, 8, 3, 0, 1)
		line(7, 9, 3, 10, 28, 1)
	elseif name == "folder" or name == "files" then
		line(2, 5, 7, 2, 0, 1)
		line(2, 7, 16, 2, 0, 1)
		line(2, 9, 2, 8, 0, 1)
		line(16, 9, 2, 8, 0, 1)
		line(2, 16, 16, 2, 0, 1)
	elseif name == "book" or name == "docs" then
		line(4, 3, 2, 14, 0, 1)
		line(6, 3, 10, 2, 0, 1)
		line(6, 16, 10, 2, 0, 1)
		line(15, 3, 2, 15, 0, 1)
		line(8, 7, 6, 1, 0, 1)
		line(8, 10, 6, 1, 0, 1)
	else
		local label = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Text = tostring(iconName or "?"):sub(1, 1):upper(),
			Parent = parent
		})
		shapes[#shapes + 1] = label
	end
	return shapes
end

function Window:_styleTabButton(tab)
	if not tab or not tab.Button then
		return
	end
	local active = self.ActiveTab == tab
	local iconColor = active and getThemeValue(self, "Accent") or getThemeValue(self, "TextFaint")
	if active then
		tween(tab.Button, 0.28, {BackgroundColor3 = getThemeValue(self, "Surface")}, Enum.EasingStyle.Quint)
		tab.ButtonStroke.Color = getThemeValue(self, "Stroke")
		tab.ButtonTitle.TextColor3 = getThemeValue(self, "Text")
		if tab.ButtonAccent then
			tab.ButtonAccent.BackgroundColor3 = getThemeValue(self, "Accent")
			tween(tab.ButtonAccent, 0.3, {BackgroundTransparency = 0, Size = UDim2.new(0, 4, 1, -12)}, Enum.EasingStyle.Quint)
		end
	else
		tween(tab.Button, 0.28, {BackgroundColor3 = getThemeValue(self, "Panel")}, Enum.EasingStyle.Quint)
		tab.ButtonStroke.Color = getThemeValue(self, "StrokeSoft")
		tab.ButtonTitle.TextColor3 = getThemeValue(self, "TextMuted")
		if tab.ButtonAccent then
			tween(tab.ButtonAccent, 0.24, {BackgroundTransparency = 1, Size = UDim2.new(0, 3, 1, -16)}, Enum.EasingStyle.Quint)
		end
	end
	if tab.ButtonIcon then
		tab.ButtonIcon.TextColor3 = iconColor
	end
	if tab.ButtonIconImage then
		tab.ButtonIconImage.ImageColor3 = iconColor
		tab.ButtonIconImage.ImageTransparency = active and 0 or 0.18
	end
	if tab.ButtonIconShapes then
		for _, shape in ipairs(tab.ButtonIconShapes) do
			if shape:IsA("TextLabel") then
				shape.TextColor3 = iconColor
			else
				shape.BackgroundColor3 = iconColor
			end
		end
	end
end

function Window:_selectTab(tab)
	if not tab then
		return
	end
	self.ActiveTab = tab
	self.PageTitle.Text = tab.Name
	self.PageSubtitle.Text = tab.Description or ""
	for _, candidate in ipairs(self.Tabs) do
		candidate.Page.Visible = candidate == tab
		self:_styleTabButton(candidate)
	end
	self:_applySearch()
	if tab.Page then
		self:_updatePageCanvas(tab.Page)
	end
	self:_queueSmartResize()
end

function Window:_updateContentOffset()
	local width = self.SidebarCollapsed and 64 or self.SidebarWidth
	tween(self.Sidebar, 0.44, {Size = UDim2.new(0, width, 1, -58)}, Enum.EasingStyle.Quint)
	tween(self.Content, 0.44, {Position = UDim2.new(0, width, 0, 58), Size = UDim2.new(1, -width, 1, -58)}, Enum.EasingStyle.Quint)
	for _, tab in ipairs(self.Tabs) do
		tab.ButtonTitle.Visible = not self.SidebarCollapsed
	end
	self:_queueSmartResize()
end

function Window:_refreshAdaptiveLayouts()
	if type(self._adaptiveHandlers) ~= "table" then
		return
	end
	for i = #self._adaptiveHandlers, 1, -1 do
		local handler = self._adaptiveHandlers[i]
		if type(handler) ~= "function" then
			table.remove(self._adaptiveHandlers, i)
		else
			local ok = pcall(handler)
			if not ok then
				table.remove(self._adaptiveHandlers, i)
			end
		end
	end
end

function Window:_addAdaptiveHandler(handler)
	if type(handler) ~= "function" then
		return
	end
	self._adaptiveHandlers[#self._adaptiveHandlers + 1] = handler
	task.defer(function()
		if self.Root and self.Root.Parent then
			self:_refreshAdaptiveLayouts()
			self:_queueSmartResize()
		end
	end)
end

function Window:_getPagePadding(page)
	local pad = page and page:FindFirstChildOfClass("UIPadding")
	if not pad then
		return 0, 0, 0, 0
	end
	return pad.PaddingLeft.Offset, pad.PaddingRight.Offset, pad.PaddingTop.Offset, pad.PaddingBottom.Offset
end

function Window:_updatePageCanvas(page)
	if not page or not page:IsA("ScrollingFrame") then
		return 0
	end
	local _, _, padTop, padBottom = self:_getPagePadding(page)
	local layout = page:FindFirstChildOfClass("UIListLayout")
	local contentHeight = 0
	if layout then
		contentHeight = math.max(contentHeight, layout.AbsoluteContentSize.Y)
	end
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local scaleY = child.Position.Y.Scale ~= 0 and child.Position.Y.Scale * math.max(0, page.AbsoluteSize.Y) or 0
			local bottom = scaleY + child.Position.Y.Offset + child.AbsoluteSize.Y
			if child.Size.Y.Scale ~= 0 and child.AbsoluteSize.Y <= 1 then
				bottom = scaleY + child.Position.Y.Offset + (child.Size.Y.Scale * math.max(0, page.AbsoluteSize.Y)) + child.Size.Y.Offset
			end
			contentHeight = math.max(contentHeight, bottom)
		end
	end
	local bottomReserve = tonumber(self.ScrollBottomPadding) or 56
	local canvasHeight = math.max(0, math.ceil(contentHeight + padTop + padBottom + bottomReserve))
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.CanvasSize = UDim2.fromOffset(0, canvasHeight)
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.ScrollingEnabled = true
	page.Active = true
	local maxScroll = math.max(0, canvasHeight - math.max(0, page.AbsoluteSize.Y))
	if page.CanvasPosition.Y > maxScroll then
		page.CanvasPosition = Vector2.new(page.CanvasPosition.X, maxScroll)
	end
	return canvasHeight
end

function Window:_refreshPageCanvases()
	for _, tab in ipairs(self.Tabs or {}) do
		if tab.Page then
			self:_updatePageCanvas(tab.Page)
		end
	end
end

function Window:_measureActiveContent()
	local active = self.ActiveTab
	local minimumContentWidth = tonumber(self.SmartContentMinWidth) or 390
	local pageContentHeight = 0
	if active and active.Page then
		pageContentHeight = self:_updatePageCanvas(active.Page)
		local pageWidth = math.max(0, active.Page.AbsoluteSize.X)
		for _, element in ipairs(active.Elements or {}) do
			if element and element.Parent and element.Visible then
				local elementWidth = tonumber(element:GetAttribute("AnchorlineMinWidth")) or 0
				if elementWidth <= 0 and element.AbsoluteSize.X > 0 then
					elementWidth = math.min(element.AbsoluteSize.X, pageWidth)
				end
				minimumContentWidth = math.max(minimumContentWidth, elementWidth)
			end
		end
	end
	return minimumContentWidth, pageContentHeight
end

function Window:_calculateSmartSize()
	local viewport = getViewportSize()
	local margin = tonumber(self.SmartViewportMargin) or 44
	local baseMinWidth = tonumber(self.MinWidth) or 560
	local baseMinHeight = tonumber(self.MinHeight) or 390
	local safeViewportWidth = math.max(baseMinWidth, viewport.X - margin)
	local safeViewportHeight = math.max(baseMinHeight, viewport.Y - margin)
	local maxWidth = math.min(tonumber(self.MaxWidth) or 1040, safeViewportWidth)
	local maxHeight = math.min(tonumber(self.MaxHeight) or 760, safeViewportHeight)
	local contentMinWidth, pageContentHeight = self:_measureActiveContent()
	local sidebarWidth = self.SidebarCollapsed and 64 or self.SidebarWidth
	local smartMinWidth = math.min(maxWidth, math.max(baseMinWidth, sidebarWidth + contentMinWidth + 42))
	local smartMinHeight = math.min(maxHeight, math.max(baseMinHeight, 360))
	local desiredWidth = math.max(tonumber(self.Width) or baseMinWidth, smartMinWidth)
	local chromeHeight = 58 + 66 + 30
	local desiredContentHeight = math.min(pageContentHeight, math.max(180, maxHeight - chromeHeight))
	local desiredHeight = math.max(tonumber(self.Height) or baseMinHeight, chromeHeight + desiredContentHeight)
	local targetWidth, targetHeight = clampVectorSize(desiredWidth, desiredHeight, smartMinWidth, smartMinHeight, maxWidth, maxHeight)
	return targetWidth, targetHeight, smartMinWidth, smartMinHeight, maxWidth, maxHeight
end

function Window:SmartResize(animated)
	if not self.SmartResizeEnabled or not self.Root or self.Root.Parent == nil or self.Minimized then
		return self
	end
	self:_refreshAdaptiveLayouts()
	self:_refreshPageCanvases()
	local targetWidth, targetHeight, smartMinWidth, smartMinHeight = self:_calculateSmartSize()
	self._computedMinWidth = smartMinWidth
	self._computedMinHeight = smartMinHeight
	local targetSize = UDim2.fromOffset(targetWidth, targetHeight)
	local currentSize = self.Root.AbsoluteSize
	if math.abs(currentSize.X - targetWidth) < 1 and math.abs(currentSize.Y - targetHeight) < 1 then
		return self
	end
	if animated then
		tween(self.Root, 0.52, {Size = targetSize}, Enum.EasingStyle.Quint)
	else
		self.Root.Size = targetSize
	end
	self.Width = targetWidth
	self.Height = targetHeight
	local function deferredRefresh()
		if self.Root and self.Root.Parent then
			self:_refreshAdaptiveLayouts()
			self:_refreshPageCanvases()
		end
	end
	task.defer(deferredRefresh)
	task.delay(0.08, deferredRefresh)
	task.delay(0.24, deferredRefresh)
	task.delay(0.56, deferredRefresh)
	return self
end

function Window:RefreshLayout(animated)
	self:_refreshAdaptiveLayouts()
	self:_refreshPageCanvases()
	return self:SmartResize(animated ~= false)
end

function Window:_queueSmartResize()
	if not self.SmartResizeEnabled or self._smartResizeQueued then
		return
	end
	self._smartResizeQueued = true
	task.delay(0.035, function()
		self._smartResizeQueued = false
		if self.Root and self.Root.Parent then
			self:SmartResize(true)
		end
	end)
end

function Window:CollapseSidebar(value)
	if value == nil then
		self.SidebarCollapsed = not self.SidebarCollapsed
	else
		self.SidebarCollapsed = value and true or false
	end
	self:_updateContentOffset()
	return self.SidebarCollapsed
end

function Window:Minimize(value)
	if value == nil then
		self.Minimized = not self.Minimized
	else
		self.Minimized = value and true or false
	end
	if self.Minimized then
		self._lastSize = self.Root.Size
		self.Sidebar.Visible = false
		self.Content.Visible = false
		self.ResizeHandle.Visible = false
		tween(self.Root, 0.36, {Size = UDim2.new(0, math.max(420, self.Root.AbsoluteSize.X), 0, 58)}, Enum.EasingStyle.Quint)
	else
		self.Sidebar.Visible = true
		self.Content.Visible = true
		self.ResizeHandle.Visible = true
		tween(self.Root, 0.36, {Size = self._lastSize or UDim2.fromOffset(self.Width, self.Height)}, Enum.EasingStyle.Quint)
	end
	return self.Minimized
end

function Window:Show()
	self.Gui.Enabled = true
	self.Hidden = false
	if self.Root then
		self.Root.Visible = true
		self.Root.GroupTransparency = 1
		local basePosition = self._visiblePosition or self.Root.Position
		self.Root.Position = basePosition + UDim2.fromOffset(0, 10)
		tween(self.Root, 0.42, {GroupTransparency = 0, Position = basePosition}, Enum.EasingStyle.Quint)
	end
	self:_setBackgroundBlur(true)
end

function Window:Hide()
	self.Hidden = true
	if self.Root then
		self._visiblePosition = self.Root.Position
		tween(self.Root, 0.3, {GroupTransparency = 1, Position = self.Root.Position + UDim2.fromOffset(0, 10)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.32, function()
			if self.Hidden and self.Gui and self.Root then
				self.Root.Visible = false
				self.Gui.Enabled = false
			end
		end)
	else
		self.Gui.Enabled = false
	end
	self:_setBackgroundBlur(false)
end

function Window:Toggle()
	if self.Gui.Enabled then
		self:Hide()
	else
		self:Show()
	end
end

function Window:Destroy()
	self:_clearTemporaryConnections()
	self:_setBackgroundBlur(false)
	if self.BlurEffect then
		task.delay(0.32, function()
			if self.BlurEffect then
				self.BlurEffect:Destroy()
			end
		end)
	end
	for _, connection in ipairs(self._connections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end
	self._connections = {}
	self._themed = setmetatable({}, {__mode = "k"})
	if self.Gui then
		self.Gui:Destroy()
	end
end

function Window:_setBackgroundBlur(enabled)
	if not self.FrostedGlass then
		return
	end
	if enabled then
		if not self.BlurEffect then
			self.BlurEffect = new("BlurEffect", {
				Name = "AnchorlineBackgroundBlur",
				Size = 0,
				Parent = Lighting
			})
		end
		tween(self.BlurEffect, 0.45, {Size = self.BlurSize or 10}, Enum.EasingStyle.Quint)
	elseif self.BlurEffect then
		tween(self.BlurEffect, 0.28, {Size = 0}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end
end

function Window:SetFrostedGlass(enabled)
	self.FrostedGlass = enabled and true or false
	if self.Root then
		self.Root.BackgroundTransparency = self.FrostedGlass and (self.GlassTransparency or 0.12) or 0
	end
	self:_setBackgroundBlur(self.FrostedGlass and not self.Hidden)
	return self
end

function Window:_storeTemporaryConnection(connection)
	if not connection then
		return connection
	end
	self._temporaryConnections = self._temporaryConnections or {}
	self._temporaryConnections[#self._temporaryConnections + 1] = connection
	return connection
end

function Window:_clearTemporaryConnections()
	if not self._temporaryConnections then
		return
	end
	for _, connection in ipairs(self._temporaryConnections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end
	self._temporaryConnections = {}
end

function Window:_makeDraggable()
	local header = self.Header
	local root = self.Root
	local dragging = false
	local dragStart = nil
	local startPosition = nil
	local moveConnection = nil
	local endConnection = nil

	local function stopDragging()
		dragging = false
		if moveConnection then
			moveConnection:Disconnect()
			moveConnection = nil
		end
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
		self._temporaryConnections = {}
	end

	self._connections[#self._connections + 1] = header.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self.Minimized then
			return
		end
		stopDragging()
		dragging = true
		dragStart = input.Position
		startPosition = root.Position
		moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging or not dragStart or not startPosition then
				return
			end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = moveInput.Position - dragStart
			root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end)
		endConnection = UserInputService.InputEnded:Connect(function(endInput)
			if endInput == input or endInput.UserInputType == input.UserInputType then
				stopDragging()
			end
		end)
		self:_storeTemporaryConnection(moveConnection)
		self:_storeTemporaryConnection(endConnection)
	end)
end

function Window:_makeResizable()
	local resizing = false
	local resizeStart = nil
	local startSize = nil
	local moveConnection = nil
	local endConnection = nil
	local function bounds()
		local viewport = getViewportSize()
		local margin = tonumber(self.SmartViewportMargin) or 44
		local minWidth = math.max(tonumber(self.MinWidth) or 560, tonumber(self._computedMinWidth) or 0)
		local minHeight = math.max(tonumber(self.MinHeight) or 390, math.min(tonumber(self._computedMinHeight) or 0, tonumber(self.MaxHeight) or 760))
		local maxWidth = math.min(tonumber(self.MaxWidth) or 1040, math.max(minWidth, viewport.X - margin))
		local maxHeight = math.min(tonumber(self.MaxHeight) or 760, math.max(minHeight, viewport.Y - margin))
		return minWidth, minHeight, maxWidth, maxHeight
	end

	local function stopResizing()
		resizing = false
		if moveConnection then
			moveConnection:Disconnect()
			moveConnection = nil
		end
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
		self._temporaryConnections = {}
		self:_refreshAdaptiveLayouts()
		self:_refreshPageCanvases()
	end

	self._connections[#self._connections + 1] = self.ResizeHandle.InputBegan:Connect(function(input)
		if self.Minimized then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		stopResizing()
		resizing = true
		resizeStart = input.Position
		startSize = self.Root.AbsoluteSize
		moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
			if not resizing or not resizeStart or not startSize then
				return
			end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = moveInput.Position - resizeStart
			local minWidth, minHeight, maxWidth, maxHeight = bounds()
			local newWidth = math.clamp(startSize.X + delta.X, minWidth, maxWidth)
			local newHeight = math.clamp(startSize.Y + delta.Y, minHeight, maxHeight)
			self.Root.Size = UDim2.fromOffset(newWidth, newHeight)
			self.Width = newWidth
			self.Height = newHeight
			self:_refreshAdaptiveLayouts()
			self:_refreshPageCanvases()
		end)
		endConnection = UserInputService.InputEnded:Connect(function(endInput)
			if endInput == input or endInput.UserInputType == input.UserInputType then
				stopResizing()
			end
		end)
		self:_storeTemporaryConnection(moveConnection)
		self:_storeTemporaryConnection(endConnection)
	end)
end

function Window:_registerFlag(flag, controller)
	if type(flag) ~= "string" or flag == "" then
		return
	end
	self.Flags[flag] = controller
	Anchorline.Flags[flag] = controller
end

function Window:_flagData()
	local data = {}
	for flag, controller in pairs(self.Flags) do
		if controller and type(controller.Get) == "function" then
			local value = controller:Get()
			if typeof(value) == "Color3" then
				data[flag] = colorToTable(value)
			elseif typeof(value) == "EnumItem" then
				data[flag] = value.Name
			else
				data[flag] = value
			end
		end
	end
	return data
end

function Window:_configurationPath(fileName)
	local config = self.Configuration
	local folder = config.FolderName or config.Folder or "Anchorline"
	local file = fileName or config.FileName or config.File or self.Title:gsub("%W+", "_")
	return folder, folder .. "/" .. file .. ".json"
end

function Window:SaveConfiguration(fileName)
	if not fileAvailable() then
		self:Notify({Title = "Configuration unavailable", Content = "Your environment does not expose file saving functions.", Type = "Warning"})
		return false
	end
	local folder, path = self:_configurationPath(fileName)
	ensureFolder(folder)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(self:_flagData())
	end)
	if not ok then
		self:Notify({Title = "Configuration error", Content = "Could not encode current settings.", Type = "Error"})
		return false
	end
	local success, err = pcall(writefile, path, encoded)
	if not success then
		self:Notify({Title = "Configuration error", Content = tostring(err), Type = "Error"})
		return false
	end
	self:Notify({Title = "Configuration saved", Content = path, Type = "Success", Duration = 3})
	return true
end

function Window:LoadConfiguration(fileName)
	if not fileAvailable() then
		return false
	end
	local _, path = self:_configurationPath(fileName)
	if not isfile(path) then
		return false
	end
	local okRead, raw = pcall(readfile, path)
	if not okRead or type(raw) ~= "string" then
		return false
	end
	local okDecode, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or type(decoded) ~= "table" then
		self:Notify({Title = "Configuration error", Content = "The saved file is not valid JSON.", Type = "Error"})
		return false
	end
	for flag, value in pairs(decoded) do
		local controller = self.Flags[flag]
		if controller and type(controller.Set) == "function" then
			controller:Set(value, true)
		end
	end
	self:Notify({Title = "Configuration loaded", Content = path, Type = "Success", Duration = 3})
	return true
end

function Window:_autoSave()
	if not self.Configuration.Enabled or self.Configuration.AutoSave == false then
		return
	end
	if self._saveQueued then
		return
	end
	self._saveQueued = true
	task.delay(0.3, function()
		self._saveQueued = false
		if self.Gui and self.Gui.Parent then
			self:SaveConfiguration()
		end
	end)
end

function Window:_notificationColors(kind)
	if kind == "Success" then
		return getThemeValue(self, "Success")
	elseif kind == "Warning" then
		return getThemeValue(self, "Warning")
	elseif kind == "Error" or kind == "Danger" then
		return getThemeValue(self, "Danger")
	else
		return getThemeValue(self, "Accent")
	end
end

function Window:Notify(options)
	options = options or {}
	local kind = tostring(options.Type or options.Kind or "Info")
	local accent = self:_notificationColors(kind)
	local duration = tonumber(options.Duration) or 4

	local wrapper = new("Frame", {
		Name = "NotificationSlot",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = self.NotificationList,
		ZIndex = 60
	})

	local card = new("Frame", {
		Name = "NotificationCard",
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -54, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = wrapper,
		ZIndex = 61
	}, {
		corner(14),
		padding(14, 14, 13, 13),
		listLayout(Enum.FillDirection.Vertical, 7)
	})
	self:_track(card, {BackgroundColor3 = "Panel"})
	local cardStroke = stroke(getThemeValue(self, "Stroke"), 1, 1)
	cardStroke.Parent = card
	cardStroke.ZIndex = 62
	self:_track(cardStroke, {Color = "Stroke"})

	local header = new("Frame", {
		Name = "NotificationHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = card,
		ZIndex = 63
	})

	local badge = new("Frame", {
		Name = "StatusBadge",
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = header,
		ZIndex = 64
	}, {corner(8)})

	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(options.Title or "Notification"),
		TextTransparency = 1,
		Parent = header,
		ZIndex = 64
	})
	self:_track(title, {TextColor3 = "Text"})

	local content = new("TextLabel", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tostring(options.Content or ""),
		TextTransparency = 1,
		Parent = card,
		ZIndex = 64
	})
	self:_track(content, {TextColor3 = "TextMuted"})

	task.defer(function()
		if not card or not card.Parent then return end
		tween(card, 0.5, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = self.FrostedGlass and 0.1 or 0}, Enum.EasingStyle.Quint)
		tween(cardStroke, 0.36, {Transparency = 0}, Enum.EasingStyle.Quint)
		tween(badge, 0.34, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint)
		tween(title, 0.34, {TextTransparency = 0}, Enum.EasingStyle.Quint)
		tween(content, 0.38, {TextTransparency = 0}, Enum.EasingStyle.Quint)
	end)

	task.delay(duration, function()
		if not card or not card.Parent then
			return
		end
		tween(card, 0.34, {Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -54, 0, 0), BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(cardStroke, 0.25, {Transparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(badge, 0.22, {BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(title, 0.22, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(content, 0.22, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.38)
		if wrapper then
			wrapper:Destroy()
		end
	end)
	return wrapper
end

function Window:Prompt(options)
	options = options or {}
	local overlay = new("Frame", {
		Name = "PromptOverlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = self.Gui,
		ZIndex = 80
	})
	self:_track(overlay, {BackgroundColor3 = "Overlay"})
	local card = new("Frame", {
		Name = "PromptCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 81,
		Parent = overlay
	}, {
		corner(16),
		stroke(getThemeValue(self, "Stroke"), 1, 0),
		padding(20, 20, 20, 20),
		listLayout(Enum.FillDirection.Vertical, 10)
	})
	self:_track(card, {BackgroundColor3 = "Panel"})
	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(options.Title or "Confirm action"),
		ZIndex = 82,
		Parent = card
	})
	self:_track(title, {TextColor3 = "Text"})
	local content = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(options.Content or ""),
		ZIndex = 82,
		Parent = card
	})
	self:_track(content, {TextColor3 = "TextMuted"})
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		ZIndex = 82,
		Parent = card
	}, {listLayout(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)})
	local cancel = new("TextButton", {
		Size = UDim2.fromOffset(104, 34),
		BackgroundTransparency = 0,
		Text = tostring(options.CancelText or "Cancel"),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		ZIndex = 83,
		Parent = row
	}, {corner(5), stroke(getThemeValue(self, "StrokeSoft"), 1, 0)})
	self:_track(cancel, {BackgroundColor3 = "Surface", TextColor3 = "Text"})
	local confirm = new("TextButton", {
		Size = UDim2.fromOffset(104, 34),
		BackgroundTransparency = 0,
		Text = tostring(options.ConfirmText or "Confirm"),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		ZIndex = 83,
		Parent = row
	}, {corner(5)})
	self:_track(confirm, {BackgroundColor3 = "Accent", TextColor3 = "AccentText"})
	local closed = false
	local function close(value)
		if closed then
			return
		end
		closed = true
		safeCall(options.Callback, value)
		tween(overlay, 0.22, {BackgroundTransparency = 1})
		tween(card, 0.22, {BackgroundTransparency = 1})
		task.delay(0.18, function()
			if overlay then
				overlay:Destroy()
			end
		end)
	end
	cancel.MouseButton1Click:Connect(function()
		close(false)
	end)
	confirm.MouseButton1Click:Connect(function()
		close(true)
	end)
	tween(overlay, 0.28, {BackgroundTransparency = 0.55})
	tween(card, 0.32, {BackgroundTransparency = self.FrostedGlass and 0.08 or 0})
	return overlay
end

function Window:_applySearch()
	local active = self.ActiveTab
	if not active then
		return
	end
	local query = string.lower(self.SearchBox.Text or "")
	for _, object in ipairs(active.Elements) do
		if object and object.Parent then
			local searchText = string.lower(object:GetAttribute("SearchText") or object.Name or "")
			object.Visible = query == "" or string.find(searchText, query, 1, true) ~= nil
		end
	end
	self:_queueSmartResize()
end

function Window:CreateTab(name, icon, description)
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = tostring(name or "Tab")
	tab.IconAsset = self:_resolveIcon(icon)
	tab.Icon = tostring(icon or string.sub(tab.Name, 1, 1)):sub(1, 2)
	tab.Description = description
	tab.Elements = {}

	local button = new("TextButton", {
		Name = tab.Name .. "TabButton",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = self.FrostedGlass and 0.18 or 0,
		AutoButtonColor = false,
		Text = "",
		Parent = self.TabList
	}, {corner(10)})
	local buttonStroke = stroke(getThemeValue(self, "StrokeSoft"), 1, 0)
	buttonStroke.Parent = button
	local indicator = new("Frame", {
		Name = "SelectionIndicator",
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.new(0, 3, 1, -14),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = button
	}, {corner(2)})
	local iconImage = new("ImageLabel", {
		Name = "IconImage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(13, 7),
		Size = UDim2.fromOffset(20, 20),
		ScaleType = Enum.ScaleType.Fit,
		Visible = tab.IconAsset ~= nil,
		Parent = button
	})
	if tab.IconAsset then
		iconImage.Image = tab.IconAsset.Image
		if tab.IconAsset.ImageRectOffset then
			iconImage.ImageRectOffset = tab.IconAsset.ImageRectOffset
		end
		if tab.IconAsset.ImageRectSize then
			iconImage.ImageRectSize = tab.IconAsset.ImageRectSize
		end
	end
	local iconHolder = new("Frame", {
		Name = "VectorIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(13, 7),
		Size = UDim2.fromOffset(20, 20),
		Visible = tab.IconAsset == nil,
		Parent = button
	})
	local iconShapes = createVectorIcon(iconHolder, icon or tab.Name)
	local iconLabel = nil
	local titleLabel = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tab.Name,
		Parent = button
	})

	local page = new("ScrollingFrame", {
		Name = tab.Name .. "Page",
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollBarThickness = 5,
		ScrollBarImageTransparency = 0.18,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		Parent = self.Pages
	}, {
		padding(16, 16, 14, 16),
		listLayout(Enum.FillDirection.Vertical, 10)
	})
	self:_track(page, {ScrollBarImageColor3 = "Accent"})
	local pageLayout = page:FindFirstChildOfClass("UIListLayout")
	if pageLayout then
		self._connections[#self._connections + 1] = pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			self:_updatePageCanvas(page)
			self:_queueSmartResize()
		end)
	end

	tab.Button = button
	tab.ButtonStroke = buttonStroke
	tab.ButtonTitle = titleLabel
	tab.ButtonIcon = iconLabel
	tab.ButtonIconImage = iconImage
	tab.ButtonIconShapes = iconShapes
	tab.ButtonAccent = indicator
	tab.Page = page

	button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			tween(button, 0.12, {BackgroundColor3 = getThemeValue(self, "Surface")})
		end
	end)
	button.MouseLeave:Connect(function()
		self:_styleTabButton(tab)
	end)
	button.MouseButton1Click:Connect(function()
		self:_selectTab(tab)
	end)

	self.Tabs[#self.Tabs + 1] = tab
	self:_styleTabButton(tab)
	if not self.ActiveTab then
		self:_selectTab(tab)
	end
	return tab
end

function Window:_createElement(tab, titleText, searchText, height)
	local frame = new("Frame", {
		Name = tostring(titleText or "Element"),
		Size = UDim2.new(1, 0, 0, height or 54),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = self.FrostedGlass and 0.14 or 0,
		ClipsDescendants = true,
		Parent = tab.Page
	}, {
		corner(12),
		padding(14, 14, 12, 12),
		listLayout(Enum.FillDirection.Vertical, 8)
	})
	frame:SetAttribute("SearchText", tostring(searchText or titleText or ""))
	frame:SetAttribute("AnchorlineMinWidth", 320)
	local s = stroke(getThemeValue(self, "StrokeSoft"), 1, 0)
	s.Parent = frame
	self:_track(frame, {BackgroundColor3 = "PanelAlt"})
	self:_track(s, {Color = "StrokeSoft"})
	tab.Elements[#tab.Elements + 1] = frame
	local elementLayout = frame:FindFirstChildOfClass("UIListLayout")
	if elementLayout then
		self._connections[#self._connections + 1] = elementLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			self:_queueSmartResize()
		end)
	end
	self:_queueSmartResize()
	return frame
end

function Tab:_headerRow(parent, titleText, descriptionText)
	local row = new("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, descriptionText and descriptionText ~= "" and 38 or 26),
		Parent = parent
	})
	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(titleText or "Element"),
		Parent = row
	})
	self.Window:_track(title, {TextColor3 = "Text"})
	if descriptionText and descriptionText ~= "" then
		local description = new("TextLabel", {
			Name = "Description",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 16),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(descriptionText),
			Parent = row
		})
		self.Window:_track(description, {TextColor3 = "TextMuted"})
	end
	return row, title
end

function Tab:CreateSection(name)
	local frame = new("Frame", {
		Name = tostring(name or "Section"),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Parent = self.Page
	})
	frame:SetAttribute("SearchText", tostring(name or "Section"))
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -4, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(tostring(name or "Section")),
		Parent = frame
	})
	self.Window:_track(label, {TextColor3 = "TextFaint"})
	self.Elements[#self.Elements + 1] = frame
	return frame
end

function Tab:CreateDivider()
	local frame = new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		Parent = self.Page
	})
	frame:SetAttribute("SearchText", "divider separator")
	local line = new("Frame", {
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Parent = frame
	})
	self.Window:_track(line, {BackgroundColor3 = "StrokeSoft"})
	self.Elements[#self.Elements + 1] = frame
	return frame
end

function Tab:CreateLabel(text)
	local frame = self.Window:_createElement(self, tostring(text or "Label"), tostring(text or "Label"), 42)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(text or "Label"),
		Parent = frame
	})
	self.Window:_track(label, {TextColor3 = "TextMuted"})
	local lastWidth = -1
	local function resizeLabel(force)
		if not frame or not frame.Parent then
			return
		end
		local width = math.floor(frame.AbsoluteSize.X)
		if width <= 40 then
			width = math.max(300, tonumber(self.Window.SmartContentMinWidth) or 390)
		end
		if not force and math.abs(width - lastWidth) < 2 then
			return
		end
		lastWidth = width
		local h = measureWrappedText(label.Text, 13, Enum.Font.Gotham, math.max(140, width - 28))
		label.Size = UDim2.new(1, 0, 0, h)
		frame.Size = UDim2.new(1, 0, 0, math.max(42, h + 24))
		self.Window:_refreshPageCanvases()
	end
	self.Window._connections[#self.Window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		resizeLabel(false)
	end)
	task.defer(function() resizeLabel(true) end)
	local controller = {}
	function controller:Set(value)
		label.Text = tostring(value)
		frame:SetAttribute("SearchText", tostring(value))
		lastWidth = -1
		resizeLabel(true)
	end
	function controller:Get()
		return label.Text
	end
	return controller
end

function Tab:CreateParagraph(options)
	options = options or {}
	local titleText = tostring(options.Title or options.Name or "Paragraph")
	local bodyText = tostring(options.Content or options.Text or "")
	local frame = self.Window:_createElement(self, titleText, titleText .. " " .. bodyText, 70)
	frame.AutomaticSize = Enum.AutomaticSize.None
	self:_headerRow(frame, titleText, "")
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = bodyText,
		Parent = frame
	})
	self.Window:_track(label, {TextColor3 = "TextMuted"})
	local lastWidth = -1
	local function resizeParagraph(force)
		if not frame or not frame.Parent then
			return
		end
		local width = math.floor(frame.AbsoluteSize.X)
		if width <= 40 then
			width = math.max(300, tonumber(self.Window.SmartContentMinWidth) or 390)
		end
		if not force and math.abs(width - lastWidth) < 2 then
			return
		end
		lastWidth = width
		local textWidth = math.max(140, width - 28)
		local bodyHeight = measureWrappedText(label.Text, 13, Enum.Font.Gotham, textWidth)
		label.Size = UDim2.new(1, 0, 0, bodyHeight)
		frame.Size = UDim2.new(1, 0, 0, math.max(70, 26 + 8 + bodyHeight + 24))
		self.Window:_refreshPageCanvases()
	end
	self.Window._connections[#self.Window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		resizeParagraph(false)
	end)
	task.defer(function() resizeParagraph(true) end)
	task.delay(0.1, function() resizeParagraph(true) end)
	local controller = {}
	function controller:Set(value)
		label.Text = tostring(value)
		frame:SetAttribute("SearchText", titleText .. " " .. tostring(value))
		lastWidth = -1
		resizeParagraph(true)
	end
	function controller:Get()
		return label.Text
	end
	return controller
end

function Tab:CreateButton(options)
	options = options or {}
	local name = tostring(options.Name or "Button")
	local frame = self.Window:_createElement(self, name, name .. " " .. tostring(options.Description or "button"), 62)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(112, 32),
		Text = tostring(options.ButtonText or "Run"),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		Parent = row
	}, {corner(5)})
	self.Window:_track(button, {BackgroundColor3 = "Accent", TextColor3 = "AccentText"})
	button.MouseEnter:Connect(function()
		tween(button, 0.12, {BackgroundColor3 = getThemeValue(self.Window, "Accent")})
	end)
	button.MouseButton1Click:Connect(function()
		tween(button, 0.08, {Size = UDim2.fromOffset(106, 30)})
		task.delay(0.08, function()
			if button and button.Parent then
				tween(button, 0.12, {Size = UDim2.fromOffset(112, 32)})
			end
		end)
		safeCall(options.Callback)
	end)
	local controller = {}
	function controller:Fire()
		safeCall(options.Callback)
	end
	return controller
end

function Tab:CreateToggle(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Toggle")
	local value = options.CurrentValue and true or false
	local frame = self.Window:_createElement(self, name, name .. " " .. tostring(options.Description or "toggle"), 62)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(48, 26),
		Text = "",
		AutoButtonColor = false,
		Parent = row
	}, {corner(13)})
	local buttonStroke = stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)
	buttonStroke.Parent = button
	self.Window:_track(buttonStroke, {Color = "StrokeSoft"})
	local knob = new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
		BorderSizePixel = 0,
		Parent = button
	}, {corner(10)})
	self.Window:_track(knob, {BackgroundColor3 = "ControlKnob"})

	local controller = {Type = "Toggle", Flag = options.Flag}
	local function render(animated)
		local activeColor = getThemeValue(self.Window, "Success")
		local inactiveColor = getThemeValue(self.Window, "Surface")
		local targetColor = value and activeColor or inactiveColor
		local targetPosition = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
		if animated then
			tween(button, 0.34, {BackgroundColor3 = targetColor}, Enum.EasingStyle.Quint)
			tween(knob, 0.34, {Position = targetPosition}, Enum.EasingStyle.Quint)
		else
			button.BackgroundColor3 = targetColor
			knob.Position = targetPosition
		end
	end
	function controller:Set(newValue, loading)
		value = newValue and true or false
		render(not loading)
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	function controller:Toggle()
		controller:Set(not value)
		return value
	end
	button.MouseButton1Click:Connect(function()
		controller:Set(not value)
	end)
	local keyOption = options.Keybind or options.CurrentKeybind or options.ToggleKey
	if keyOption then
		local toggleKey = normalizeKey(keyOption)
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or isTyping() then
				return
			end
			if input.KeyCode == toggleKey then
				controller:Set(not value)
			end
		end)
		self.Window._connections[#self.Window._connections + 1] = connection
	end
	render(false)
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateSlider(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Slider")
	local range = options.Range or {0, 100}
	local minValue = tonumber(range[1]) or 0
	local maxValue = tonumber(range[2]) or 100
	local increment = tonumber(options.Increment) or 1
	local suffix = tostring(options.Suffix or "")
	local value = tonumber(options.CurrentValue) or minValue
	local frame = self.Window:_createElement(self, name, name .. " " .. tostring(options.Description or "slider"), 78)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local valueLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(120, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row
	})
	self.Window:_track(valueLabel, {TextColor3 = "TextMuted"})
	local track = new("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundTransparency = 0,
		Parent = frame
	}, {corner(4)})
	self.Window:_track(track, {BackgroundColor3 = "Surface"})
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = track
	}, {corner(4)})
	self.Window:_track(fill, {BackgroundColor3 = "Accent"})
	local hit = new("TextButton", {
		Name = "Input",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, -7),
		Text = "",
		AutoButtonColor = false,
		Parent = track
	})
	local controller = {Type = "Slider", Flag = options.Flag}
	local dragging = false
	local function snap(number)
		if increment > 0 then
			number = math.floor((number - minValue) / increment + 0.5) * increment + minValue
		end
		return math.clamp(number, minValue, maxValue)
	end
	local function render(animated)
		local percent = 0
		if maxValue ~= minValue then
			percent = (value - minValue) / (maxValue - minValue)
		end
		local targetSize = UDim2.fromScale(math.clamp(percent, 0, 1), 1)
		if animated then
			tween(fill, 0.18, {Size = targetSize}, Enum.EasingStyle.Quint)
		else
			fill.Size = targetSize
		end
		valueLabel.Text = tostring(value) .. (suffix ~= "" and " " .. suffix or "")
	end
	local function updateFromX(x, loading)
		local percent = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		controller:Set(snap(minValue + (maxValue - minValue) * percent), loading)
	end
	function controller:Set(newValue, loading)
		value = snap(tonumber(newValue) or minValue)
		render(not loading)
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	local moveConnection = nil
	local endConnection = nil
	local function stopDraggingSlider()
		dragging = false
		if moveConnection then
			moveConnection:Disconnect()
			moveConnection = nil
		end
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
	end
	window._connections[#window._connections + 1] = hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		stopDraggingSlider()
		dragging = true
		updateFromX(input.Position.X)
		moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
			if dragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
				updateFromX(moveInput.Position.X)
			end
		end)
		endConnection = UserInputService.InputEnded:Connect(function(endInput)
			if endInput == input or endInput.UserInputType == input.UserInputType then
				stopDraggingSlider()
			end
		end)
	end)
	controller:Set(value, true)
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateInput(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Input")
	local value = tostring(options.CurrentValue or "")
	local frame = self.Window:_createElement(self, name, name .. " " .. tostring(options.PlaceholderText or options.Placeholder or "input"), 82)
	self:_headerRow(frame, name, options.Description)
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0,
		Text = value,
		PlaceholderText = tostring(options.PlaceholderText or options.Placeholder or "Type here"),
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame
	}, {corner(5), padding(10, 10, 0, 0), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(box, {BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "TextFaint"})
	local controller = {Type = "Input", Flag = options.Flag}
	function controller:Set(newValue, loading)
		value = tostring(newValue or "")
		box.Text = value
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	box.FocusLost:Connect(function(enterPressed)
		local text = box.Text
		if options.Numeric then
			local number = tonumber(text)
			if number then
				text = tostring(number)
				box.Text = text
			else
				box.Text = value
				return
			end
		end
		controller:Set(text)
		if options.RemoveTextAfterFocusLost or options.ClearOnSubmit then
			box.Text = ""
		end
		safeCall(options.FocusLostCallback, text, enterPressed)
	end)
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateDropdown(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Dropdown")
	local multiple = options.Multiple or options.MultiSelect or false
	local optionsList = options.Options or {}
	local selected = options.CurrentOption or options.CurrentValue or (multiple and {} or nil)
	if multiple and type(selected) ~= "table" then
		selected = {}
	elseif not multiple and type(selected) == "table" then
		selected = selected[1] and tostring(selected[1]) or nil
	end
	local searchableOptions = {}
	for _, item in ipairs(optionsList) do
		searchableOptions[#searchableOptions + 1] = tostring(item)
	end
	local frame = self.Window:_createElement(self, name, name .. " dropdown " .. table.concat(searchableOptions, " "), 86)
	self:_headerRow(frame, name, options.Description)
	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = frame
	}, {corner(5), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(button, {BackgroundColor3 = "Input"})
	local selectedText = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -42, 1, 0),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button
	})
	self.Window:_track(selectedText, {TextColor3 = "Text"})
	local arrow = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(20, 34),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "v",
		Parent = button
	})
	self.Window:_track(arrow, {TextColor3 = "TextMuted"})
	local list = new("Frame", {
		Name = "Options",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = frame
	}, {listLayout(Enum.FillDirection.Vertical, 6)})
	local controller = {Type = "Dropdown", Flag = options.Flag}
	local open = false
	local optionButtons = {}
	local function selectedList()
		if multiple then
			local values = {}
			for key, enabled in pairs(selected) do
				if enabled then
					values[#values + 1] = key
				end
			end
			table.sort(values)
			return values
		end
		if selected == nil then
			return {}
		end
		return {selected}
	end
	local function renderText()
		local values = selectedList()
		if #values == 0 then
			selectedText.Text = tostring(options.Placeholder or "Select an option")
		else
			selectedText.Text = table.concat(values, ", ")
		end
	end
	local function renderButtons()
		for _, b in ipairs(optionButtons) do
			if b then
				b:Destroy()
			end
		end
		optionButtons = {}
		for _, option in ipairs(optionsList) do
			local optionName = tostring(option)
			local optionButton = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				Text = optionName,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Parent = list
			}, {corner(4), padding(10, 10, 0, 0)})
			self.Window:_track(optionButton, {TextColor3 = "Text", BackgroundColor3 = "Surface"})
			optionButton.MouseButton1Click:Connect(function()
				if multiple then
					selected[optionName] = not selected[optionName]
				else
					selected = optionName
					open = false
					list.Visible = false
					arrow.Text = "v"
					tween(arrow, 0.2, {Rotation = 0}, Enum.EasingStyle.Quint)
					window:_queueSmartResize()
				end
				renderText()
				safeCall(options.Callback, controller:Get())
				window:_autoSave()
			end)
			optionButtons[#optionButtons + 1] = optionButton
		end
	end
	function controller:Set(newValue, loading)
		if multiple then
			selected = {}
			if type(newValue) == "table" then
				for key, item in pairs(newValue) do
					if type(key) == "string" and item == true then
						selected[key] = true
					elseif type(item) == "string" then
						selected[item] = true
					end
				end
			end
		else
			if type(newValue) == "table" then
				selected = tostring(newValue[1] or "")
			else
				selected = tostring(newValue or "")
			end
		end
		renderText()
		if not loading then
			safeCall(options.Callback, controller:Get())
			window:_autoSave()
		end
	end
	function controller:Get()
		if multiple then
			return selectedList()
		end
		return selected
	end
	function controller:Refresh(newOptions, keepValue)
		optionsList = newOptions or {}
		if not keepValue then
			selected = multiple and {} or nil
		end
		renderButtons()
		renderText()
	end
	button.MouseButton1Click:Connect(function()
		open = not open
		list.Visible = open
		arrow.Text = open and "^" or "v"
		tween(arrow, 0.22, {Rotation = open and 180 or 0}, Enum.EasingStyle.Quint)
		window:_queueSmartResize()
	end)
	renderButtons()
	renderText()
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateKeybind(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Keybind")
	local current = normalizeKey(options.CurrentKeybind or options.Keybind or Enum.KeyCode.RightControl)
	local listening = false
	local frame = self.Window:_createElement(self, name, name .. " keybind shortcut", 62)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(124, 32),
		Text = current.Name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AutoButtonColor = false,
		Parent = row
	}, {corner(5), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(button, {BackgroundColor3 = "Input", TextColor3 = "Text"})
	local controller = {Type = "Keybind", Flag = options.Flag}
	function controller:Set(newValue, loading)
		current = normalizeKey(newValue)
		button.Text = current.Name
		if not loading then
			safeCall(options.ChangedCallback, current)
			window:_autoSave()
		end
	end
	function controller:Get()
		return current.Name
	end
	button.MouseButton1Click:Connect(function()
		listening = true
		button.Text = "Press a key"
	end)
	local downConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isTyping() then
			return
		end
		if listening then
			if input.KeyCode ~= Enum.KeyCode.Unknown then
				listening = false
				controller:Set(input.KeyCode)
			end
			return
		end
		if input.KeyCode == current then
			if options.HoldToInteract then
				safeCall(options.Callback, true)
			else
				safeCall(options.Callback)
			end
		end
	end)
	self.Window._connections[#self.Window._connections + 1] = downConnection
	if options.HoldToInteract then
		local upConnection = UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == current then
				safeCall(options.Callback, false)
			end
		end)
		self.Window._connections[#self.Window._connections + 1] = upConnection
	end
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateProgress(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Progress")
	local range = options.Range or {0, 100}
	local minValue = tonumber(range[1]) or 0
	local maxValue = tonumber(range[2]) or 100
	local suffix = tostring(options.Suffix or "%")
	local value = tonumber(options.CurrentValue) or minValue
	local frame = self.Window:_createElement(self, name, name .. " progress", 72)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(120, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row
	})
	self.Window:_track(label, {TextColor3 = "TextMuted"})
	local track = new("Frame", {Size = UDim2.new(1, 0, 0, 8), Parent = frame}, {corner(4)})
	self.Window:_track(track, {BackgroundColor3 = "Surface"})
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track}, {corner(4)})
	self.Window:_track(fill, {BackgroundColor3 = "Accent"})
	local controller = {Type = "Progress"}
	function controller:Set(newValue)
		value = math.clamp(tonumber(newValue) or minValue, minValue, maxValue)
		local percent = maxValue ~= minValue and (value - minValue) / (maxValue - minValue) or 0
		tween(fill, 0.24, {Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1)}, Enum.EasingStyle.Quint)
		label.Text = tostring(value) .. suffix
	end
	function controller:Get()
		return value
	end
	controller:Set(value)
	return controller
end

function Tab:CreateColorPicker(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Color Picker")
	local value = tableToColor(options.Color or options.CurrentColor, getThemeValue(self.Window, "Accent"))
	local frame = self.Window:_createElement(self, name, name .. " color picker rgb presets", 112)
	frame:SetAttribute("AnchorlineAdaptive", "ColorPicker")
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)

	local rgbRow = new("Frame", {
		Name = "RGBRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = frame
	})

	local preview = new("TextButton", {
		Name = "Preview",
		Size = UDim2.fromOffset(54, 32),
		Text = "",
		AutoButtonColor = false,
		Parent = rgbRow
	}, {corner(8), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})

	local fields = new("Frame", {
		Name = "RGBFields",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.new(1, -66, 0, 32),
		Parent = rgbRow
	}, {listLayout(Enum.FillDirection.Horizontal, 8)})

	local boxes = {}
	local function makeBox(labelText)
		local box = new("TextBox", {
			Size = UDim2.new(1 / 3, -6, 1, 0),
			BackgroundTransparency = self.Window.FrostedGlass and 0.16 or 0,
			Text = "0",
			PlaceholderText = labelText,
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = fields
		}, {corner(8), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
		self.Window:_track(box, {BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "TextFaint"})
		boxes[labelText] = box
		return box
	end
	makeBox("R")
	makeBox("G")
	makeBox("B")

	local presets = new("Frame", {
		Name = "Presets",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = frame
	})
	local presetGrid = new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		CellPadding = UDim2.fromOffset(8, 8),
		CellSize = UDim2.fromOffset(32, 32)
	})
	presetGrid.Parent = presets

	local controller = {Type = "ColorPicker", Flag = options.Flag}
	local presetColors = options.Presets or {
		Color3.fromRGB(82, 121, 107),
		Color3.fromRGB(72, 112, 129),
		Color3.fromRGB(130, 94, 63),
		Color3.fromRGB(76, 142, 99),
		Color3.fromRGB(166, 121, 54),
		Color3.fromRGB(174, 66, 60),
		Color3.fromRGB(232, 228, 219),
		Color3.fromRGB(84, 91, 88)
	}

	local function relayout()
		if not frame or not frame.Parent then
			return
		end
		local width = math.max(frame.AbsoluteSize.X - 28, 240)
		local compact = width < 390
		local chipSize = compact and 30 or 32
		local gap = compact and 7 or 8
		local columns = math.max(1, math.floor((width + gap) / (chipSize + gap)))
		presetGrid.CellPadding = UDim2.fromOffset(gap, gap)
		presetGrid.CellSize = UDim2.fromOffset(chipSize, chipSize)
		presetGrid.FillDirectionMaxCells = columns
		local rows = math.max(1, math.ceil(#presetColors / columns))
		presets.Size = UDim2.new(1, 0, 0, rows * chipSize + math.max(rows - 1, 0) * gap)
		if compact then
			preview.Size = UDim2.fromOffset(48, 32)
			fields.Position = UDim2.fromOffset(58, 0)
			fields.Size = UDim2.new(1, -58, 0, 32)
		else
			preview.Size = UDim2.fromOffset(54, 32)
			fields.Position = UDim2.fromOffset(66, 0)
			fields.Size = UDim2.new(1, -66, 0, 32)
		end
	end

	local function render()
		preview.BackgroundColor3 = value
		local packed = colorToTable(value)
		boxes.R.Text = tostring(packed.R)
		boxes.G.Text = tostring(packed.G)
		boxes.B.Text = tostring(packed.B)
	end

	function controller:Set(newValue, loading)
		value = tableToColor(newValue, value)
		render()
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end

	local function updateFromBoxes()
		local r = tonumber(boxes.R.Text) or 0
		local g = tonumber(boxes.G.Text) or 0
		local b = tonumber(boxes.B.Text) or 0
		controller:Set(Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255)))
	end
	for _, box in pairs(boxes) do
		box.FocusLost:Connect(updateFromBoxes)
	end
	for index, color in ipairs(presetColors) do
		local chip = new("TextButton", {
			Name = "Preset" .. tostring(index),
			BackgroundColor3 = color,
			Text = "",
			AutoButtonColor = false,
			Parent = presets
		}, {corner(8), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
		chip.MouseEnter:Connect(function()
			tween(chip, 0.18, {BackgroundTransparency = 0.04}, Enum.EasingStyle.Quint)
		end)
		chip.MouseLeave:Connect(function()
			tween(chip, 0.2, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint)
		end)
		chip.MouseButton1Click:Connect(function()
			controller:Set(color)
		end)
	end

	self.Window:_addAdaptiveHandler(relayout)
	self.Window._connections[#self.Window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		relayout()
	end)
	self.Window._connections[#self.Window._connections + 1] = presetGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		presets.Size = UDim2.new(1, 0, 0, math.max(32, presetGrid.AbsoluteContentSize.Y))
		self.Window:_queueSmartResize()
	end)
	render()
	relayout()
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateInfoBox(options)
	options = options or {}
	local window = self.Window
	local kind = tostring(options.Type or options.Kind or "Info")
	local name = tostring(options.Title or options.Name or kind)
	local body = tostring(options.Content or options.Text or options.Description or "")
	local frame = window:_createElement(self, name, name .. " " .. body .. " info notice", 84)
	frame.AutomaticSize = Enum.AutomaticSize.None
	frame.ClipsDescendants = true
	local inheritedLayout = frame:FindFirstChildOfClass("UIListLayout")
	if inheritedLayout then
		inheritedLayout:Destroy()
	end
	local accent = window:_notificationColors(kind)
	local strip = new("Frame", {
		Name = "AccentStrip",
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(0, 4, 1, -28),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = frame
	}, {corner(2)})
	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -30, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
		Parent = frame
	})
	window:_track(title, {TextColor3 = "Text"})
	local label = new("TextLabel", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -30, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = body,
		Parent = frame
	})
	window:_track(label, {TextColor3 = "TextMuted"})
	local lastWidth = -1
	local resizeQueued = false
	local function resizeBox(force)
		if not frame or not frame.Parent then
			return
		end
		local width = math.floor(frame.AbsoluteSize.X)
		if width <= 40 then
			width = math.max(300, tonumber(window.SmartContentMinWidth) or 390)
		end
		if not force and math.abs(width - lastWidth) < 2 then
			return
		end
		lastWidth = width
		local textWidth = math.max(140, width - 48)
		local bodyHeight = measureWrappedText(body, 13, Enum.Font.Gotham, textWidth)
		local titleHeight = measureWrappedText(name, 14, Enum.Font.GothamMedium, textWidth)
		title.Size = UDim2.new(1, -30, 0, math.max(20, titleHeight))
		label.Position = UDim2.fromOffset(16, 18 + math.max(20, titleHeight) + 8)
		label.Size = UDim2.new(1, -30, 0, bodyHeight)
		local height = math.max(74, 18 + math.max(20, titleHeight) + 8 + bodyHeight + 18)
		frame.Size = UDim2.new(1, 0, 0, height)
		strip.Position = UDim2.fromOffset(0, 14)
		strip.Size = UDim2.new(0, 4, 1, -28)
		window:_refreshPageCanvases()
	end
	local function queueResize(force)
		if resizeQueued then
			return
		end
		resizeQueued = true
		task.defer(function()
			resizeQueued = false
			resizeBox(force)
			window:_queueSmartResize()
		end)
	end
	window._connections[#window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		queueResize(false)
	end)
	queueResize(true)
	task.delay(0.1, function() resizeBox(true) end)
	local controller = {}
	function controller:Set(value)
		body = tostring(value or "")
		label.Text = body
		frame:SetAttribute("SearchText", name .. " " .. body)
		lastWidth = -1
		queueResize(true)
	end
	function controller:Get()
		return body
	end
	return controller
end

function Tab:CreateBadge(options)
	options = options or {}
	local name = tostring(options.Name or "Badge")
	local value = tostring(options.Value or options.Text or "Ready")
	local frame = self.Window:_createElement(self, name, name .. " " .. value .. " badge status", 54)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local badge = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(104, 28),
		BackgroundTransparency = self.Window.FrostedGlass and 0.1 or 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = value,
		Parent = row
	}, {corner(8), padding(8, 8, 0, 0), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(badge, {BackgroundColor3 = "AccentSoft", TextColor3 = "Accent"})
	local controller = {}
	function controller:Set(newValue)
		value = tostring(newValue or "")
		badge.Text = value
		frame:SetAttribute("SearchText", name .. " " .. value)
	end
	function controller:Get()
		return value
	end
	return controller
end

function Tab:CreateStatCard(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Statistic")
	local value = tostring(options.Value or "0")
	local caption = tostring(options.Caption or options.Description or "")
	local frame = self.Window:_createElement(self, name, name .. " " .. value .. " stat metric", 92)
	frame:SetAttribute("AnchorlineMinWidth", 360)
	local top = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = frame
	})
	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -110, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
		Parent = top
	})
	self.Window:_track(title, {TextColor3 = "TextMuted"})
	local badgeText = tostring(options.Badge or options.Status or "")
	local badge = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(96, 24),
		BackgroundTransparency = self.Window.FrostedGlass and 0.12 or 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		Text = badgeText,
		Visible = badgeText ~= "",
		Parent = top
	}, {corner(8), padding(8, 8, 0, 0), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(badge, {BackgroundColor3 = "AccentSoft", TextColor3 = "Accent"})
	local valueLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = value,
		Parent = frame
	})
	self.Window:_track(valueLabel, {TextColor3 = "Text"})
	local captionLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = caption,
		Parent = frame
	})
	self.Window:_track(captionLabel, {TextColor3 = "TextMuted"})
	local controller = {Type = "StatCard"}
	function controller:Set(newValue, newCaption)
		value = tostring(newValue or "")
		valueLabel.Text = value
		if newCaption ~= nil then
			caption = tostring(newCaption or "")
			captionLabel.Text = caption
		end
		frame:SetAttribute("SearchText", name .. " " .. value .. " " .. caption)
		window:_queueSmartResize()
	end
	function controller:SetBadge(newBadge)
		badgeText = tostring(newBadge or "")
		badge.Text = badgeText
		badge.Visible = badgeText ~= ""
	end
	function controller:Get()
		return value
	end
	return controller
end

function Tab:CreateActionGrid(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Actions")
	local actions = options.Actions or options.Buttons or {}
	local frame = self.Window:_createElement(self, name, name .. " action buttons grid", 88)
	frame:SetAttribute("AnchorlineAdaptive", "ActionGrid")
	frame:SetAttribute("AnchorlineMinWidth", 380)
	self:_headerRow(frame, name, options.Description)
	local gridHolder = new("Frame", {
		Name = "ActionGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = frame
	})
	local grid = new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		CellPadding = UDim2.fromOffset(8, 8),
		CellSize = UDim2.fromOffset(128, 34)
	})
	grid.Parent = gridHolder
	local buttons = {}
	local function makeAction(action, index)
		local label = tostring(action.Name or action.Title or action.Text or ("Action " .. tostring(index)))
		local button = new("TextButton", {
			Name = "Action" .. tostring(index),
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			AutoButtonColor = false,
			Parent = gridHolder
		}, {corner(8), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
		self.Window:_track(button, {BackgroundColor3 = "Surface", TextColor3 = "Text"})
		button.MouseEnter:Connect(function()
			tween(button, 0.18, {BackgroundColor3 = getThemeValue(self.Window, "SurfaceHover")}, Enum.EasingStyle.Quint)
		end)
		button.MouseLeave:Connect(function()
			tween(button, 0.22, {BackgroundColor3 = getThemeValue(self.Window, "Surface")}, Enum.EasingStyle.Quint)
		end)
		button.MouseButton1Click:Connect(function()
			tween(button, 0.1, {BackgroundTransparency = 0.08}, Enum.EasingStyle.Quint)
			task.delay(0.12, function()
				if button and button.Parent then
					tween(button, 0.16, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint)
				end
			end)
			safeCall(action.Callback, label, index)
		end)
		buttons[#buttons + 1] = button
	end
	for index, action in ipairs(actions) do
		if type(action) == "table" then
			makeAction(action, index)
		else
			makeAction({Name = tostring(action)}, index)
		end
	end
	local function relayout()
		if not frame or not frame.Parent then return end
		local width = math.max(frame.AbsoluteSize.X - 28, 240)
		local minCell = tonumber(options.MinButtonWidth) or 118
		local gap = 8
		local columns = math.max(1, math.floor((width + gap) / (minCell + gap)))
		local cellWidth = math.floor((width - gap * math.max(columns - 1, 0)) / columns)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
		grid.CellSize = UDim2.fromOffset(math.max(minCell, cellWidth), 34)
		grid.FillDirectionMaxCells = columns
		local rows = math.max(1, math.ceil(math.max(#buttons, 1) / columns))
		gridHolder.Size = UDim2.new(1, 0, 0, rows * 34 + math.max(rows - 1, 0) * gap)
	end
	self.Window:_addAdaptiveHandler(relayout)
	self.Window._connections[#self.Window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
	local controller = {Type = "ActionGrid"}
	function controller:Refresh(newActions)
		for _, button in ipairs(buttons) do
			if button then button:Destroy() end
		end
		buttons = {}
		actions = newActions or {}
		for index, action in ipairs(actions) do
			if type(action) == "table" then makeAction(action, index) else makeAction({Name = tostring(action)}, index) end
		end
		relayout()
		window:_queueSmartResize()
	end
	return controller
end

function Tab:CreateSegmentedControl(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Segmented Control")
	local choices = options.Options or {"One", "Two"}
	local selected = tostring(options.CurrentOption or options.CurrentValue or choices[1] or "")
	local frame = self.Window:_createElement(self, name, name .. " segmented control " .. table.concat(choices, " "), 84)
	self:_headerRow(frame, name, options.Description)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = self.Window.FrostedGlass and 0.35 or 0,
		Parent = frame
	}, {corner(8), padding(3, 3, 3, 3), listLayout(Enum.FillDirection.Horizontal, 4)})
	self.Window:_track(row, {BackgroundColor3 = "Surface"})
	local controller = {Type = "SegmentedControl", Flag = options.Flag}
	local buttons = {}
	local function render(animated)
		for optionName, button in pairs(buttons) do
			local active = optionName == selected
			local props = {
				BackgroundColor3 = getThemeValue(self.Window, active and "Accent" or "Surface"),
				TextColor3 = getThemeValue(self.Window, active and "AccentText" or "TextMuted")
			}
			if animated then tween(button, 0.22, props, Enum.EasingStyle.Quint) else for k,v in pairs(props) do button[k] = v end end
		end
	end
	for _, option in ipairs(choices) do
		local optionName = tostring(option)
		local button = new("TextButton", {
			Size = UDim2.new(1 / math.max(#choices, 1), -3, 1, 0),
			Text = optionName,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			AutoButtonColor = false,
			Parent = row
		}, {corner(6)})
		buttons[optionName] = button
		button.MouseButton1Click:Connect(function()
			controller:Set(optionName)
		end)
	end
	function controller:Set(newValue, loading)
		selected = tostring(newValue or selected)
		render(not loading)
		if not loading then
			safeCall(options.Callback, selected)
			window:_autoSave()
		end
	end
	function controller:Get()
		return selected
	end
	render(false)
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateStepper(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Stepper")
	local range = options.Range or {0, 10}
	local minValue = tonumber(range[1]) or 0
	local maxValue = tonumber(range[2]) or 10
	local step = tonumber(options.Step or options.Increment) or 1
	local value = math.clamp(tonumber(options.CurrentValue) or minValue, minValue, maxValue)
	local frame = self.Window:_createElement(self, name, name .. " stepper number", 64)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = frame})
	self:_headerRow(row, name, options.Description)
	local controls = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(142, 32),
		BackgroundTransparency = 1,
		Parent = row
	}, {listLayout(Enum.FillDirection.Horizontal, 6)})
	local function makeButton(text)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(32, 30),
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = false,
			Parent = controls
		}, {corner(7), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
		self.Window:_track(b, {BackgroundColor3 = "Surface", TextColor3 = "TextMuted"})
		return b
	end
	local minus = makeButton("−")
	local valueText = new("TextLabel", {
		Size = UDim2.fromOffset(58, 30),
		BackgroundTransparency = self.Window.FrostedGlass and 0.2 or 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Parent = controls
	}, {corner(7), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(valueText, {BackgroundColor3 = "Input", TextColor3 = "Text"})
	local plus = makeButton("+")
	local controller = {Type = "Stepper", Flag = options.Flag}
	local function render()
		valueText.Text = tostring(value)
	end
	function controller:Set(newValue, loading)
		value = math.clamp(tonumber(newValue) or value, minValue, maxValue)
		render()
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	minus.MouseButton1Click:Connect(function() controller:Set(value - step) end)
	plus.MouseButton1Click:Connect(function() controller:Set(value + step) end)
	render()
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateTextArea(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or "Text Area")
	local value = tostring(options.CurrentValue or "")
	local height = tonumber(options.Height) or 126
	local frame = self.Window:_createElement(self, name, name .. " multiline textarea notes", height)
	self:_headerRow(frame, name, options.Description)
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, math.max(54, height - 58)),
		BackgroundTransparency = self.Window.FrostedGlass and 0.18 or 0,
		Text = value,
		PlaceholderText = tostring(options.PlaceholderText or options.Placeholder or "Type here"),
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame
	}, {corner(8), padding(10, 10, 8, 8), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	self.Window:_track(box, {BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "TextFaint"})
	local controller = {Type = "TextArea", Flag = options.Flag}
	function controller:Set(newValue, loading)
		value = tostring(newValue or "")
		box.Text = value
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	box.FocusLost:Connect(function(enterPressed)
		controller:Set(box.Text)
		safeCall(options.FocusLostCallback, box.Text, enterPressed)
	end)
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateSpacer(height)
	local frame = new("Frame", {
		Name = "Spacer",
		Size = UDim2.new(1, 0, 0, tonumber(height) or 8),
		BackgroundTransparency = 1,
		Parent = self.Page
	})
	self.Elements[#self.Elements + 1] = frame
	return frame
end

function Tab:CreateSeparator()
	return self:CreateDivider()
end



Anchorline.Motion.Micro = 0.14
Anchorline.Motion.Fast = 0.24
Anchorline.Motion.Base = 0.38
Anchorline.Motion.Panel = 0.5
Anchorline.Motion.Exit = 0.3

local function anchorlineKindColor(window, kind)
	kind = tostring(kind or "Info")
	if kind == "Success" or kind == "Good" or kind == "Passed" then
		return getThemeValue(window, "Success")
	elseif kind == "Warning" or kind == "Warn" or kind == "Partial" then
		return getThemeValue(window, "Warning")
	elseif kind == "Error" or kind == "Danger" or kind == "Fail" or kind == "Failed" then
		return getThemeValue(window, "Danger")
	else
		return getThemeValue(window, "Accent")
	end
end

local function anchorlineClearChildren(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") or child:IsA("UICorner") or child:IsA("UIStroke") then
			continue
		end
		child:Destroy()
	end
end

local function anchorlineSetTextSize(textLabel, size)
	if textLabel and textLabel.Parent then
		pcall(function()
			textLabel.TextSize = size
		end)
	end
end

function Window:GetTab(name)
	local target = tostring(name or "")
	for _, tab in ipairs(self.Tabs) do
		if tab.Name == target then
			return tab
		end
	end
	return nil
end

function Window:CreateOrGetTab(name, icon, description)
	local existing = self:GetTab(name)
	if existing then
		if description ~= nil then
			existing.Description = tostring(description)
		end
		return existing
	end
	return self:CreateTab(name, icon, description)
end

function Window:SetTitle(text)
	self.Title = tostring(text or "")
	local title = self.Header and self.Header:FindFirstChild("Title")
	if title then
		title.Text = self.Title
	end
	return self
end

function Window:SetSubtitle(text)
	self.Subtitle = tostring(text or "")
	local subtitle = self.Header and self.Header:FindFirstChild("Subtitle")
	if subtitle then
		subtitle.Text = self.Subtitle
	end
	return self
end

function Window:SetSize(width, height, animated)
	width = tonumber(width) or self.Width
	height = tonumber(height) or self.Height
	local viewport = getViewportSize()
	local maxWidth = math.min(self.MaxWidth or viewport.X, viewport.X - (self.SmartViewportMargin or 44) * 2)
	local maxHeight = math.min(self.MaxHeight or viewport.Y, viewport.Y - (self.SmartViewportMargin or 44) * 2)
	width, height = clampVectorSize(width, height, self.MinWidth or 420, self.MinHeight or 320, maxWidth, maxHeight)
	self.Width = width
	self.Height = height
	if animated then
		tween(self.Root, Anchorline.Motion.Panel, {Size = UDim2.fromOffset(width, height)}, Enum.EasingStyle.Quint)
	else
		self.Root.Size = UDim2.fromOffset(width, height)
	end
	task.defer(function()
		if self.Root and self.Root.Parent then
			self:RefreshLayout(false)
		end
	end)
	return self
end

function Window:SetPosition(position, animated)
	if typeof(position) ~= "UDim2" then
		return self
	end
	if animated then
		tween(self.Root, Anchorline.Motion.Panel, {Position = position}, Enum.EasingStyle.Quint)
	else
		self.Root.Position = position
	end
	return self
end

function Window:SetSmartResize(enabled)
	self.SmartResizeEnabled = enabled and true or false
	if self.SmartResizeEnabled then
		self:SmartResize(true)
	else
		self:RefreshLayout(false)
	end
	return self
end

function Window:SetAccentColor(color)
	if typeof(color) ~= "Color3" then
		return self
	end
	local custom = {}
	for key, value in pairs(self.Theme or Anchorline.Themes.Workbench) do
		custom[key] = value
	end
	custom.Accent = color
	custom.AccentHover = color:Lerp(Color3.new(0, 0, 0), 0.12)
	custom.AccentSoft = color:Lerp(Color3.new(1, 1, 1), 0.78)
	self.Theme = custom
	self.ThemeName = "CustomAccent"
	self:_applyTheme()
	return self
end

function Window:SetGlassTransparency(value)
	local transparency = math.clamp(tonumber(value) or self.GlassTransparency or 0.12, 0, 1)
	self.GlassTransparency = transparency
	if self.Root then
		tween(self.Root, Anchorline.Motion.Base, {BackgroundTransparency = self.FrostedGlass and transparency or 0}, Enum.EasingStyle.Quint)
	end
	return self
end

function Window:SetBlurSize(size)
	self.BlurSize = math.clamp(tonumber(size) or self.BlurSize or 10, 0, 30)
	if self._blurEffect then
		tween(self._blurEffect, Anchorline.Motion.Base, {Size = self.BlurSize}, Enum.EasingStyle.Quint)
	end
	return self
end

function Window:BringToFront()
	if self.Gui then
		self.Gui.DisplayOrder = math.max(self.Gui.DisplayOrder or 0, 1000) + 1
	end
	return self
end

function Window:FitContent(animated)
	return self:SmartResize(animated ~= false)
end

function Window:Notify(options)
	options = options or {}
	local kind = tostring(options.Type or options.Kind or "Info")
	local accent = anchorlineKindColor(self, kind)
	local duration = tonumber(options.Duration)
	if duration == nil then duration = 4 end
	local actions = type(options.Actions) == "table" and options.Actions or nil
	local closed = false

	local wrapper = new("Frame", {
		Name = "NotificationSlot",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = self.NotificationList,
		ZIndex = 60
	})

	local card = new("Frame", {
		Name = "NotificationCard",
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -64, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = wrapper,
		ZIndex = 61
	}, {
		corner(14),
		padding(14, 14, 13, 12),
		listLayout(Enum.FillDirection.Vertical, 8)
	})
	self:_track(card, {BackgroundColor3 = "Panel"})
	local cardStroke = stroke(getThemeValue(self, "Stroke"), 1, 1)
	cardStroke.Parent = card
	cardStroke.ZIndex = 62
	self:_track(cardStroke, {Color = "Stroke"})

	local header = new("Frame", {
		Name = "NotificationHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = card,
		ZIndex = 63
	})
	local badge = new("Frame", {
		Name = "StatusBadge",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = header,
		ZIndex = 64
	}, {corner(8)})
	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -52, 0, 24),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(options.Title or "Notification"),
		TextTransparency = 1,
		Parent = header,
		ZIndex = 64
	})
	self:_track(title, {TextColor3 = "Text"})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextTransparency = 1,
		AutoButtonColor = false,
		Parent = header,
		ZIndex = 65
	})
	self:_track(close, {TextColor3 = "TextFaint"})
	local content = new("TextLabel", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tostring(options.Content or ""),
		TextTransparency = 1,
		Parent = card,
		ZIndex = 64
	})
	self:_track(content, {TextColor3 = "TextMuted"})

	local actionRow
	if actions and #actions > 0 then
		actionRow = new("Frame", {
			Name = "Actions",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = card,
			ZIndex = 64
		}, {listLayout(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)})
	end

	local progressTrack = new("Frame", {
		Name = "ProgressTrack",
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundTransparency = duration > 0 and 0.82 or 1,
		BorderSizePixel = 0,
		Parent = card,
		ZIndex = 64
	}, {corner(2)})
	progressTrack.BackgroundColor3 = accent
	local progressFill = new("Frame", {
		Name = "ProgressFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = accent,
		BackgroundTransparency = duration > 0 and 0.12 or 1,
		BorderSizePixel = 0,
		Parent = progressTrack,
		ZIndex = 65
	}, {corner(2)})

	local controller = {Frame = wrapper, Card = card}
	local function closeNotification()
		if closed then return end
		closed = true
		if not card or not card.Parent then return end
		tween(card, Anchorline.Motion.Exit, {Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -68, 0, 0), BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(cardStroke, 0.24, {Transparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(badge, 0.2, {BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(title, 0.2, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(close, 0.2, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(content, 0.2, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		if actionRow then
			for _, item in ipairs(actionRow:GetChildren()) do
				if item:IsA("TextButton") then tween(item, 0.2, {TextTransparency = 1, BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end
			end
		end
		task.delay(0.36, function()
			if wrapper then wrapper:Destroy() end
		end)
	end
	controller.Close = closeNotification
	controller.Destroy = closeNotification
	close.MouseButton1Click:Connect(closeNotification)

	if actionRow then
		for index, action in ipairs(actions) do
			local label = tostring(action.Text or action.Name or action.Title or ("Action " .. index))
			local actionButton = new("TextButton", {
				Name = "Action" .. index,
				Size = UDim2.fromOffset(92, 28),
				BackgroundTransparency = 1,
				TextTransparency = 1,
				Text = label,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				AutoButtonColor = false,
				Parent = actionRow,
				ZIndex = 66
			}, {corner(8), stroke(getThemeValue(self, "StrokeSoft"), 1, 0)})
			self:_track(actionButton, {BackgroundColor3 = action.Primary and "Accent" or "Surface", TextColor3 = action.Primary and "AccentText" or "Text"})
			actionButton.MouseEnter:Connect(function()
				tween(actionButton, 0.18, {BackgroundTransparency = 0.04}, Enum.EasingStyle.Quint)
			end)
			actionButton.MouseLeave:Connect(function()
				tween(actionButton, 0.2, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint)
			end)
			actionButton.MouseButton1Click:Connect(function()
				safeCall(action.Callback, controller, index)
				if action.CloseOnClick ~= false then
					closeNotification()
				end
			end)
		end
	end

	task.defer(function()
		if not card or not card.Parent then return end
		tween(card, Anchorline.Motion.Panel, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = self.FrostedGlass and 0.08 or 0}, Enum.EasingStyle.Quint)
		tween(cardStroke, 0.38, {Transparency = 0}, Enum.EasingStyle.Quint)
		tween(badge, 0.34, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint)
		tween(title, 0.34, {TextTransparency = 0}, Enum.EasingStyle.Quint)
		tween(close, 0.34, {TextTransparency = 0.18}, Enum.EasingStyle.Quint)
		tween(content, 0.38, {TextTransparency = 0}, Enum.EasingStyle.Quint)
		if actionRow then
			for _, item in ipairs(actionRow:GetChildren()) do
				if item:IsA("TextButton") then tween(item, 0.34, {TextTransparency = 0, BackgroundTransparency = 0}, Enum.EasingStyle.Quint) end
			end
		end
		if duration > 0 then
			tween(progressFill, duration, {Size = UDim2.fromScale(0, 1)}, Enum.EasingStyle.Linear)
		end
	end)
	if duration > 0 then
		task.delay(duration, closeNotification)
	end
	return controller
end

function Tab:Clear()
	for _, child in ipairs(self.Page:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end
	self.Elements = {}
	self.Window:_refreshPageCanvases()
	self.Window:_queueSmartResize()
	return self
end

function Tab:CreateHero(options)
	options = options or {}
	local window = self.Window
	local titleText = tostring(options.Title or options.Name or self.Name)
	local subtitleText = tostring(options.Subtitle or options.Description or "")
	local bodyText = tostring(options.Content or options.Text or "")
	local height = tonumber(options.Height) or 132
	local frame = window:_createElement(self, titleText, titleText .. " " .. subtitleText .. " " .. bodyText .. " hero header", height)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	frame.BackgroundTransparency = window.FrostedGlass and 0.08 or frame.BackgroundTransparency
	local accentRail = new("Frame", {
		Name = "HeroAccent",
		Size = UDim2.new(0, 5, 1, 0),
		BorderSizePixel = 0,
		Parent = frame
	}, {corner(3)})
	accentRail.BackgroundColor3 = anchorlineKindColor(window, options.Type or options.Kind or "Info")
	local iconBox = new("Frame", {
		Name = "HeroIconBox",
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = window.FrostedGlass and 0.12 or 0,
		Parent = frame
	}, {corner(14), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(iconBox, {BackgroundColor3 = "AccentSoft"})
	local asset = window:_resolveIcon(options.Icon or options.Image)
	if asset then
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(24, 24),
			ScaleType = Enum.ScaleType.Fit,
			Image = asset.Image,
			ImageColor3 = options.Tint == false and Color3.fromRGB(255, 255, 255) or getThemeValue(window, "Accent"),
			Parent = iconBox
		})
		if asset.ImageRectOffset then image.ImageRectOffset = asset.ImageRectOffset end
		if asset.ImageRectSize then image.ImageRectSize = asset.ImageRectSize end
	else
		local vector = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(20, 20), Parent = iconBox})
		local shapes = createVectorIcon(vector, options.Icon or titleText)
		for _, shape in ipairs(shapes) do
			if shape:IsA("TextLabel") then shape.TextColor3 = getThemeValue(window, "Accent") else shape.BackgroundColor3 = getThemeValue(window, "Accent") end
		end
	end
	local title = new("TextLabel", {
		Name = "HeroTitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(80, 17),
		Size = UDim2.new(1, -96, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = titleText,
		Parent = frame
	})
	window:_track(title, {TextColor3 = "Text"})
	local subtitle = new("TextLabel", {
		Name = "HeroSubtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(80, 44),
		Size = UDim2.new(1, -96, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = subtitleText,
		Parent = frame
	})
	window:_track(subtitle, {TextColor3 = "TextMuted"})
	local body = new("TextLabel", {
		Name = "HeroBody",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 78),
		Size = UDim2.new(1, -36, 0, 34),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = bodyText,
		Parent = frame
	})
	window:_track(body, {TextColor3 = "TextMuted"})
	local controller = {}
	function controller:SetTitle(value)
		title.Text = tostring(value or "")
		frame:SetAttribute("SearchText", title.Text .. " " .. subtitle.Text .. " " .. body.Text)
	end
	function controller:SetSubtitle(value)
		subtitle.Text = tostring(value or "")
		frame:SetAttribute("SearchText", title.Text .. " " .. subtitle.Text .. " " .. body.Text)
	end
	function controller:SetContent(value)
		body.Text = tostring(value or "")
		frame:SetAttribute("SearchText", title.Text .. " " .. subtitle.Text .. " " .. body.Text)
	end
	return controller
end

function Tab:CreateCallout(options)
	options = options or {}
	local window = self.Window
	local kind = tostring(options.Type or options.Kind or "Info")
	local titleText = tostring(options.Title or options.Name or kind)
	local bodyText = tostring(options.Content or options.Text or options.Description or "")
	local action = options.Action
	local frame = window:_createElement(self, titleText, titleText .. " " .. bodyText .. " callout", action and 96 or 78)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local inheritedLayout = frame:FindFirstChildOfClass("UIListLayout")
	if inheritedLayout then inheritedLayout:Destroy() end
	local accent = anchorlineKindColor(window, kind)
	local icon = new("Frame", {Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = accent, BackgroundTransparency = 0, Parent = frame}, {corner(8)})
	local mark = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = kind == "Success" and "✓" or kind == "Warning" and "!" or (kind == "Error" or kind == "Danger") and "×" or "i", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = getThemeValue(window, "AccentText"), Parent = icon})
	local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 13), Size = UDim2.new(1, -66, 0, 20), Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = titleText, Parent = frame})
	window:_track(title, {TextColor3 = "Text"})
	local body = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 39), Size = UDim2.new(1, action and -170 or -66, 0, 34), Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = bodyText, Parent = frame})
	window:_track(body, {TextColor3 = "TextMuted"})
	if action then
		local button = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 13), Size = UDim2.fromOffset(104, 30), Text = tostring(action.Text or action.Name or "Open"), Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, Parent = frame}, {corner(8)})
		window:_track(button, {BackgroundColor3 = "Accent", TextColor3 = "AccentText"})
		button.MouseEnter:Connect(function() tween(button, 0.18, {BackgroundTransparency = 0.06}, Enum.EasingStyle.Quint) end)
		button.MouseLeave:Connect(function() tween(button, 0.2, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint) end)
		button.MouseButton1Click:Connect(function() safeCall(action.Callback) end)
	end
	local controller = {}
	function controller:Set(value)
		bodyText = tostring(value or "")
		body.Text = bodyText
		frame:SetAttribute("SearchText", titleText .. " " .. bodyText)
	end
	return controller
end

function Tab:CreateStatusList(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Status List")
	local items = options.Items or {}
	local frame = window:_createElement(self, name, name .. " status list", 60 + math.max(#items, 1) * 32)
	frame:SetAttribute("AnchorlineMinWidth", 400)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Rows", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#items, 1) * 32), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 6)})
	local rows = {}
	local function renderRow(item, index)
		local row = new("Frame", {Name = "StatusRow" .. index, BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Size = UDim2.new(1, 0, 0, 28), Parent = holder}, {corner(8), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(row, {BackgroundColor3 = "Surface"})
		local statusColor = anchorlineKindColor(window, item.Type or item.Status or item.Kind or "Info")
		new("Frame", {Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = statusColor, BorderSizePixel = 0, Parent = row}, {corner(4)})
		local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(0.55, -28, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Name or item.Title or item[1] or "Item"), Parent = row})
		window:_track(label, {TextColor3 = "Text"})
		local value = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.45, -18, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Value or item.Text or item[2] or ""), Parent = row})
		window:_track(value, {TextColor3 = "TextMuted"})
		rows[#rows + 1] = {Frame = row, Label = label, Value = value}
	end
	local controller = {Type = "StatusList"}
	function controller:SetItems(newItems)
		items = newItems or {}
		anchorlineClearChildren(holder)
		rows = {}
		for index, item in ipairs(items) do renderRow(type(item) == "table" and item or {Name = tostring(item)}, index) end
		holder.Size = UDim2.new(1, 0, 0, math.max(#items, 1) * 34)
		frame.Size = UDim2.new(1, 0, 0, 58 + math.max(#items, 1) * 34)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	function controller:GetItems() return items end
	controller:SetItems(items)
	return controller
end

function Tab:CreateDataTable(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Data Table")
	local columns = options.Columns or {"Name", "Value"}
	local rows = options.Rows or {}
	local rowHeight = tonumber(options.RowHeight) or 30
	local maxVisibleRows = tonumber(options.MaxVisibleRows) or 8
	local frame = window:_createElement(self, name, name .. " table data rows", 96 + math.min(math.max(#rows, 1), maxVisibleRows) * rowHeight)
	frame:SetAttribute("AnchorlineMinWidth", 440)
	self:_headerRow(frame, name, options.Description)
	local tableFrame = new("Frame", {Name = "Table", BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Size = UDim2.new(1, 0, 0, rowHeight * (math.min(#rows, maxVisibleRows) + 1) + 4), Parent = frame}, {corner(10), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(tableFrame, {BackgroundColor3 = "Surface"})
	local header = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rowHeight), Parent = tableFrame})
	local function makeCell(parent, text, columnIndex, columnCount, font, colorKey)
		local cell = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new((columnIndex - 1) / columnCount, 10, 0, 0), Size = UDim2.new(1 / columnCount, -20, 1, 0), Font = font or Enum.Font.Gotham, TextSize = 12, TextXAlignment = columnIndex == columnCount and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(text or ""), Parent = parent})
		window:_track(cell, {TextColor3 = colorKey or "TextMuted"})
		return cell
	end
	for i, col in ipairs(columns) do makeCell(header, col, i, math.max(#columns, 1), Enum.Font.GothamMedium, "Text") end
	local list = new("ScrollingFrame", {Name = "Rows", Position = UDim2.fromOffset(0, rowHeight), Size = UDim2.new(1, 0, 1, -rowHeight), CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Active = true, ScrollingEnabled = #rows > maxVisibleRows, ScrollBarThickness = #rows > maxVisibleRows and 4 or 0, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = tableFrame}, {listLayout(Enum.FillDirection.Vertical, 0)})
	local controller = {Type = "DataTable"}
	function controller:SetRows(newRows)
		rows = newRows or {}
		anchorlineClearChildren(list)
		for rowIndex, rowData in ipairs(rows) do
			local row = new("Frame", {Name = "Row" .. rowIndex, BackgroundTransparency = rowIndex % 2 == 0 and 0.72 or 1, Size = UDim2.new(1, 0, 0, rowHeight), Parent = list})
			row.BackgroundColor3 = getThemeValue(window, "PanelAlt")
			for colIndex = 1, math.max(#columns, 1) do
				local value = type(rowData) == "table" and (rowData[colIndex] or rowData[columns[colIndex]]) or rowData
				makeCell(row, value, colIndex, math.max(#columns, 1), Enum.Font.Gotham, "TextMuted")
			end
		end
		local visibleRows = math.min(math.max(#rows, 1), maxVisibleRows)
		tableFrame.Size = UDim2.new(1, 0, 0, rowHeight * (visibleRows + 1) + 4)
		list.CanvasSize = UDim2.fromOffset(0, #rows * rowHeight + 2)
		list.ScrollingEnabled = #rows > maxVisibleRows
		list.ScrollBarThickness = #rows > maxVisibleRows and 4 or 0
		frame.Size = UDim2.new(1, 0, 0, 62 + tableFrame.Size.Y.Offset)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	function controller:GetRows() return rows end
	controller:SetRows(rows)
	return controller
end

function Tab:CreateLogConsole(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Console")
	local height = tonumber(options.Height) or 180
	local lines = {}
	local maxLines = tonumber(options.MaxLines) or 200
	local frame = window:_createElement(self, name, name .. " console log output", height + 62)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local console = new("ScrollingFrame", {Name = "Log", Size = UDim2.new(1, 0, 0, height), CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Active = true, ScrollingEnabled = true, ScrollBarThickness = 4, BackgroundTransparency = window.FrostedGlass and 0.18 or 0, BorderSizePixel = 0, Parent = frame}, {corner(10), padding(10, 10, 8, 8)})
	window:_track(console, {BackgroundColor3 = "Surface", ScrollBarImageColor3 = "Accent"})
	local text = new("TextLabel", {Name = "Text", BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = "", Parent = console})
	window:_track(text, {TextColor3 = "TextMuted"})
	local controller = {Type = "LogConsole"}
	local function refresh()
		text.Text = table.concat(lines, "\n")
		task.defer(function()
			if text and text.Parent then
				console.CanvasSize = UDim2.fromOffset(0, math.max(height + 1, text.AbsoluteSize.Y + 18))
				console.CanvasPosition = Vector2.new(0, math.max(0, console.CanvasSize.Y.Offset))
			end
		end)
	end
	function controller:Append(value, kind)
		local prefix = kind and ("[" .. tostring(kind) .. "] ") or ""
		lines[#lines + 1] = prefix .. tostring(value or "")
		while #lines > maxLines do table.remove(lines, 1) end
		refresh()
	end
	function controller:Clear()
		lines = {}
		refresh()
	end
	function controller:SetLines(newLines)
		lines = {}
		for _, line in ipairs(newLines or {}) do lines[#lines + 1] = tostring(line) end
		refresh()
	end
	function controller:GetLines() return lines end
	refresh()
	return controller
end

function Tab:CreateSearchableList(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Searchable List")
	local items = options.Items or {}
	local height = tonumber(options.Height) or 210
	local frame = window:_createElement(self, name, name .. " searchable list", height + 100)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local search = new("TextBox", {Name = "Search", Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Text = "", PlaceholderText = tostring(options.Placeholder or "Filter items"), ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame}, {corner(9), padding(10, 10, 0, 0), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(search, {BackgroundColor3 = "Input", TextColor3 = "Text", PlaceholderColor3 = "TextFaint"})
	local listFrame = new("ScrollingFrame", {Name = "Items", Size = UDim2.new(1, 0, 0, height), CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Active = true, ScrollingEnabled = true, ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 6)})
	window:_track(listFrame, {ScrollBarImageColor3 = "Accent"})
	local buttons = {}
	local controller = {Type = "SearchableList"}
	local function makeButton(item, index)
		local label = tostring(type(item) == "table" and (item.Name or item.Title or item.Text or item[1]) or item)
		local value = type(item) == "table" and (item.Value or item.Id or item[2] or label) or item
		local button = new("TextButton", {Name = "Item" .. index, Size = UDim2.new(1, -6, 0, 32), BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Text = label, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Parent = listFrame}, {corner(8), padding(10, 10, 0, 0), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(button, {BackgroundColor3 = "Surface", TextColor3 = "Text"})
		button:SetAttribute("SearchText", label:lower())
		button.MouseEnter:Connect(function() tween(button, 0.16, {BackgroundColor3 = getThemeValue(window, "SurfaceHover")}, Enum.EasingStyle.Quint) end)
		button.MouseLeave:Connect(function() tween(button, 0.2, {BackgroundColor3 = getThemeValue(window, "Surface")}, Enum.EasingStyle.Quint) end)
		button.MouseButton1Click:Connect(function() safeCall(options.Callback, value, item, index) end)
		buttons[#buttons + 1] = button
	end
	local function applyFilter()
		local query = search.Text:lower()
		local visible = 0
		for _, button in ipairs(buttons) do
			local match = query == "" or tostring(button:GetAttribute("SearchText") or ""):find(query, 1, true) ~= nil
			button.Visible = match
			if match then visible += 1 end
		end
		listFrame.CanvasSize = UDim2.fromOffset(0, math.max(height + 1, visible * 38))
	end
	function controller:SetItems(newItems)
		items = newItems or {}
		anchorlineClearChildren(listFrame)
		buttons = {}
		for index, item in ipairs(items) do makeButton(item, index) end
		applyFilter()
	end
	function controller:GetItems() return items end
	search:GetPropertyChangedSignal("Text"):Connect(applyFilter)
	controller:SetItems(items)
	return controller
end

function Tab:CreateImageCard(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Image")
	local caption = tostring(options.Caption or options.Description or "")
	local height = tonumber(options.Height) or 180
	local frame = window:_createElement(self, name, name .. " " .. caption .. " image card", height + 72)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, caption)
	local box = new("Frame", {Name = "ImageBox", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = window.FrostedGlass and 0.16 or 0, Parent = frame}, {corner(12), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(box, {BackgroundColor3 = "Surface"})
	local image = new("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), ScaleType = options.ScaleType or Enum.ScaleType.Fit, Parent = box})
	local asset = window:_resolveIcon(options.Image or options.Icon or options.Asset)
	if asset then
		image.Image = asset.Image
		if asset.ImageRectOffset then image.ImageRectOffset = asset.ImageRectOffset end
		if asset.ImageRectSize then image.ImageRectSize = asset.ImageRectSize end
	end
	local controller = {Image = image, Frame = frame}
	function controller:SetImage(assetValue)
		local resolved = window:_resolveIcon(assetValue)
		if resolved then
			image.Image = resolved.Image
			image.ImageRectOffset = resolved.ImageRectOffset or Vector2.new(0, 0)
			image.ImageRectSize = resolved.ImageRectSize or Vector2.new(0, 0)
		end
	end
	return controller
end

function Tab:CreateLoadingSpinner(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Loading")
	local labelText = tostring(options.Text or options.Description or "Working")
	local frame = window:_createElement(self, name, name .. " loading spinner", 72)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = frame})
	local spinner = new("Frame", {Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Parent = row})
	local ringA = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 4), BorderSizePixel = 0, BackgroundColor3 = getThemeValue(window, "Accent"), Parent = spinner}, {corner(2)})
	local ringB = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 28), BorderSizePixel = 0, BackgroundColor3 = getThemeValue(window, "Accent"), BackgroundTransparency = 0.45, Parent = spinner}, {corner(2)})
	local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -48, 0, 22), Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Text = name, Parent = row})
	window:_track(title, {TextColor3 = "Text"})
	local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 22), Size = UDim2.new(1, -48, 0, 18), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = labelText, Parent = row})
	window:_track(label, {TextColor3 = "TextMuted"})
	local running = true
	local rotation = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not running or not spinner or spinner.Parent == nil then
			if connection then connection:Disconnect() end
			return
		end
		rotation = (rotation + dt * 180) % 360
		spinner.Rotation = rotation
	end)
	window._connections[#window._connections + 1] = connection
	local controller = {Type = "LoadingSpinner"}
	function controller:SetText(value)
		labelText = tostring(value or "")
		label.Text = labelText
	end
	function controller:Start()
		running = true
	end
	function controller:Stop()
		running = false
	end
	function controller:Destroy()
		running = false
		if connection then connection:Disconnect() end
		if frame then frame:Destroy() end
	end
	return controller
end

function Tab:CreateKeyValue(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Details")
	local items = options.Items or options.Values or {}
	local frame = window:_createElement(self, name, name .. " key value details", 58 + math.max(#items, 1) * 28)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Pairs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#items, 1) * 28), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 4)})
	local controller = {Type = "KeyValue"}
	function controller:SetItems(newItems)
		items = newItems or {}
		anchorlineClearChildren(holder)
		for index, item in ipairs(items) do
			local key = tostring(type(item) == "table" and (item.Key or item.Name or item[1]) or index)
			local value = tostring(type(item) == "table" and (item.Value or item.Text or item[2]) or item)
			local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = holder})
			local left = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(0.45, -4, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = key, Parent = row})
			window:_track(left, {TextColor3 = "TextMuted"})
			local right = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.55, -4, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = value, Parent = row})
			window:_track(right, {TextColor3 = "Text"})
		end
		holder.Size = UDim2.new(1, 0, 0, math.max(#items, 1) * 28)
		frame.Size = UDim2.new(1, 0, 0, 58 + math.max(#items, 1) * 28)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	function controller:GetItems() return items end
	controller:SetItems(items)
	return controller
end



function Tab:CreateToolbar(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Toolbar")
	local tools = options.Tools or options.Actions or options.Buttons or {}
	local frame = window:_createElement(self, name, name .. " toolbar quick actions", 74)
	frame:SetAttribute("AnchorlineAdaptive", "Toolbar")
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "ToolbarButtons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = frame})
	local grid = new("UIGridLayout", {SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, CellPadding = UDim2.fromOffset(8, 8), CellSize = UDim2.fromOffset(110, 34)})
	grid.Parent = holder
	local buttons = {}
	local function build(tool, index)
		local label = tostring(tool.Name or tool.Title or tool.Text or ("Tool " .. index))
		local button = new("TextButton", {Name = "Tool" .. index, Text = "", AutoButtonColor = false, Parent = holder}, {corner(9), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(button, {BackgroundColor3 = tool.Primary and "Accent" or "Surface", TextColor3 = tool.Primary and "AccentText" or "Text"})
		local asset = window:_resolveIcon(tool.Icon or tool.Image)
		if asset then
			local image = new("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(18, 18), ScaleType = Enum.ScaleType.Fit, Image = asset.Image, ImageColor3 = tool.Tint == false and Color3.fromRGB(255, 255, 255) or getThemeValue(window, tool.Primary and "AccentText" or "Accent"), Parent = button})
			if asset.ImageRectOffset then image.ImageRectOffset = asset.ImageRectOffset end
			if asset.ImageRectSize then image.ImageRectSize = asset.ImageRectSize end
		end
		local textLabel = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(asset and 34 or 10, 0), Size = UDim2.new(1, asset and -42 or -20, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = label, Parent = button})
		window:_track(textLabel, {TextColor3 = tool.Primary and "AccentText" or "Text"})
		button.MouseEnter:Connect(function() tween(button, 0.16, {BackgroundTransparency = 0.06}, Enum.EasingStyle.Quint) end)
		button.MouseLeave:Connect(function() tween(button, 0.2, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint) end)
		button.MouseButton1Click:Connect(function() safeCall(tool.Callback, label, index, tool) end)
		buttons[#buttons + 1] = button
	end
	local function relayout()
		if not frame or not frame.Parent then return end
		local width = math.max(frame.AbsoluteSize.X - 28, 260)
		local minCell = tonumber(options.MinButtonWidth) or 108
		local gap = 8
		local columns = math.max(1, math.floor((width + gap) / (minCell + gap)))
		local cellWidth = math.floor((width - gap * math.max(columns - 1, 0)) / columns)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
		grid.CellSize = UDim2.fromOffset(math.max(minCell, cellWidth), 34)
		grid.FillDirectionMaxCells = columns
		local rows = math.max(1, math.ceil(math.max(#buttons, 1) / columns))
		holder.Size = UDim2.new(1, 0, 0, rows * 34 + math.max(rows - 1, 0) * gap)
		frame.Size = UDim2.new(1, 0, 0, 56 + holder.Size.Y.Offset)
		window:_refreshPageCanvases()
	end
	local controller = {Type = "Toolbar"}
	function controller:SetTools(newTools)
		tools = newTools or {}
		anchorlineClearChildren(holder)
		buttons = {}
		for index, tool in ipairs(tools) do build(type(tool) == "table" and tool or {Name = tostring(tool)}, index) end
		relayout()
		window:_queueSmartResize()
	end
	window:_addAdaptiveHandler(relayout)
	window._connections[#window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	controller:SetTools(tools)
	return controller
end

function Tab:CreateChecklist(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Checklist")
	local items = options.Items or {}
	local values = {}
	local frame = window:_createElement(self, name, name .. " checklist tasks", 62 + math.max(#items, 1) * 34)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#items, 1) * 34), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 6)})
	local rows = {}
	local controller = {Type = "Checklist", Flag = options.Flag}
	local function renderRow(rowData, index)
		local label = tostring(type(rowData) == "table" and (rowData.Name or rowData.Title or rowData.Text or rowData[1]) or rowData)
		values[index] = type(rowData) == "table" and rowData.Checked and true or false
		local button = new("TextButton", {Name = "Check" .. index, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Text = "", AutoButtonColor = false, Parent = holder}, {corner(8), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(button, {BackgroundColor3 = "Surface"})
		local box = new("Frame", {Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, Parent = button}, {corner(5), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		local check = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "✓", Font = Enum.Font.GothamBold, TextSize = 12, TextTransparency = values[index] and 0 or 1, Parent = box})
		window:_track(check, {TextColor3 = "AccentText"})
		local text = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -46, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = label, Parent = button})
		window:_track(text, {TextColor3 = "Text"})
		local function render(animated)
			local checked = values[index]
			local props = {BackgroundColor3 = getThemeValue(window, checked and "Accent" or "Input")}
			if animated then tween(box, 0.2, props, Enum.EasingStyle.Quint) else box.BackgroundColor3 = props.BackgroundColor3 end
			tween(check, animated and 0.18 or 0, {TextTransparency = checked and 0 or 1}, Enum.EasingStyle.Quint)
		end
		button.MouseButton1Click:Connect(function()
			values[index] = not values[index]
			render(true)
			safeCall(options.Callback, values, index, values[index])
			window:_autoSave()
		end)
		render(false)
		rows[#rows + 1] = {Button = button, Render = render}
	end
	function controller:Set(newValues, loading)
		if type(newValues) == "table" then
			for index, value in pairs(newValues) do values[index] = value and true or false end
			for _, row in ipairs(rows) do row.Render(not loading) end
		end
		if not loading then
			safeCall(options.Callback, values)
			window:_autoSave()
		end
	end
	function controller:Get() return values end
	function controller:SetItems(newItems)
		items = newItems or {}
		anchorlineClearChildren(holder)
		rows = {}
		values = {}
		for index, item in ipairs(items) do renderRow(item, index) end
		holder.Size = UDim2.new(1, 0, 0, math.max(#items, 1) * 34)
		frame.Size = UDim2.new(1, 0, 0, 62 + math.max(#items, 1) * 34)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	controller:SetItems(items)
	window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateTimeline(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Timeline")
	local events = options.Events or options.Items or {}
	local frame = window:_createElement(self, name, name .. " timeline events", 60 + math.max(#events, 1) * 54)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Events", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#events, 1) * 54), Parent = frame})
	local controller = {Type = "Timeline"}
	local function renderEvent(event, index)
		local y = (index - 1) * 54
		local color = anchorlineKindColor(window, event.Type or event.Status or "Info")
		if index < #events then
			new("Frame", {Position = UDim2.fromOffset(15, y + 23), Size = UDim2.fromOffset(2, 38), BorderSizePixel = 0, BackgroundColor3 = getThemeValue(window, "StrokeSoft"), Parent = holder})
		end
		new("Frame", {Position = UDim2.fromOffset(9, y + 10), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, BackgroundColor3 = color, Parent = holder}, {corner(7)})
		local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(36, y + 4), Size = UDim2.new(1, -46, 0, 20), Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(event.Title or event.Name or event[1] or "Event"), Parent = holder})
		window:_track(title, {TextColor3 = "Text"})
		local body = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(36, y + 26), Size = UDim2.new(1, -46, 0, 18), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(event.Text or event.Description or event[2] or ""), Parent = holder})
		window:_track(body, {TextColor3 = "TextMuted"})
	end
	function controller:SetEvents(newEvents)
		events = newEvents or {}
		anchorlineClearChildren(holder)
		for index, event in ipairs(events) do renderEvent(type(event) == "table" and event or {Title = tostring(event)}, index) end
		holder.Size = UDim2.new(1, 0, 0, math.max(#events, 1) * 54)
		frame.Size = UDim2.new(1, 0, 0, 60 + math.max(#events, 1) * 54)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	function controller:GetEvents() return events end
	controller:SetEvents(events)
	return controller
end

function Tab:CreateMeter(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Meter")
	local value = tonumber(options.Value or options.CurrentValue) or 0
	local minValue = tonumber(options.Min or (options.Range and options.Range[1])) or 0
	local maxValue = tonumber(options.Max or (options.Range and options.Range[2])) or 100
	local suffix = tostring(options.Suffix or "%")
	local frame = window:_createElement(self, name, name .. " meter gauge", 98)
	self:_headerRow(frame, name, options.Description)
	local valueText = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = frame})
	window:_track(valueText, {TextColor3 = "Text"})
	local track = new("Frame", {Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Parent = frame}, {corner(6)})
	window:_track(track, {BackgroundColor3 = "Surface"})
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = anchorlineKindColor(window, options.Type or "Info"), Parent = track}, {corner(6)})
	local caption = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(options.Caption or ""), Parent = frame})
	window:_track(caption, {TextColor3 = "TextMuted"})
	local controller = {Type = "Meter", Flag = options.Flag}
	function controller:Set(newValue, loading)
		value = math.clamp(tonumber(newValue) or value, minValue, maxValue)
		local percent = maxValue ~= minValue and (value - minValue) / (maxValue - minValue) or 0
		valueText.Text = tostring(value) .. suffix
		tween(fill, loading and 0 or 0.32, {Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1)}, Enum.EasingStyle.Quint)
		if not loading then
			safeCall(options.Callback, value)
			window:_autoSave()
		end
	end
	function controller:Get() return value end
	controller:Set(value, true)
	window:_registerFlag(options.Flag, controller)
	return controller
end

function Anchorline:CreateWindow(options)
	options = options or {}
	local self = setmetatable({}, Window)
	self.Title = tostring(options.Title or options.Name or "Anchorline")
	self.Subtitle = tostring(options.Subtitle or options.LoadingSubtitle or "Reusable interface library")
	self.Width = tonumber(options.Width) or 780
	self.Height = tonumber(options.Height) or 520
	self.SidebarWidth = tonumber(options.SidebarWidth) or 188
	self.SmartResizeEnabled = options.SmartResize ~= false
	self.SmartViewportMargin = tonumber(options.SmartViewportMargin) or 44
	self.SmartContentMinWidth = tonumber(options.SmartContentMinWidth) or 390
	self.ScrollBottomPadding = tonumber(options.ScrollBottomPadding) or 64
	self.MinWidth = tonumber(options.MinWidth) or 560
	self.MinHeight = tonumber(options.MinHeight) or 390
	self.MaxWidth = tonumber(options.MaxWidth) or 1040
	self.MaxHeight = tonumber(options.MaxHeight) or 760
	self.SidebarCollapsed = false
	self.Hidden = false
	self.Minimized = false
	self.Tabs = {}
	self.Flags = {}
	self._themed = setmetatable({}, {__mode = "k"})
	self._connections = {}
	self._temporaryConnections = {}
	self._adaptiveHandlers = {}
	self.Configuration = options.Configuration or options.ConfigurationSaving or {Enabled = false}
	if self.Configuration.Enabled == nil then
		self.Configuration.Enabled = false
	end
	self.ThemeName = "Workbench"
	self.Theme = Anchorline.Themes.Workbench
	self.FrostedGlass = options.FrostedGlass ~= false
	self.GlassTransparency = tonumber(options.GlassTransparency) or 0.12
	self.BlurSize = tonumber(options.BlurSize) or 10
	self.IconProvider = findLucideProvider(options.IconProvider or options.Lucide or Anchorline.IconProvider)

	local parent = options.Parent or resolveParent()
	local guiName = "Anchorline_" .. HttpService:GenerateGUID(false):gsub("-", "")
	local gui = new("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = options.DisplayOrder or 999,
		Parent = parent
	})
	self.Gui = gui

	local root = new("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = options.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.Width, self.Height),
		BackgroundTransparency = self.FrostedGlass and self.GlassTransparency or 0,
		GroupTransparency = 0,
		ClipsDescendants = true,
		Parent = gui
	}, {corner(25)})
	self.Root = root
	self:_track(root, {BackgroundColor3 = "Background"})
	local rootStroke = stroke(getThemeValue(self, "Stroke"), 1, 0)
	rootStroke.Parent = root
	self:_track(rootStroke, {Color = "Stroke"})
	local rootGradient = new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.52, 0.05),
			NumberSequenceKeypoint.new(1, 0.1)
		})
	})
	rootGradient.Parent = root

	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		Parent = root
	})
	self.Header = header
	local headerLine = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, 0),
		Size = UDim2.new(1, -48, 0, 1),
		BorderSizePixel = 0,
		Parent = header
	})
	self:_track(headerLine, {BackgroundColor3 = "StrokeSoft"})
	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -150, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Title,
		Parent = header
	})
	self:_track(title, {TextColor3 = "Text"})
	local subtitle = new("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 29),
		Size = UDim2.new(1, -150, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Subtitle,
		Parent = header
	})
	self:_track(subtitle, {TextColor3 = "TextMuted"})

	local controls = new("Frame", {
		Name = "Controls",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(126, 34),
		Parent = header
	}, {listLayout(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)})
	local function controlButton(text)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(36, 32),
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = false,
			Parent = controls
		}, {corner(10), stroke(getThemeValue(self, "StrokeSoft"), 1, 0)})
		self:_track(b, {BackgroundColor3 = "Surface", TextColor3 = "TextMuted"})
		b.MouseEnter:Connect(function()
			tween(b, 0.16, {BackgroundColor3 = getThemeValue(self, "SurfaceHover")})
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.18, {BackgroundColor3 = getThemeValue(self, "Surface")})
		end)
		return b
	end
	local sidebarButton = controlButton("≡")
	local minimizeButton = controlButton("−")
	local closeButton = controlButton("×")
	closeButton.TextColor3 = getThemeValue(self, "Danger")

	local sidebar = new("Frame", {
		Name = "Sidebar",
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(0, self.SidebarWidth, 1, -58),
		BackgroundTransparency = 1,
		Parent = root
	})
	self.Sidebar = sidebar
	local sidebarLine = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BorderSizePixel = 0,
		Parent = sidebar
	})
	self:_track(sidebarLine, {BackgroundColor3 = "StrokeSoft"})
	local tabList = new("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 1, -24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = sidebar
	}, {listLayout(Enum.FillDirection.Vertical, 8)})
	self.TabList = tabList

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.new(0, self.SidebarWidth, 0, 58),
		Size = UDim2.new(1, -self.SidebarWidth, 1, -58),
		BackgroundTransparency = 1,
		Parent = root
	})
	self.Content = content

	local contentHeader = new("Frame", {
		Name = "ContentHeader",
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundTransparency = 1,
		Parent = content
	})
	local pageTitle = new("TextLabel", {
		Name = "PageTitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(0.5, -20, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = contentHeader
	})
	self.PageTitle = pageTitle
	self:_track(pageTitle, {TextColor3 = "Text"})
	local pageSubtitle = new("TextLabel", {
		Name = "PageSubtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 36),
		Size = UDim2.new(0.5, -20, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = contentHeader
	})
	self.PageSubtitle = pageSubtitle
	self:_track(pageSubtitle, {TextColor3 = "TextMuted"})

	local searchWrap = new("Frame", {
		Name = "SearchWrap",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(210, 34),
		BackgroundTransparency = self.FrostedGlass and 0.18 or 0,
		Parent = contentHeader
	}, {corner(10), stroke(getThemeValue(self, "StrokeSoft"), 1, 0)})
	self:_track(searchWrap, {BackgroundColor3 = "Input"})
	local searchBox = new("TextBox", {
		Name = "Search",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		PlaceholderText = "Search controls",
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = searchWrap
	})
	self.SearchBox = searchBox
	self:_track(searchBox, {TextColor3 = "Text", PlaceholderColor3 = "TextFaint"})

	local pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, -2, 1, -72),
		BackgroundTransparency = 1,
		Parent = content
	})
	self.Pages = pages

	local resizeHandle = new("TextButton", {
		Name = "ResizeHandle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Text = "◢",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
		Parent = root
	})
	self.ResizeHandle = resizeHandle
	self:_track(resizeHandle, {TextColor3 = "TextFaint"})

	local notificationList = new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
		ZIndex = 60
	}, {listLayout(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)})
	self.NotificationList = notificationList

	sidebarButton.MouseButton1Click:Connect(function()
		self:CollapseSidebar()
	end)
	minimizeButton.MouseButton1Click:Connect(function()
		self:Minimize()
	end)
	closeButton.MouseButton1Click:Connect(function()
		self:Prompt({
			Title = "Close interface",
			Content = "This will destroy the current Anchorline window and its controls.",
			ConfirmText = "Close",
			CancelText = "Keep open",
			Callback = function(confirmed)
				if confirmed then
					self:Destroy()
				end
			end
		})
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:_applySearch()
	end)

	self:_makeDraggable()
	self:_makeResizable()

	local toggleKey = normalizeKey(options.ToggleKey or options.HideKey or Enum.KeyCode.RightShift)
	self._connections[#self._connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isTyping() then
			return
		end
		if input.KeyCode == toggleKey then
			self:Toggle()
		end
	end)

	self:SetTheme(options.Theme or "Workbench")
	self:_setBackgroundBlur(self.FrostedGlass)
	Anchorline.Windows[#Anchorline.Windows + 1] = self
	Anchorline.LastWindow = self

	if self.Configuration.Enabled then
		task.defer(function()
			self:LoadConfiguration()
		end)
	end

	task.defer(function()
		if self.Root and self.Root.Parent then
			self:SmartResize(false)
		end
	end)

	return self
end

function Anchorline:Notify(options)
	local window = self.LastWindow or Anchorline.LastWindow
	if window and window.Notify then
		return window:Notify(options)
	end
	warn("Anchorline UI notification requested before a window was created.")
end

function Anchorline:GetFlag(flag)
	local controller = self.Flags[flag]
	if controller and type(controller.Get) == "function" then
		return controller:Get()
	end
	return nil
end

function Anchorline:SetFlag(flag, value)
	local controller = self.Flags[flag]
	if controller and type(controller.Set) == "function" then
		controller:Set(value)
		return true
	end
	return false
end

function Anchorline:SetIconProvider(provider)
	if type(provider) == "table" then
		Anchorline.IconProvider = provider
	end
	return Anchorline
end

function Anchorline:SetIconAlias(alias, iconName)
	if type(alias) == "string" and type(iconName) == "string" then
		Anchorline.IconAliases[alias] = iconName
	end
	return Anchorline
end

function Anchorline:AddIconAliases(aliases)
	if type(aliases) == "table" then
		for alias, iconName in pairs(aliases) do
			if type(alias) == "string" and type(iconName) == "string" then
				Anchorline.IconAliases[alias] = iconName
			end
		end
	end
	return Anchorline
end

function Anchorline:SetTheme(name, theme)
	if type(name) == "string" and type(theme) == "table" then
		Anchorline.Themes[name] = theme
	end
	return Anchorline
end

return Anchorline
