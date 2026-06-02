local Anchorline = {}
Anchorline.__index = Anchorline
Anchorline.Name = "Anchorline UI"
Anchorline.Version = "1.1.0"
Anchorline.Flags = {}
Anchorline.Windows = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

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
	local object = Instance.new(className)
	if properties then
		for property, value in pairs(properties) do
			object[property] = value
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
	local info = TweenInfo.new(time or 0.18, easingStyle or Enum.EasingStyle.Quart, easingDirection or Enum.EasingDirection.Out)
	local t = TweenService:Create(object, info, properties)
	t:Play()
	return t
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
		return Enum.KeyCode[cleaned] or Enum.KeyCode.RightControl
	end
	return Enum.KeyCode.RightControl
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

Anchorline.Themes = {
	Foundry = {
		Background = Color3.fromRGB(12, 14, 16),
		Panel = Color3.fromRGB(17, 20, 23),
		PanelAlt = Color3.fromRGB(22, 25, 29),
		Surface = Color3.fromRGB(27, 31, 36),
		SurfaceHover = Color3.fromRGB(34, 39, 45),
		Input = Color3.fromRGB(13, 16, 19),
		Stroke = Color3.fromRGB(45, 52, 60),
		StrokeSoft = Color3.fromRGB(34, 40, 47),
		Text = Color3.fromRGB(232, 236, 241),
		TextMuted = Color3.fromRGB(151, 160, 171),
		TextFaint = Color3.fromRGB(99, 109, 121),
		Accent = Color3.fromRGB(125, 164, 139),
		AccentSoft = Color3.fromRGB(35, 55, 44),
		AccentText = Color3.fromRGB(8, 11, 10),
		Success = Color3.fromRGB(91, 178, 123),
		Warning = Color3.fromRGB(205, 162, 88),
		Danger = Color3.fromRGB(203, 83, 83),
		Overlay = Color3.fromRGB(0, 0, 0)
	},
	Graphite = {
		Background = Color3.fromRGB(12, 14, 16),
		Panel = Color3.fromRGB(17, 20, 23),
		PanelAlt = Color3.fromRGB(22, 25, 29),
		Surface = Color3.fromRGB(27, 31, 36),
		SurfaceHover = Color3.fromRGB(34, 39, 45),
		Input = Color3.fromRGB(13, 16, 19),
		Stroke = Color3.fromRGB(45, 52, 60),
		StrokeSoft = Color3.fromRGB(34, 40, 47),
		Text = Color3.fromRGB(232, 236, 241),
		TextMuted = Color3.fromRGB(151, 160, 171),
		TextFaint = Color3.fromRGB(99, 109, 121),
		Accent = Color3.fromRGB(125, 164, 139),
		AccentSoft = Color3.fromRGB(35, 55, 44),
		AccentText = Color3.fromRGB(8, 11, 10),
		Success = Color3.fromRGB(91, 178, 123),
		Warning = Color3.fromRGB(205, 162, 88),
		Danger = Color3.fromRGB(203, 83, 83),
		Overlay = Color3.fromRGB(0, 0, 0)
	},
	Slate = {
		Background = Color3.fromRGB(16, 17, 19),
		Panel = Color3.fromRGB(22, 24, 27),
		PanelAlt = Color3.fromRGB(27, 30, 34),
		Surface = Color3.fromRGB(33, 37, 42),
		SurfaceHover = Color3.fromRGB(42, 47, 53),
		Input = Color3.fromRGB(18, 20, 23),
		Stroke = Color3.fromRGB(55, 61, 69),
		StrokeSoft = Color3.fromRGB(40, 45, 52),
		Text = Color3.fromRGB(235, 237, 240),
		TextMuted = Color3.fromRGB(156, 163, 174),
		TextFaint = Color3.fromRGB(104, 112, 124),
		Accent = Color3.fromRGB(150, 164, 180),
		AccentSoft = Color3.fromRGB(48, 55, 64),
		AccentText = Color3.fromRGB(13, 15, 17),
		Success = Color3.fromRGB(88, 174, 120),
		Warning = Color3.fromRGB(205, 160, 82),
		Danger = Color3.fromRGB(201, 82, 82),
		Overlay = Color3.fromRGB(0, 0, 0)
	},
	Porcelain = {
		Background = Color3.fromRGB(235, 237, 240),
		Panel = Color3.fromRGB(248, 249, 250),
		PanelAlt = Color3.fromRGB(242, 244, 246),
		Surface = Color3.fromRGB(232, 235, 239),
		SurfaceHover = Color3.fromRGB(223, 227, 233),
		Input = Color3.fromRGB(255, 255, 255),
		Stroke = Color3.fromRGB(186, 194, 204),
		StrokeSoft = Color3.fromRGB(211, 216, 224),
		Text = Color3.fromRGB(31, 35, 41),
		TextMuted = Color3.fromRGB(92, 101, 113),
		TextFaint = Color3.fromRGB(133, 143, 156),
		Accent = Color3.fromRGB(89, 127, 102),
		AccentSoft = Color3.fromRGB(216, 228, 220),
		AccentText = Color3.fromRGB(255, 255, 255),
		Success = Color3.fromRGB(69, 146, 94),
		Warning = Color3.fromRGB(168, 124, 56),
		Danger = Color3.fromRGB(183, 67, 67),
		Overlay = Color3.fromRGB(0, 0, 0)
	},
	Evergreen = {
		Background = Color3.fromRGB(13, 17, 15),
		Panel = Color3.fromRGB(18, 25, 21),
		PanelAlt = Color3.fromRGB(24, 32, 28),
		Surface = Color3.fromRGB(31, 41, 36),
		SurfaceHover = Color3.fromRGB(39, 51, 45),
		Input = Color3.fromRGB(15, 20, 17),
		Stroke = Color3.fromRGB(50, 65, 57),
		StrokeSoft = Color3.fromRGB(37, 49, 43),
		Text = Color3.fromRGB(231, 238, 232),
		TextMuted = Color3.fromRGB(151, 168, 157),
		TextFaint = Color3.fromRGB(99, 119, 107),
		Accent = Color3.fromRGB(112, 165, 130),
		AccentSoft = Color3.fromRGB(34, 66, 46),
		AccentText = Color3.fromRGB(7, 12, 9),
		Success = Color3.fromRGB(103, 193, 133),
		Warning = Color3.fromRGB(204, 165, 86),
		Danger = Color3.fromRGB(199, 82, 82),
		Overlay = Color3.fromRGB(0, 0, 0)
	},
	Clay = {
		Background = Color3.fromRGB(27, 23, 21),
		Panel = Color3.fromRGB(35, 30, 27),
		PanelAlt = Color3.fromRGB(43, 37, 33),
		Surface = Color3.fromRGB(52, 45, 40),
		SurfaceHover = Color3.fromRGB(62, 53, 47),
		Input = Color3.fromRGB(30, 26, 23),
		Stroke = Color3.fromRGB(77, 66, 58),
		StrokeSoft = Color3.fromRGB(60, 52, 46),
		Text = Color3.fromRGB(244, 237, 229),
		TextMuted = Color3.fromRGB(190, 177, 164),
		TextFaint = Color3.fromRGB(133, 120, 108),
		Accent = Color3.fromRGB(177, 130, 93),
		AccentSoft = Color3.fromRGB(73, 49, 36),
		AccentText = Color3.fromRGB(18, 12, 8),
		Success = Color3.fromRGB(92, 174, 118),
		Warning = Color3.fromRGB(206, 160, 84),
		Danger = Color3.fromRGB(199, 82, 82),
		Overlay = Color3.fromRGB(0, 0, 0)
	}
}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local function getThemeValue(window, key)
	local theme = window.Theme or Anchorline.Themes.Foundry
	return theme[key] or Anchorline.Themes.Foundry[key] or Color3.fromRGB(255, 255, 255)
