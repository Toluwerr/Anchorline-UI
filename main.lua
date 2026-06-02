local Anchorline = {}
Anchorline.__index = Anchorline
Anchorline.Name = "Anchorline UI"
Anchorline.Version = "3.8.0"
Anchorline.Flags = {}
Anchorline.Windows = setmetatable({}, {__mode = "v"})
Anchorline.IconStyle = "Lucide"
Anchorline.LucideProvider = nil
Anchorline.IconProvider = nil
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


local serviceCache = {
	Players = Players,
	UserInputService = UserInputService,
	TweenService = TweenService,
	RunService = RunService,
	HttpService = HttpService,
	TextService = TextService,
	CoreGui = CoreGui,
	ReplicatedStorage = ReplicatedStorage,
	Lighting = Lighting,
	Workspace = Workspace
}
local unavailableServiceCache = {}
local serviceAliases = {
	UIS = "UserInputService",
	TS = "TweenService",
	RS = "ReplicatedStorage",
	Run = "RunService",
	HTTP = "HttpService",
	Text = "TextService",
	CG = "CoreGui",
	LightingService = "Lighting",
	World = "Workspace"
}

local function normalizeServiceName(serviceName)
	if type(serviceName) ~= "string" then
		return nil
	end
	local cleaned = serviceName:gsub("^%s+", ""):gsub("%s+$", "")
	if cleaned == "" then
		return nil
	end
	return serviceAliases[cleaned] or cleaned
end

local function safeGetService(serviceName)
	local normalized = normalizeServiceName(serviceName)
	if not normalized then
		return nil, "Service name must be a non-empty string"
	end
	if serviceCache[normalized] then
		return serviceCache[normalized], nil
	end
	if unavailableServiceCache[normalized] then
		return nil, unavailableServiceCache[normalized]
	end
	local ok, serviceOrError = pcall(game.GetService, game, normalized)
	if ok and serviceOrError then
		serviceCache[normalized] = serviceOrError
		return serviceOrError, nil
	end
	local message = tostring(serviceOrError or "Service is unavailable")
	unavailableServiceCache[normalized] = message
	return nil, message
end

function Anchorline:GetService(serviceName, silent)
	local service, message = safeGetService(serviceName)
	if not service and not silent then
		warn("Anchorline UI service unavailable: " .. tostring(serviceName) .. " (" .. tostring(message) .. ")")
	end
	return service, message
end

function Anchorline:HasService(serviceName)
	return self:GetService(serviceName, true) ~= nil
end

function Anchorline:IsServiceAvailable(serviceName)
	return self:HasService(serviceName)
end

function Anchorline:GetServices(serviceNames, silent)
	local results = {}
	if type(serviceNames) ~= "table" then
		return results
	end
	for _, serviceName in ipairs(serviceNames) do
		local service, message = self:GetService(serviceName, silent)
		results[serviceName] = service or false
		if not service then
			results[tostring(serviceName) .. "_Error"] = message
		end
	end
	return results
end

function Anchorline:ClearServiceCache(serviceName)
	if serviceName == nil then
		unavailableServiceCache = {}
		return true
	end
	local normalized = normalizeServiceName(serviceName)
	if normalized then
		unavailableServiceCache[normalized] = nil
		return true
	end
	return false
end

Anchorline.Services = setmetatable({}, {
	__index = function(_, serviceName)
		return Anchorline:GetService(serviceName, true)
	end,
	__call = function(_, serviceName, silent)
		return Anchorline:GetService(serviceName, silent)
	end
})

