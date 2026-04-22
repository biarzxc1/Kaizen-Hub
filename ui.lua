--!strict
--[[
	Kaizen Hub - Roblox UI Library (inspired by Asus Hub + shadcn/ui)
	- Fully responsive: scales cleanly on mobile + PC, re-lays-out on rotation / resize
	- Shadcn-accurate Switch (track 44x24 / thumb 20x20 with proper padding)
	- Pixel-perfect Slider (tracks the exact InputObject for no drift on mobile)
	- Solid dark theme matching the reference design
	- Real frame-drawn icons (no asset IDs, always render)
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
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local IsMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================================================
-- THEME (shadcn/ui dark)
-- ==========================================================================
local THEME = {
	Window              = Color3.fromRGB(14, 14, 16),
	WindowTransparency  = 0.08,
	Sidebar             = Color3.fromRGB(16, 16, 18),
	Card                = Color3.fromRGB(32, 32, 36),
	CardTransparency    = 0.15,
	CardHover           = Color3.fromRGB(44, 44, 50),
	Accent              = Color3.fromRGB(255, 255, 255),
	Text                = Color3.fromRGB(245, 245, 247),
	SubText             = Color3.fromRGB(161, 161, 170),
	TabInactive         = Color3.fromRGB(161, 161, 170),
	-- shadcn switch
	SwitchOff           = Color3.fromRGB(39, 39, 42),   -- input
	SwitchOn            = Color3.fromRGB(250, 250, 250),-- primary
	ThumbLight          = Color3.fromRGB(255, 255, 255),
	ThumbDark           = Color3.fromRGB(10, 10, 10),
	-- shadcn slider
	TrackOff            = Color3.fromRGB(39, 39, 42),   -- secondary (empty track)
	TrackOn             = Color3.fromRGB(250, 250, 250),-- primary (filled track)
	Border              = Color3.fromRGB(63, 63, 70),
	BorderSoft          = Color3.fromRGB(255, 255, 255),
	Toast               = Color3.fromRGB(24, 24, 27),
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

-- Tween helper that tracks and cancels the previous tween on the same instance+prop-set
-- so rapid toggles/slider drags never fight each other.
local _activeTweens: {[Instance]: Tween} = {}
local function tween(inst: Instance, time: number, props: {[string]: any}, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local prev = _activeTweens[inst]
	if prev then
		pcall(function() prev:Cancel() end)
	end
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	_activeTweens[inst] = t
	t.Completed:Connect(function()
		if _activeTweens[inst] == t then _activeTweens[inst] = nil end
	end)
	t:Play()
	return t
end

-- Apply a glassmorphism effect (translucent bg + soft highlight gradient)
local function glass(parent: GuiObject, intensity: number?)
	intensity = intensity or 1
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
	local overlay = Instance.new("Frame")
	overlay.Name = "GlassHighlight"
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BackgroundTransparency = 0.92
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.ZIndex = (parent.ZIndex or 1)
	overlay.Parent = parent
	g.Parent = overlay
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

-- Draggable (mouse + touch) — tracks the actual input object to be accurate on mobile
local function makeDraggable(frame: GuiObject, handle: GuiObject)
	local dragInput: InputObject? = nil
	local dragStart: Vector3? = nil
	local startPos: UDim2? = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			dragStart = input.Position
			startPos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragInput = nil
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragStart and startPos then
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
AsusLib._screens = {}

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

	-- ============================================================
	-- RESPONSIVE SIZING — scales to viewport (portrait/landscape/PC)
	-- ============================================================
	local camera = workspace.CurrentCamera
	local function computeSize()
		local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
		local vw, vh = viewport.X, viewport.Y
		local w, h
		if IsMobile then
			-- Mobile
			if vw < 600 then
				-- small portrait phone
				w = math.clamp(vw * 0.92, 320, 560)
				h = math.clamp(vh * 0.80, 260, 440)
			elseif vw < 1100 then
				-- landscape phone / small tablet
				w = math.clamp(vw * 0.62, 460, 720)
				h = math.clamp(vh * 0.72, 300, 460)
			else
				-- tablet landscape
				w = math.clamp(vw * 0.56, 560, 820)
				h = math.clamp(vh * 0.68, 320, 500)
			end
		else
			-- Desktop: proportional with generous cap for big monitors
			w = math.clamp(vw * 0.48, 580, 840)
			h = math.clamp(vh * 0.62, 400, 560)
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
	stroke(THEME.BorderSoft, 1, Window, 0.85)
	glass(Window, 0.6)

	-- ---------- TITLE BAR ----------
	local titleBarHeight = IsMobile and 42 or 46
	local TitleBar = new("Frame", {
		Name                   = "TitleBar",
		Size                   = UDim2.new(1, 0, 0, titleBarHeight),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})
	padding(TitleBar, 0, 0, IsMobile and 14 or 18, 10)

	local TitleLabel = new("TextLabel", {
		Size                   = UDim2.new(1, -90, 1, 0),
		BackgroundTransparency = 1,
		Text                   = title or "Kaizen Hub",
		TextColor3             = THEME.Text,
		Font                   = Enum.Font.GothamBold,
		TextSize               = IsMobile and 14 or 16,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextYAlignment         = Enum.TextYAlignment.Center,
		TextTruncate           = Enum.TextTruncate.AtEnd,
		Parent                 = TitleBar,
	})

	local btnSize = IsMobile and 34 or 30
	local MinBtn = new("TextButton", {
		Size                   = UDim2.fromOffset(btnSize, btnSize),
		Position               = UDim2.new(1, -(btnSize + 24), 0.5, 0),
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
		Size                   = UDim2.fromOffset(btnSize, btnSize),
		Position               = UDim2.new(1, -btnSize + 4, 0.5, 0),
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
		Size                   = UDim2.new(1, 0, 1, -titleBarHeight),
		Position               = UDim2.new(0, 0, 0, titleBarHeight),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})

	-- Sidebar width scales proportionally with the current window width
	-- across mobile / tablet / desktop so the layout stays balanced.
	local function computeSidebarWidth()
		local w = winW
		if IsMobile then
			-- Phones: compact sidebar, ~24% of the window, clamped.
			return math.clamp(math.floor(w * 0.24), 118, 150)
		end
		-- Desktop / tablet: wider, ~26% of window, clamped.
		return math.clamp(math.floor(w * 0.26), 160, 210)
	end

	local sidebarWidth = computeSidebarWidth()
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
	padding(Content, 4, 14, 4, IsMobile and 12 or 18)

	-- Rebuild layout on rotation / resize
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local s = computeSize()
			winW, winH = s.X, s.Y                        -- keep cached size current
			tween(Window, 0.2, { Size = UDim2.fromOffset(s.X, s.Y) })
			local newSidebar = computeSidebarWidth()     -- uses the fresh winW
			tween(Sidebar, 0.2, { Size = UDim2.new(0, newSidebar, 1, 0) })
			tween(Content, 0.2, {
				Size     = UDim2.new(1, -newSidebar, 1, 0),
				Position = UDim2.new(0, newSidebar, 0, 0),
			})
		end)
	end

	-- ---------- FLOATING RESTORE ICON ----------
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

	-- ---------- VISIBILITY ----------
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

	MinBtn.MouseButton1Click:Connect(function() setHidden(true, true) end)
	RestoreIcon.MouseButton1Click:Connect(function() setHidden(false) end)
	CloseBtn.MouseButton1Click:Connect(function()
		tween(Window, 0.18, { Size = UDim2.new(0, 0, 0, 0) })
		task.wait(0.2)
		ScreenGui:Destroy()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.K then
			if ScreenGui.Parent then setHidden(not hidden) end
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
			Size                   = UDim2.new(1, 0, 0, IsMobile and 38 or 40),
			BackgroundTransparency = 1,
			Parent                 = TabList,
		})

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
			TextSize               = IsMobile and 13 or 15,
			TextXAlignment         = Enum.TextXAlignment.Left,
			TextTruncate           = Enum.TextTruncate.AtEnd,
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
			Size                   = UDim2.new(1, 0, 0, IsMobile and 28 or 32),
			BackgroundTransparency = 1,
			Text                   = name,
			TextColor3             = THEME.Text,
			Font                   = Enum.Font.GothamBold,
			TextSize               = IsMobile and 18 or 22,
			TextXAlignment         = Enum.TextXAlignment.Left,
			LayoutOrder            = 0,
			Parent                 = Page,
		})

		new("UIListLayout", {
			Padding   = UDim.new(0, IsMobile and 6 or 8),
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
				Size                   = UDim2.new(1, 0, 0, IsMobile and 38 or 42),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			local tl = new("TextLabel", {
				Size                   = UDim2.new(1, -28, 1, 0),
				Position               = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				Text                   = text,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = IsMobile and 13 or 14,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})
			return { SetText = function(_, s: string) tl.Text = s end }
		end

		-- ==============================================================
		-- TOGGLE (shadcn/ui Switch — Radix primitive)
		-- Reference: https://ui.shadcn.com/docs/components/radix/switch
		-- Track: w-11 (44px) h-6 (24px)
		-- Thumb: h-5 w-5 (20px) with 2px padding on all sides
		-- OFF: bg-input (dark zinc), thumb white
		-- ON : bg-primary (white), thumb dark
		-- Smooth transition-transform animation
		-- ==============================================================
		function TabObj:CreateToggle(opts: {
			Name: string, Description: string?, Default: boolean?, Callback: ((boolean) -> ())?
		})
			local state = opts.Default == true
			local cb    = opts.Callback or function() end
			local hasDesc = opts.Description and opts.Description ~= ""

			-- shadcn Switch: w-11 h-6 (44x24) on desktop.
			-- On mobile we only bump vertical size by 1px for easier tapping.
			-- These are the EXACT compact proportions shown in the Asus Hub reference.
			local swW, swH, thumbPad
			if IsMobile then
				swW, swH, thumbPad = 40, 22, 2
			else
				swW, swH, thumbPad = 36, 20, 2
			end
			local thumb = swH - (thumbPad * 2)

			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundColor3       = THEME.Card,
				BackgroundTransparency = THEME.CardTransparency,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 9 or 11, IsMobile and 9 or 11, IsMobile and 12 or 14, IsMobile and 12 or 14)
			new("UISizeConstraint", {
				MinSize = Vector2.new(0, IsMobile and 40 or 44),
				Parent  = Card,
			})
			glass(Card, 0.4)

			-- Horizontal row layout: text grows, switch stays pinned right
			local reserveRight = swW + 10
			local TextCol = new("Frame", {
				Size                   = UDim2.new(1, -reserveRight, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent                 = Card,
			})
			new("UIListLayout", {
				Padding        = UDim.new(0, 3),
				SortOrder      = Enum.SortOrder.LayoutOrder,
				FillDirection  = Enum.FillDirection.Vertical,
				Parent         = TextCol,
			})

			new("TextLabel", {
				Size                   = UDim2.new(1, 0, 0, IsMobile and 16 or 18),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = IsMobile and 12 or 14,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextTruncate           = Enum.TextTruncate.AtEnd,
				LayoutOrder            = 1,
				Parent                 = TextCol,
			})
			if hasDesc then
				new("TextLabel", {
					Name                   = "Description",
					Size                   = UDim2.new(1, 0, 0, 0),
					AutomaticSize          = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = IsMobile and 10 or 11,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextYAlignment         = Enum.TextYAlignment.Top,
					TextWrapped            = true,
					LayoutOrder            = 2,
					Parent                 = TextCol,
				})
			end

			-- Switch track (pill)
			local Switch = new("Frame", {
				Name                   = "Switch",
				Size                   = UDim2.fromOffset(swW, swH),
				Position               = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(1, 0.5),
				BackgroundColor3       = THEME.SwitchOff,
				BorderSizePixel        = 0,
				Parent                 = Card,
			})
			corner(math.floor(swH / 2), Switch)
			local SwitchStroke = stroke(THEME.Border, 1, Switch, 0.4)

			-- Thumb
			local Knob = new("Frame", {
				Name                   = "Thumb",
				Size                   = UDim2.fromOffset(thumb, thumb),
				Position               = UDim2.fromOffset(thumbPad, thumbPad),
				BackgroundColor3       = THEME.ThumbLight,
				BorderSizePixel        = 0,
				Parent                 = Switch,
			})
			corner(math.floor(thumb / 2), Knob)
			-- Very subtle ring on the thumb (shadcn uses shadow-lg + ring)
			stroke(Color3.fromRGB(0, 0, 0), 1, Knob, 0.88)

			local Btn = new("TextButton", {
				Size                   = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text                   = "",
				AutoButtonColor        = false,
				Parent                 = Card,
			})

			local knobOn  = UDim2.fromOffset(swW - thumb - thumbPad, thumbPad)
			local knobOff = UDim2.fromOffset(thumbPad, thumbPad)

			local function render(animated: boolean?)
				local t = (animated == false) and 0 or 0.18
				if state then
					tween(Switch,       t, { BackgroundColor3 = THEME.SwitchOn })
					tween(SwitchStroke, t, { Transparency = 1 })
					tween(Knob,         t, { Position = knobOn,  BackgroundColor3 = THEME.ThumbDark })
				else
					tween(Switch,       t, { BackgroundColor3 = THEME.SwitchOff })
					tween(SwitchStroke, t, { Transparency = 0.4 })
					tween(Knob,         t, { Position = knobOff, BackgroundColor3 = THEME.ThumbLight })
				end
			end

			Btn.MouseButton1Click:Connect(function()
				state = not state
				render(true)
				task.spawn(cb, state)
			end)
			-- Hover on desktop only
			if not IsMobile then
				Card.MouseEnter:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
				Card.MouseLeave:Connect(function() tween(Card, 0.15, { BackgroundColor3 = THEME.Card }) end)
			end
			render(false)

			return {
				Set = function(_, v: boolean) state = v and true or false; render(true); task.spawn(cb, state) end,
				Get = function() return state end,
			}
		end

		-- ==============================================================
		-- SLIDER (shadcn/ui Slider — Radix primitive)
		-- Reference: https://ui.shadcn.com/docs/components/radix/slider
		-- Track: thin bar (h-1.5 = 6px in shadcn, we use 4px for roblox)
		-- Range (filled portion): primary white
		-- Thumb: h-5 w-5 (20px) circle, white, ring border
		-- Drag: tracks the SPECIFIC InputObject for pixel-accurate mobile dragging
		-- ==============================================================
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
			corner(10, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 10 or 12, IsMobile and 10 or 12, IsMobile and 13 or 14, IsMobile and 13 or 14)
			new("UISizeConstraint", {
				MinSize = Vector2.new(0, IsMobile and 50 or 54),
				Parent  = Card,
			})
			glass(Card, 0.4)

			-- Layout: text column (left, auto-grows) | value label + track (right, fixed fraction)
			-- The right section takes ~46% of card width on mobile, 42% on PC.
			local rightFrac = IsMobile and 0.46 or 0.42
			local trackThickness = 3
			local knobPx = IsMobile and 14 or 12

			-- Right container holds value number + track, vertically centered in the card
			local RightCol = new("Frame", {
				Name                   = "SliderRight",
				Size                   = UDim2.new(rightFrac, -8, 1, 0),
				Position               = UDim2.new(1, 0, 0, 0),
				AnchorPoint            = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Parent                 = Card,
			})

			-- Value label on the left of the right section
			local valueLabelW = IsMobile and 30 or 32
			local ValueLabel = new("TextLabel", {
				Size                   = UDim2.fromOffset(valueLabelW, 18),
				Position               = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text                   = tostring(value),
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamMedium,
				TextSize               = IsMobile and 12 or 13,
				TextXAlignment         = Enum.TextXAlignment.Right,
				Parent                 = RightCol,
			})

			-- Track fills the rest of the right column, to the right of the value label
			-- Uses Scale width so it responds to every viewport / window-resize automatically.
			local trackLeftPad = valueLabelW + 8
			local Track = new("Frame", {
				Name                   = "Track",
				Size                   = UDim2.new(1, -trackLeftPad, 0, trackThickness),
				Position               = UDim2.new(0, trackLeftPad, 0.5, 0),
				AnchorPoint            = Vector2.new(0, 0.5),
				BackgroundColor3       = THEME.TrackOff,
				BorderSizePixel        = 0,
				Parent                 = RightCol,
			})
			corner(trackThickness, Track)
			-- Minimum size so the track never collapses on very narrow cards
			new("UISizeConstraint", {
				MinSize = Vector2.new(80, trackThickness),
				Parent  = Track,
			})

			local Fill = new("Frame", {
				Name                   = "Range",
				Size                   = UDim2.new(0, 0, 1, 0),
				BackgroundColor3       = THEME.TrackOn,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(trackThickness, Fill)

			local Knob = new("Frame", {
				Name                   = "Thumb",
				Size                   = UDim2.fromOffset(knobPx, knobPx),
				Position               = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(0.5, 0.5),
				BackgroundColor3       = THEME.Accent,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(math.floor(knobPx / 2), Knob)
			stroke(Color3.fromRGB(0, 0, 0), 1, Knob, 0.85)

			-- Invisible hit-pad over the thumb for easier dragging on mobile.
			-- Larger on mobile so shrinking the visible knob doesn't hurt tap accuracy.
			local hitExpand = IsMobile and 22 or 14
			local KnobHit = new("TextButton", {
				Size                   = UDim2.fromOffset(knobPx + hitExpand, knobPx + hitExpand),
				Position               = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text                   = "",
				AutoButtonColor        = false,
				Parent                 = Knob,
			})

			-- Text column: title + optional description. Reserves space so it never overlaps track.
			local TextCol = new("Frame", {
				Size                   = UDim2.new(1 - rightFrac, -4, 0, 0),
				AutomaticSize          = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent                 = Card,
			})
			new("UIListLayout", {
				Padding       = UDim.new(0, 3),
				SortOrder     = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Parent        = TextCol,
			})

			new("TextLabel", {
				Size                   = UDim2.new(1, 0, 0, IsMobile and 16 or 18),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = IsMobile and 12 or 14,
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
					TextSize               = IsMobile and 10 or 11,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextYAlignment         = Enum.TextYAlignment.Top,
					TextWrapped            = true,
					LayoutOrder            = 2,
					Parent                 = TextCol,
				})
			end

			-- =========== VALUE MATH & UPDATE ===========
			local function setValue(v: number, fire: boolean?, animated: boolean?)
				v = math.clamp(v, minV, maxV)
				if inc and inc > 0 then
					v = math.floor(((v - minV) / inc) + 0.5) * inc + minV
					v = math.clamp(v, minV, maxV)
				end
				value = v
				local alpha = (maxV == minV) and 0 or (v - minV) / (maxV - minV)
				if animated then
					tween(Fill, 0.08, { Size = UDim2.new(alpha, 0, 1, 0) }, Enum.EasingStyle.Linear)
					tween(Knob, 0.08, { Position = UDim2.new(alpha, 0, 0.5, 0) }, Enum.EasingStyle.Linear)
				else
					Fill.Size     = UDim2.new(alpha, 0, 1, 0)
					Knob.Position = UDim2.new(alpha, 0, 0.5, 0)
				end
				-- Show integer if increment is whole, else format with 2 decimals
				if inc >= 1 and math.floor(inc) == inc then
					ValueLabel.Text = tostring(math.floor(v))
				else
					ValueLabel.Text = string.format("%.2f", v)
				end
				if fire ~= false then task.spawn(cb, v) end
			end
			setValue(value, false, false)

			-- =========== ACCURATE DRAG LOGIC ===========
			-- Tracks the exact InputObject that started the drag. This is the key to
			-- pixel-accurate mobile sliding (UIS.InputChanged fires for ALL active
			-- touches; without filtering by the original InputObject the slider
			-- would jump when a second finger touched the screen).
			local activeInput: InputObject? = nil

			local function updateFromPos(screenX: number)
				local absX  = Track.AbsolutePosition.X
				local absW  = Track.AbsoluteSize.X
				if absW <= 0 then return end
				local alpha = math.clamp((screenX - absX) / absW, 0, 1)
				setValue(minV + (maxV - minV) * alpha, true, false)
			end

			local function beginDrag(input: InputObject)
				activeInput = input
				tween(Knob, 0.12, { Size = UDim2.fromOffset(knobPx + 3, knobPx + 3) })
				updateFromPos(input.Position.X)
			end
			local function endDrag()
				activeInput = nil
				tween(Knob, 0.12, { Size = UDim2.fromOffset(knobPx, knobPx) })
			end

			-- Clicking anywhere on the track jumps the knob + starts a drag
			Track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
					beginDrag(input)
				end
			end)
			-- Grabbing the thumb hit-pad also starts a drag
			KnobHit.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
					activeInput = input
					tween(Knob, 0.12, { Size = UDim2.fromOffset(knobPx + 3, knobPx + 3) })
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if activeInput and input == activeInput then
					updateFromPos(input.Position.X)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if activeInput and input == activeInput then
					endDrag()
				end
			end)

			return {
				Set = function(_, v: number) setValue(v, true, true) end,
				Get = function() return value end,
			}
		end

		-- ---------- BUTTON ----------
		function TabObj:CreateButton(opts: { Name: string, Description: string?, Callback: (() -> ())? })
			local cb = opts.Callback or function() end
			local hasBtnDesc = opts.Description and opts.Description ~= ""
			-- Compact row height matching shadcn Button: taller only if a description is shown.
			local btnH
			if hasBtnDesc then
				btnH = IsMobile and 42 or 46
			else
				btnH = IsMobile and 34 or 36
			end
			local Card = new("TextButton", {
				Size                   = UDim2.new(1, 0, 0, btnH),
				BackgroundColor3       = THEME.Card,
				AutoButtonColor        = false,
				BorderSizePixel        = 0,
				Text                   = "",
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)

			new("TextLabel", {
				Size                   = UDim2.new(1, -28, 0, hasBtnDesc and 18 or btnH),
				Position               = UDim2.new(0, 14, 0, hasBtnDesc and 6 or 0),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = IsMobile and 13 or 14,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextYAlignment         = hasBtnDesc and Enum.TextYAlignment.Center or Enum.TextYAlignment.Center,
				Parent                 = Card,
			})
			if hasBtnDesc then
				new("TextLabel", {
					Size                   = UDim2.new(1, -28, 0, 14),
					Position               = UDim2.new(0, 14, 0, 24),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = IsMobile and 11 or 12,
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