end

function Window:_track(instance, propertyMap)
	self._themed[#self._themed + 1] = {Instance = instance, Properties = propertyMap}
	for property, themeKey in pairs(propertyMap) do
		if instance and instance.Parent ~= nil then
			instance[property] = getThemeValue(self, themeKey)
		end
	end
	return instance
end

function Window:_applyTheme()
	for i = #self._themed, 1, -1 do
		local entry = self._themed[i]
		if not entry.Instance or entry.Instance.Parent == nil then
			table.remove(self._themed, i)
		else
			for property, themeKey in pairs(entry.Properties) do
				entry.Instance[property] = getThemeValue(self, themeKey)
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
		self.Theme = Anchorline.Themes[theme] or Anchorline.Themes.Foundry
	elseif type(theme) == "table" then
		self.ThemeName = "Custom"
		self.Theme = theme
	else
		self.ThemeName = "Foundry"
		self.Theme = Anchorline.Themes.Foundry
	end
	self:_applyTheme()
	return self
end

function Window:_styleTabButton(tab)
	if not tab or not tab.Button then
		return
	end
	local active = self.ActiveTab == tab
	if active then
		tab.Button.BackgroundColor3 = getThemeValue(self, "Surface")
		tab.ButtonStroke.Color = getThemeValue(self, "Stroke")
		tab.ButtonTitle.TextColor3 = getThemeValue(self, "Text")
		tab.ButtonIcon.TextColor3 = getThemeValue(self, "Accent")
		if tab.ButtonAccent then
			tab.ButtonAccent.BackgroundColor3 = getThemeValue(self, "Accent")
			tab.ButtonAccent.BackgroundTransparency = 0
		end
	else
		tab.Button.BackgroundColor3 = getThemeValue(self, "Panel")
		tab.ButtonStroke.Color = getThemeValue(self, "StrokeSoft")
		tab.ButtonTitle.TextColor3 = getThemeValue(self, "TextMuted")
		tab.ButtonIcon.TextColor3 = getThemeValue(self, "TextFaint")
		if tab.ButtonAccent then
			tab.ButtonAccent.BackgroundTransparency = 1
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
end

function Window:_updateContentOffset()
	local width = self.SidebarCollapsed and 64 or self.SidebarWidth
	tween(self.Sidebar, 0.2, {Size = UDim2.new(0, width, 1, -52)})
	tween(self.Content, 0.2, {Position = UDim2.new(0, width, 0, 52), Size = UDim2.new(1, -width, 1, -52)})
	for _, tab in ipairs(self.Tabs) do
		tab.ButtonTitle.Visible = not self.SidebarCollapsed
	end
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
		tween(self.Root, 0.22, {Size = UDim2.new(0, math.max(380, self.Root.AbsoluteSize.X), 0, 52)})
	else
		self.Sidebar.Visible = true
		self.Content.Visible = true
		self.ResizeHandle.Visible = true
		tween(self.Root, 0.22, {Size = self._lastSize or UDim2.fromOffset(self.Width, self.Height)})
	end
	return self.Minimized
end

function Window:Show()
	self.Gui.Enabled = true
	self.Hidden = false
end

function Window:Hide()
	self.Gui.Enabled = false
	self.Hidden = true
end

function Window:Toggle()
	if self.Gui.Enabled then
		self:Hide()
	else
		self:Show()
	end
end

function Window:Destroy()
	for _, connection in ipairs(self._connections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end
	self._connections = {}
	if self.Gui then
		self.Gui:Destroy()
	end
end

function Window:_makeDraggable()
	local dragging = false
	local dragStart = nil
	local startPosition = nil
	local dragInput = nil
	local header = self.Header
	local root = self.Root

	self._connections[#self._connections + 1] = header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = root.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	self._connections[#self._connections + 1] = header.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	self._connections[#self._connections + 1] = UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging and dragStart and startPosition then
			local delta = input.Position - dragStart
			root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
end

function Window:_makeResizable()
	local resizing = false
	local resizeStart = nil
	local startSize = nil
	local minWidth = 520
	local minHeight = 360
	local maxWidth = 980
	local maxHeight = 740

	self._connections[#self._connections + 1] = self.ResizeHandle.InputBegan:Connect(function(input)
		if self.Minimized then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStart = input.Position
			startSize = self.Root.AbsoluteSize
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
				end
			end)
		end
	end)

	self._connections[#self._connections + 1] = UserInputService.InputChanged:Connect(function(input)
		if not resizing or not resizeStart or not startSize then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - resizeStart
		local newWidth = math.clamp(startSize.X + delta.X, minWidth, maxWidth)
		local newHeight = math.clamp(startSize.Y + delta.Y, minHeight, maxHeight)
		self.Root.Size = UDim2.fromOffset(newWidth, newHeight)
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
	local item = new("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.NotificationList
	}, {
		corner(10),
		padding(12, 12, 10, 10),
		listLayout(Enum.FillDirection.Vertical, 4)
	})
	self:_track(item, {BackgroundColor3 = "Panel", BorderColor3 = "Panel"})
	local itemStroke = stroke(getThemeValue(self, "StrokeSoft"), 1, 0)
	itemStroke.Parent = item
	self:_track(itemStroke, {Color = "StrokeSoft"})

	local accentBar = new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = self:_notificationColors(options.Type),
		Parent = item
	}, {corner(10)})

	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(options.Title or "Notification"),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = item
	})
	self:_track(title, {TextColor3 = "Text"})

	local content = new("TextLabel", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tostring(options.Content or ""),
		Parent = item
	})
	self:_track(content, {TextColor3 = "TextMuted"})

	item.BackgroundTransparency = 1
	itemStroke.Transparency = 1
	title.TextTransparency = 1
	content.TextTransparency = 1
	accentBar.BackgroundTransparency = 1
	task.defer(function()
		tween(item, 0.2, {BackgroundTransparency = 0})
		tween(itemStroke, 0.2, {Transparency = 0})
		tween(title, 0.2, {TextTransparency = 0})
		tween(content, 0.2, {TextTransparency = 0})
		tween(accentBar, 0.2, {BackgroundTransparency = 0})
	end)
	local duration = tonumber(options.Duration) or 4
	task.delay(duration, function()
		if not item or not item.Parent then
			return
		end
		tween(item, 0.18, {BackgroundTransparency = 1})
		tween(itemStroke, 0.18, {Transparency = 1})
		tween(title, 0.18, {TextTransparency = 1})
		tween(content, 0.18, {TextTransparency = 1})
		tween(accentBar, 0.18, {BackgroundTransparency = 1})
		task.wait(0.2)
		if item then
			item:Destroy()
		end
	end)
	return item
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
		corner(6),
		stroke(getThemeValue(self, "Stroke"), 1, 0),
		padding(18, 18, 18, 18),
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
		tween(overlay, 0.16, {BackgroundTransparency = 1})
		tween(card, 0.16, {BackgroundTransparency = 1})
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
	tween(overlay, 0.16, {BackgroundTransparency = 0.45})
	tween(card, 0.16, {BackgroundTransparency = 0})
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
end