local function safeCall(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end
	local ok, result = pcall(callback, ...)
	if not ok then
		warn("Anchorline UI user callback error: " .. tostring(result))
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

local function countDecimalPlaces(value)
	local text = tostring(value or 0)
	if text:find("e") or text:find("E") then
		text = string.format("%.10f", tonumber(value) or 0)
	end
	local decimal = text:match("%.(%d+)")
	if not decimal then
		return 0
	end
	decimal = decimal:gsub("0+$", "")
	return math.clamp(#decimal, 0, 6)
end

local function formatSliderNumber(value, increment, precision)
	local places = tonumber(precision)
	if not places then
		places = countDecimalPlaces(increment)
	end
	places = math.clamp(math.floor(places), 0, 6)
	local number = tonumber(value) or 0
	local rounded = number
	if places > 0 then
		local scale = 10 ^ places
		rounded = math.floor(number * scale + 0.5) / scale
	else
		rounded = math.floor(number + 0.5)
	end
	local formatted = string.format("%." .. tostring(places) .. "f", rounded)
	if places > 0 then
		formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	end
	return formatted
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
	local cleaned = tostring(value):lower():gsub("%s+", "-"):gsub("_", "-"):gsub("[^%w%-]", "")
	cleaned = cleaned:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
	return cleaned
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

local function resolveIconVector2(value)
	if typeof(value) == "Vector2" then
		return value
	end
	if type(value) == "table" then
		local x = value.X or value.x or value[1] or 0
		local y = value.Y or value.y or value[2] or 0
		return Vector2.new(tonumber(x) or 0, tonumber(y) or 0)
	end
	return nil
end

local function resolveIconAssetFromTable(value)
	if type(value) ~= "table" then
		return nil
	end

	local image = value.Image or value.Url or value.URL or value.Asset or value.AssetId or value.Id or value.image or value.url or value.asset or value.assetId or value.id
	if typeof(image) == "number" then
		image = "rbxassetid://" .. tostring(image)
	elseif isNumericAssetString(image) then
		image = "rbxassetid://" .. image
	end
	if type(image) ~= "string" or image == "" then
		return nil
	end

	local data = {Image = image}
	local rectOffset = resolveIconVector2(value.ImageRectOffset or value.imageRectOffset or value.RectOffset or value.rectOffset)
	local rectSize = resolveIconVector2(value.ImageRectSize or value.imageRectSize or value.RectSize or value.rectSize)
	if rectOffset then
		data.ImageRectOffset = rectOffset
	end
	if rectSize then
		data.ImageRectSize = rectSize
	end
	return data
end

local function applyIconAssetToImageLabel(imageLabel, asset)
	if not imageLabel or not asset or type(asset.Image) ~= "string" or asset.Image == "" then
		return false
	end
	imageLabel.Image = asset.Image
	imageLabel.ImageRectOffset = asset.ImageRectOffset or Vector2.new(0, 0)
	imageLabel.ImageRectSize = asset.ImageRectSize or Vector2.new(0, 0)
	return true
end

local function providerHasLucideApi(provider)
	return type(provider) == "table" and (type(provider.GetAsset) == "function" or type(provider.ImageLabel) == "function")
end

local function requireLucideModule(module)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, provider = pcall(require, module)
	if ok and providerHasLucideApi(provider) then
		return provider
	end
	return nil
end

local function resolveLucideProviderCandidate(candidate)
	if providerHasLucideApi(candidate) then
		return candidate
	end
	if typeof(candidate) ~= "Instance" then
		return nil
	end
	if candidate:IsA("ModuleScript") then
		return requireLucideModule(candidate)
	end
	local directNames = {"Lucide", "LucideIcons", "lucide-roblox", "lucide-icons", "init", "Init", "main", "Main"}
	for _, name in ipairs(directNames) do
		local child = candidate:FindFirstChild(name)
		local provider = resolveLucideProviderCandidate(child)
		if provider then
			return provider
		end
	end
	local scanned = 0
	for _, descendant in ipairs(candidate:GetDescendants()) do
		scanned += 1
		if scanned > 80 then break end
		if descendant:IsA("ModuleScript") then
			local lowerName = descendant.Name:lower()
			if lowerName:find("lucide", 1, true) then
				local provider = requireLucideModule(descendant)
				if provider then
					return provider
				end
			end
		end
	end
	return nil
end

local function findReplicatedStorageLucideProvider()
	if not ReplicatedStorage then
		return nil
	end
	for _, name in ipairs({"Lucide", "LucideIcons", "lucide-roblox"}) do
		local provider = resolveLucideProviderCandidate(ReplicatedStorage:FindFirstChild(name))
		if provider then
			return provider
		end
	end
	return nil
end

local function getGlobalLucideProvider()
	local containers = {_G}
	if type(getgenv) == "function" then
		local ok, env = pcall(getgenv)
		if ok and type(env) == "table" then
			containers[#containers + 1] = env
		end
	end
	for _, env in ipairs(containers) do
		for _, key in ipairs({"AnchorlineLucide", "Lucide", "LucideIcons", "lucide"}) do
			local candidate = rawget(env, key)
			if providerHasLucideApi(candidate) then
				return candidate
			end
		end
	end
	return nil
end

local function findModuleByPath(root, segments)
	local current = root
	for _, segment in ipairs(segments) do
		if not current then return nil end
		current = current:FindFirstChild(segment)
	end
	if current and current:IsA("ModuleScript") then
		return current
	end
	return nil
end

local function findLucideProvider(explicitProvider)
	if providerHasLucideApi(explicitProvider) then
		return explicitProvider
	end
	if typeof(explicitProvider) == "Instance" and explicitProvider:IsA("ModuleScript") then
		local provider = requireLucideModule(explicitProvider)
		if provider then return provider end
	end
	if providerHasLucideApi(Anchorline.LucideProvider) then
		return Anchorline.LucideProvider
	end
	if providerHasLucideApi(Anchorline.IconProvider) then
		return Anchorline.IconProvider
	end
	local globalProvider = getGlobalLucideProvider()
	if globalProvider then
		Anchorline.LucideProvider = globalProvider
		Anchorline.IconProvider = globalProvider
		return globalProvider
	end

	local roots = {ReplicatedStorage}
	local replicatedFirst = safeGetService("ReplicatedFirst")
	local starterGui = safeGetService("StarterGui")
	if replicatedFirst then roots[#roots + 1] = replicatedFirst end
	if starterGui then roots[#roots + 1] = starterGui end
	if LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
		roots[#roots + 1] = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end

	local commonPaths = {
		{"Lucide"},
		{"LucideIcons"},
		{"lucide-roblox"},
		{"lucide-icons"},
		{"Packages", "Lucide"},
		{"Packages", "LucideIcons"},
		{"Packages", "lucide-roblox"},
		{"Packages", "lucide-icons"},
		{"Packages", "_Index", "latte-soft_lucide-icons@0.1.3", "lucide-icons"},
		{"Packages", "_Index", "latte-soft_lucide-icons@0.1.2", "lucide-icons"},
		{"Packages", "_Index", "virtualbutfake_lucide-roblox@1.1.2", "lucide-roblox"},
	}

	for _, root in ipairs(roots) do
		for _, path in ipairs(commonPaths) do
			local module = findModuleByPath(root, path)
			local provider = requireLucideModule(module)
			if provider then
				Anchorline.LucideProvider = provider
				Anchorline.IconProvider = provider
				return provider
			end
		end
	end

	for _, root in ipairs(roots) do
		local scanned = 0
		for _, descendant in ipairs(root:GetDescendants()) do
			scanned += 1
			if scanned > 220 then break end
			if descendant:IsA("ModuleScript") then
				local lowerName = descendant.Name:lower()
				if lowerName:find("lucide", 1, true) then
					local provider = requireLucideModule(descendant)
					if provider then
						Anchorline.LucideProvider = provider
						Anchorline.IconProvider = provider
						return provider
					end
				end
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


local getLucideIconCandidates
local getLucideAssetFromProvider
local getBundledLucideAsset

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
	if type(icon) ~= "string" then
		return nil
	end
	if isNumericAssetString(icon) then
		return {Image = "rbxassetid://" .. icon}
	end
	if isRobloxImagePath(icon) then
		return {Image = icon}
	end

	local providers = {}
	local seen = {}
	local function addProvider(provider)
		local resolved = resolveLucideProviderCandidate(provider)
		if resolved and not seen[resolved] then
			seen[resolved] = true
			providers[#providers + 1] = resolved
		end
	end

	addProvider(Anchorline.IconProvider)
	addProvider(self.IconProvider)
	addProvider(Anchorline.LucideProvider)
	addProvider(self.LucideProvider)
	addProvider(findReplicatedStorageLucideProvider())
	addProvider(findLucideProvider(nil))

	for _, provider in ipairs(providers) do
		local parsed = getLucideAssetFromProvider(provider, icon, 48)
		if parsed then
			self.IconProvider = provider
			self.LucideProvider = provider
			Anchorline.IconProvider = Anchorline.IconProvider or provider
			Anchorline.LucideProvider = Anchorline.LucideProvider or provider
			return parsed
		end
	end

	local bundled = getBundledLucideAsset and getBundledLucideAsset(icon, 48)
	if bundled then
		return bundled
	end

	return nil
end

local function createTextFallbackIcon(parent, iconName)
	return {}
end

function getLucideIconCandidates(icon)
	local name = normalizeIconName(icon)
	if name == "" then
		name = "circle"
	end
	local aliases = {
		["analytics"] = {"bar-chart-3", "bar-chart", "chart-column"},
		["stats"] = {"bar-chart-3", "bar-chart", "chart-column"},
		["results"] = {"clipboard-list", "list-checks", "bar-chart-3"},
		["chart"] = {"bar-chart-3", "bar-chart"},
		["trend"] = {"line-chart", "chart-line", "activity"},
		["warning"] = {"alert-triangle", "triangle-alert", "circle-alert"},
		["alert"] = {"alert-triangle", "triangle-alert", "circle-alert"},
		["success"] = {"check-circle", "circle-check", "check"},
		["error"] = {"x-circle", "circle-x", "x"},
		["close"] = {"x", "x-circle"},
		["script"] = {"code", "terminal", "file-code"},
		["notification"] = {"bell", "bell-ring"},
		["toolbox"] = {"wrench", "briefcase", "hammer"},
		["tools"] = {"wrench", "settings"},
		["test"] = {"beaker", "flask-conical", "test-tube"},
		["flask"] = {"flask-conical", "beaker", "test-tube"},
		["esp"] = {"eye", "scan-eye"},
		["visuals"] = {"eye", "scan-eye"},
		["main"] = {"home", "panel-left"},
		["config"] = {"settings", "sliders-horizontal"},
		["players"] = {"users", "user-round"},
		["user"] = {"user", "user-round"},
		["users"] = {"users", "users-round"},
		["aim"] = {"crosshair", "target"},
		["power"] = {"zap", "bolt"},
		["files"] = {"folder", "files"},
		["docs"] = {"book-open-text", "book-open", "book"},
		["tasks"] = {"clipboard-list", "list-checks", "clipboard-check"},
		["paint"] = {"palette", "paintbrush"},
		["color"] = {"palette", "paintbrush"},
		["controls"] = {"sliders-horizontal", "sliders"},
		["database"] = {"database", "server"},
		["document"] = {"file-text", "file"},
		["run"] = {"play", "circle-play"},
		["reload"] = {"refresh-cw", "rotate-cw"},
		["delete"] = {"trash-2", "trash"},
		["secure"] = {"lock", "shield-check"},
		["network"] = {"wifi", "router"},
		["menu-list"] = {"list", "list-checks"},
		["bar-chart"] = {"bar-chart-3", "bar-chart"},
		["bar-chart-2"] = {"bar-chart-2", "bar-chart-3", "bar-chart"},
		["chart-bar"] = {"bar-chart-3", "bar-chart"},
		["clipboard"] = {"clipboard-list", "clipboard"},
		["clipboard-list"] = {"clipboard-list", "list-checks", "clipboard"},
		["file"] = {"file-text", "file"},
		["file-text"] = {"file-text", "file"},
		["alert-triangle"] = {"alert-triangle", "triangle-alert"},
		["check-circle"] = {"check-circle", "circle-check"},
		["x-circle"] = {"x-circle", "circle-x"},
		["zap"] = {"zap", "bolt"},
		["activity"] = {"activity", "chart-no-axes-column-increasing"},
		["sliders"] = {"sliders-horizontal", "sliders"},
		["sliders-horizontal"] = {"sliders-horizontal", "sliders"},
		["magnifying-glass"] = {"search"},
		["wrench"] = {"wrench", "settings"},
		["target"] = {"target", "crosshair"},
		["shield"] = {"shield", "shield-check"},
		["terminal"] = {"terminal", "square-terminal"},
		["home"] = {"home", "house"},
		["settings"] = {"settings", "cog"},
		["download"] = {"download", "download-cloud"},
		["upload"] = {"upload", "upload-cloud"},
		["copy"] = {"copy", "copy-check"},
		["search"] = {"search"},
		["server"] = {"server", "database"},
		["folder"] = {"folder", "folder-open"},
		["lock"] = {"lock"},
		["unlock"] = {"unlock"},
		["wifi"] = {"wifi"},
		["bug"] = {"bug"},
		["rocket"] = {"rocket"},
		["pause"] = {"pause"},
		["play"] = {"play"},
		["trash"] = {"trash-2", "trash"},
		["info"] = {"info"},
		["bell"] = {"bell"},
		["eye"] = {"eye"},
		["code"] = {"code", "file-code"},
		["book"] = {"book-open", "book"},
	}
	local output = {}
	local seen = {}
	local function push(value)
		value = normalizeIconName(value)
		if value ~= "" and not seen[value] then
			seen[value] = true
			output[#output + 1] = value
		end
	end
	push(name)
	if aliases[name] then
		for _, value in ipairs(aliases[name]) do push(value) end
	end
	return output
end

function getLucideAssetFromProvider(provider, icon, size)
	if not providerHasLucideApi(provider) then
		return nil
	end
	local candidates = getLucideIconCandidates(icon)
	for _, candidate in ipairs(candidates) do
		if type(provider.GetAsset) == "function" then
			for _, args in ipairs({
				{provider, candidate, size or 48},
				{candidate, size or 48},
				{provider, candidate},
				{candidate},
			}) do
				local ok, asset = pcall(provider.GetAsset, table.unpack(args))
				local parsed = ok and resolveIconAssetFromTable(asset) or nil
				if parsed then
					return parsed, candidate
				end
			end
		end
		if type(provider.ImageLabel) == "function" then
			local ok, image = pcall(provider.ImageLabel, candidate, size or 48, {BackgroundTransparency = 1})
			if ok and image and image:IsA("ImageLabel") then
				local data = {
					Image = image.Image,
					ImageRectOffset = image.ImageRectOffset,
					ImageRectSize = image.ImageRectSize
				}
				image:Destroy()
				return data, candidate
			end
		end
	end
	return nil
end

local bundledLucideIcons = nil
local bundledLucideLoadAttempted = false
local bundledLucideSource = "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua"

local function loadBundledLucideIcons()
	if bundledLucideLoadAttempted then
		return bundledLucideIcons
	end
	bundledLucideLoadAttempted = true

	if type(loadstring) ~= "function" then
		return nil
	end

	local content
	local ok, result = pcall(function()
		return game:HttpGet(bundledLucideSource)
	end)
	if ok and type(result) == "string" and #result > 0 then
		content = result
	end

	if not content then
		local requestFunction = (syn and syn.request) or (http and http.request) or http_request or request
		if type(requestFunction) == "function" then
			local requestOk, response = pcall(requestFunction, {Url = bundledLucideSource, Method = "GET"})
			if requestOk and type(response) == "table" and type(response.Body) == "string" and #response.Body > 0 then
				content = response.Body
			end
		end
	end

	if not content then
		return nil
	end

	local chunkOk, chunk = pcall(loadstring, content)
	if not chunkOk or type(chunk) ~= "function" then
		return nil
	end

	local runOk, icons = pcall(chunk)
	if runOk and type(icons) == "table" then
		bundledLucideIcons = icons
		return icons
	end

	return nil
end

function getBundledLucideAsset(icon, size)
	local icons = loadBundledLucideIcons()
	if type(icons) ~= "table" then
		return nil
	end

	local requestedSize = tostring(size or 48) .. "px"
	local sizedIcons = icons[requestedSize] or icons["48px"] or icons["256px"]
	if type(sizedIcons) ~= "table" then
		return nil
	end

	for _, candidate in ipairs(getLucideIconCandidates(icon)) do
		local entry = sizedIcons[candidate]
		if type(entry) == "table" and entry[1] then
			local image = entry[1]
			if type(image) == "number" then
				image = "rbxassetid://" .. tostring(image)
			elseif isNumericAssetString(image) then
				image = "rbxassetid://" .. image
			end
			if type(image) == "string" and image ~= "" then
				local rectSize = resolveIconVector2(entry[2]) or Vector2.new(size or 48, size or 48)
				local rectOffset = resolveIconVector2(entry[3]) or Vector2.new(0, 0)
				return {
					Image = image,
					ImageRectSize = rectSize,
					ImageRectOffset = rectOffset
				}
			end
		end
	end

	return nil
end

local function createVectorIcon(parent, iconName)
	if Anchorline.IconStyle == "Lucide" then
		return createTextFallbackIcon(parent, iconName)
	end
	local name = normalizeIconName(iconName)
	if name == "" then
		name = "toolbox"
	end

	local aliases = {
		["bar-chart-3"] = "bar-chart",
		["bar-chart-2"] = "bar-chart",
		["chart-bar"] = "bar-chart",
		["clipboard-list"] = "clipboard",
		["file-text"] = "file",
		["alert-triangle"] = "warning",
		["check-circle"] = "check",
		["x-circle"] = "x",
		["zap"] = "bolt",
		["activity"] = "pulse",
		["database"] = "server",
		["sliders-horizontal"] = "sliders",
		["palette"] = "color",
		["magnifying-glass"] = "search",
		["wrench"] = "tools"
	}
	name = aliases[name] or name

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
	local function ring(x, y, size, thickness)
		local outer = rect(x, y, size, size, math.floor(size / 2))
		local inner = shape("Frame", {
			Position = UDim2.fromOffset(x + thickness, y + thickness),
			Size = UDim2.fromOffset(size - thickness * 2, size - thickness * 2),
			BackgroundTransparency = 0,
			ZIndex = outer.ZIndex + 1
		}, {corner(math.floor((size - thickness * 2) / 2))})
		inner:SetAttribute("AnchorlineIconCutout", true)
		return outer, inner
	end
	local function chevron(x, y, direction)
		if direction == "right" then
			line(x, y, 7, 2, 45, 1)
			line(x, y + 5, 7, 2, -45, 1)
		elseif direction == "left" then
			line(x, y, 7, 2, -45, 1)
			line(x, y + 5, 7, 2, 45, 1)
		elseif direction == "down" then
			line(x, y, 7, 2, 45, 1)
			line(x + 5, y, 7, 2, -45, 1)
		else
			line(x, y + 5, 7, 2, -45, 1)
			line(x + 5, y + 5, 7, 2, 45, 1)
		end
	end

	if name == "bar-chart" or name == "analytics" or name == "stats" or name == "results" or name == "chart" then
		line(3, 16, 14, 2, 0, 1)
		rect(4, 11, 3, 5, 2)
		rect(9, 7, 3, 9, 2)
		rect(14, 4, 3, 12, 2)
	elseif name == "line-chart" or name == "trend" then
		line(3, 16, 14, 2, 0, 1)
		line(4, 13, 5, 2, -28, 1)
		line(8, 11, 4, 2, 24, 1)
		line(11, 10, 6, 2, -38, 1)
		dot(3, 12, 3)
		dot(8, 9, 3)
		dot(12, 10, 3)
		dot(16, 6, 3)
	elseif name == "info" or name == "help" then
		ring(3, 3, 14, 2)
		dot(9, 6, 2)
		line(9, 9, 2, 5, 0, 1)
		line(8, 14, 4, 2, 0, 1)
	elseif name == "check" or name == "success" then
		ring(3, 3, 14, 2)
		line(5, 10, 5, 2, 45, 1)
		line(8, 11, 8, 2, -45, 1)
	elseif name == "x" or name == "close" or name == "error" then
		ring(3, 3, 14, 2)
		line(6, 6, 9, 2, 45, 1)
		line(6, 12, 9, 2, -45, 1)
	elseif name == "warning" or name == "alert" then
		line(10, 2, 8, 15, -28, 1)
		line(10, 2, 8, 15, 28, 1)
		line(5, 17, 11, 2, 0, 1)
		line(9, 8, 2, 5, 0, 1)
		dot(8, 14, 4)
	elseif name == "code" or name == "script" or name == "terminal" then
		rect(3, 4, 14, 12, 3)
		line(5, 8, 4, 2, -35, 1)
		line(5, 10, 4, 2, 35, 1)
		line(11, 8, 4, 2, 35, 1)
		line(11, 10, 4, 2, -35, 1)
		line(7, 15, 8, 2, 0, 1)
	elseif name == "bell" or name == "notification" then
		rect(6, 7, 8, 8, 4)
		line(5, 14, 10, 2, 0, 1)
		dot(8, 16, 4)
		line(9, 3, 2, 4, 0, 1)
		line(6, 5, 8, 2, 18, 1)
	elseif name == "toolbox" or name == "tools" then
		rect(3, 7, 14, 10, 3)
		line(7, 5, 6, 2, 0, 1)
		line(7, 5, 2, 4, 0, 1)
		line(12, 5, 2, 4, 0, 1)
		line(3, 10, 14, 2, 0, 1)
		dot(9, 12, 3)
	elseif name == "test" or name == "flask" then
		line(7, 3, 6, 2, 0, 1)
		line(9, 5, 2, 6, 0, 1)
		line(7, 10, 6, 7, -20, 2)
		line(7, 10, 6, 7, 20, 2)
		line(5, 16, 10, 2, 0, 1)
		dot(7, 13, 2)
		dot(11, 14, 2)
	elseif name == "esp" or name == "eye" or name == "visuals" then
		line(3, 10, 7, 2, -28, 1)
		line(10, 8, 7, 2, 28, 1)
		line(3, 10, 7, 2, 28, 1)
		line(10, 12, 7, 2, -28, 1)
		ring(7, 7, 6, 2)
	elseif name == "home" or name == "main" then
		line(4, 9, 7, 2, -38, 1)
		line(9, 4, 7, 2, 38, 1)
		rect(5, 10, 10, 7, 2)
		rect(8, 13, 4, 4, 1)
	elseif name == "settings" or name == "gear" or name == "config" then
		ring(6, 6, 8, 2)
		line(9, 1, 2, 4, 0, 1)
		line(9, 15, 2, 4, 0, 1)
		line(1, 9, 4, 2, 0, 1)
		line(15, 9, 4, 2, 0, 1)
		line(4, 4, 4, 2, 45, 1)
		line(12, 4, 4, 2, -45, 1)
		line(4, 14, 4, 2, -45, 1)
		line(12, 14, 4, 2, 45, 1)
	elseif name == "players" or name == "user" or name == "users" then
		ring(4, 3, 6, 2)
		rect(2, 12, 10, 5, 4)
		ring(12, 5, 4, 1)
		rect(11, 13, 7, 4, 3)
	elseif name == "target" or name == "aim" then
		ring(4, 4, 12, 2)
		dot(8, 8, 4)
		line(9, 0, 2, 4, 0, 1)
		line(9, 16, 2, 4, 0, 1)
		line(0, 9, 4, 2, 0, 1)
		line(16, 9, 4, 2, 0, 1)
	elseif name == "shield" or name == "security" then
		line(5, 3, 10, 2, 0, 1)
		line(5, 3, 2, 8, 0, 1)
		line(13, 3, 2, 8, 0, 1)
		line(6, 11, 4, 6, -32, 1)
		line(10, 15, 4, 2, -20, 1)
		line(12, 11, 4, 6, 32, 1)
	elseif name == "bolt" or name == "power" then
		line(10, 1, 3, 9, 25, 1)
		line(6, 9, 8, 3, 0, 1)
		line(7, 9, 3, 10, 25, 1)
	elseif name == "folder" or name == "files" then
		rect(2, 6, 16, 11, 3)
		rect(3, 4, 7, 4, 2)
		line(3, 8, 14, 2, 0, 1)
	elseif name == "book" or name == "docs" then
		rect(4, 3, 12, 15, 2)
		line(6, 3, 2, 15, 0, 1)
		line(8, 7, 6, 1, 0, 1)
		line(8, 10, 6, 1, 0, 1)
		line(8, 13, 4, 1, 0, 1)
	elseif name == "clipboard" or name == "tasks" then
		rect(5, 4, 10, 14, 2)
		rect(7, 2, 6, 4, 2)
		line(7, 8, 6, 1, 0, 1)
		line(7, 11, 6, 1, 0, 1)
		line(7, 14, 4, 1, 0, 1)
	elseif name == "search" then
		ring(4, 4, 9, 2)
		line(12, 12, 6, 2, 45, 1)
	elseif name == "color" or name == "paint" then
		ring(3, 3, 14, 2)
		dot(6, 6, 3)
		dot(11, 6, 3)
		dot(8, 11, 3)
		line(12, 14, 4, 2, -35, 1)
	elseif name == "sliders" or name == "controls" then
		line(3, 5, 14, 2, 0, 1)
		dot(6, 3, 5)
		line(3, 10, 14, 2, 0, 1)
		dot(12, 8, 5)
		line(3, 15, 14, 2, 0, 1)
		dot(8, 13, 5)
	elseif name == "server" or name == "database" then
		rect(4, 3, 12, 5, 3)
		rect(4, 8, 12, 5, 3)
		rect(4, 13, 12, 5, 3)
		dot(6, 5, 2)
		dot(6, 10, 2)
		dot(6, 15, 2)
	elseif name == "file" or name == "document" then
		rect(5, 3, 11, 15, 2)
		line(12, 3, 4, 4, 45, 1)
		line(7, 9, 6, 1, 0, 1)
		line(7, 12, 7, 1, 0, 1)
		line(7, 15, 5, 1, 0, 1)
	elseif name == "play" or name == "run" then
		line(6, 4, 2, 12, 0, 1)
		line(7, 4, 9, 7, 35, 1)
		line(7, 16, 9, 7, -35, 1)
	elseif name == "refresh" or name == "reload" then
		ring(4, 4, 12, 2)
		chevron(12, 3, "right")
		chevron(1, 10, "left")
	elseif name == "copy" then
		rect(6, 5, 10, 11, 2)
		rect(3, 8, 10, 10, 2)
	elseif name == "trash" or name == "delete" then
		line(5, 5, 10, 2, 0, 1)
		line(7, 3, 6, 2, 0, 1)
		rect(6, 7, 8, 11, 2)
		line(8, 9, 1, 7, 0, 1)
		line(11, 9, 1, 7, 0, 1)
	elseif name == "bug" then
		rect(6, 6, 8, 10, 4)
		line(7, 4, 6, 2, 0, 1)
		line(4, 8, 4, 1, -25, 1)
		line(12, 8, 4, 1, 25, 1)
		line(4, 13, 4, 1, 25, 1)
		line(12, 13, 4, 1, -25, 1)
	elseif name == "rocket" then
		line(10, 2, 5, 10, 25, 2)
		line(6, 9, 6, 7, -25, 2)
		dot(10, 7, 3)
		line(5, 15, 4, 2, -35, 1)
	elseif name == "pulse" or name == "activity" then
		line(2, 11, 4, 2, 0, 1)
		line(5, 11, 4, 2, -62, 1)
		line(8, 4, 5, 12, 20, 1)
		line(12, 12, 3, 2, -45, 1)
		line(14, 10, 4, 2, 0, 1)
	elseif name == "lock" or name == "secure" then
		rect(5, 8, 10, 9, 3)
		line(7, 8, 2, 5, 0, 1)
		line(11, 8, 2, 5, 0, 1)
		line(7, 5, 6, 2, 0, 1)
		dot(9, 12, 2)
	elseif name == "unlock" then
		rect(5, 8, 10, 9, 3)
		line(7, 8, 2, 5, 0, 1)
		line(11, 5, 2, 8, 0, 1)
		line(11, 5, 5, 2, 0, 1)
		dot(9, 12, 2)
	elseif name == "download" then
		line(9, 3, 2, 9, 0, 1)
		chevron(5, 9, "down")
		line(4, 16, 12, 2, 0, 1)
	elseif name == "upload" then
		line(9, 8, 2, 8, 0, 1)
		chevron(5, 3, "up")
		line(4, 16, 12, 2, 0, 1)
	elseif name == "wifi" or name == "network" then
		line(3, 8, 14, 2, 25, 1)
		line(3, 8, 14, 2, -25, 1)
		line(6, 12, 8, 2, 25, 1)
		line(6, 12, 8, 2, -25, 1)
		dot(8, 16, 4)
	elseif name == "list" or name == "menu-list" then
		dot(3, 5, 3)
		dot(3, 10, 3)
		dot(3, 15, 3)
		line(8, 6, 9, 2, 0, 1)
		line(8, 11, 9, 2, 0, 1)
		line(8, 16, 9, 2, 0, 1)
	elseif name == "pause" then
		rect(6, 4, 3, 12, 1)
		rect(12, 4, 3, 12, 1)
	else
		-- Unknown icon names intentionally render no letter fallback.
		-- Valid icons should resolve through Lucide or through a Roblox image asset.
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
	if tab.ButtonIconBox then
		local boxTransparency = active and (self.FrostedGlass and 0.12 or 0.08) or (self.FrostedGlass and 0.5 or 0.68)
		tween(tab.ButtonIconBox, 0.24, {BackgroundTransparency = boxTransparency}, Enum.EasingStyle.Quint)
		tab.ButtonIconBox.BackgroundColor3 = active and getThemeValue(self, "AccentSoft") or getThemeValue(self, "SurfaceHover")
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
			elseif shape:GetAttribute("AnchorlineIconCutout") then
				shape.BackgroundColor3 = tab.ButtonIconBox and tab.ButtonIconBox.BackgroundColor3 or getThemeValue(self, "Surface")
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

function Window:_measureChildBottom(page, child)
	if not page or not child or not child:IsA("GuiObject") or not child.Visible then
		return 0
	end
	local pageHeight = math.max(0, page.AbsoluteSize.Y)
	local positionOffset = child.Position.Y.Offset
	if child.Position.Y.Scale ~= 0 then
		positionOffset = positionOffset + child.Position.Y.Scale * pageHeight
	end
	local childHeight = child.AbsoluteSize.Y
	if childHeight <= 1 and child.Size.Y.Scale ~= 0 then
		childHeight = math.max(0, child.Size.Y.Scale * pageHeight + child.Size.Y.Offset)
	end
	local absoluteDelta = page.CanvasPosition.Y + (child.AbsolutePosition.Y - page.AbsolutePosition.Y) + child.AbsoluteSize.Y
	local positionedBottom = positionOffset + childHeight
	return math.max(positionedBottom, absoluteDelta)
end

function Window:_getPageContentHeight(page)
	if not page or not page:IsA("ScrollingFrame") then
		return 0
	end
	local _, _, padTop, padBottom = self:_getPagePadding(page)
	local layout = page:FindFirstChildOfClass("UIListLayout")
	local contentHeight = 0
	if layout then
		contentHeight = math.max(contentHeight, layout.AbsoluteContentSize.Y + padTop + padBottom)
	end
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			contentHeight = math.max(contentHeight, self:_measureChildBottom(page, child) + padBottom)
		end
	end
	return math.max(0, math.ceil(contentHeight))
end

function Window:_updatePageCanvas(page)
	if not page or not page:IsA("ScrollingFrame") then
		return 0
	end
	local contentHeight = self:_getPageContentHeight(page)
	local bottomReserve = math.max(32, tonumber(self.ScrollBottomPadding) or 64)
	local viewportHeight = math.max(0, page.AbsoluteSize.Y)
	local canvasHeight = math.max(viewportHeight, math.ceil(contentHeight + bottomReserve))
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.CanvasSize = UDim2.fromOffset(0, canvasHeight)
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.ScrollingEnabled = true
	page.Active = true
	page.ClipsDescendants = true
	local maxScroll = math.max(0, canvasHeight - viewportHeight)
	if page.CanvasPosition.Y > maxScroll then
		page.CanvasPosition = Vector2.new(page.CanvasPosition.X, maxScroll)
	end
	return canvasHeight, contentHeight
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
		local _, measuredHeight = self:_updatePageCanvas(active.Page)
		pageContentHeight = measuredHeight or 0
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
		for _, child in ipairs(active.Page:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				local childMinWidth = tonumber(child:GetAttribute("AnchorlineMinWidth")) or 0
				if childMinWidth <= 0 and child.AbsoluteSize.X > 0 then
					childMinWidth = math.min(child.AbsoluteSize.X, pageWidth)
				end
				minimumContentWidth = math.max(minimumContentWidth, childMinWidth)
			end
		end
	end
	return minimumContentWidth, pageContentHeight
end

function Window:_calculateSmartSize()
	local viewport = getViewportSize()
	local margin = math.max(12, tonumber(self.SmartViewportMargin) or 44)
	local baseMinWidth = tonumber(self.MinWidth) or 560
	local baseMinHeight = tonumber(self.MinHeight) or 390
	local availableWidth = math.max(baseMinWidth, viewport.X - margin * 2)
	local availableHeight = math.max(baseMinHeight, viewport.Y - margin * 2)
	local maxWidth = math.min(tonumber(self.MaxWidth) or 1040, availableWidth)
	local maxHeight = math.min(tonumber(self.MaxHeight) or 760, availableHeight)
	local contentMinWidth, pageContentHeight = self:_measureActiveContent()
	local sidebarWidth = self.SidebarCollapsed and 64 or self.SidebarWidth
	local outerGutter = 42
	local smartMinWidth = math.min(maxWidth, math.max(baseMinWidth, sidebarWidth + contentMinWidth + outerGutter))
	local chromeHeight = 58 + 66 + 38
	local maximumScrollableContentHeight = math.max(180, maxHeight - chromeHeight)
	local fittedContentHeight = math.min(pageContentHeight, maximumScrollableContentHeight)
	local smartMinHeight = math.min(maxHeight, math.max(baseMinHeight, chromeHeight + math.min(fittedContentHeight, 260)))
	local targetWidth = math.max(smartMinWidth, tonumber(self.Width) or baseMinWidth)
	local targetHeight = math.max(smartMinHeight, chromeHeight + fittedContentHeight)
	if self._manualSizeLocked then
		targetWidth = math.max(targetWidth, tonumber(self.Width) or targetWidth)
		targetHeight = math.max(targetHeight, tonumber(self.Height) or targetHeight)
	end
	targetWidth, targetHeight = clampVectorSize(targetWidth, targetHeight, smartMinWidth, smartMinHeight, maxWidth, maxHeight)
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
	local needsResize = math.abs(currentSize.X - targetWidth) >= 1 or math.abs(currentSize.Y - targetHeight) >= 1
	if needsResize then
		if animated then
			tween(self.Root, 0.46, {Size = targetSize}, Enum.EasingStyle.Quint)
		else
			self.Root.Size = targetSize
		end
		self.Width = targetWidth
		self.Height = targetHeight
	end
	local function deferredRefresh()
		if self.Root and self.Root.Parent then
			self:_refreshAdaptiveLayouts()
			self:_refreshPageCanvases()
		end
	end
	task.defer(deferredRefresh)
	task.delay(0.04, deferredRefresh)
	task.delay(0.12, deferredRefresh)
	task.delay(0.28, deferredRefresh)
	task.delay(0.5, deferredRefresh)
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
	task.delay(0.03, function()
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
		self._manualSizeLocked = true
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
	local iconBox = new("Frame", {
		Name = "IconBox",
		Position = UDim2.fromOffset(9, 5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = self.FrostedGlass and 0.36 or 0.52,
		BorderSizePixel = 0,
		Parent = button
	}, {corner(8)})
	self:_track(iconBox, {BackgroundColor3 = "AccentSoft"})
	local iconImage = new("ImageLabel", {
		Name = "IconImage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(20, 20),
		ScaleType = Enum.ScaleType.Fit,
		Visible = tab.IconAsset ~= nil,
		Parent = iconBox
	})
	if tab.IconAsset then
		applyIconAssetToImageLabel(iconImage, tab.IconAsset)
	end
	local iconHolder = new("Frame", {
		Name = "VectorIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(20, 20),
		Visible = tab.IconAsset == nil,
		Parent = iconBox
	})
	local iconShapes = createVectorIcon(iconHolder, icon or tab.Name)
	if #iconShapes == 0 then
		iconHolder.Visible = false
	end
	local iconLabel = nil
	local titleLabel = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -54, 1, 0),
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
	tab.ButtonIconBox = iconBox
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
	local precision = options.Precision or options.DecimalPlaces or options.Decimals
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
		valueLabel.Text = formatSliderNumber(value, increment, precision) .. (suffix ~= "" and " " .. suffix or "")
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
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UITableLayout") or child:IsA("UIPadding") or child:IsA("UICorner") or child:IsA("UIStroke") then
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
	self._manualSizeLocked = false
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
	frame.ClipsDescendants = true
	frame.BackgroundTransparency = window.FrostedGlass and 0.08 or frame.BackgroundTransparency
	local accentRail = new("Frame", {
		Name = "HeroAccent",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(0, 5, 1, -32),
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
			ImageColor3 = options.Tint == false and Color3.fromRGB(255, 255, 255) or getThemeValue(window, "Accent"),
			Parent = iconBox
		})
		applyIconAssetToImageLabel(image, asset)
	else
		local vector = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(20, 20), Parent = iconBox})
		local shapes = createVectorIcon(vector, options.Icon or titleText)
		for _, shape in ipairs(shapes) do
			if shape:IsA("TextLabel") then
				shape.TextColor3 = getThemeValue(window, "Accent")
			elseif shape:GetAttribute("AnchorlineIconCutout") then
				shape.BackgroundColor3 = iconBox.BackgroundColor3
			else
				shape.BackgroundColor3 = getThemeValue(window, "Accent")
			end
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
		applyIconAssetToImageLabel(image, asset)
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
			local image = new("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(18, 18), ScaleType = Enum.ScaleType.Fit, ImageColor3 = tool.Tint == false and Color3.fromRGB(255, 255, 255) or getThemeValue(window, tool.Primary and "AccentText" or "Accent"), Parent = button})
			applyIconAssetToImageLabel(image, asset)
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
	local resolved = findLucideProvider(provider)
	if resolved then
		Anchorline.IconProvider = resolved
		Anchorline.LucideProvider = resolved
	elseif type(provider) == "table" then
		Anchorline.IconProvider = provider
		Anchorline.LucideProvider = provider
	end
	return Anchorline
end

function Anchorline:UseLucide(provider)
	local resolved = findLucideProvider(provider)
	if resolved then
		Anchorline.IconProvider = resolved
		Anchorline.LucideProvider = resolved
	end
	return Anchorline
end

Anchorline.SetLucideProvider = Anchorline.UseLucide

function Anchorline:HasLucide()
	return findLucideProvider(Anchorline.LucideProvider or Anchorline.IconProvider) ~= nil
end

function Anchorline:SetTheme(name, theme)
	if type(name) == "string" and type(theme) == "table" then
		Anchorline.Themes[name] = theme
	end
	return Anchorline
end



-- Anchorline compatibility and hardening layer
-- This layer keeps Anchorline's native API intact while accepting common patterns from Rayfield-style,
-- Kavo-style, Orion-style, and basic custom UI scripts. It avoids emoji aliases and keeps all icons
-- resolved through clean vector names, Roblox asset IDs, or a Lucide provider when available.

local function anchorlineTrim(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function anchorlineNormalizeType(value)
	local cleaned = anchorlineTrim(value):lower()
	cleaned = cleaned:gsub("[%s_]+", "-"):gsub("[^%w%-]", "")
	cleaned = cleaned:gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
	return cleaned
end

local function anchorlineCopyTable(source)
	local copy = {}
	if type(source) == "table" then
		for key, value in pairs(source) do
			copy[key] = value
		end
	end
	return copy
end

local function anchorlinePackOptions(a, b, c, d, e, f)
	if type(a) == "table" then
		return anchorlineCopyTable(a)
	end
	return {
		Name = a,
		Description = b,
		Callback = c,
		Value = d,
		Extra = e,
		Extra2 = f
	}
end

local function anchorlineEnhanceController(controller)
	if type(controller) ~= "table" then
		return controller
	end
	if type(controller.Get) == "function" then
		controller.GetValue = controller.GetValue or function(self)
			return self:Get()
		end
		controller.Value = controller.Value or function(self)
			return self:Get()
		end
	end
	if type(controller.Set) == "function" then
		controller.SetValue = controller.SetValue or function(self, value)
			return self:Set(value)
		end
		controller.Update = controller.Update or function(self, value)
			return self:Set(value)
		end
		controller.SetState = controller.SetState or function(self, value)
			return self:Set(value)
		end
	end
	if type(controller.Refresh) == "function" then
		controller.SetOptions = controller.SetOptions or function(self, options, keepValue)
			return self:Refresh(options, keepValue)
		end
		controller.UpdateOptions = controller.UpdateOptions or function(self, options, keepValue)
			return self:Refresh(options, keepValue)
		end
	end
	if type(controller.Fire) == "function" then
		controller.Call = controller.Call or function(self, ...)
			return self:Fire(...)
		end
	end
	return controller
end

local anchorlineNativeCreateButton = Tab.CreateButton
local anchorlineNativeCreateToggle = Tab.CreateToggle
local anchorlineNativeCreateSlider = Tab.CreateSlider
local anchorlineNativeCreateInput = Tab.CreateInput
local anchorlineNativeCreateDropdown = Tab.CreateDropdown
local anchorlineNativeCreateKeybind = Tab.CreateKeybind
local anchorlineNativeCreateColorPicker = Tab.CreateColorPicker
local anchorlineNativeCreateProgress = Tab.CreateProgress
local anchorlineNativeCreateInfoBox = Tab.CreateInfoBox
local anchorlineNativeCreateParagraph = Tab.CreateParagraph
local anchorlineNativeCreateLabel = Tab.CreateLabel
local anchorlineNativeCreateSection = Tab.CreateSection
local anchorlineNativeCreateDivider = Tab.CreateDivider

local function anchorlineNormalizeButtonOptions(a, b, c)
	local options = anchorlinePackOptions(a, b, c)
	options.Name = options.Name or options.Title or options.Text or "Button"
	options.Description = options.Description or options.Info or options.Content
	options.ButtonText = options.ButtonText or options.TextButton or options.ActionText or options.Label or options.ButtonName or "Run"
	if type(options.Callback) ~= "function" and type(c) == "function" then
		options.Callback = c
	end
	return options
end

function Tab:CreateButton(a, b, c)
	return anchorlineEnhanceController(anchorlineNativeCreateButton(self, anchorlineNormalizeButtonOptions(a, b, c)))
end

local function anchorlineNormalizeToggleOptions(a, b, c, d)
	local options = anchorlinePackOptions(a, b, c, d)
	options.Name = options.Name or options.Title or options.Text or "Toggle"
	options.Description = options.Description or options.Info or options.Content
	if options.CurrentValue == nil then
		if options.Default ~= nil then options.CurrentValue = options.Default end
		if options.Value ~= nil then options.CurrentValue = options.Value end
		if options.Enabled ~= nil then options.CurrentValue = options.Enabled end
	end
	if options.Keybind == nil then
		options.Keybind = options.Key or options.Bind or options.CurrentKeybind
	end
	if type(options.Callback) ~= "function" and type(c) == "function" then
		options.Callback = c
	end
	return options
end

function Tab:CreateToggle(a, b, c, d)
	return anchorlineEnhanceController(anchorlineNativeCreateToggle(self, anchorlineNormalizeToggleOptions(a, b, c, d)))
end

local function anchorlineNormalizeSliderOptions(a, b, c, d, e, f)
	local options = anchorlinePackOptions(a, b, f, c, d, e)
	if type(a) == "table" then
		options = anchorlineCopyTable(a)
	end
	options.Name = options.Name or options.Title or options.Text or "Slider"
	options.Description = options.Description or options.Info or options.Content
	if not options.Range then
		local minValue = options.Min or options.Minimum or options.min or (type(c) == "number" and c or nil) or 0
		local maxValue = options.Max or options.Maximum or options.max or (type(d) == "number" and d or nil) or 100
		options.Range = {minValue, maxValue}
	end
	if options.CurrentValue == nil then
		options.CurrentValue = options.Default or options.Value or options.StartValue or options.Current or (type(e) == "number" and e or nil) or options.Range[1]
	end
	options.Increment = tonumber(options.Increment or options.Step or options.step or options.Interval) or 1
	options.Suffix = options.Suffix or options.Unit or ""
	if type(options.Callback) ~= "function" then
		if type(b) == "function" then options.Callback = b end
		if type(e) == "function" then options.Callback = e end
		if type(f) == "function" then options.Callback = f end
	end
	return options
end

function Tab:CreateSlider(a, b, c, d, e, f)
	return anchorlineEnhanceController(anchorlineNativeCreateSlider(self, anchorlineNormalizeSliderOptions(a, b, c, d, e, f)))
end

local function anchorlineNormalizeInputOptions(a, b, c)
	local options = anchorlinePackOptions(a, b, c)
	options.Name = options.Name or options.Title or options.Text or "Input"
	options.Description = options.Description or options.Info or options.Content
	options.PlaceholderText = options.PlaceholderText or options.Placeholder or options.DefaultText or options.Hint or "Type here"
	if options.CurrentValue == nil then
		options.CurrentValue = options.Default or options.Value or ""
	end
	if type(options.Callback) ~= "function" and type(c) == "function" then
		options.Callback = c
	end
	return options
end

function Tab:CreateInput(a, b, c)
	return anchorlineEnhanceController(anchorlineNativeCreateInput(self, anchorlineNormalizeInputOptions(a, b, c)))
end

local function anchorlineNormalizeDropdownOptions(a, b, c, d)
	local options = anchorlinePackOptions(a, b, d)
	if type(a) == "table" then
		options = anchorlineCopyTable(a)
	end
	options.Name = options.Name or options.Title or options.Text or "Dropdown"
	options.Description = options.Description or options.Info or options.Content
	options.Options = options.Options or options.Values or options.Items or options.List or (type(c) == "table" and c or {})
	if options.CurrentOption == nil then
		options.CurrentOption = options.Default or options.Value or options.CurrentValue
	end
	if options.Multiple == nil then
		options.Multiple = options.MultiSelect or options.MultipleOptions or false
	end
	if type(options.Callback) ~= "function" then
		if type(c) == "function" then options.Callback = c end
		if type(d) == "function" then options.Callback = d end
	end
	return options
end

function Tab:CreateDropdown(a, b, c, d)
	return anchorlineEnhanceController(anchorlineNativeCreateDropdown(self, anchorlineNormalizeDropdownOptions(a, b, c, d)))
end

local function anchorlineNormalizeKeybindOptions(a, b, c, d)
	local options = anchorlinePackOptions(a, b, d, c)
	if type(a) == "table" then
		options = anchorlineCopyTable(a)
	end
	options.Name = options.Name or options.Title or options.Text or "Keybind"
	options.Description = options.Description or options.Info or options.Content
	options.CurrentKeybind = options.CurrentKeybind or options.Keybind or options.Key or options.Bind or (typeof(c) == "EnumItem" and c or nil) or Enum.KeyCode.RightControl
	if type(options.Callback) ~= "function" then
		if type(c) == "function" then options.Callback = c end
		if type(d) == "function" then options.Callback = d end
	end
	return options
end

function Tab:CreateKeybind(a, b, c, d)
	return anchorlineEnhanceController(anchorlineNativeCreateKeybind(self, anchorlineNormalizeKeybindOptions(a, b, c, d)))
end

local function anchorlineNormalizeColorOptions(a, b, c)
	local options = anchorlinePackOptions(a, b, c)
	if type(a) == "table" then
		options = anchorlineCopyTable(a)
	end
	options.Name = options.Name or options.Title or options.Text or "Color Picker"
	options.Description = options.Description or options.Info or options.Content
	options.Color = options.Color or options.CurrentColor or options.Default or options.Value
	if type(options.Callback) ~= "function" and type(c) == "function" then
		options.Callback = c
	end
	return options
end

function Tab:CreateColorPicker(a, b, c)
	return anchorlineEnhanceController(anchorlineNativeCreateColorPicker(self, anchorlineNormalizeColorOptions(a, b, c)))
end

function Tab:CreateProgress(a, b, c, d, e)
	return anchorlineEnhanceController(anchorlineNativeCreateProgress(self, anchorlineNormalizeSliderOptions(a, b, c, d, e)))
end

function Tab:CreateLabel(a)
	if type(a) == "table" then
		return anchorlineNativeCreateLabel(self, a.Text or a.Name or a.Title or a.Content or "Label")
	end
	return anchorlineNativeCreateLabel(self, a)
end

function Tab:CreateParagraph(a, b)
	if type(a) == "table" then
		return anchorlineNativeCreateParagraph(self, a)
	end
	return anchorlineNativeCreateParagraph(self, {Title = a or "Paragraph", Content = b or ""})
end

function Tab:CreateInfoBox(a, b, c)
	if type(a) == "table" then
		return anchorlineNativeCreateInfoBox(self, a)
	end
	return anchorlineNativeCreateInfoBox(self, {Title = a or "Info", Content = b or "", Type = c or "Info"})
end

function Tab:CreateSection(a)
	if type(a) == "table" then
		return anchorlineNativeCreateSection(self, a.Name or a.Title or a.Text or "Section")
	end
	return anchorlineNativeCreateSection(self, a)
end

function Tab:CreateDivider()
	return anchorlineNativeCreateDivider(self)
end

function Tab:CreateElement(kindOrOptions, maybeOptions)
	local kind = nil
	local options = nil
	if type(kindOrOptions) == "table" then
		options = anchorlineCopyTable(kindOrOptions)
		kind = options.Type or options.ElementType or options.Kind or options.Class or options.Control or options.Component
	elseif type(kindOrOptions) == "string" and type(maybeOptions) == "table" then
		kind = kindOrOptions
		options = anchorlineCopyTable(maybeOptions)
	elseif type(kindOrOptions) == "string" then
		kind = kindOrOptions
		options = {Name = kindOrOptions}
	else
		options = {}
	end

	if not kind or kind == "" then
		if options.Range or options.Min or options.Max then
			kind = "slider"
		elseif options.Options or options.Values or options.Items then
			kind = "dropdown"
		elseif options.Color or options.CurrentColor then
			kind = "color-picker"
		elseif options.CurrentKeybind or options.Keybind or options.Key then
			kind = "keybind"
		elseif type(options.CurrentValue) == "boolean" or type(options.Default) == "boolean" then
			kind = "toggle"
		elseif options.PlaceholderText or options.Placeholder or options.Input then
			kind = "input"
		elseif options.Content and not options.Callback then
			kind = "paragraph"
		elseif options.Callback then
			kind = "button"
		else
			kind = "label"
		end
	end

	local normalized = anchorlineNormalizeType(kind)
	if normalized == "button" or normalized == "action" then
		return self:CreateButton(options)
	elseif normalized == "toggle" or normalized == "switch" or normalized == "checkbox" then
		return self:CreateToggle(options)
	elseif normalized == "slider" or normalized == "range" then
		return self:CreateSlider(options)
	elseif normalized == "input" or normalized == "textbox" or normalized == "text-box" or normalized == "textinput" then
		return self:CreateInput(options)
	elseif normalized == "dropdown" or normalized == "select" or normalized == "combo" or normalized == "combobox" then
		return self:CreateDropdown(options)
	elseif normalized == "keybind" or normalized == "bind" or normalized == "key" then
		return self:CreateKeybind(options)
	elseif normalized == "color" or normalized == "colour" or normalized == "colorpicker" or normalized == "color-picker" or normalized == "colourpicker" then
		return self:CreateColorPicker(options)
	elseif normalized == "progress" or normalized == "meter" then
		return self:CreateProgress(options)
	elseif normalized == "section" or normalized == "heading" then
		return self:CreateSection(options)
	elseif normalized == "divider" or normalized == "separator" or normalized == "line" then
		return self:CreateDivider()
	elseif normalized == "paragraph" or normalized == "textblock" or normalized == "text-block" then
		return self:CreateParagraph(options)
	elseif normalized == "infobox" or normalized == "info-box" or normalized == "notice" or normalized == "callout" then
		if self.CreateCallout and normalized == "callout" then
			return self:CreateCallout(options)
		end
		return self:CreateInfoBox(options)
	elseif normalized == "badge" and self.CreateBadge then
		return self:CreateBadge(options)
	elseif normalized == "stat" or normalized == "statcard" or normalized == "stat-card" then
		if self.CreateStatCard then return self:CreateStatCard(options) end
	elseif normalized == "textarea" or normalized == "text-area" then
		if self.CreateTextArea then return self:CreateTextArea(options) end
	elseif normalized == "spacer" then
		if self.CreateSpacer then return self:CreateSpacer(options.Height or options.Size or 12) end
	end
	return self:CreateLabel(options.Text or options.Name or options.Title or tostring(kind))
end

Tab.AddElement = Tab.CreateElement
Tab.Element = Tab.CreateElement
Tab.AddButton = Tab.CreateButton
Tab.Button = Tab.CreateButton
Tab.NewButton = Tab.CreateButton
Tab.AddToggle = Tab.CreateToggle
Tab.Toggle = Tab.CreateToggle
Tab.NewToggle = Tab.CreateToggle
Tab.AddSlider = Tab.CreateSlider
Tab.Slider = Tab.CreateSlider
Tab.NewSlider = function(self, name, description, minValue, maxValue, defaultValue, callback)
	return self:CreateSlider({Name = name, Description = description, Range = {minValue or 0, maxValue or 100}, CurrentValue = defaultValue, Callback = callback})
end
Tab.AddInput = Tab.CreateInput
Tab.Input = Tab.CreateInput
Tab.TextBox = Tab.CreateInput
Tab.Textbox = Tab.CreateInput
Tab.AddTextbox = Tab.CreateInput
Tab.NewTextBox = function(self, name, description, callback)
	return self:CreateInput({Name = name, Description = description, Callback = callback})
end
Tab.AddDropdown = Tab.CreateDropdown
Tab.Dropdown = Tab.CreateDropdown
Tab.NewDropdown = function(self, name, description, options, callback)
	return self:CreateDropdown({Name = name, Description = description, Options = options or {}, Callback = callback})
end
Tab.AddKeybind = Tab.CreateKeybind
Tab.Keybind = Tab.CreateKeybind
Tab.NewKeybind = function(self, name, description, key, callback)
	return self:CreateKeybind({Name = name, Description = description, CurrentKeybind = key, Callback = callback})
end
Tab.AddColorPicker = Tab.CreateColorPicker
Tab.ColorPicker = Tab.CreateColorPicker
Tab.AddColorpicker = Tab.CreateColorPicker
Tab.NewColorPicker = function(self, name, description, color, callback)
	return self:CreateColorPicker({Name = name, Description = description, Color = color, Callback = callback})
end
Tab.AddLabel = Tab.CreateLabel
Tab.Label = Tab.CreateLabel
Tab.NewLabel = Tab.CreateLabel
Tab.AddParagraph = Tab.CreateParagraph
Tab.Paragraph = Tab.CreateParagraph
Tab.AddSection = Tab.CreateSection
Tab.Section = Tab.CreateSection
Tab.AddDivider = Tab.CreateDivider
Tab.Divider = Tab.CreateDivider

local function anchorlineCreateSectionProxy(tab, name)
	tab:CreateSection(name)
	local section = {Tab = tab, Name = tostring(name or "Section")}
	function section:CreateElement(...)
		return self.Tab:CreateElement(...)
	end
	function section:CreateButton(...)
		return self.Tab:CreateButton(...)
	end
	function section:CreateToggle(...)
		return self.Tab:CreateToggle(...)
	end
	function section:CreateSlider(...)
		return self.Tab:CreateSlider(...)
	end
	function section:CreateInput(...)
		return self.Tab:CreateInput(...)
	end
	function section:CreateDropdown(...)
		return self.Tab:CreateDropdown(...)
	end
	function section:CreateKeybind(...)
		return self.Tab:CreateKeybind(...)
	end
	function section:CreateColorPicker(...)
		return self.Tab:CreateColorPicker(...)
	end
	function section:CreateLabel(...)
		return self.Tab:CreateLabel(...)
	end
	function section:CreateParagraph(...)
		return self.Tab:CreateParagraph(...)
	end
	section.AddElement = section.CreateElement
	section.AddButton = section.CreateButton
	section.Button = section.CreateButton
	section.NewButton = section.CreateButton
	section.AddToggle = section.CreateToggle
	section.Toggle = section.CreateToggle
	section.NewToggle = section.CreateToggle
	section.AddSlider = section.CreateSlider
	section.Slider = section.CreateSlider
	section.NewSlider = function(self, nameText, description, minValue, maxValue, defaultValue, callback)
		return self.Tab:CreateSlider({Name = nameText, Description = description, Range = {minValue or 0, maxValue or 100}, CurrentValue = defaultValue, Callback = callback})
	end
	section.AddDropdown = section.CreateDropdown
	section.Dropdown = section.CreateDropdown
	section.NewDropdown = function(self, nameText, description, items, callback)
		return self.Tab:CreateDropdown({Name = nameText, Description = description, Options = items or {}, Callback = callback})
	end
	section.AddTextbox = section.CreateInput
	section.NewTextBox = function(self, nameText, description, callback)
		return self.Tab:CreateInput({Name = nameText, Description = description, Callback = callback})
	end
	section.AddKeybind = section.CreateKeybind
	section.NewKeybind = function(self, nameText, description, key, callback)
		return self.Tab:CreateKeybind({Name = nameText, Description = description, CurrentKeybind = key, Callback = callback})
	end
	section.AddColorPicker = section.CreateColorPicker
	section.NewColorPicker = function(self, nameText, description, color, callback)
		return self.Tab:CreateColorPicker({Name = nameText, Description = description, Color = color, Callback = callback})
	end
	section.AddLabel = section.CreateLabel
	section.NewLabel = section.CreateLabel
	local visualNames = {"Banner", "EmptyState", "MetricGrid", "CardGrid", "ProfileCard", "Accordion", "PropertyGrid", "ResourceBars", "CodeBlock", "CommandPanel", "SplitPanel", "Dashboard"}
	for _, visualName in ipairs(visualNames) do
		section["Create" .. visualName] = function(self, ...)
			local method = self.Tab["Create" .. visualName]
			if type(method) == "function" then
				return method(self.Tab, ...)
			end
			return self.Tab:CreateElement(visualName, ...)
		end
		section["Add" .. visualName] = section["Create" .. visualName]
	end
	return section
end

function Tab:NewSection(name)
	return anchorlineCreateSectionProxy(self, name)
end

local anchorlineNativeCreateTab = Window.CreateTab
function Window:CreateTab(name, icon, description)
	if type(name) == "table" then
		local options = name
		return anchorlineNativeCreateTab(self, options.Name or options.Title or options.Text or "Tab", options.Icon or options.Image or options.Logo, options.Description or options.Subtitle)
	end
	return anchorlineNativeCreateTab(self, name, icon, description)
end

Window.AddTab = Window.CreateTab
Window.NewTab = Window.CreateTab
Window.Tab = Window.CreateTab
Window.GetOrCreateTab = Window.CreateOrGetTab
Window.AddPage = Window.CreateTab
Window.Page = Window.CreateTab

function Window:CreateElement(kindOrOptions, maybeOptions)
	local targetTab = self.ActiveTab
	if not targetTab then
		targetTab = self:CreateTab("Main", "home", "Main controls")
	end
	return targetTab:CreateElement(kindOrOptions, maybeOptions)
end

Window.AddElement = Window.CreateElement
Window.Element = Window.CreateElement

function Window:MakeNotification(options)
	return self:Notify(options)
end
Window.CreateNotification = Window.Notify
Window.Notification = Window.Notify
Window.Minimise = Window.Minimize
Window.ToggleUI = Window.Toggle
Window.Close = Window.Destroy

function Window:GetFlag(flag)
	local controller = self.Flags and self.Flags[flag]
	if controller and type(controller.Get) == "function" then
		return controller:Get()
	end
	return nil
end

function Window:SetFlag(flag, value)
	local controller = self.Flags and self.Flags[flag]
	if controller and type(controller.Set) == "function" then
		controller:Set(value)
		return true
	end
	return false
end

function Window:LoadConfig(fileName)
	return self:LoadConfiguration(fileName)
end
function Window:SaveConfig(fileName)
	return self:SaveConfiguration(fileName)
end


function Window:GetService(serviceName, silent)
	return Anchorline:GetService(serviceName, silent)
end

function Window:HasService(serviceName)
	return Anchorline:HasService(serviceName)
end

function Window:IsServiceAvailable(serviceName)
	return Anchorline:IsServiceAvailable(serviceName)
end

local anchorlineNativeCreateWindow = Anchorline.CreateWindow
function Anchorline:CreateWindow(options)
	if type(options) ~= "table" then
		options = {Title = tostring(options or "Anchorline")}
	end
	options.Title = options.Title or options.Name or options.WindowName or options.LoadingTitle or "Anchorline"
	options.Subtitle = options.Subtitle or options.LoadingSubtitle or options.Description or "Reusable interface library"
	options.Configuration = options.Configuration or options.ConfigurationSaving or options.Config or {Enabled = false}
	if options.ToggleKey == nil then
		options.ToggleKey = options.HideKey or options.ToggleBind or Enum.KeyCode.RightShift
	end
	local window = anchorlineNativeCreateWindow(self, options)
	return window
end

function Anchorline:MakeWindow(options)
	return self:CreateWindow(options)
end

function Anchorline:CreateLib(name, theme)
	return self:CreateWindow({Title = name or "Anchorline", Theme = theme or "Workbench"})
end

function Anchorline:MakeNotification(options)
	return self:Notify(options)
end

function Anchorline:LoadConfiguration(fileName)
	local window = self.LastWindow or Anchorline.LastWindow
	if window and window.LoadConfiguration then
		return window:LoadConfiguration(fileName)
	end
	return false
end

function Anchorline:SaveConfiguration(fileName)
	local window = self.LastWindow or Anchorline.LastWindow
	if window and window.SaveConfiguration then
		return window:SaveConfiguration(fileName)
	end
	return false
end

function Anchorline:Destroy()
	for _, window in ipairs(self.Windows or {}) do
		if window and type(window.Destroy) == "function" then
			pcall(function()
				window:Destroy()
			end)
		end
	end
	self.Windows = setmetatable({}, {__mode = "v"})
	self.LastWindow = nil
end



local function anchorlineVisualIcon(window, parent, icon, size, color, cutoutColor)
	size = tonumber(size) or 22
	local asset = window:_resolveIcon(icon)
	if asset then
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(0, 0),
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = color or getThemeValue(window, "Accent"),
			Parent = parent
		})
		applyIconAssetToImageLabel(image, asset)
		return {Root = image, Shapes = {image}}
	end
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent
	})
	local scale = math.max(size / 20, 0.8)
	local inner = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(math.floor((size - 20) / 2), math.floor((size - 20) / 2)),
		Size = UDim2.fromOffset(20, 20),
		Parent = holder
	})
	if math.abs(scale - 1) > 0.01 then
		new("UIScale", {Scale = scale, Parent = inner})
	end
	local shapes = createVectorIcon(inner, icon)
	for _, shapeObject in ipairs(shapes) do
		if shapeObject:IsA("TextLabel") then
			shapeObject.TextColor3 = color or getThemeValue(window, "Accent")
		elseif shapeObject:GetAttribute("AnchorlineIconCutout") then
			shapeObject.BackgroundColor3 = cutoutColor or getThemeValue(window, "Surface")
		else
			shapeObject.BackgroundColor3 = color or getThemeValue(window, "Accent")
		end
	end
	return {Root = holder, Shapes = shapes}
end

local function anchorlineVisualButton(window, parent, text, width, primary, callback)
	local button = new("TextButton", {
		Name = "VisualButton",
		Size = UDim2.fromOffset(width or 108, 34),
		Text = tostring(text or "Action"),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
		Parent = parent
	}, {corner(10), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(button, {BackgroundColor3 = primary and "Accent" or "Surface", TextColor3 = primary and "AccentText" or "Text"})
	button.MouseEnter:Connect(function()
		tween(button, 0.16, {BackgroundTransparency = primary and 0.05 or 0.08}, Enum.EasingStyle.Quint)
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.2, {BackgroundTransparency = 0}, Enum.EasingStyle.Quint)
	end)
	button.MouseButton1Click:Connect(function()
		safeCall(callback)
	end)
	return button
end

local function anchorlineVisualRelayoutGrid(window, frame, holder, grid, count, minimumWidth, cellHeight, topHeight, gap)
	if not frame or not frame.Parent or not holder or not holder.Parent or not grid then return end
	local available = math.max(frame.AbsoluteSize.X - 28, 260)
	minimumWidth = tonumber(minimumWidth) or 150
	cellHeight = tonumber(cellHeight) or 82
	gap = tonumber(gap) or 10
	local columns = math.max(1, math.floor((available + gap) / (minimumWidth + gap)))
	local cellWidth = math.max(minimumWidth, math.floor((available - gap * math.max(columns - 1, 0)) / columns))
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	grid.FillDirectionMaxCells = columns
	local rows = math.max(1, math.ceil(math.max(count or 0, 1) / columns))
	local holderHeight = rows * cellHeight + math.max(rows - 1, 0) * gap
	holder.Size = UDim2.new(1, 0, 0, holderHeight)
	frame.Size = UDim2.new(1, 0, 0, (tonumber(topHeight) or 56) + holderHeight)
	window:_refreshPageCanvases()
end

function Tab:CreateBanner(options)
	options = options or {}
	local window = self.Window
	local titleText = tostring(options.Title or options.Name or "Banner")
	local bodyText = tostring(options.Content or options.Description or options.Text or "")
	local action = options.Action or options.Button
	local height = tonumber(options.Height) or (action and 116 or 94)
	local frame = window:_createElement(self, titleText, titleText .. " " .. bodyText .. " banner", height)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	if layout then layout:Destroy() end
	frame:SetAttribute("AnchorlineMinWidth", 430)
	local accentColor = anchorlineKindColor(window, options.Type or options.Kind or "Info")
	local glow = new("Frame", {Name = "BannerTint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = accentColor, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = frame}, {corner(12)})
	local rail = new("Frame", {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(5, height), BackgroundColor3 = accentColor, BorderSizePixel = 0, Parent = frame}, {corner(3)})
	local iconBox = new("Frame", {Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(42, 42), BackgroundTransparency = window.FrostedGlass and 0.12 or 0, Parent = frame}, {corner(13), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(iconBox, {BackgroundColor3 = "AccentSoft"})
	anchorlineVisualIcon(window, iconBox, options.Icon or options.Image or options.Type or "info", 22, accentColor, iconBox.BackgroundColor3).Root.Position = UDim2.fromOffset(10, 10)
	local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(72, 18), Size = UDim2.new(1, action and -214 or -92, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = titleText, Parent = frame})
	window:_track(title, {TextColor3 = "Text"})
	local bodyHeight = math.max(34, measureWrappedText(bodyText, 13, Enum.Font.Gotham, math.max(frame.AbsoluteSize.X - (action and 260 or 120), 260)))
	local body = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(72, 45), Size = UDim2.new(1, action and -214 or -92, 0, math.min(bodyHeight, 44)), Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = bodyText, Parent = frame})
	window:_track(body, {TextColor3 = "TextMuted"})
	local actionButton
	if action then
		actionButton = anchorlineVisualButton(window, frame, action.Text or action.Name or "Open", tonumber(action.Width) or 112, action.Primary ~= false, action.Callback)
		actionButton.AnchorPoint = Vector2.new(1, 0.5)
		actionButton.Position = UDim2.new(1, -16, 0.5, 0)
	end
	local controller = {Type = "Banner", Frame = frame}
	function controller:SetTitle(value)
		titleText = tostring(value or "")
		title.Text = titleText
		frame:SetAttribute("SearchText", titleText .. " " .. bodyText)
	end
	function controller:SetContent(value)
		bodyText = tostring(value or "")
		body.Text = bodyText
		frame:SetAttribute("SearchText", titleText .. " " .. bodyText)
	end
	return controller
end

function Tab:CreateEmptyState(options)
	options = options or {}
	local window = self.Window
	local titleText = tostring(options.Title or options.Name or "Nothing here yet")
	local bodyText = tostring(options.Content or options.Description or options.Text or "Add items or run an action to populate this section.")
	local height = tonumber(options.Height) or 154
	local frame = window:_createElement(self, titleText, titleText .. " " .. bodyText .. " empty state", height)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	if layout then layout:Destroy() end
	local iconCircle = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(48, 48), BackgroundTransparency = window.FrostedGlass and 0.12 or 0, Parent = frame}, {corner(18), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(iconCircle, {BackgroundColor3 = "AccentSoft"})
	anchorlineVisualIcon(window, iconCircle, options.Icon or "folder", 24, getThemeValue(window, "Accent"), iconCircle.BackgroundColor3).Root.Position = UDim2.fromOffset(12, 12)
	local title = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.new(1, -40, 0, 24), Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Text = titleText, Parent = frame})
	window:_track(title, {TextColor3 = "Text"})
	local body = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 106), Size = UDim2.new(1, -72, 0, 40), Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Text = bodyText, Parent = frame})
	window:_track(body, {TextColor3 = "TextMuted"})
	return {Type = "EmptyState", Frame = frame, SetTitle = function(_, value) title.Text = tostring(value or "") end, SetContent = function(_, value) body.Text = tostring(value or "") end}
end

function Tab:CreateMetricGrid(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Metrics")
	local items = options.Items or options.Metrics or options.Stats or {}
	local frame = window:_createElement(self, name, name .. " metric grid stats", 168)
	frame:SetAttribute("AnchorlineMinWidth", 440)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "MetricCells", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), Parent = frame})
	local grid = new("UIGridLayout", {SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = holder})
	local cells = {}
	local controller = {Type = "MetricGrid", Frame = frame}
	local function render(item, index)
		local cell = new("Frame", {Name = "Metric" .. index, BackgroundTransparency = window.FrostedGlass and 0.16 or 0, Parent = holder}, {corner(12), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(cell, {BackgroundColor3 = "Surface"})
		local iconBox = new("Frame", {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = window.FrostedGlass and 0.14 or 0, Parent = cell}, {corner(10)})
		window:_track(iconBox, {BackgroundColor3 = "AccentSoft"})
		anchorlineVisualIcon(window, iconBox, item.Icon or item.Image or "bar-chart", 18, anchorlineKindColor(window, item.Type or item.Status or "Info"), iconBox.BackgroundColor3).Root.Position = UDim2.fromOffset(7, 7)
		local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 11), Size = UDim2.new(1, -64, 0, 18), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Name or item.Title or item.Label or "Metric"), Parent = cell})
		window:_track(title, {TextColor3 = "TextMuted"})
		local value = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 31), Size = UDim2.new(1, -64, 0, 24), Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Value or item.Text or "0"), Parent = cell})
		window:_track(value, {TextColor3 = "Text"})
		local delta = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 16), Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Delta or item.Description or item.Subtitle or ""), Parent = cell})
		window:_track(delta, {TextColor3 = "TextFaint"})
		cells[#cells + 1] = {Frame = cell, Title = title, Value = value, Delta = delta}
	end
	local function relayout()
		anchorlineVisualRelayoutGrid(window, frame, holder, grid, #items, tonumber(options.MinCellWidth) or 168, tonumber(options.CellHeight) or 86, 56, tonumber(options.Gap) or 10)
	end
	function controller:SetItems(newItems)
		items = newItems or {}
		anchorlineClearChildren(holder)
		cells = {}
		for index, item in ipairs(items) do render(type(item) == "table" and item or {Name = tostring(item)}, index) end
		relayout()
		window:_queueSmartResize()
	end
	function controller:GetItems() return items end
	window:_addAdaptiveHandler(relayout)
	window._connections[#window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	controller:SetItems(items)
	return controller
end

function Tab:CreateCardGrid(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Cards")
	local cards = options.Cards or options.Items or {}
	local frame = window:_createElement(self, name, name .. " card grid actions", 178)
	frame:SetAttribute("AnchorlineMinWidth", 450)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Cards", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 106), Parent = frame})
	local grid = new("UIGridLayout", {SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = holder})
	local buttons = {}
	local controller = {Type = "CardGrid", Frame = frame}
	local function build(card, index)
		local button = new("TextButton", {Name = "Card" .. index, Text = "", AutoButtonColor = false, BackgroundTransparency = window.FrostedGlass and 0.16 or 0, Parent = holder}, {corner(13), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(button, {BackgroundColor3 = "Surface"})
		local iconBox = new("Frame", {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = window.FrostedGlass and 0.16 or 0, Parent = button}, {corner(11)})
		window:_track(iconBox, {BackgroundColor3 = "AccentSoft"})
		anchorlineVisualIcon(window, iconBox, card.Icon or card.Image or "toolbox", 18, anchorlineKindColor(window, card.Type or card.Status or "Info"), iconBox.BackgroundColor3).Root.Position = UDim2.fromOffset(8, 8)
		local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(56, 12), Size = UDim2.new(1, -70, 0, 18), Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(card.Title or card.Name or "Card"), Parent = button})
		window:_track(title, {TextColor3 = "Text"})
		local body = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 34), Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = tostring(card.Description or card.Content or card.Text or ""), Parent = button})
		window:_track(body, {TextColor3 = "TextMuted"})
		if card.Badge or card.Tag then
			local badge = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 12), Size = UDim2.fromOffset(62, 20), BackgroundTransparency = window.FrostedGlass and 0.14 or 0, Font = Enum.Font.GothamMedium, TextSize = 10, Text = tostring(card.Badge or card.Tag), Parent = button}, {corner(8)})
			window:_track(badge, {BackgroundColor3 = "AccentSoft", TextColor3 = "Accent"})
		end
		button.MouseEnter:Connect(function() tween(button, 0.18, {BackgroundTransparency = window.FrostedGlass and 0.08 or 0.03}, Enum.EasingStyle.Quint) end)
		button.MouseLeave:Connect(function() tween(button, 0.2, {BackgroundTransparency = window.FrostedGlass and 0.16 or 0}, Enum.EasingStyle.Quint) end)
		button.MouseButton1Click:Connect(function() safeCall(card.Callback or options.Callback, card, index) end)
		buttons[#buttons + 1] = button
	end
	local function relayout()
		anchorlineVisualRelayoutGrid(window, frame, holder, grid, #cards, tonumber(options.MinCardWidth) or 190, tonumber(options.CardHeight) or 100, 56, tonumber(options.Gap) or 10)
	end
	function controller:SetCards(newCards)
		cards = newCards or {}
		anchorlineClearChildren(holder)
		buttons = {}
		for index, card in ipairs(cards) do build(type(card) == "table" and card or {Title = tostring(card)}, index) end
		relayout()
		window:_queueSmartResize()
	end
	function controller:GetCards() return cards end
	window:_addAdaptiveHandler(relayout)
	window._connections[#window._connections + 1] = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	controller:SetCards(cards)
	return controller
end

function Tab:CreateProfileCard(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Profile")
	local subtitle = tostring(options.Subtitle or options.Role or options.Description or "")
	local details = options.Details or options.Rows or {}
	local actions = options.Actions or {}
	local height = tonumber(options.Height) or (112 + math.max(#details, 0) * 26 + (#actions > 0 and 44 or 0))
	local frame = window:_createElement(self, name, name .. " " .. subtitle .. " profile card", height)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	if layout then layout:Destroy() end
	frame:SetAttribute("AnchorlineMinWidth", 430)
	local avatar = new("Frame", {Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(58, 58), BackgroundTransparency = window.FrostedGlass and 0.1 or 0, Parent = frame}, {corner(20), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
	window:_track(avatar, {BackgroundColor3 = "AccentSoft"})
	local asset = window:_resolveIcon(options.Avatar or options.Image)
	if asset then
		local image = new("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(50, 50), ScaleType = Enum.ScaleType.Crop, Parent = avatar}, {corner(17)})
		applyIconAssetToImageLabel(image, asset)
	else
		local initials = tostring(options.Initials or string.sub(name, 1, 2)):upper()
		new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 18, Text = initials, TextColor3 = getThemeValue(window, "Accent"), Parent = avatar})
	end
	local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(88, 20), Size = UDim2.new(1, -104, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = name, Parent = frame})
	window:_track(title, {TextColor3 = "Text"})
	local sub = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(88, 44), Size = UDim2.new(1, -104, 0, 18), Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = subtitle, Parent = frame})
	window:_track(sub, {TextColor3 = "TextMuted"})
	local y = 88
	local valueLabels = {}
	for index, item in ipairs(details) do
		local label = tostring(item.Label or item.Name or item[1] or "Detail")
		local value = tostring(item.Value or item.Text or item[2] or "")
		local row = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 22), Parent = frame})
		local left = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(0.42, 0, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = label, Parent = row})
		window:_track(left, {TextColor3 = "TextMuted"})
		local right = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0.42, 0, 0, 0), Size = UDim2.new(0.58, 0, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = value, Parent = row})
		window:_track(right, {TextColor3 = "Text"})
		valueLabels[index] = right
		y += 26
	end
	if #actions > 0 then
		local actionHolder = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(16, y + 6), Size = UDim2.new(1, -32, 0, 34), Parent = frame}, {listLayout(Enum.FillDirection.Horizontal, 8)})
		for index, action in ipairs(actions) do
			anchorlineVisualButton(window, actionHolder, action.Text or action.Name or ("Action " .. index), tonumber(action.Width) or 104, action.Primary, action.Callback)
		end
	end
	return {Type = "ProfileCard", Frame = frame, SetTitle = function(_, value) title.Text = tostring(value or "") end, SetSubtitle = function(_, value) sub.Text = tostring(value or "") end, SetDetail = function(_, index, value) if valueLabels[index] then valueLabels[index].Text = tostring(value or "") end end}
