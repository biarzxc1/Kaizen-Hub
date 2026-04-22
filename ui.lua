--!strict
--[[
	Kaizen Hub - Roblox UI Library (inspired by Asus Hub)
	- Fully responsive: scales cleanly on mobile + PC, re-lays-out on rotation
	- Solid dark theme matching the reference design
	- Real frame-drawn icons (no asset IDs, always render)
	- White-gradient toggles, smooth tween animations
	- Scrollable sidebar + scrollable tab pages
	- Notification system (top-right toasts)
	- K to toggle visibility on PC, floating circle to restore on mobile
	- Clicking minimize (-) hides the window and shows a toast

	USAGE:
		local Kaizen  = loadstring(game:HttpGet("https://raw.githubusercontent.com/biarzxc1/Kaizen-Hub/refs/heads/main/ui.lua"))()
		local Window  = Kaizen:CreateWindow("Kaizen Hub | Game | Delta")
		local Visuals = Window:CreateTab("Visuals", "eye")
		Visuals:CreateLabel("Esp all Crates in map")
		Visuals:CreateToggle({ Name="Esp Crates", Default=false, Callback=function(v) end })
		Visuals:CreateSlider({ Name="Range (studs)", Min=0, Max=100, Default=30, Callback=function(v) end })
		Kaizen:Notify({ Title = "Loaded", Text = "Welcome to Kaizen Hub" })

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
	-- Glassmorphism dark theme (inspired by Asus Hub + shadcn/ui)
	Window            = Color3.fromRGB(14, 14, 16),   -- deep base
	WindowTransparency = 0.08,                         -- slight see-through for glass feel
	Sidebar           = Color3.fromRGB(16, 16, 18),
	SidebarTransparency = 0.05,
	Card              = Color3.fromRGB(32, 32, 36),
	CardTransparency  = 0.15,                          -- translucent cards
	CardHover         = Color3.fromRGB(44, 44, 50),
	Accent            = Color3.fromRGB(255, 255, 255),
	Text              = Color3.fromRGB(245, 245, 247),
	SubText           = Color3.fromRGB(161, 161, 170), -- shadcn muted-foreground
	TabInactive       = Color3.fromRGB(161, 161, 170),
	-- shadcn switch colors (dark mode)
	SwitchOff         = Color3.fromRGB(39, 39, 42),    -- input
	SwitchOn          = Color3.fromRGB(250, 250, 250), -- primary
	ThumbLight        = Color3.fromRGB(255, 255, 255),
	ThumbDark         = Color3.fromRGB(10, 10, 10),
	-- Legacy aliases (kept for slider track compatibility)
	ToggleOff         = Color3.fromRGB(39, 39, 42),
	ToggleOn          = Color3.fromRGB(250, 250, 250),
	Border            = Color3.fromRGB(63, 63, 70),    -- shadcn border
	BorderSoft        = Color3.fromRGB(255, 255, 255),
	Toast             = Color3.fromRGB(24, 24, 27),
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

-- Apply a glassmorphism effect: translucent bg + soft top-to-bottom highlight gradient
-- + subtle inner border. Roblox GUIs can't blur, so this simulates frosted glass.
local function glass(parent: GuiObject, intensity: number?)
	intensity = intensity or 1
	-- Top highlight gradient (lighter at top, darker at bottom) - gives a "lit" look
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    0.55 - 0.15 * intensity),
		NumberSequenceKeypoint.new(0.5,  0.8),
		NumberSequenceKeypoint.new(1,    0.9),
	})
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	-- We parent to a separate overlay frame so it doesn't tint the bg color
	local overlay = Instance.new("Frame")
	overlay.Name = "GlassHighlight"
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BackgroundTransparency = 0.92
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.ZIndex = (parent.ZIndex or 1)
	overlay.Parent = parent
	g.Parent = overlay
	-- Match parent corner radius if present
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UICorner") then
			local c = Instance.new("UICorner")
			c.CornerRadius = child.CornerRadius
			c.Parent = overlay
			break
		end
	end
	return overlay
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

