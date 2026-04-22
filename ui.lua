--!strict
--[[
	AsusLib - Roblox UI Library (v3)
	- Responsive: scales cleanly on mobile + PC
	- Solid dark theme matching the reference design
	- Real frame-drawn icons (no asset IDs, always render)
	- Notification system (top-right toasts)
	- K to toggle visibility on PC, floating circle to restore on mobile
	- Clicking minimize (-) hides the window and shows a toast

	USAGE:
		local AsusLib = loadstring(game:HttpGet("YOUR_URL/AsusLib.lua"))()
		local Window  = AsusLib:CreateWindow("Asus Hub | Game | Delta")
		local Visuals = Window:CreateTab("Visuals", "eye")
		Visuals:CreateLabel("Esp all Crates in map")
		Visuals:CreateToggle({ Name="Esp Crates", Description="View all crates.", Default=false, Callback=function(v) end })
		Visuals:CreateSlider({ Name="Range (studs)", Description="Detection radius.", Min=0, Max=100, Default=30, Callback=function(v) end })
		AsusLib:Notify({ Title = "Loaded", Text = "Welcome to Asus Hub" })

	Icons: eye, swords, users, basket, settings, x, minus, home, bell
--]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local IsMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================================================
-- THEME (matches the reference screenshots)
-- ==========================================================================
local THEME = {
	Window       = Color3.fromRGB(20, 20, 20),   -- deep solid dark
	Sidebar      = Color3.fromRGB(20, 20, 20),
	Card         = Color3.fromRGB(40, 40, 40),   -- card surface
	CardHover    = Color3.fromRGB(50, 50, 50),
	Accent       = Color3.fromRGB(255, 255, 255),-- the white "thing" (selection bar + on-toggle)
	Text         = Color3.fromRGB(255, 255, 255),
	SubText      = Color3.fromRGB(170, 170, 170),
	TabInactive  = Color3.fromRGB(175, 175, 175),
	ToggleOff    = Color3.fromRGB(60, 60, 60),
	ToggleOn     = Color3.fromRGB(255, 255, 255),
	Border       = Color3.fromRGB(45, 45, 45),
	Toast        = Color3.fromRGB(28, 28, 28),
}

-- ==========================================================================
-- HELPERS
-- ==========================================================================
local function new(class: string, props: {[string]: any}): Instance
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	return inst
end

local function corner(radius: number, parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(color: Color3, thickness: number, parent: Instance, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent: Instance, top: number, bottom: number, left: number, right: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, top)
	p.PaddingBottom = UDim.new(0, bottom)
	p.PaddingLeft   = UDim.new(0, left)
	p.PaddingRight  = UDim.new(0, right)
	p.Parent = parent
	return p
end

local function tween(inst: Instance, time: number, props: {[string]: any})
	local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Draggable (mouse + touch)
local function makeDraggable(frame: GuiObject, handle: GuiObject)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function getParent(): Instance
	local ok, cg = pcall(function()
		if (getgenv and getgenv().gethui) then return getgenv().gethui() end
		if gethui then return gethui() end
		return CoreGui
	end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- ==========================================================================
-- ICONS (drawn with native Frames)
-- ==========================================================================
local function iconContainer(parent: Instance, size: number?): Frame
	return (new("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size or 20, size or 20),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: any) :: Frame
end

local function line(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, rot: number?)
	local f = new("Frame", {
		Size                   = UDim2.fromOffset(w, h),
		Position               = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundColor3       = color,
		BorderSizePixel        = 0,
		Rotation               = rot or 0,
		Parent                 = parent,
	})
	corner(math.min(w, h) / 2, f)
	return f
end

local function ring(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, thickness: number)
	local f = new("Frame", {
		Size                   = UDim2.fromOffset(w, h),
		Position               = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = parent,
	})
	corner(math.max(w, h), f)
	stroke(color, thickness, f)
	return f
end

local function dot(parent: Instance, color: Color3, x: number, y: number, size: number)
	local f = new("Frame", {
		Size                   = UDim2.fromOffset(size, size),
		Position               = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundColor3       = color,
		BorderSizePixel        = 0,
		Parent                 = parent,
	})
	corner(size, f)
	return f
end

local ICON_DRAWERS: {[string]: (Frame, Color3) -> ()} = {}

ICON_DRAWERS.x = function(c, color)
	line(c, color, 0, 0, 18, 2, 45)
	line(c, color, 0, 0, 18, 2, -45)
end

ICON_DRAWERS.minus = function(c, color)
	line(c, color, 0, 0, 14, 2, 0)
end

ICON_DRAWERS.home = function(c, color)
	-- Triangle roof (approximated) + square base
	line(c, color, -4, -4, 12, 2, 45)
	line(c, color,  4, -4, 12, 2, -45)
	local base = new("Frame", {
		Size = UDim2.fromOffset(12, 10),
		Position = UDim2.new(0.5, 0, 0.5, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, base)
	stroke(color, 1.6, base)
end

ICON_DRAWERS.bell = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(7, body)
	stroke(color, 1.6, body)
	line(c, color, 0, 7, 6, 2, 0)
	dot(c, color, 0, 9, 2)
end

ICON_DRAWERS.eye = function(c, color)
	local lens = new("Frame", {
		Size                   = UDim2.fromOffset(18, 12),
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(6, lens)
	stroke(color, 1.6, lens)
	ring(c, color, 0, 0, 7, 7, 1.6)
	dot(c, color, 0, 0, 3)
end

ICON_DRAWERS.swords = function(c, color)
	line(c, color, -1, -1, 16, 2, 45)
	line(c, color, 1, -1, 16, 2, -45)
	line(c, color, -6, -6, 5, 2, -45)
	line(c, color, 6, -6, 5, 2, 45)
	dot(c, color, -7, 7, 3)
	dot(c, color, 7, 7, 3)
end

ICON_DRAWERS.users = function(c, color)
	ring(c, color, -3, -4, 6, 6, 1.6)
	ring(c, color, 4, -4, 6, 6, 1.6)
	local b1 = new("Frame", {
		Size                   = UDim2.fromOffset(10, 6),
		Position               = UDim2.new(0.5, -3, 0.5, 4),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(4, b1)
	stroke(color, 1.6, b1)
	local b2 = new("Frame", {
		Size                   = UDim2.fromOffset(10, 6),
		Position               = UDim2.new(0.5, 4, 0.5, 4),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(4, b2)
	stroke(color, 1.6, b2)
end

ICON_DRAWERS.basket = function(c, color)
	local handle = new("Frame", {
		Size                   = UDim2.fromOffset(10, 8),
		Position               = UDim2.new(0.5, 0, 0.5, -3),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(6, handle)
	stroke(color, 1.6, handle)
	line(c, color, 0, 1, 18, 2, 0)
	local body = new("Frame", {
		Size                   = UDim2.fromOffset(16, 8),
		Position               = UDim2.new(0.5, 0, 0.5, 5),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	line(c, color, -4, 5, 1.4, 6, 0)
	line(c, color, 0,  5, 1.4, 6, 0)
	line(c, color, 4,  5, 1.4, 6, 0)
end

ICON_DRAWERS.settings = function(c, color)
	ring(c, color, 0, 0, 8, 8, 1.6)
	dot(c, color, 0, 0, 2)
	local radius = 7
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local x = math.cos(angle) * radius
		local y = math.sin(angle) * radius
		local tooth = new("Frame", {
			Size                   = UDim2.fromOffset(3, 3),
			Position               = UDim2.new(0.5, x, 0.5, y),
			AnchorPoint            = Vector2.new(0.5, 0.5),
			BackgroundColor3       = color,
			BorderSizePixel        = 0,
			Rotation               = i * 45,
			Parent                 = c,
		})
		corner(1, tooth)
	end
end

local function drawIcon(parent: Instance, name: string, color: Color3, size: number?): Frame
	local c = iconContainer(parent, size)
	local drawer = ICON_DRAWERS[name]
	if drawer then drawer(c, color) end
	return c
end

local function recolorIcon(container: Frame, name: string, color: Color3)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	local drawer = ICON_DRAWERS[name]
	if drawer then drawer(container, color) end
end

-- ==========================================================================
-- LIBRARY
-- ==========================================================================
local AsusLib = {}
AsusLib._screens = {} -- track all created ScreenGuis for Notify

-- ----------------------------------------------------------------------
-- NOTIFICATIONS (top-right toasts)
-- ----------------------------------------------------------------------
local NotifyContainer: ScreenGui? = nil

local function ensureNotifyContainer()
	if NotifyContainer and NotifyContainer.Parent then return NotifyContainer end
	local host = getParent()
	local existing = host:FindFirstChild("AsusLibNotify")
	if existing then
		NotifyContainer = existing :: ScreenGui
		return NotifyContainer
	end
	local sg = new("ScreenGui", {
		Name           = "AsusLibNotify",
		IgnoreGuiInset = true,
		ResetOnSpawn   = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder   = 10000,
		Parent         = host,
	})
	local holder = new("Frame", {
		Name                   = "Holder",
		Size                   = UDim2.new(0, 320, 1, -20),
		Position               = UDim2.new(1, -16, 0, 16),
		AnchorPoint            = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent                 = sg,
	})
	new("UIListLayout", {
		Padding              = UDim.new(0, 8),
		HorizontalAlignment  = Enum.HorizontalAlignment.Right,
		VerticalAlignment    = Enum.VerticalAlignment.Top,
		SortOrder            = Enum.SortOrder.LayoutOrder,
		Parent               = holder,
	})
	NotifyContainer = sg
	return sg
end

function AsusLib:Notify(opts: { Title: string?, Text: string, Duration: number? })
	local duration = opts.Duration or 3
	local sg       = ensureNotifyContainer()
	local holder   = sg:FindFirstChild("Holder") :: Frame

	local toast = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, 64),
		BackgroundColor3       = THEME.Toast,
		BorderSizePixel        = 0,
		BackgroundTransparency = 1,
		Parent                 = holder,
	})
	corner(10, toast)
	stroke(THEME.Border, 1, toast, 0.3)
	padding(toast, 10, 10, 14, 14)

	local iconBox = new("Frame", {
		Size                   = UDim2.fromOffset(20, 20),
		Position               = UDim2.new(0, 0, 0, 4),
		BackgroundTransparency = 1,
		Parent                 = toast,
	})
	drawIcon(iconBox, "bell", THEME.Accent, 20).Size = UDim2.new(1, 0, 1, 0)

	new("TextLabel", {
		Size                   = UDim2.new(1, -28, 0, 20),
		Position               = UDim2.new(0, 28, 0, 0),
		BackgroundTransparency = 1,
		Text                   = opts.Title or "Notification",
		TextColor3             = THEME.Text,
		Font                   = Enum.Font.GothamBold,
		TextSize               = 14,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextTransparency       = 1,
		Parent                 = toast,
	})
	new("TextLabel", {
		Size                   = UDim2.new(1, -28, 0, 22),
		Position               = UDim2.new(0, 28, 0, 20),
		BackgroundTransparency = 1,
		Text                   = opts.Text,
		TextColor3             = THEME.SubText,
		Font                   = Enum.Font.Gotham,
		TextSize               = 13,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextWrapped            = true,
		TextTransparency       = 1,
		Parent                 = toast,
	})

	-- Fade in
	tween(toast, 0.18, { BackgroundTransparency = 0 })
	for _, child in ipairs(toast:GetChildren()) do
		if child:IsA("TextLabel") then
			tween(child, 0.18, { TextTransparency = 0 })
		end
	end

	task.delay(duration, function()
		if not toast.Parent then return end
		tween(toast, 0.25, { BackgroundTransparency = 1 })
		for _, child in ipairs(toast:GetChildren()) do
			if child:IsA("TextLabel") then
				tween(child, 0.25, { TextTransparency = 1 })
			end
		end
		task.wait(0.3)
		toast:Destroy()
	end)
end

-- ----------------------------------------------------------------------
-- CREATE WINDOW
-- ----------------------------------------------------------------------
function AsusLib:CreateWindow(title: string)
	local host = getParent()
	local existing = host:FindFirstChild("AsusLibGui")
	if existing then existing:Destroy() end

	local ScreenGui = new("ScreenGui", {
		Name              = "AsusLibGui",
		IgnoreGuiInset    = true,
		ResetOnSpawn      = false,
		ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
		DisplayOrder      = 9999,
		Parent            = host,
	})
	table.insert(AsusLib._screens, ScreenGui)

	-- Responsive sizing (smaller on mobile than before)
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local winW, winH
	if IsMobile then
		winW = math.min(viewport.X * 0.78, 640)
		winH = math.min(viewport.Y * 0.72, 400)
	else
		winW = math.min(viewport.X * 0.55, 720)
		winH = math.min(viewport.Y * 0.70, 480)
	end

	local Window = new("Frame", {
		Name                   = "Window",
		Size                   = UDim2.fromOffset(winW, winH),
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundColor3       = THEME.Window,
		BorderSizePixel        = 0,
		ClipsDescendants       = true,
		Parent                 = ScreenGui,
	})
	corner(14, Window)
	stroke(THEME.Border, 1, Window, 0.35)

	-- ---------- TITLE BAR ----------
	local TitleBar = new("Frame", {
		Name                   = "TitleBar",
		Size                   = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})
	padding(TitleBar, 0, 0, 18, 12)

	local TitleLabel = new("TextLabel", {
		Size                   = UDim2.new(1, -90, 1, 0),
		BackgroundTransparency = 1,
		Text                   = title or "Asus Hub",
		TextColor3             = THEME.Text,
		Font                   = Enum.Font.GothamBold,
		TextSize               = 16,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextYAlignment         = Enum.TextYAlignment.Center,
		Parent                 = TitleBar,
	})

	local MinBtn = new("TextButton", {
		Size                   = UDim2.fromOffset(30, 30),
		Position               = UDim2.new(1, -56, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text                   = "",
		AutoButtonColor        = false,
		Parent                 = TitleBar,
	})
	local minIcon = drawIcon(MinBtn, "minus", THEME.Text, 20)
	minIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	minIcon.AnchorPoint = Vector2.new(0.5, 0.5)

	local CloseBtn = new("TextButton", {
		Size                   = UDim2.fromOffset(30, 30),
		Position               = UDim2.new(1, -26, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text                   = "",
		AutoButtonColor        = false,
		Parent                 = TitleBar,
	})
	local closeIcon = drawIcon(CloseBtn, "x", THEME.Text, 20)
	closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)

	makeDraggable(Window, TitleBar)

	-- ---------- BODY ----------
	local Body = new("Frame", {
		Size                   = UDim2.new(1, 0, 1, -46),
		Position               = UDim2.new(0, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})

	-- Sidebar
	local sidebarWidth = IsMobile and 140 or 180
	local Sidebar = new("Frame", {
		Name                   = "Sidebar",
		Size                   = UDim2.new(0, sidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent                 = Body,
	})
	padding(Sidebar, 4, 12, 10, 6)

	local TabList = new("Frame", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent                 = Sidebar,
	})
	new("UIListLayout", {
		Padding   = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent    = TabList,
	})

	-- Content
	local Content = new("Frame", {
		Size                   = UDim2.new(1, -sidebarWidth, 1, 0),
		Position               = UDim2.new(0, sidebarWidth, 0, 0),
		BackgroundTransparency = 1,
		Parent                 = Body,
	})
	padding(Content, 4, 14, 4, 18)

	-- ---------- FLOATING RESTORE ICON (shown when window is hidden) ----------
	local RestoreIcon = new("ImageButton", {
		Name                   = "RestoreIcon",
		Size                   = UDim2.fromOffset(48, 48),
		Position               = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundColor3       = THEME.Window,
		BorderSizePixel        = 0,
		Image                  = "",
		AutoButtonColor        = false,
		Visible                = false,
		Parent                 = ScreenGui,
	})
	corner(24, RestoreIcon)
	stroke(THEME.Accent, 1.5, RestoreIcon, 0.4)
	local restoreIconBox = drawIcon(RestoreIcon, "home", THEME.Accent, 22)
	restoreIconBox.Position   = UDim2.new(0.5, 0, 0.5, 0)
	restoreIconBox.AnchorPoint = Vector2.new(0.5, 0.5)
	makeDraggable(RestoreIcon, RestoreIcon)

	-- ---------- VISIBILITY LOGIC ----------
	local hidden = false
	local function setHidden(h: boolean, notify: boolean?)
		hidden = h
		Window.Visible      = not h
		RestoreIcon.Visible = h
		if h and notify ~= false then
			local hint = IsMobile and "Tap the floating icon to re-open."
				or "Press K to toggle the UI back."
			AsusLib:Notify({ Title = "UI Hidden", Text = hint, Duration = 3.5 })
		end
	end

	MinBtn.MouseButton1Click:Connect(function()
		setHidden(true, true)
	end)

	RestoreIcon.MouseButton1Click:Connect(function()
		setHidden(false)
	end)

	CloseBtn.MouseButton1Click:Connect(function()
		tween(Window, 0.18, { Size = UDim2.new(0, 0, 0, 0) })
		task.wait(0.2)
		ScreenGui:Destroy()
	end)

	-- K keybind to toggle visibility (PC)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.K then
			if ScreenGui.Parent then
				setHidden(not hidden)
			end
		end
	end)

	local WindowObj = {}
	WindowObj.Tabs = {}
	WindowObj._gui = ScreenGui

	function WindowObj:Notify(opts) AsusLib:Notify(opts) end
	function WindowObj:SetVisible(v: boolean) setHidden(not v, false) end
	function WindowObj:Destroy() ScreenGui:Destroy() end

	-- ---------- TAB ----------
	function WindowObj:CreateTab(name: string, iconName: string?)
		iconName = iconName or "eye"

		local tabRow = new("Frame", {
			Name                   = "Tab_" .. name,
			Size                   = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Parent                 = TabList,
		})

		-- White accent bar (the "white thing" on active tab)
		local accent = new("Frame", {
			Size                   = UDim2.fromOffset(3, 22),
			Position               = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundColor3       = THEME.Accent,
			BorderSizePixel        = 0,
			BackgroundTransparency = 1,
			Parent                 = tabRow,
		})
		corner(2, accent)

		local iconBox = new("Frame", {
			Size                   = UDim2.fromOffset(20, 20),
			Position               = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Parent                 = tabRow,
		})
		drawIcon(iconBox, iconName :: string, THEME.TabInactive, 20).Size = UDim2.new(1, 0, 1, 0)

		local label = new("TextLabel", {
			Size                   = UDim2.new(1, -44, 1, 0),
			Position               = UDim2.new(0, 42, 0, 0),
			BackgroundTransparency = 1,
			Text                   = "| " .. name,
			TextColor3             = THEME.TabInactive,
			Font                   = Enum.Font.GothamMedium,
			TextSize               = IsMobile and 14 or 15,
			TextXAlignment         = Enum.TextXAlignment.Left,
			Parent                 = tabRow,
		})

		local click = new("TextButton", {
			Size                   = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text                   = "",
			AutoButtonColor        = false,
			Parent                 = tabRow,
		})

		local Page = new("ScrollingFrame", {
			Name                   = "Page_" .. name,
			Size                   = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			ScrollBarThickness     = 3,
			ScrollBarImageColor3   = Color3.fromRGB(90, 90, 90),
			CanvasSize             = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize    = Enum.AutomaticSize.Y,
			ScrollingDirection     = Enum.ScrollingDirection.Y,
			Visible                = false,
			Parent                 = Content,
		})
		padding(Page, 0, 14, 0, 8)

		new("TextLabel", {
			Name                   = "Header",
			Size                   = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
			Text                   = name,
			TextColor3             = THEME.Text,
			Font                   = Enum.Font.GothamBold,
			TextSize               = IsMobile and 22 or 24,
			TextXAlignment         = Enum.TextXAlignment.Left,
			LayoutOrder            = 0,
			Parent                 = Page,
		})

		new("UIListLayout", {
			Padding   = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent    = Page,
		})

		local TabObj = {}
		TabObj._order = 1
		local function nextOrder()
			TabObj._order = TabObj._order + 1
			return TabObj._order
		end

		local function select()
			for _, t in ipairs(WindowObj.Tabs) do
				t.page.Visible = false
				t.label.TextColor3 = THEME.TabInactive
				recolorIcon(t.iconBox, t.iconName, THEME.TabInactive)
				t.accent.BackgroundTransparency = 1
			end
			Page.Visible = true
			label.TextColor3 = THEME.Text
			recolorIcon(iconBox, iconName :: string, THEME.Text)
			accent.BackgroundTransparency = 0
		end

		click.MouseButton1Click:Connect(select)

		table.insert(WindowObj.Tabs, {
			page = Page, label = label, iconBox = iconBox,
			iconName = iconName, accent = accent, select = select,
		})

		if #WindowObj.Tabs == 1 then select() end

		-- ---------- LABEL ----------
		function TabObj:CreateLabel(text: string)
			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, 50),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			local tl = new("TextLabel", {
				Size                   = UDim2.new(1, -32, 1, 0),
				Position               = UDim2.new(0, 18, 0, 0),
				BackgroundTransparency = 1,
				Text                   = text,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})
			return { SetText = function(_, s: string) tl.Text = s end }
		end

		-- ---------- TOGGLE ----------
		function TabObj:CreateToggle(opts: {
			Name: string, Description: string?, Default: boolean?, Callback: ((boolean) -> ())?
		})
			local state = opts.Default == true
			local cb    = opts.Callback or function() end

			local hasDesc = opts.Description and opts.Description ~= ""
			local cardH   = hasDesc and 70 or 54

			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, cardH),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			padding(Card, 12, 12, 18, 16)

			new("TextLabel", {
				Size                   = UDim2.new(1, -64, 0, 20),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})
			if hasDesc then
				new("TextLabel", {
					Position               = UDim2.new(0, 0, 0, 22),
					Size                   = UDim2.new(1, -64, 0, 18),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = 12,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextWrapped            = true,
					Parent                 = Card,
				})
			end

			local Switch = new("Frame", {
				Size                   = UDim2.fromOffset(44, 24),
				Position               = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(1, 0.5),
				BackgroundColor3       = THEME.ToggleOff,
				BorderSizePixel        = 0,
				Parent                 = Card,
			})
			corner(12, Switch)

			local Knob = new("Frame", {
				Size                   = UDim2.fromOffset(18, 18),
				Position               = UDim2.fromOffset(3, 3),
				BackgroundColor3       = Color3.fromRGB(255, 255, 255),
				BorderSizePixel        = 0,
				Parent                 = Switch,
			})
			corner(9, Knob)

			local Btn = new("TextButton", {
				Size                   = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text                   = "",
				AutoButtonColor        = false,
				Parent                 = Card,
			})

			local function render(animated: boolean?)
				local t = animated == false and 0 or 0.15
				if state then
					tween(Switch, t, { BackgroundColor3 = THEME.ToggleOn })
					tween(Knob,   t, { Position = UDim2.fromOffset(23, 3), BackgroundColor3 = Color3.fromRGB(30, 30, 30) })
				else
					tween(Switch, t, { BackgroundColor3 = THEME.ToggleOff })
					tween(Knob,   t, { Position = UDim2.fromOffset(3, 3),  BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
				end
			end

			Btn.MouseButton1Click:Connect(function()
				state = not state
				render(true)
				task.spawn(cb, state)
			end)
			render(false)

			return {
				Set = function(_, v: boolean) state = v and true or false; render(true); task.spawn(cb, state) end,
				Get = function() return state end,
			}
		end

		-- ---------- SLIDER ----------
		function TabObj:CreateSlider(opts: {
			Name: string, Description: string?, Min: number, Max: number,
			Default: number?, Increment: number?, Callback: ((number) -> ())?
		})
			local minV  = opts.Min or 0
			local maxV  = opts.Max or 100
			local inc   = opts.Increment or 1
			local value = math.clamp(opts.Default or minV, minV, maxV)
			local cb    = opts.Callback or function() end

			local hasDesc = opts.Description and opts.Description ~= ""
			local cardH   = hasDesc and 82 or 62

			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, cardH),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			padding(Card, 12, 12, 18, 16)

			local trackWidth = IsMobile and 110 or 140
			local Track = new("Frame", {
				Size                   = UDim2.fromOffset(trackWidth, 4),
				Position               = UDim2.new(1, 0, 0, 12),
				AnchorPoint            = Vector2.new(1, 0),
				BackgroundColor3       = THEME.ToggleOff,
				BorderSizePixel        = 0,
				Parent                 = Card,
			})
			corner(2, Track)

			local Fill = new("Frame", {
				Size                   = UDim2.new(0, 0, 1, 0),
				BackgroundColor3       = THEME.Accent,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(2, Fill)

			local Knob = new("Frame", {
				Size                   = UDim2.fromOffset(14, 14),
				Position               = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(0.5, 0.5),
				BackgroundColor3       = THEME.Accent,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(7, Knob)

			local ValueLabel = new("TextLabel", {
				Size                   = UDim2.fromOffset(46, 20),
				Position               = UDim2.new(1, -trackWidth - 10, 0, 4),
				AnchorPoint            = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text                   = tostring(value),
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamMedium,
				TextSize               = 14,
				TextXAlignment         = Enum.TextXAlignment.Right,
				Parent                 = Card,
			})

			new("TextLabel", {
				Size                   = UDim2.new(1, -trackWidth - 60, 0, 20),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})

			if hasDesc then
				new("TextLabel", {
					Position               = UDim2.new(0, 0, 0, 24),
					Size                   = UDim2.new(1, -trackWidth - 60, 0, 28),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = 12,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextYAlignment         = Enum.TextYAlignment.Top,
					TextWrapped            = true,
					Parent                 = Card,
				})
			end

			local function setValue(v: number, fire: boolean?)
				v = math.clamp(v, minV, maxV)
				v = math.floor((v / inc) + 0.5) * inc
				value = v
				local alpha = (maxV == minV) and 0 or (v - minV) / (maxV - minV)
				Fill.Size     = UDim2.new(alpha, 0, 1, 0)
				Knob.Position = UDim2.new(alpha, 0, 0.5, 0)
				ValueLabel.Text = tostring(v)
				if fire ~= false then task.spawn(cb, v) end
			end
			setValue(value, false)

			local dragging = false
			local function updateFromInput(input: InputObject)
				local pos  = input.Position.X
				local abs  = Track.AbsolutePosition.X
				local size = Track.AbsoluteSize.X
				local alpha = math.clamp((pos - abs) / size, 0, 1)
				setValue(minV + (maxV - minV) * alpha, true)
			end

			Track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					updateFromInput(input)
				end
			end)
			Knob.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				) then updateFromInput(input) end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			return {
				Set = function(_, v: number) setValue(v, true) end,
				Get = function() return value end,
			}
		end

		-- ---------- BUTTON ----------
		function TabObj:CreateButton(opts: { Name: string, Description: string?, Callback: (() -> ())? })
			local cb = opts.Callback or function() end
			local Card = new("TextButton", {
				Size                   = UDim2.new(1, 0, 0, 50),
				BackgroundColor3       = THEME.Card,
				AutoButtonColor        = false,
				BorderSizePixel        = 0,
				Text                   = "",
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)

			new("TextLabel", {
				Size                   = UDim2.new(1, -32, 0, 20),
				Position               = UDim2.new(0, 18, 0, 8),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})
			if opts.Description then
				new("TextLabel", {
					Size                   = UDim2.new(1, -32, 0, 16),
					Position               = UDim2.new(0, 18, 0, 26),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = 12,
					TextXAlignment         = Enum.TextXAlignment.Left,
					Parent                 = Card,
				})
			end

			Card.MouseEnter:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
			Card.MouseLeave:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.Card }) end)
			Card.MouseButton1Click:Connect(function() task.spawn(cb) end)

			return { Fire = function() task.spawn(cb) end }
		end

		return TabObj
	end

	return WindowObj
end

-- Expose globally so both usage patterns work
pcall(function()
	if typeof(getgenv) == "function" then
		getgenv().AsusLib = AsusLib
	end
end)
pcall(function()
	_G.AsusLib = AsusLib
	shared.AsusLib = AsusLib
end)

return AsusLib