end

function Tab:CreateAccordion(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Accordion")
	local sections = options.Sections or options.Items or {}
	local frame = window:_createElement(self, name, name .. " accordion collapsible sections", 90)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Sections", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 8)})
	local rows = {}
	local controller = {Type = "Accordion", Frame = frame}
	local function updateHeight()
		local total = 0
		for _, row in ipairs(rows) do
			total += row.Container.Size.Y.Offset + 8
		end
		holder.Size = UDim2.new(1, 0, 0, math.max(total - 8, 34))
		frame.Size = UDim2.new(1, 0, 0, 56 + holder.Size.Y.Offset)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	local function build(section, index)
		local open = section.Open ~= false and options.DefaultOpen ~= false
		local bodyText = tostring(section.Content or section.Text or section.Description or "")
		local bodyHeight = math.max(34, measureWrappedText(bodyText, 13, Enum.Font.Gotham, math.max(frame.AbsoluteSize.X - 58, 300)) + 18)
		local container = new("Frame", {Name = "Accordion" .. index, BackgroundTransparency = window.FrostedGlass and 0.16 or 0, Size = UDim2.new(1, 0, 0, open and 44 + bodyHeight or 38), Parent = holder}, {corner(10), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(container, {BackgroundColor3 = "Surface"})
		local header = new("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Text = "", AutoButtonColor = false, Parent = container})
		local arrow = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(18, 38), Font = Enum.Font.GothamBold, TextSize = 12, Text = open and "−" or "+", Parent = header})
		window:_track(arrow, {TextColor3 = "Accent"})
		local title = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -48, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(section.Title or section.Name or ("Section " .. index)), Parent = header})
		window:_track(title, {TextColor3 = "Text"})
		local body = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 40), Size = UDim2.new(1, -52, 0, bodyHeight - 6), Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = bodyText, Visible = open, Parent = container})
		window:_track(body, {TextColor3 = "TextMuted"})
		local row = {Container = container, Body = body, Arrow = arrow, Open = open, BodyHeight = bodyHeight}
		local function render(animated)
			body.Visible = row.Open
			arrow.Text = row.Open and "−" or "+"
			local targetHeight = row.Open and 44 + row.BodyHeight or 38
			if animated then tween(container, 0.28, {Size = UDim2.new(1, 0, 0, targetHeight)}, Enum.EasingStyle.Quint) else container.Size = UDim2.new(1, 0, 0, targetHeight) end
			task.delay(animated and 0.29 or 0, updateHeight)
		end
		header.MouseButton1Click:Connect(function()
			row.Open = not row.Open
			render(true)
			safeCall(options.Callback, index, row.Open, section)
		end)
		rows[#rows + 1] = row
		render(false)
	end
	function controller:SetSections(newSections)
		sections = newSections or {}
		anchorlineClearChildren(holder)
		rows = {}
		for index, section in ipairs(sections) do build(type(section) == "table" and section or {Title = tostring(section)}, index) end
		updateHeight()
	end
	function controller:GetSections() return sections end
	controller:SetSections(sections)
	return controller
end

function Tab:CreatePropertyGrid(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Properties")
	local rowsData = options.Rows or options.Properties or options.Items or {}
	local frame = window:_createElement(self, name, name .. " properties inspector", 62 + math.max(#rowsData, 1) * 30)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Rows", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#rowsData, 1) * 30), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 6)})
	local labels = {}
	local controller = {Type = "PropertyGrid", Frame = frame}
	local function build(row, index)
		local item = type(row) == "table" and row or {Name = tostring(row)}
		local rowFrame = new("Frame", {Name = "Property" .. index, BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Size = UDim2.new(1, 0, 0, 28), Parent = holder}, {corner(8), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(rowFrame, {BackgroundColor3 = "Surface"})
		local nameLabel = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.46, -10, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Name or item.Label or item.Key or "Property"), Parent = rowFrame})
		window:_track(nameLabel, {TextColor3 = "TextMuted"})
		local valueLabel = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0.46, 0, 0, 0), Size = UDim2.new(0.54, -10, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Value or item.Text or item[2] or ""), Parent = rowFrame})
		window:_track(valueLabel, {TextColor3 = "Text"})
		labels[index] = valueLabel
	end
	function controller:SetRows(newRows)
		rowsData = newRows or {}
		anchorlineClearChildren(holder)
		labels = {}
		for index, row in ipairs(rowsData) do build(row, index) end
		holder.Size = UDim2.new(1, 0, 0, math.max(#rowsData, 1) * 34)
		frame.Size = UDim2.new(1, 0, 0, 62 + math.max(#rowsData, 1) * 34)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	function controller:SetValue(index, value)
		if labels[index] then labels[index].Text = tostring(value or "") end
	end
	controller:SetRows(rowsData)
	return controller
end

function Tab:CreateResourceBars(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Resources")
	local bars = options.Bars or options.Items or {}
	local frame = window:_createElement(self, name, name .. " resource bars", 62 + math.max(#bars, 1) * 42)
	frame:SetAttribute("AnchorlineMinWidth", 420)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Bars", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#bars, 1) * 42), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 10)})
	local controllers = {}
	local controller = {Type = "ResourceBars", Frame = frame}
	local function build(bar, index)
		local item = type(bar) == "table" and bar or {Name = tostring(bar), Value = 0}
		local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = holder})
		local label = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 0, 16), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Name or item.Title or "Bar"), Parent = row})
		window:_track(label, {TextColor3 = "Text"})
		local valueLabel = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 16), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = row})
		window:_track(valueLabel, {TextColor3 = "TextMuted"})
		local track = new("Frame", {Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Parent = row}, {corner(5)})
		window:_track(track, {BackgroundColor3 = "Surface"})
		local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = anchorlineKindColor(window, item.Type or item.Status or "Info"), BorderSizePixel = 0, Parent = track}, {corner(5)})
		local minValue = tonumber(item.Min) or 0
		local maxValue = tonumber(item.Max) or 100
		local value = tonumber(item.Value or item.CurrentValue) or 0
		local suffix = tostring(item.Suffix or "%")
		local barController = {}
		function barController:Set(newValue, loading)
			value = math.clamp(tonumber(newValue) or value, minValue, maxValue)
			local percent = maxValue ~= minValue and (value - minValue) / (maxValue - minValue) or 0
			valueLabel.Text = tostring(math.floor(value * 100 + 0.5) / 100) .. suffix
			tween(fill, loading and 0 or 0.26, {Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1)}, Enum.EasingStyle.Quint)
		end
		function barController:Get() return value end
		barController:Set(value, true)
		controllers[index] = barController
	end
	function controller:SetBars(newBars)
		bars = newBars or {}
		anchorlineClearChildren(holder)
		controllers = {}
		for index, bar in ipairs(bars) do build(bar, index) end
		holder.Size = UDim2.new(1, 0, 0, math.max(#bars, 1) * 42)
		frame.Size = UDim2.new(1, 0, 0, 62 + math.max(#bars, 1) * 42)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	function controller:SetValue(index, value)
		if controllers[index] then controllers[index]:Set(value) end
	end
	function controller:GetBar(index) return controllers[index] end
	controller:SetBars(bars)
	return controller
end

function Tab:CreateCodeBlock(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Code")
	local codeText = tostring(options.Code or options.Text or options.Content or "")
	local lines = math.clamp(select(2, codeText:gsub("\n", "\n")) + 1, 3, tonumber(options.MaxLines) or 12)
	local frame = window:_createElement(self, name, name .. " code block script snippet", 74 + lines * 18)
	frame:SetAttribute("AnchorlineMinWidth", 460)
	self:_headerRow(frame, name, options.Description)
	local codeFrame = new("Frame", {Name = "CodeFrame", BackgroundTransparency = window.FrostedGlass and 0.14 or 0, Size = UDim2.new(1, 0, 0, lines * 18 + 22), Parent = frame}, {corner(10), stroke(getThemeValue(window, "StrokeSoft"), 1, 0), padding(12, 12, 10, 10)})
	window:_track(codeFrame, {BackgroundColor3 = "Surface"})
	local label = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, options.CopyButton ~= false and -88 or 0, 1, 0), Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Text = codeText, Parent = codeFrame})
	window:_track(label, {TextColor3 = "Text"})
	if options.CopyButton ~= false then
		local copyButton = anchorlineVisualButton(window, codeFrame, options.CopyText or "Copy", 72, false, function()
			if setclipboard then pcall(setclipboard, codeText) end
			safeCall(options.OnCopy or options.Callback, codeText)
		end)
		copyButton.AnchorPoint = Vector2.new(1, 0)
		copyButton.Position = UDim2.new(1, 0, 0, 0)
	end
	local controller = {Type = "CodeBlock", Frame = frame}
	function controller:SetCode(value)
		codeText = tostring(value or "")
		label.Text = codeText
	end
	function controller:GetCode() return codeText end
	return controller
end

function Tab:CreateCommandPanel(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Commands")
	local commands = options.Commands or options.Items or {}
	local frame = window:_createElement(self, name, name .. " command panel shortcuts", 62 + math.max(#commands, 1) * 40)
	frame:SetAttribute("AnchorlineMinWidth", 440)
	self:_headerRow(frame, name, options.Description)
	local holder = new("Frame", {Name = "Commands", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(#commands, 1) * 40), Parent = frame}, {listLayout(Enum.FillDirection.Vertical, 8)})
	local controller = {Type = "CommandPanel", Frame = frame}
	local function build(command, index)
		local item = type(command) == "table" and command or {Name = tostring(command)}
		local button = new("TextButton", {Name = "Command" .. index, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Text = "", AutoButtonColor = false, Parent = holder}, {corner(10), stroke(getThemeValue(window, "StrokeSoft"), 1, 0)})
		window:_track(button, {BackgroundColor3 = "Surface"})
		local iconBox = new("Frame", {Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = button})
		anchorlineVisualIcon(window, iconBox, item.Icon or "terminal", 20, anchorlineKindColor(window, item.Type or "Info"), getThemeValue(window, "Surface"))
		local label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -150, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(item.Name or item.Title or "Command"), Parent = button})
		window:_track(label, {TextColor3 = "Text"})
		local key = new("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(96, 22), BackgroundTransparency = window.FrostedGlass and 0.14 or 0, Font = Enum.Font.GothamMedium, TextSize = 11, Text = tostring(item.Key or item.Shortcut or "Run"), Parent = button}, {corner(8)})
		window:_track(key, {BackgroundColor3 = "AccentSoft", TextColor3 = "Accent"})
		button.MouseEnter:Connect(function() tween(button, 0.16, {BackgroundTransparency = window.FrostedGlass and 0.1 or 0.04}, Enum.EasingStyle.Quint) end)
		button.MouseLeave:Connect(function() tween(button, 0.2, {BackgroundTransparency = window.FrostedGlass and 0.18 or 0}, Enum.EasingStyle.Quint) end)
		button.MouseButton1Click:Connect(function() safeCall(item.Callback or options.Callback, item, index) end)
	end
	function controller:SetCommands(newCommands)
		commands = newCommands or {}
		anchorlineClearChildren(holder)
		for index, command in ipairs(commands) do build(command, index) end
		holder.Size = UDim2.new(1, 0, 0, math.max(#commands, 1) * 44)
		frame.Size = UDim2.new(1, 0, 0, 62 + math.max(#commands, 1) * 44)
		window:_refreshPageCanvases()
		window:_queueSmartResize()
	end
	controller:SetCommands(commands)
	return controller
end

function Tab:CreateSplitPanel(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Split Panel")
	local left = options.Left or {}
	local right = options.Right or {}
	local height = tonumber(options.Height) or 154
	local frame = window:_createElement(self, name, name .. " split panel", height)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	if layout then layout:Destroy() end
	frame:SetAttribute("AnchorlineMinWidth", 480)
	local function panel(sideData, xScale, xOffset, widthScale, titleDefault)
		local panelFrame = new("Frame", {BackgroundTransparency = window.FrostedGlass and 0.18 or 0, Position = UDim2.new(xScale, xOffset, 0, 12), Size = UDim2.new(widthScale, -18, 1, -24), Parent = frame}, {corner(12), stroke(getThemeValue(window, "StrokeSoft"), 1, 0), padding(12, 12, 10, 10)})
		window:_track(panelFrame, {BackgroundColor3 = "Surface"})
		local title = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(sideData.Title or sideData.Name or titleDefault), Parent = panelFrame})
		window:_track(title, {TextColor3 = "Text"})
		local text = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -30), Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = tostring(sideData.Content or sideData.Text or sideData.Description or ""), Parent = panelFrame})
		window:_track(text, {TextColor3 = "TextMuted"})
		return {Frame = panelFrame, Title = title, Text = text}
	end
	local leftPanel = panel(left, 0, 12, 0.5, "Left")
	local rightPanel = panel(right, 0.5, 6, 0.5, "Right")
	return {Type = "SplitPanel", Frame = frame, Left = leftPanel, Right = rightPanel}
end

function Tab:CreateDashboard(options)
	options = options or {}
	local controllers = {}
	controllers.Banner = self:CreateBanner({Title = options.Title or options.Name or "Dashboard", Description = options.Description or options.Subtitle or "Overview", Icon = options.Icon or "home", Type = options.Type or "Info", Action = options.Action})
	if options.Metrics or options.Stats then
		controllers.Metrics = self:CreateMetricGrid({Name = options.MetricsTitle or "Metrics", Description = options.MetricsDescription, Items = options.Metrics or options.Stats})
	end
	if options.Actions then
		controllers.Actions = self:CreateCardGrid({Name = options.ActionsTitle or "Actions", Description = options.ActionsDescription, Cards = options.Actions, Callback = options.ActionCallback})
	end
	if options.Statuses or options.Status then
		controllers.Status = self:CreateStatusList({Name = options.StatusTitle or "Status", Description = options.StatusDescription, Items = options.Statuses or options.Status})
	end
	return controllers
end

Tab.CreateHeaderBar = Tab.CreateBanner
Tab.CreateNoticeBanner = Tab.CreateBanner
Tab.CreateMetricCards = Tab.CreateMetricGrid
Tab.CreateStatsGrid = Tab.CreateMetricGrid
Tab.CreateFeatureGrid = Tab.CreateCardGrid
Tab.CreateQuickActions = Tab.CreateCardGrid
Tab.CreateActionCards = Tab.CreateCardGrid
Tab.CreateUserCard = Tab.CreateProfileCard
Tab.CreateInspector = Tab.CreatePropertyGrid
Tab.CreateProperties = Tab.CreatePropertyGrid
Tab.CreateBars = Tab.CreateResourceBars
Tab.CreateShortcutPanel = Tab.CreateCommandPanel

local anchorlineVisualCreateElement = Tab.CreateElement
function Tab:CreateElement(kindOrOptions, maybeOptions)
	local kind = nil
	local options = nil
	if type(kindOrOptions) == "table" then
		options = anchorlineCopyTable(kindOrOptions)
		kind = options.Type or options.ElementType or options.Kind or options.Class or options.Control or options.Component
	elseif type(kindOrOptions) == "string" and type(maybeOptions) == "table" then
		kind = kindOrOptions
		options = anchorlineCopyTable(maybeOptions)
	elseif type(kindOrOptions) == "string" then
		kind = kindOrOptions
		options = {Name = kindOrOptions}
	else
		options = {}
	end
	local normalized = anchorlineNormalizeType(kind or "")
	if normalized == "banner" or normalized == "headerbar" or normalized == "page-header" or normalized == "noticebanner" then
		return self:CreateBanner(options)
	elseif normalized == "empty" or normalized == "empty-state" or normalized == "emptystate" then
		return self:CreateEmptyState(options)
	elseif normalized == "metric-grid" or normalized == "metrics" or normalized == "metriccards" or normalized == "stats-grid" or normalized == "stats" then
		return self:CreateMetricGrid(options)
	elseif normalized == "card-grid" or normalized == "cards" or normalized == "feature-grid" or normalized == "quick-actions" or normalized == "action-cards" then
		return self:CreateCardGrid(options)
	elseif normalized == "profile" or normalized == "profile-card" or normalized == "user-card" then
		return self:CreateProfileCard(options)
	elseif normalized == "accordion" or normalized == "collapse" or normalized == "collapsible" then
		return self:CreateAccordion(options)
	elseif normalized == "properties" or normalized == "property-grid" or normalized == "inspector" then
		return self:CreatePropertyGrid(options)
	elseif normalized == "resource-bars" or normalized == "bars" or normalized == "health-bars" then
		return self:CreateResourceBars(options)
	elseif normalized == "code-block" or normalized == "codeblock" or normalized == "snippet" then
		return self:CreateCodeBlock(options)
	elseif normalized == "commands" or normalized == "command-panel" or normalized == "shortcuts" or normalized == "shortcut-panel" then
		return self:CreateCommandPanel(options)
	elseif normalized == "split" or normalized == "split-panel" or normalized == "two-column" then
		return self:CreateSplitPanel(options)
	elseif normalized == "dashboard" or normalized == "overview" then
		return self:CreateDashboard(options)
	end
	return anchorlineVisualCreateElement(self, kindOrOptions, maybeOptions)
end
Tab.AddElement = Tab.CreateElement
Tab.Element = Tab.CreateElement

Anchorline.VisualComponents = {
	"Banner",
	"EmptyState",
	"MetricGrid",
	"CardGrid",
	"ProfileCard",
	"Accordion",
	"PropertyGrid",
	"ResourceBars",
	"CodeBlock",
	"CommandPanel",
	"SplitPanel",
	"Dashboard"
}

local anchorlineMetatable = getmetatable(Anchorline) or {}
anchorlineMetatable.__call = function(self, options)
	return self:CreateWindow(options)
end
setmetatable(Anchorline, anchorlineMetatable)


Anchorline.Version = "3.8.0"
Anchorline.Appearance = Anchorline.Appearance or {}
Anchorline.Appearance.Modernized = true
Anchorline.Appearance.Depth = true
Anchorline.Appearance.CardRadius = 16
Anchorline.Appearance.TabRadius = 14

local function anchorlineCreateGradient(parent, rotation, transparency)
	local gradient = new("UIGradient", {
		Rotation = rotation or 90,
		Transparency = transparency or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.56, 0.05),
			NumberSequenceKeypoint.new(1, 0.16)
		}),
		Parent = parent
	})
	return gradient
end

local function anchorlineBindVisualSync(window, object, callback)
	if not window or not object or type(callback) ~= "function" then
		return
	end
	local function run()
		if window.Root and window.Root.Parent and object.Parent then
			callback()
		end
	end
	run()
	window._connections[#window._connections + 1] = window.Root:GetPropertyChangedSignal("Position"):Connect(run)
	window._connections[#window._connections + 1] = window.Root:GetPropertyChangedSignal("Size"):Connect(run)
	window._connections[#window._connections + 1] = window.Root:GetPropertyChangedSignal("Visible"):Connect(run)
end

local function anchorlineAddModernWindowDepth(window)
	if not window or not window.Root or not window.Gui or window._modernVisualLayer then
		return window
	end
	window._modernVisualLayer = true
	window.Root.ZIndex = 20
	local shadow = new("Frame", {
		Name = "WindowSoftShadow",
		AnchorPoint = window.Root.AnchorPoint,
		Position = window.Root.Position + UDim2.fromOffset(0, 12),
		Size = window.Root.Size,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = window.Gui
	}, {
		corner(27),
		anchorlineCreateGradient(nil, 90, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.6, 0.03),
			NumberSequenceKeypoint.new(1, 0.18)
		}))
	})
	shadow.UIGradient.Parent = shadow
	window:_track(shadow, {BackgroundColor3 = "Overlay"})
	anchorlineBindVisualSync(window, shadow, function()
		shadow.AnchorPoint = window.Root.AnchorPoint
		shadow.Position = window.Root.Position + UDim2.fromOffset(0, 12)
		shadow.Size = window.Root.Size
		shadow.Visible = window.Root.Visible
	end)
	local topLight = new("Frame", {
		Name = "WindowTopLight",
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, 120),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = window.Root
	}, {
		corner(24),
		anchorlineCreateGradient(nil, 90, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.55, 0.76),
			NumberSequenceKeypoint.new(1, 1)
		}))
	})
	topLight.UIGradient.Parent = topLight
	window:_track(topLight, {BackgroundColor3 = "GlassHighlight"})
	local bottomShade = new("Frame", {
		Name = "WindowBottomShade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 1, 1, -1),
		Size = UDim2.new(1, -2, 0, 92),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = window.Root
	}, {
		corner(24),
		anchorlineCreateGradient(nil, 90, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.42),
			NumberSequenceKeypoint.new(1, 0.16)
		}))
	})
	bottomShade.UIGradient.Parent = bottomShade
	window:_track(bottomShade, {BackgroundColor3 = "GlassShade"})
	return window