local function tween(inst: Instance, time: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
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

	-- Responsive sizing — scales to viewport, auto-updates on rotation / resize
	local camera = workspace.CurrentCamera
	local function computeSize()
		local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
		local w, h
		if IsMobile then
			-- Smaller on mobile: ~72% of viewport, capped so it never overflows
			w = math.clamp(viewport.X * 0.72, 340, 600)
			h = math.clamp(viewport.Y * 0.68, 260, 380)
		else
			w = math.clamp(viewport.X * 0.50, 560, 720)
			h = math.clamp(viewport.Y * 0.65, 380, 480)
		end
		return Vector2.new(math.floor(w), math.floor(h))
	end
	local winSize = computeSize()
	local winW, winH = winSize.X, winSize.Y

	local Window = new("Frame", {
		Name                   = "Window",
		Size                   = UDim2.fromOffset(winW, winH),
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundColor3       = THEME.Window,
		BackgroundTransparency = THEME.WindowTransparency,
		BorderSizePixel        = 0,
		ClipsDescendants       = true,
		Parent                 = ScreenGui,
	})
	corner(16, Window)
	-- Soft outer glow border (glass edge)
	stroke(THEME.BorderSoft, 1, Window, 0.85)
	glass(Window, 0.6)

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
		Text                   = title or "Kaizen Hub",
		TextColor3             = THEME.Text,
		Font                   = Enum.Font.GothamBold,
		TextSize               = IsMobile and 15 or 16,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextYAlignment         = Enum.TextYAlignment.Center,
		TextTruncate           = Enum.TextTruncate.AtEnd,
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

	-- Keep the window sized to the viewport (handles rotation / resizing)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local s = computeSize()
			tween(Window, 0.2, { Size = UDim2.fromOffset(s.X, s.Y) })
		end)
	end

	-- ---------- BODY ----------
	local Body = new("Frame", {
		Size                   = UDim2.new(1, 0, 1, -46),
		Position               = UDim2.new(0, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})

	-- Sidebar (scrollable — fits any number of tabs)
	local sidebarWidth = IsMobile and 132 or 180
	local Sidebar = new("Frame", {
		Name                   = "Sidebar",
		Size                   = UDim2.new(0, sidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent                 = Body,
	})
	padding(Sidebar, 6, 12, 8, 4)

	local TabList = new("ScrollingFrame", {
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ScrollBarThickness     = 2,
		ScrollBarImageColor3   = Color3.fromRGB(80, 80, 80),
		ScrollBarImageTransparency = 0.4,
		CanvasSize             = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize    = Enum.AutomaticSize.Y,
		ScrollingDirection     = Enum.ScrollingDirection.Y,
		ElasticBehavior        = Enum.ElasticBehavior.WhenScrollable,
		Parent                 = Sidebar,
	})
	new("UIListLayout", {
		Padding   = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent    = TabList,
	})
	new("UIPadding", {
		PaddingTop    = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
		Parent        = TabList,
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
				tween(t.label, 0.15, { TextColor3 = THEME.TabInactive })
				recolorIcon(t.iconBox, t.iconName, THEME.TabInactive)
				tween(t.accent, 0.15, { BackgroundTransparency = 1, Size = UDim2.fromOffset(3, 0) })
			end
			Page.Visible = true
			tween(label, 0.15, { TextColor3 = THEME.Text })
			recolorIcon(iconBox, iconName :: string, THEME.Text)
			tween(accent, 0.2, { BackgroundTransparency = 0, Size = UDim2.fromOffset(3, 22) }, Enum.EasingStyle.Back)
		end

		click.MouseButton1Click:Connect(select)
		-- Hover feedback on PC
		if not IsMobile then
			click.MouseEnter:Connect(function()
				if not Page.Visible then tween(label, 0.12, { TextColor3 = Color3.fromRGB(220, 220, 220) }) end
			end)
			click.MouseLeave:Connect(function()
				if not Page.Visible then tween(label, 0.15, { TextColor3 = THEME.TabInactive }) end
			end)
		end

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

			-- Card auto-grows with description; switch is vertically centered via anchor
			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundColor3       = THEME.Card,
				BackgroundTransparency = THEME.CardTransparency,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 12 or 14, IsMobile and 12 or 14, IsMobile and 14 or 18, IsMobile and 14 or 18)
			new("UISizeConstraint", {
				MinSize = Vector2.new(0, IsMobile and 48 or 54),
				Parent  = Card,
			})
			glass(Card, 0.4)

			-- Reserve space on the right for the switch; text column fills the rest
			local reserveRight = IsMobile and 58 or 64
			local TextCol = new("Frame", {
				Size                   = UDim2.new(1, -reserveRight, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent                 = Card,
			})
			new("UIListLayout", {
				Padding        = UDim.new(0, 4),
				SortOrder      = Enum.SortOrder.LayoutOrder,
				FillDirection  = Enum.FillDirection.Vertical,
				Parent         = TextCol,
			})

			new("TextLabel", {
				Size                   = UDim2.new(1, 0, 0, IsMobile and 18 or 20),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = IsMobile and 14 or 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextTruncate           = Enum.TextTruncate.AtEnd,
				LayoutOrder            = 1,
				Parent                 = TextCol,
			})
			if hasDesc then
				local Desc = new("TextLabel", {
					Size                   = UDim2.new(1, 0, 0, 0),
					AutomaticSize          = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = IsMobile and 11 or 12,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextYAlignment         = Enum.TextYAlignment.Top,
					TextWrapped            = true,
					LayoutOrder            = 2,
					Parent                 = TextCol,
				})
				Desc.Name = "Description"
			end

			-- ======================================================
			-- SHADCN/UI Switch (flat, minimal, pill track + circle thumb)
			-- Track: w-11 h-6 (44x24)  |  Thumb: h-5 w-5 (20x20)
			-- OFF: dark muted track, white thumb
			-- ON : white track, dark thumb
			-- ======================================================
			local swW   = IsMobile and 46 or 44
			local swH   = IsMobile and 26 or 24
			local thumb = swH - 4   -- shadcn thumb = track height - 4px padding

			local Switch = new("Frame", {
				Size                   = UDim2.fromOffset(swW, swH),
				Position               = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(1, 0.5),
				BackgroundColor3       = THEME.SwitchOff,
				BackgroundTransparency = 0,
				BorderSizePixel        = 0,
				Parent                 = Card,
			})
			corner(math.floor(swH / 2), Switch)
			-- Shadcn has a subtle ring border on the switch
			local SwitchStroke = stroke(THEME.Border, 1, Switch, 0.4)

			local Knob = new("Frame", {
				Size                   = UDim2.fromOffset(thumb, thumb),
				Position               = UDim2.fromOffset(2, 2),
				BackgroundColor3       = THEME.ThumbLight,
				BorderSizePixel        = 0,
				Parent                 = Switch,
			})
			corner(math.floor(thumb / 2), Knob)
			-- Soft drop shadow (shadcn-like) via a second frame beneath the knob
			local KnobShadow = new("Frame", {
				Size                   = UDim2.new(1, 2, 1, 2),
				Position               = UDim2.fromOffset(-1, 0),
				BackgroundColor3       = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.75,
				BorderSizePixel        = 0,
				ZIndex                 = Knob.ZIndex - 1,
				Parent                 = Switch,
			})
			corner(math.floor(thumb / 2), KnobShadow)

			local Btn = new("TextButton", {
				Size                   = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text                   = "",
				AutoButtonColor        = false,
				Parent                 = Card,
			})

			local knobOn    = UDim2.fromOffset(swW - thumb - 2, 2)
			local knobOff   = UDim2.fromOffset(2, 2)
			local shadowOn  = UDim2.fromOffset(swW - thumb - 3, 0)
			local shadowOff = UDim2.fromOffset(-1, 0)

			local function render(animated: boolean?)
				local t = animated == false and 0 or 0.2
				if state then
					tween(Switch,     t, { BackgroundColor3 = THEME.SwitchOn })
					tween(SwitchStroke, t, { Transparency = 1 })
					tween(Knob,       t, { Position = knobOn,   BackgroundColor3 = THEME.ThumbDark })
					tween(KnobShadow, t, { Position = shadowOn, BackgroundTransparency = 0.65 })
				else
					tween(Switch,     t, { BackgroundColor3 = THEME.SwitchOff })
					tween(SwitchStroke, t, { Transparency = 0.4 })
					tween(Knob,       t, { Position = knobOff,   BackgroundColor3 = THEME.ThumbLight })
					tween(KnobShadow, t, { Position = shadowOff, BackgroundTransparency = 0.75 })
				end
			end

			Btn.MouseButton1Click:Connect(function()
				state = not state
				-- Shadcn doesn't squash, it uses a clean linear/ease-out slide.
				render(true)
				task.spawn(cb, state)
			end)
			-- Subtle card hover on desktop
			Card.MouseEnter:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
			Card.MouseLeave:Connect(function() tween(Card, 0.15, { BackgroundColor3 = THEME.Card }) end)
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

			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundColor3       = THEME.Card,
				BackgroundTransparency = THEME.CardTransparency,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 12 or 14, IsMobile and 12 or 14, IsMobile and 14 or 18, IsMobile and 14 or 18)
			new("UISizeConstraint", {
				MinSize = Vector2.new(0, IsMobile and 56 or 62),
				Parent  = Card,
			})
			glass(Card, 0.4)

			-- Track is a fraction of card width; much more responsive than fixed px
			local trackFrac = IsMobile and 0.40 or 0.38
			local trackMinPx = 100
			local Track = new("Frame", {
				Size                   = UDim2.new(trackFrac, 0, 0, 4),
				Position               = UDim2.new(1, 0, 0, IsMobile and 12 or 14),
				AnchorPoint            = Vector2.new(1, 0),
				BackgroundColor3       = THEME.ToggleOff,
				BorderSizePixel        = 0,
				Parent                 = Card,
			})
			new("UISizeConstraint", {
				MinSize = Vector2.new(trackMinPx, 4),
				MaxSize = Vector2.new(180, 4),
				Parent  = Track,
			})
			corner(2, Track)

			local Fill = new("Frame", {
				Size                   = UDim2.new(0, 0, 1, 0),
				BackgroundColor3       = THEME.Accent,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(2, Fill)

			local knobPx = IsMobile and 18 or 14
			local Knob = new("Frame", {
				Size                   = UDim2.fromOffset(knobPx, knobPx),
				Position               = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(0.5, 0.5),
				BackgroundColor3       = THEME.Accent,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(math.floor(knobPx / 2), Knob)
			stroke(Color3.fromRGB(0, 0, 0), 1, Knob, 0.85)

			-- Value label sits just to the LEFT of the track (screenshot: "30" before bar)
			local ValueLabel = new("TextLabel", {
				Size                   = UDim2.fromOffset(44, 20),
				AnchorPoint            = Vector2.new(1, 0.5),
				Position               = UDim2.new(1 - trackFrac, -6, 0, (IsMobile and 12 or 14) + 2),
				BackgroundTransparency = 1,
				Text                   = tostring(value),
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamMedium,
				TextSize               = IsMobile and 13 or 14,
				TextXAlignment         = Enum.TextXAlignment.Right,
				Parent                 = Card,
			})

			-- Text column: title + optional description, reserves space for track+value on the right
			local TextCol = new("Frame", {
				Size                   = UDim2.new(1 - trackFrac, -12, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent                 = Card,
			})
			new("UIListLayout", {
				Padding       = UDim.new(0, 4),
				SortOrder     = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Parent        = TextCol,
			})

			new("TextLabel", {
				Size                   = UDim2.new(1, 0, 0, IsMobile and 18 or 20),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = IsMobile and 14 or 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextTruncate           = Enum.TextTruncate.AtEnd,
				LayoutOrder            = 1,
				Parent                 = TextCol,
			})

			if hasDesc then
				new("TextLabel", {
					Size                   = UDim2.new(1, 0, 0, 0),
					AutomaticSize          = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = IsMobile and 11 or 12,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextYAlignment         = Enum.TextYAlignment.Top,
					TextWrapped            = true,
					LayoutOrder            = 2,
					Parent                 = TextCol,
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