function Window:CreateTab(name, icon, description)
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Name = tostring(name or "Tab")
	tab.Icon = tostring(icon or string.sub(tab.Name, 1, 1)):sub(1, 2)
	tab.Description = description
	tab.Elements = {}

	local button = new("TextButton", {
		Name = tab.Name .. "TabButton",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = self.TabList
	}, {corner(5)})
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
	local iconLabel = new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(22, 34),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = tab.Icon,
		Parent = button
	})
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
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.25,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = self.Pages
	}, {
		padding(16, 16, 14, 16),
		listLayout(Enum.FillDirection.Vertical, 10)
	})
	self:_track(page, {ScrollBarImageColor3 = "Accent"})

	tab.Button = button
	tab.ButtonStroke = buttonStroke
	tab.ButtonTitle = titleLabel
	tab.ButtonIcon = iconLabel
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
		BackgroundTransparency = 0,
		ClipsDescendants = false,
		Parent = tab.Page
	}, {
		corner(6),
		padding(12, 12, 10, 10),
		listLayout(Enum.FillDirection.Vertical, 8)
	})
	frame:SetAttribute("SearchText", tostring(searchText or titleText or ""))
	local s = stroke(getThemeValue(self, "StrokeSoft"), 1, 0)
	s.Parent = frame
	self:_track(frame, {BackgroundColor3 = "PanelAlt"})
	self:_track(s, {Color = "StrokeSoft"})
	tab.Elements[#tab.Elements + 1] = frame
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
	local controller = {}
	function controller:Set(value)
		label.Text = tostring(value)
		frame:SetAttribute("SearchText", tostring(value))
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
	self:_headerRow(frame, titleText, "")
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = bodyText,
		Parent = frame
	})
	self.Window:_track(label, {TextColor3 = "TextMuted"})
	local controller = {}
	function controller:Set(value)
		label.Text = tostring(value)
		frame:SetAttribute("SearchText", titleText .. " " .. tostring(value))
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
	local knob = new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(3, 3),
		BorderSizePixel = 0,
		Parent = button
	}, {corner(10)})
	self.Window:_track(knob, {BackgroundColor3 = "Text"})

	local controller = {Type = "Toggle", Flag = options.Flag}
	local function render()
		button.BackgroundColor3 = value and getThemeValue(self.Window, "Accent") or getThemeValue(self.Window, "Surface")
		knob.Position = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
	end
	function controller:Set(newValue, loading)
		value = newValue and true or false
		render()
		if not loading then
			safeCall(options.Callback, value)
			self.Window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	button.MouseButton1Click:Connect(function()
		controller:Set(not value)
	end)
	render()
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateSlider(options)
	options = options or {}
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
	local function render()
		local percent = 0
		if maxValue ~= minValue then
			percent = (value - minValue) / (maxValue - minValue)
		end
		fill.Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1)
		valueLabel.Text = tostring(value) .. (suffix ~= "" and " " .. suffix or "")
	end
	local function updateFromX(x, loading)
		local percent = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		controller:Set(snap(minValue + (maxValue - minValue) * percent), loading)
	end
	function controller:Set(newValue, loading)
		value = snap(tonumber(newValue) or minValue)
		render()
		if not loading then
			safeCall(options.Callback, value)
			self.Window:_autoSave()
		end
	end
	function controller:Get()
		return value
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)
	controller:Set(value, true)
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateInput(options)
	options = options or {}
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
			self.Window:_autoSave()
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
				end
				renderText()
				safeCall(options.Callback, controller:Get())
				self.Window:_autoSave()
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
			self.Window:_autoSave()
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
	end)
	renderButtons()
	renderText()
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Tab:CreateKeybind(options)
	options = options or {}
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
			self.Window:_autoSave()
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
		fill.Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1)
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
	local name = tostring(options.Name or "Color Picker")
	local value = tableToColor(options.Color or options.CurrentColor, Color3.fromRGB(88, 142, 255))
	local frame = self.Window:_createElement(self, name, name .. " color picker rgb", 96)
	self:_headerRow(frame, name, options.Description)
	local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = frame})
	local preview = new("TextButton", {
		Size = UDim2.fromOffset(44, 30),
		Text = "",
		AutoButtonColor = false,
		Parent = row
	}, {corner(5), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
	local fields = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -54, 0, 30),
		Parent = row
	}, {listLayout(Enum.FillDirection.Horizontal, 6)})
	local boxes = {}
	local function makeBox(labelText)
		local box = new("TextBox", {
			Size = UDim2.new(0.333, -4, 1, 0),
			BackgroundTransparency = 0,
			Text = "0",
			PlaceholderText = labelText,
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = fields
		}, {corner(4), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
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
		Size = UDim2.new(1, 0, 0, 24),
		Parent = frame
	}, {listLayout(Enum.FillDirection.Horizontal, 6)})
	local controller = {Type = "ColorPicker", Flag = options.Flag}
	local presetColors = options.Presets or {
		Color3.fromRGB(88, 142, 255),
		Color3.fromRGB(55, 179, 113),
		Color3.fromRGB(236, 174, 61),
		Color3.fromRGB(230, 83, 83),
		Color3.fromRGB(155, 109, 255),
		Color3.fromRGB(231, 132, 78),
		Color3.fromRGB(240, 240, 240),
		Color3.fromRGB(24, 26, 31)
	}
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
			self.Window:_autoSave()
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
	for _, color in ipairs(presetColors) do
		local chip = new("TextButton", {
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = color,
			Text = "",
			AutoButtonColor = false,
			Parent = presets
		}, {corner(6), stroke(getThemeValue(self.Window, "StrokeSoft"), 1, 0)})
		chip.MouseButton1Click:Connect(function()
			controller:Set(color)
		end)
	end
	render()
	self.Window:_registerFlag(options.Flag, controller)
	return controller