end

local function anchorlineModernHover(window, button, normalKey, hoverKey, pressedOffset)
	if not button or not window then
		return
	end
	button.MouseEnter:Connect(function()
		if button.Parent then
			tween(button, 0.16, {BackgroundColor3 = getThemeValue(window, hoverKey or "SurfaceHover")}, Enum.EasingStyle.Quint)
		end
	end)
	button.MouseLeave:Connect(function()
		if button.Parent then
			tween(button, 0.2, {BackgroundColor3 = getThemeValue(window, normalKey or "Surface")}, Enum.EasingStyle.Quint)
		end
	end)
	button.MouseButton1Down:Connect(function()
		if button.Parent then
			local current = button.Position
			button:SetAttribute("AnchorlinePressX", current.X.Offset)
			button:SetAttribute("AnchorlinePressY", current.Y.Offset)
			tween(button, 0.08, {Position = current + UDim2.fromOffset(0, pressedOffset or 1)}, Enum.EasingStyle.Quad)
		end
	end)
	button.MouseButton1Up:Connect(function()
		if button.Parent then
			local x = button:GetAttribute("AnchorlinePressX")
			local y = button:GetAttribute("AnchorlinePressY")
			if type(x) == "number" and type(y) == "number" then
				tween(button, 0.16, {Position = UDim2.new(button.Position.X.Scale, x, button.Position.Y.Scale, y)}, Enum.EasingStyle.Quint)
			end
		end
	end)
