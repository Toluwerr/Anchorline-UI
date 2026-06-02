local CORE_URL = "https://raw.githubusercontent.com/Toluwerr/Anchorline-UI/c053751074884af3af261f35989d6a8b64312402/main.lua"
local Anchorline = loadstring(game:HttpGet(CORE_URL))()

Anchorline.Version = "3.10.0"
Anchorline.Appearance = Anchorline.Appearance or {}
Anchorline.Appearance.ReadabilityFirst = true
Anchorline.Appearance.FrostedGlassDefault = false

local unpackValues = table.unpack or unpack
local originalCreateWindow = Anchorline.CreateWindow

local function clampNumber(value, fallback, minValue, maxValue)
	local number = tonumber(value)
	if number == nil then
		number = fallback
	end
	if number < minValue then
		return minValue
	end
	if number > maxValue then
		return maxValue
	end
	return number
end

local function patchTabVisuals(window, tab)
	if not window or not tab or not tab.Button then
		return
	end

	local active = window.ActiveTab == tab
	tab.Button.ClipsDescendants = true
	tab.Button.BackgroundTransparency = window.FrostedGlass and (active and 0.04 or 0.14) or (active and 0 or 0.03)

	if tab.ButtonStroke then
		tab.ButtonStroke.Transparency = active and 0.04 or 0.22
	end

	if tab.ButtonIconBox then
		tab.ButtonIconBox.BackgroundTransparency = window.FrostedGlass and (active and 0.08 or 0.34) or (active and 0.08 or 0.18)
	end

	if tab.ButtonTitle then
		tab.ButtonTitle.TextTransparency = 0
	end

	if tab.ButtonIconImage then
		tab.ButtonIconImage.ImageTransparency = active and 0 or 0.08
	end

	if tab.ButtonAccent then
		tab.ButtonAccent.Parent = tab.Button
		tab.ButtonAccent.AnchorPoint = Vector2.new(0, 0.5)
		tab.ButtonAccent.Position = UDim2.new(0, 0, 0.5, 0)
		tab.ButtonAccent.Size = active and UDim2.new(0, 3, 1, -14) or UDim2.new(0, 3, 1, -18)
		tab.ButtonAccent.BackgroundTransparency = active and 0 or 1
		tab.ButtonAccent.BorderSizePixel = 0
	end
end

local function patchWindow(window)
	if not window or window._anchorlineReadablePatch then
		return window
	end

	window._anchorlineReadablePatch = true

	local function applyReadableSurfaces()
		local glassEnabled = window.FrostedGlass == true
		local glassTransparency = clampNumber(window.GlassTransparency, 0.12, 0, 0.28)

		if window.Root then
			window.Root.GroupTransparency = 0
			window.Root.BackgroundTransparency = glassEnabled and glassTransparency or 0
			window.Root.ClipsDescendants = true
		end

		if window.Sidebar then
			window.Sidebar.BackgroundTransparency = glassEnabled and 0.08 or 0
		end

		if window.Content then
			window.Content.BackgroundTransparency = 1
		end

		if window.BlurEffect and not glassEnabled then
			window.BlurEffect.Size = 0
		end

		for _, tab in ipairs(window.Tabs or {}) do
			patchTabVisuals(window, tab)
		end
	end

	local nativeApplyTheme = window._applyTheme
	if type(nativeApplyTheme) == "function" then
		window._applyTheme = function(self, ...)
			local results = {nativeApplyTheme(self, ...)}
			applyReadableSurfaces()
			return unpackValues(results)
		end
	end

	local nativeSetTheme = window.SetTheme
	if type(nativeSetTheme) == "function" then
		window.SetTheme = function(self, ...)
			local results = {nativeSetTheme(self, ...)}
			applyReadableSurfaces()
			return unpackValues(results)
		end
	end

	local nativeSetFrostedGlass = window.SetFrostedGlass
	window.SetFrostedGlass = function(self, enabled)
		self.FrostedGlass = enabled == true
		if type(nativeSetFrostedGlass) == "function" then
			nativeSetFrostedGlass(self, self.FrostedGlass)
		end
		applyReadableSurfaces()
		return self
	end

	window.SetGlassTransparency = function(self, value)
		self.GlassTransparency = clampNumber(value, self.GlassTransparency or 0.12, 0, 0.28)
		if self.Root then
			self.Root.BackgroundTransparency = self.FrostedGlass and self.GlassTransparency or 0
		end
		return self
	end

	local nativeStyleTabButton = window._styleTabButton
	if type(nativeStyleTabButton) == "function" then
		window._styleTabButton = function(self, tab)
			nativeStyleTabButton(self, tab)
			patchTabVisuals(self, tab)
		end
	end

	local nativeCreateTab = window.CreateTab
	if type(nativeCreateTab) == "function" then
		window.CreateTab = function(self, ...)
			local tab = nativeCreateTab(self, ...)
			patchTabVisuals(self, tab)
			applyReadableSurfaces()
			return tab
		end
	end

	local nativeCreateElement = window._createElement
	if type(nativeCreateElement) == "function" then
		window._createElement = function(self, ...)
			local frame = nativeCreateElement(self, ...)
			if frame and not self.FrostedGlass then
				frame.BackgroundTransparency = 0
			end
			return frame
		end
	end

	applyReadableSurfaces()
	return window
end

function Anchorline:CreateWindow(options)
	if type(options) ~= "table" then
		options = {Title = tostring(options or "Anchorline")}
	end

	if options.FrostedGlass == nil then
		options.FrostedGlass = false
	end

	if options.GlassTransparency == nil then
		options.GlassTransparency = 0.12
	end

	if options.BlurSize == nil then
		options.BlurSize = 0
	end

	local window = originalCreateWindow(self, options)
	return patchWindow(window)
end

Anchorline.CreateInterface = Anchorline.CreateWindow
Anchorline.Window = Anchorline.CreateWindow

return Anchorline