end

function Anchorline:CreateWindow(options)
	options = options or {}
	local self = setmetatable({}, Window)
	self.Title = tostring(options.Title or options.Name or "Anchorline")
	self.Subtitle = tostring(options.Subtitle or options.LoadingSubtitle or "Reusable interface library")
	self.Width = tonumber(options.Width) or 700
	self.Height = tonumber(options.Height) or 480
	self.SidebarWidth = tonumber(options.SidebarWidth) or 164
	self.SidebarCollapsed = false
	self.Hidden = false
	self.Minimized = false
	self.Tabs = {}
	self.Flags = {}
	self._themed = {}
	self._connections = {}
	self.Configuration = options.Configuration or options.ConfigurationSaving or {Enabled = false}
	if self.Configuration.Enabled == nil then
		self.Configuration.Enabled = false
	end
	self.ThemeName = "Foundry"
	self.Theme = Anchorline.Themes.Foundry

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

	local root = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = options.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.Width, self.Height),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Parent = gui
	}, {corner(6)})
	self.Root = root
	self:_track(root, {BackgroundColor3 = "Background"})
	local rootStroke = stroke(getThemeValue(self, "Stroke"), 1, 0)
	rootStroke.Parent = root
	self:_track(rootStroke, {Color = "Stroke"})

	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 0,
		Parent = root
	})
	self.Header = header
	self:_track(header, {BackgroundColor3 = "Panel"})
	local headerLine = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
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
		Size = UDim2.fromOffset(114, 28),
		Parent = header
	}, {listLayout(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)})
	local function controlButton(text)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(32, 28),
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = false,
			Parent = controls
		}, {corner(4), stroke(getThemeValue(self, "StrokeSoft"), 1, 0)})
		self:_track(b, {BackgroundColor3 = "Surface", TextColor3 = "TextMuted"})
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = getThemeValue(self, "SurfaceHover")
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = getThemeValue(self, "Surface")
		end)
		return b
	end
	local sidebarButton = controlButton("≡")
	local minimizeButton = controlButton("−")
	local closeButton = controlButton("×")
	closeButton.TextColor3 = getThemeValue(self, "Danger")

	local sidebar = new("Frame", {
		Name = "Sidebar",
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(0, self.SidebarWidth, 1, -52),
		BackgroundTransparency = 0,
		Parent = root
	})
	self.Sidebar = sidebar
	self:_track(sidebar, {BackgroundColor3 = "Panel"})
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
		Position = UDim2.new(0, self.SidebarWidth, 0, 52),
		Size = UDim2.new(1, -self.SidebarWidth, 1, -52),
		BackgroundTransparency = 0,
		Parent = root
	})
	self.Content = content
	self:_track(content, {BackgroundColor3 = "Background"})

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
		Parent = contentHeader
	}, {corner(5), stroke(getThemeValue(self, "StrokeSoft"), 1, 0)})
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
		Size = UDim2.new(1, 0, 1, -66),
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
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(320, 0),
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
			Content = "This will destroy the current Anchorline window.",
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

	local toggleKey = normalizeKey(options.ToggleKey or options.HideKey or Enum.KeyCode.RightControl)
	self._connections[#self._connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isTyping() then
			return
		end
		if input.KeyCode == toggleKey then
			self:Toggle()
		end
	end)

	self:SetTheme(options.Theme or "Foundry")
	Anchorline.Windows[#Anchorline.Windows + 1] = self
	Anchorline.LastWindow = self

	if self.Configuration.Enabled then
		task.defer(function()
			self:LoadConfiguration()
		end)
	end

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

return Anchorline