end

local anchorlineModernNativeApplyTheme = Window._applyTheme
function Window:_applyTheme()
	anchorlineModernNativeApplyTheme(self)
	if self._modernTitleAccent then
		self._modernTitleAccent.BackgroundColor3 = getThemeValue(self, "Accent")
	end
end

function Window:_styleTabButton(tab)
	if not tab or not tab.Button then
		return
	end
	local active = self.ActiveTab == tab
	local iconColor = active and getThemeValue(self, "Accent") or getThemeValue(self, "TextFaint")
	local buttonBackground = active and "Surface" or "Panel"
	local buttonStroke = active and "Stroke" or "StrokeSoft"
	local titleColor = active and "Text" or "TextMuted"
	tween(tab.Button, 0.26, {BackgroundColor3 = getThemeValue(self, buttonBackground)}, Enum.EasingStyle.Quint)
	if tab.ButtonStroke then
		tab.ButtonStroke.Color = getThemeValue(self, buttonStroke)
		tween(tab.ButtonStroke, 0.2, {Transparency = active and 0 or 0.28}, Enum.EasingStyle.Quint)
	end
	if tab.ButtonTitle then
		tab.ButtonTitle.TextColor3 = getThemeValue(self, titleColor)
	end
	if tab.ButtonAccent then
		tab.ButtonAccent.BackgroundColor3 = getThemeValue(self, "Accent")
		tween(tab.ButtonAccent, 0.26, {
			BackgroundTransparency = active and 0 or 1,
			Size = active and UDim2.new(0, 4, 1, -14) or UDim2.new(0, 3, 1, -22)
		}, Enum.EasingStyle.Quint)
	end
	if tab.ButtonIconBox then
		tab.ButtonIconBox.BackgroundColor3 = active and getThemeValue(self, "AccentSoft") or getThemeValue(self, "SurfaceHover")
		tween(tab.ButtonIconBox, 0.22, {BackgroundTransparency = active and 0.1 or 0.46}, Enum.EasingStyle.Quint)
	end
	if tab.ButtonIconImage then
		tab.ButtonIconImage.ImageColor3 = iconColor
		tab.ButtonIconImage.ImageTransparency = active and 0 or 0.2
	end
	if tab.ButtonIconShapes then
		for _, shape in ipairs(tab.ButtonIconShapes) do
			if shape:IsA("TextLabel") then
				shape.TextColor3 = iconColor
			elseif shape:GetAttribute("AnchorlineIconCutout") then
				shape.BackgroundColor3 = tab.ButtonIconBox and tab.ButtonIconBox.BackgroundColor3 or getThemeValue(self, "Surface")
			else
				shape.BackgroundColor3 = iconColor
			end
		end
	end
end

function Window:CreateTab(name, icon, description)
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = tostring(name or "Tab")
	tab.IconAsset = self:_resolveIcon(icon)
	tab.Icon = tostring(icon or tab.Name):sub(1, 2)
	tab.Description = description
	tab.Elements = {}
	local button = new("TextButton", {
		Name = tab.Name .. "TabButton",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = self.FrostedGlass and 0.2 or 0,
		AutoButtonColor = false,
		Text = "",
		Parent = self.TabList
	}, {corner(14)})
	local gradient = anchorlineCreateGradient(button, 90, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.68, 0.06),
		NumberSequenceKeypoint.new(1, 0.12)
	}))
	local buttonStroke = stroke(getThemeValue(self, "StrokeSoft"), 1, 0.22)
	buttonStroke.Parent = button
	local indicator = new("Frame", {
		Name = "SelectionIndicator",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(0, 3, 1, -16),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = button
	}, {corner(3)})
	local iconBox = new("Frame", {
		Name = "IconBox",
		Position = UDim2.fromOffset(11, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = self.FrostedGlass and 0.42 or 0.55,
		BorderSizePixel = 0,
		Parent = button
	}, {corner(10)})
	self:_track(iconBox, {BackgroundColor3 = "AccentSoft"})
	local iconImage = new("ImageLabel", {
		Name = "IconImage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(18, 18),
		ScaleType = Enum.ScaleType.Fit,
		Visible = tab.IconAsset ~= nil,
		Parent = iconBox
	})
	if tab.IconAsset then
		applyIconAssetToImageLabel(iconImage, tab.IconAsset)
	end
	local iconHolder = new("Frame", {
		Name = "VectorIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(20, 20),
		Visible = tab.IconAsset == nil,
		Parent = iconBox
	})
	local iconShapes = createVectorIcon(iconHolder, icon or tab.Name)
	if #iconShapes == 0 then
		iconHolder.Visible = false
	end
	local titleLabel = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -60, 1, 0),
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
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		Parent = self.Pages
	}, {
		padding(18, 18, 16, 22),
		listLayout(Enum.FillDirection.Vertical, 12)
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
	tab.ButtonIcon = nil
	tab.ButtonIconBox = iconBox
	tab.ButtonIconImage = iconImage
	tab.ButtonIconShapes = iconShapes
	tab.ButtonAccent = indicator
	tab.Page = page
	button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			tween(button, 0.16, {BackgroundColor3 = getThemeValue(self, "Surface")}, Enum.EasingStyle.Quint)
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
		BackgroundTransparency = self.FrostedGlass and 0.18 or 0,
		ClipsDescendants = true,
		Parent = tab.Page
	}, {
		corner(Anchorline.Appearance.CardRadius or 16),
		padding(16, 16, 14, 14),
		listLayout(Enum.FillDirection.Vertical, 9),
		anchorlineCreateGradient(nil, 90, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.62, 0.04),
			NumberSequenceKeypoint.new(1, 0.1)
		}))
	})
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then gradient.Parent = frame end
	frame:SetAttribute("SearchText", tostring(searchText or titleText or ""))
	frame:SetAttribute("AnchorlineMinWidth", 340)
	local s = stroke(getThemeValue(self, "StrokeSoft"), 1, 0.1)
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

function Tab:CreateGlassCard(options)
	options = options or {}
	local window = self.Window
	local name = tostring(options.Name or options.Title or "Glass Card")
	local description = options.Description or options.Content or options.Text or ""
	local height = tonumber(options.Height) or (description ~= "" and 92 or 68)
	local frame = window:_createElement(self, name, name .. " " .. tostring(description), height)
	self:_headerRow(frame, name, description)
	return {Type = "GlassCard", Frame = frame}
end

function Tab:CreateSectionHeader(options)
	options = options or {}
	local window = self.Window
	local titleText = tostring(options.Name or options.Title or "Section")
	local subtitleText = tostring(options.Description or options.Subtitle or "")
	local frame = new("Frame", {
		Name = titleText,
		Size = UDim2.new(1, 0, 0, subtitleText ~= "" and 54 or 34),
		BackgroundTransparency = 1,
		Parent = self.Page
	})
	frame:SetAttribute("SearchText", titleText .. " " .. subtitleText)
	local accent = new("Frame", {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromOffset(4, subtitleText ~= "" and 40 or 24),
		BorderSizePixel = 0,
		Parent = frame
	}, {corner(3)})
	window:_track(accent, {BackgroundColor3 = "Accent"})
	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -14, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = titleText,
		Parent = frame
	})
	window:_track(title, {TextColor3 = "Text"})
	if subtitleText ~= "" then
		local subtitle = new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 25),
			Size = UDim2.new(1, -14, 0, 20),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = subtitleText,
			Parent = frame
		})
		window:_track(subtitle, {TextColor3 = "TextMuted"})
	end
	self.Elements[#self.Elements + 1] = frame
	window:_queueSmartResize()
	return {Type = "SectionHeader", Frame = frame}
end

function Tab:CreatePill(options)
	options = options or {}
	local window = self.Window
	local text = tostring(options.Text or options.Name or options.Title or "Pill")
	local frame = window:_createElement(self, text, text, 54)
	frame.AutomaticSize = Enum.AutomaticSize.None
	local label = new("TextLabel", {
		BackgroundTransparency = window.FrostedGlass and 0.28 or 0,
		Size = UDim2.fromOffset(math.max(90, #text * 7 + 34), 28),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Text = text,
		Parent = frame
	}, {corner(14), stroke(getThemeValue(window, "StrokeSoft"), 1, 0.12)})
	window:_track(label, {BackgroundColor3 = "AccentSoft", TextColor3 = "Accent"})
	return {Type = "Pill", Frame = frame, Label = label}
end

Tab.CreateModernCard = Tab.CreateGlassCard
Tab.CreatePanelCard = Tab.CreateGlassCard
Tab.CreateModernHeader = Tab.CreateSectionHeader
Tab.CreatePillBadge = Tab.CreatePill

local anchorlineModernNativeCreateWindow = Anchorline.CreateWindow
function Anchorline:CreateWindow(options)
	local window = anchorlineModernNativeCreateWindow(self, options)
	anchorlineAddModernWindowDepth(window)
	if window and window.Header and not window._modernTitleAccent then
		local accent = new("Frame", {
			Name = "TitleAccent",
			Position = UDim2.fromOffset(18, 49),
			Size = UDim2.fromOffset(34, 3),
			BackgroundColor3 = getThemeValue(window, "Accent"),
			BorderSizePixel = 0,
			BackgroundTransparency = 0.12,
			Parent = window.Header
		}, {corner(2)})
		window._modernTitleAccent = accent
	end
	return window
end

local anchorlineModernMetatable = getmetatable(Anchorline) or {}
anchorlineModernMetatable.__call = function(self, options)
	return self:CreateWindow(options)
end
setmetatable(Anchorline, anchorlineModernMetatable)


return Anchorline
