--!strict
--[[
 Kaizen Hub - Roblox UI Library (inspired by Asus Hub + shadcn/ui)
 Updated with MORE ICONS!
 
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
 local Kaizen = loadstring(game:HttpGet("https://raw.githubusercontent.com/biarzxc1/Kaizen-Hub/refs/heads/main/ui.lua"))()
 local Window = Kaizen:CreateWindow("Kaizen Hub | Game | Delta")
 local Visuals = Window:CreateTab("Visuals", "eye")
 Visuals:CreateLabel("Esp all Crates in map")
 Visuals:CreateToggle({ Name="Esp Crates", Default=false, Callback=function(v) end })
 Visuals:CreateSlider({ Name="Range (studs)", Min=0, Max=100, Default=30, Callback=function(v) end })
 Kaizen:Notify({ Title = "Loaded", Text = "Welcome to Kaizen Hub" })

 Icons: eye, swords, users, basket, settings, x, minus, home, bell,
        crosshair, shield, target, zap, package, folder, save, refresh,
        trash, plus, check, heart, star, map, compass, gun, knife, bolt,
        fire, skull, crown, diamond, circle, square, triangle, arrow
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================================================
-- THEME (shadcn/ui dark)
-- ==========================================================================
local THEME = {
	Window = Color3.fromRGB(12, 12, 14),
	WindowTransparency = 0.06,
	Sidebar = Color3.fromRGB(14, 14, 16),
	Card = Color3.fromRGB(22, 22, 24),
	CardTransparency = 0.05,
	CardHover = Color3.fromRGB(30, 30, 34),
	Accent = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(245, 245, 247),
	SubText = Color3.fromRGB(161, 161, 170),
	TabInactive = Color3.fromRGB(161, 161, 170),
	SwitchOff = Color3.fromRGB(44, 44, 48),
	SwitchOn = Color3.fromRGB(250, 250, 250),
	ThumbLight = Color3.fromRGB(255, 255, 255),
	ThumbDark = Color3.fromRGB(10, 10, 10),
	TrackOff = Color3.fromRGB(44, 44, 48),
	TrackOn = Color3.fromRGB(250, 250, 250),
	Border = Color3.fromRGB(63, 63, 70),
	BorderSoft = Color3.fromRGB(255, 255, 255),
	Divider = Color3.fromRGB(255, 255, 255),
	DividerAlpha = 0.82,
	Toast = Color3.fromRGB(24, 24, 27),
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
	p.PaddingTop = UDim.new(0, top)
	p.PaddingBottom = UDim.new(0, bottom)
	p.PaddingLeft = UDim.new(0, left)
	p.PaddingRight = UDim.new(0, right)
	p.Parent = parent
	return p
end

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

local function glass(parent: GuiObject, intensity: number?)
	intensity = intensity or 1
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55 - 0.15 * intensity),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0.9),
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

local function makeDraggable(frame: GuiObject, handle: GuiObject)
	local dragInput: InputObject? = nil
	local dragStart: Vector3? = nil
	local startPos: UDim2? = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			dragStart = input.Position
			startPos = frame.Position
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
-- ICONS (drawn with native Frames) - EXPANDED SET
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
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rot or 0,
		Parent = parent,
	})
	corner(math.min(w, h) / 2, f)
	return f
end

local function ring(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, thickness: number)
	local f = new("Frame", {
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	corner(math.max(w, h), f)
	stroke(color, thickness, f)
	return f
end

local function dot(parent: Instance, color: Color3, x: number, y: number, size: number)
	local f = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	corner(size, f)
	return f
end

local ICON_DRAWERS: {[string]: (Frame, Color3) -> ()} = {}

-- Original icons
ICON_DRAWERS.x = function(c, color)
	line(c, color, 0, 0, 18, 2, 45)
	line(c, color, 0, 0, 18, 2, -45)
end

ICON_DRAWERS.minus = function(c, color)
	line(c, color, 0, 0, 14, 2, 0)
end

ICON_DRAWERS.home = function(c, color)
	line(c, color, -4, -4, 12, 2, 45)
	line(c, color, 4, -4, 12, 2, -45)
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
		Size = UDim2.fromOffset(18, 12),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
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
		Size = UDim2.fromOffset(10, 6),
		Position = UDim2.new(0.5, -3, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(4, b1)
	stroke(color, 1.6, b1)
	local b2 = new("Frame", {
		Size = UDim2.fromOffset(10, 6),
		Position = UDim2.new(0.5, 4, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(4, b2)
	stroke(color, 1.6, b2)
end

ICON_DRAWERS.basket = function(c, color)
	local handle = new("Frame", {
		Size = UDim2.fromOffset(10, 8),
		Position = UDim2.new(0.5, 0, 0.5, -3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(6, handle)
	stroke(color, 1.6, handle)
	line(c, color, 0, 1, 18, 2, 0)
	local body = new("Frame", {
		Size = UDim2.fromOffset(16, 8),
		Position = UDim2.new(0.5, 0, 0.5, 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	line(c, color, -4, 5, 1.4, 6, 0)
	line(c, color, 0, 5, 1.4, 6, 0)
	line(c, color, 4, 5, 1.4, 6, 0)
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
			Size = UDim2.fromOffset(3, 3),
			Position = UDim2.new(0.5, x, 0.5, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = i * 45,
			Parent = c,
		})
		corner(1, tooth)
	end
end

-- NEW ICONS

ICON_DRAWERS.crosshair = function(c, color)
	ring(c, color, 0, 0, 14, 14, 1.6)
	line(c, color, 0, -8, 2, 6, 0)
	line(c, color, 0, 8, 2, 6, 0)
	line(c, color, -8, 0, 6, 2, 0)
	line(c, color, 8, 0, 6, 2, 0)
	dot(c, color, 0, 0, 3)
end

ICON_DRAWERS.target = function(c, color)
	ring(c, color, 0, 0, 16, 16, 1.6)
	ring(c, color, 0, 0, 10, 10, 1.6)
	dot(c, color, 0, 0, 4)
end

ICON_DRAWERS.shield = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(14, 16),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(4, body)
	stroke(color, 1.6, body)
	line(c, color, -3, 0, 3, 2, 45)
	line(c, color, 2, -2, 5, 2, -45)
end

ICON_DRAWERS.zap = function(c, color)
	line(c, color, 0, -4, 2, 8, 0)
	line(c, color, -3, 0, 8, 2, 0)
	line(c, color, 0, 4, 2, 8, 0)
	dot(c, color, 3, -3, 3)
	dot(c, color, -3, 3, 3)
end

ICON_DRAWERS.bolt = function(c, color)
	line(c, color, 0, 0, 3, 16, 15)
	line(c, color, -3, -2, 8, 2, 0)
	line(c, color, 3, 2, 8, 2, 0)
end

ICON_DRAWERS.package = function(c, color)
	local box = new("Frame", {
		Size = UDim2.fromOffset(14, 12),
		Position = UDim2.new(0.5, 0, 0.5, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, box)
	stroke(color, 1.6, box)
	line(c, color, 0, -4, 18, 2, 0)
	line(c, color, 0, 2, 2, 8, 0)
end

ICON_DRAWERS.folder = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(16, 12),
		Position = UDim2.new(0.5, 0, 0.5, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	line(c, color, -4, -5, 6, 2, 0)
end

ICON_DRAWERS.save = function(c, color)
	local box = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, box)
	stroke(color, 1.6, box)
	local inner = new("Frame", {
		Size = UDim2.fromOffset(8, 5),
		Position = UDim2.new(0.5, 0, 0.5, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(1, inner)
	stroke(color, 1.4, inner)
	line(c, color, 0, -3, 6, 2, 0)
end

ICON_DRAWERS.refresh = function(c, color)
	ring(c, color, 0, 0, 14, 14, 1.6)
	line(c, color, 0, -7, 4, 2, 45)
	line(c, color, 4, -5, 4, 2, -45)
end

ICON_DRAWERS.trash = function(c, color)
	line(c, color, 0, -6, 12, 2, 0)
	line(c, color, 0, -8, 6, 2, 0)
	local body = new("Frame", {
		Size = UDim2.fromOffset(10, 12),
		Position = UDim2.new(0.5, 0, 0.5, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	line(c, color, -2, 2, 1.4, 8, 0)
	line(c, color, 2, 2, 1.4, 8, 0)
end

ICON_DRAWERS.plus = function(c, color)
	line(c, color, 0, 0, 14, 2, 0)
	line(c, color, 0, 0, 2, 14, 0)
end

ICON_DRAWERS.check = function(c, color)
	line(c, color, -3, 2, 6, 2, 45)
	line(c, color, 4, -2, 10, 2, -45)
end

ICON_DRAWERS.heart = function(c, color)
	dot(c, color, -4, -2, 6)
	dot(c, color, 4, -2, 6)
	local bottom = new("Frame", {
		Size = UDim2.fromOffset(12, 10),
		Position = UDim2.new(0.5, 0, 0.5, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = 45,
		Parent = c,
	})
	corner(2, bottom)
	stroke(color, 1.6, bottom)
end

ICON_DRAWERS.star = function(c, color)
	dot(c, color, 0, -6, 4)
	dot(c, color, -6, 0, 4)
	dot(c, color, 6, 0, 4)
	dot(c, color, -4, 6, 4)
	dot(c, color, 4, 6, 4)
	line(c, color, 0, 0, 4, 4, 0)
end

ICON_DRAWERS.map = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(16, 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	line(c, color, -3, 0, 2, 14, 15)
	line(c, color, 3, 0, 2, 14, -15)
end

ICON_DRAWERS.compass = function(c, color)
	ring(c, color, 0, 0, 16, 16, 1.6)
	line(c, color, 0, -2, 2, 8, 0)
	line(c, color, 0, 2, 2, 8, 180)
	dot(c, color, 0, 0, 3)
end

ICON_DRAWERS.gun = function(c, color)
	line(c, color, 0, -2, 16, 3, 0)
	line(c, color, -6, 0, 4, 2, 0)
	line(c, color, 3, 3, 4, 6, 0)
	dot(c, color, -6, -2, 3)
end

ICON_DRAWERS.knife = function(c, color)
	line(c, color, 0, 0, 16, 3, 45)
	line(c, color, -5, 5, 6, 2, 45)
	dot(c, color, 5, -5, 3)
end

ICON_DRAWERS.fire = function(c, color)
	dot(c, color, 0, 4, 8)
	dot(c, color, -2, 0, 5)
	dot(c, color, 2, 0, 5)
	dot(c, color, 0, -4, 4)
end

ICON_DRAWERS.skull = function(c, color)
	ring(c, color, 0, -2, 14, 12, 1.6)
	dot(c, color, -3, -2, 4)
	dot(c, color, 3, -2, 4)
	line(c, color, 0, 4, 6, 2, 0)
	line(c, color, -2, 6, 2, 3, 0)
	line(c, color, 2, 6, 2, 3, 0)
end

ICON_DRAWERS.crown = function(c, color)
	line(c, color, 0, 4, 16, 2, 0)
	line(c, color, -6, 0, 2, 8, 15)
	line(c, color, 0, -2, 2, 8, 0)
	line(c, color, 6, 0, 2, 8, -15)
	dot(c, color, -6, -4, 3)
	dot(c, color, 0, -6, 3)
	dot(c, color, 6, -4, 3)
end

ICON_DRAWERS.diamond = function(c, color)
	local d = new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = 45,
		Parent = c,
	})
	corner(2, d)
	stroke(color, 1.6, d)
end

ICON_DRAWERS.circle = function(c, color)
	ring(c, color, 0, 0, 14, 14, 1.6)
end

ICON_DRAWERS.square = function(c, color)
	local s = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, s)
	stroke(color, 1.6, s)
end

ICON_DRAWERS.triangle = function(c, color)
	line(c, color, 0, -4, 12, 2, 0)
	line(c, color, -5, 3, 10, 2, -60)
	line(c, color, 5, 3, 10, 2, 60)
end

ICON_DRAWERS.arrow = function(c, color)
	line(c, color, 0, 0, 2, 14, 0)
	line(c, color, -4, -4, 8, 2, 45)
	line(c, color, 4, -4, 8, 2, -45)
end

ICON_DRAWERS.backpack = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(12, 14),
		Position = UDim2.new(0.5, 0, 0.5, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(3, body)
	stroke(color, 1.6, body)
	local handle = new("Frame", {
		Size = UDim2.fromOffset(6, 4),
		Position = UDim2.new(0.5, 0, 0.5, -7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(3, handle)
	stroke(color, 1.4, handle)
	line(c, color, 0, 4, 8, 2, 0)
end

ICON_DRAWERS.info = function(c, color)
	ring(c, color, 0, 0, 14, 14, 1.6)
	dot(c, color, 0, -3, 3)
	line(c, color, 0, 3, 2, 6, 0)
end

ICON_DRAWERS.warning = function(c, color)
	line(c, color, -5, 5, 12, 2, 0)
	line(c, color, -3, 0, 10, 2, -65)
	line(c, color, 3, 0, 10, 2, 65)
	dot(c, color, 0, -2, 3)
	line(c, color, 0, 3, 2, 4, 0)
end

ICON_DRAWERS.lock = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(12, 10),
		Position = UDim2.new(0.5, 0, 0.5, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	local handle = new("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0.5, 0, 0.5, -4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(4, handle)
	stroke(color, 1.4, handle)
	dot(c, color, 0, 3, 3)
end

ICON_DRAWERS.unlock = function(c, color)
	local body = new("Frame", {
		Size = UDim2.fromOffset(12, 10),
		Position = UDim2.new(0.5, 0, 0.5, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	line(c, color, -3, -4, 2, 8, 0)
	line(c, color, 0, -7, 8, 2, 0)
	dot(c, color, 0, 3, 3)
end

ICON_DRAWERS.power = function(c, color)
	ring(c, color, 0, 2, 12, 12, 1.6)
	line(c, color, 0, -4, 2, 10, 0)
end

ICON_DRAWERS.download = function(c, color)
	line(c, color, 0, 0, 2, 12, 0)
	line(c, color, -4, 3, 6, 2, 45)
	line(c, color, 4, 3, 6, 2, -45)
	line(c, color, 0, 8, 14, 2, 0)
end

ICON_DRAWERS.upload = function(c, color)
	line(c, color, 0, 0, 2, 12, 0)
	line(c, color, -4, -3, 6, 2, -45)
	line(c, color, 4, -3, 6, 2, 45)
	line(c, color, 0, 8, 14, 2, 0)
end

ICON_DRAWERS.search = function(c, color)
	ring(c, color, -2, -2, 10, 10, 1.6)
	line(c, color, 4, 4, 6, 2, 45)
end

ICON_DRAWERS.menu = function(c, color)
	line(c, color, 0, -4, 14, 2, 0)
	line(c, color, 0, 0, 14, 2, 0)
	line(c, color, 0, 4, 14, 2, 0)
end

ICON_DRAWERS.grid = function(c, color)
	dot(c, color, -4, -4, 4)
	dot(c, color, 0, -4, 4)
	dot(c, color, 4, -4, 4)
	dot(c, color, -4, 0, 4)
	dot(c, color, 0, 0, 4)
	dot(c, color, 4, 0, 4)
	dot(c, color, -4, 4, 4)
	dot(c, color, 0, 4, 4)
	dot(c, color, 4, 4, 4)
end

ICON_DRAWERS.speed = function(c, color)
	ring(c, color, 0, 2, 14, 10, 1.6)
	line(c, color, 2, -2, 8, 2, -45)
	dot(c, color, 0, 2, 3)
end

ICON_DRAWERS.run = function(c, color)
	dot(c, color, 0, -6, 4)
	line(c, color, 0, 0, 2, 8, 15)
	line(c, color, -3, 5, 6, 2, -30)
	line(c, color, 3, 5, 6, 2, 30)
	line(c, color, 4, -2, 6, 2, 45)
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
		Name = "AsusLibNotify",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10000,
		Parent = host,
	})
	local holder = new("Frame", {
		Name = "Holder",
		Size = UDim2.new(0, 320, 1, -20),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = sg,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	NotifyContainer = sg
	return sg
end

function AsusLib:Notify(opts: { Title: string?, Text: string, Duration: number? })
	local duration = opts.Duration or 3
	local sg = ensureNotifyContainer()
	local holder = sg:FindFirstChild("Holder") :: Frame

	local toast = new("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = THEME.Toast,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	corner(10, toast)
	stroke(THEME.Border, 1, toast, 0.3)
	padding(toast, 10, 10, 14, 14)

	local iconBox = new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(0, 0, 0, 4),
		BackgroundTransparency = 1,
		Parent = toast,
	})
	drawIcon(iconBox, "bell", THEME.Accent, 20).Size = UDim2.new(1, 0, 1, 0)

	new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 20),
		Position = UDim2.new(0, 28, 0, 0),
		BackgroundTransparency = 1,
		Text = opts.Title or "Notification",
		TextColor3 = THEME.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
		Parent = toast,
	})
	new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.new(0, 28, 0, 20),
		BackgroundTransparency = 1,
		Text = opts.Text,
		TextColor3 = THEME.SubText,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextTransparency = 1,
		Parent = toast,
	})

	tween(toast, 0.18, { BackgroundTransparency = 0 })
	for _, child in ipairs(toast:GetChildren()) do
		if child:IsA("TextLabel") then
			tween(child, 0.18, { TextTransparency = 0 })
		end
	end

	task.delay(duration, function()
		tween(toast, 0.2, { BackgroundTransparency = 1 })
		for _, child in ipairs(toast:GetChildren()) do
			if child:IsA("TextLabel") then
				tween(child, 0.2, { TextTransparency = 1 })
			end
		end
		task.wait(0.25)
		toast:Destroy()
	end)
end

-- ----------------------------------------------------------------------
-- WINDOW
-- ----------------------------------------------------------------------
function AsusLib:CreateWindow(title: string)
	local host = getParent()

	-- Cleanup previous
	for _, old in ipairs(host:GetChildren()) do
		if old.Name == "AsusLibWindow" then old:Destroy() end
	end

	local sg = new("ScreenGui", {
		Name = "AsusLibWindow",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9999,
		Parent = host,
	})
	table.insert(AsusLib._screens, sg)

	-- Sizing
	local winW = IsMobile and 340 or 540
	local winH = IsMobile and 380 or 440
	local sideW = IsMobile and 110 or 150

	local Main = new("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(winW, winH),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = THEME.Window,
		BackgroundTransparency = THEME.WindowTransparency,
		BorderSizePixel = 0,
		Parent = sg,
	})
	corner(14, Main)
	stroke(THEME.Border, 1, Main, 0.2)
	glass(Main, 0.6)

	-- Titlebar
	local TitleBar = new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, IsMobile and 38 or 44),
		BackgroundTransparency = 1,
		Parent = Main,
	})
	padding(TitleBar, 0, 0, 16, 12)
	makeDraggable(Main, TitleBar)

	new("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = THEME.Text,
		Font = Enum.Font.GothamBold,
		TextSize = IsMobile and 14 or 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = TitleBar,
	})

	local BtnHolder = new("Frame", {
		Size = UDim2.fromOffset(50, 20),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = TitleBar,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = BtnHolder,
	})

	local function titleBtn(iconName: string, onClick: () -> ())
		local b = new("TextButton", {
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Text = "",
			Parent = BtnHolder,
		})
		local ic = drawIcon(b, iconName, THEME.SubText, 16)
		ic.Position = UDim2.new(0.5, 0, 0.5, 0)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		b.MouseEnter:Connect(function() recolorIcon(ic, iconName, THEME.Text) end)
		b.MouseLeave:Connect(function() recolorIcon(ic, iconName, THEME.SubText) end)
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	titleBtn("x", function()
		sg:Destroy()
	end)
	titleBtn("minus", function()
		sg.Enabled = false
		AsusLib:Notify({ Title = "Kaizen Hub", Text = "Press K or tap floating button to restore" })
	end)

	-- Divider under titlebar
	local Divider = new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, IsMobile and 38 or 44),
		BackgroundColor3 = THEME.Divider,
		BackgroundTransparency = THEME.DividerAlpha,
		BorderSizePixel = 0,
		Parent = Main,
	})

	-- Sidebar (scrollable)
	local SidebarScroll = new("ScrollingFrame", {
		Name = "Sidebar",
		Size = UDim2.new(0, sideW, 1, -(IsMobile and 40 or 46)),
		Position = UDim2.new(0, 0, 0, IsMobile and 40 or 46),
		BackgroundColor3 = THEME.Sidebar,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = Main,
	})
	corner(0, SidebarScroll)
	padding(SidebarScroll, 10, 10, 10, 10)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = SidebarScroll,
	})

	-- Content area (tab pages host)
	local Content = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -sideW, 1, -(IsMobile and 40 or 46)),
		Position = UDim2.new(0, sideW, 0, IsMobile and 40 or 46),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = Main,
	})

	local WindowObj = {}
	WindowObj._gui = sg
	WindowObj._main = Main
	WindowObj._tabs = {}
	WindowObj._activeTab = nil

	function WindowObj:SetVisible(v: boolean)
		sg.Enabled = v
	end

	-- Create Tab
	function WindowObj:CreateTab(name: string, iconName: string?)
		local order = #self._tabs + 1
		iconName = iconName or "home"

		-- Sidebar button
		local TabBtn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, IsMobile and 32 or 36),
			BackgroundColor3 = THEME.CardHover,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = order,
			Parent = SidebarScroll,
		})
		corner(8, TabBtn)

		local IconFrame = drawIcon(TabBtn, iconName, THEME.TabInactive, IsMobile and 16 or 18)
		IconFrame.Position = UDim2.new(0, IsMobile and 8 or 12, 0.5, 0)
		IconFrame.AnchorPoint = Vector2.new(0, 0.5)

		local Label = new("TextLabel", {
			Size = UDim2.new(1, -(IsMobile and 30 or 38), 1, 0),
			Position = UDim2.new(0, IsMobile and 28 or 36, 0, 0),
			BackgroundTransparency = 1,
			Text = "| " .. name,
			TextColor3 = THEME.TabInactive,
			Font = Enum.Font.GothamMedium,
			TextSize = IsMobile and 12 or 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = TabBtn,
		})

		-- Active indicator
		local Indicator = new("Frame", {
			Size = UDim2.new(0, 3, 0.6, 0),
			Position = UDim2.new(0, 0, 0.2, 0),
			BackgroundColor3 = THEME.Accent,
			BorderSizePixel = 0,
			Visible = false,
			Parent = TabBtn,
		})
		corner(2, Indicator)

		-- Scrollable page
		local Page = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(100, 100, 105),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			Parent = Content,
		})
		padding(Page, 12, 12, 14, 14)
		new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = Page,
		})

		local TabObj = { _page = Page, _btn = TabBtn, _icon = IconFrame, _iconName = iconName, _label = Label, _indicator = Indicator }
		table.insert(self._tabs, TabObj)

		local function activate()
			for _, t in ipairs(self._tabs) do
				t._page.Visible = false
				t._indicator.Visible = false
				recolorIcon(t._icon, t._iconName, THEME.TabInactive)
				t._label.TextColor3 = THEME.TabInactive
				t._btn.BackgroundTransparency = 1
			end
			Page.Visible = true
			Indicator.Visible = true
			recolorIcon(IconFrame, iconName, THEME.Accent)
			Label.TextColor3 = THEME.Text
			TabBtn.BackgroundTransparency = 0.85
			self._activeTab = TabObj
		end

		TabBtn.MouseButton1Click:Connect(activate)
		TabBtn.MouseEnter:Connect(function()
			if self._activeTab ~= TabObj then
				tween(TabBtn, 0.12, { BackgroundTransparency = 0.9 })
			end
		end)
		TabBtn.MouseLeave:Connect(function()
			if self._activeTab ~= TabObj then
				tween(TabBtn, 0.12, { BackgroundTransparency = 1 })
			end
		end)

		if order == 1 then activate() end

		-- Element ordering
		local _order = 0
		local function nextOrder() _order = _order + 1 return _order end

		-- ---------- SECTION ----------
		function TabObj:CreateSection(text: string)
			local sec = new("TextLabel", {
				Size = UDim2.new(1, 0, 0, IsMobile and 20 or 24),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = THEME.SubText,
				Font = Enum.Font.GothamBold,
				TextSize = IsMobile and 11 or 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			return sec
		end

		-- ---------- LABEL ----------
		function TabObj:CreateLabel(text: string)
			local lbl = new("TextLabel", {
				Size = UDim2.new(1, 0, 0, IsMobile and 18 or 20),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = THEME.SubText,
				Font = Enum.Font.Gotham,
				TextSize = IsMobile and 12 or 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			return { SetText = function(_, s: string) lbl.Text = s or "" end }
		end

		-- ---------- TOGGLE (shadcn switch) ----------
		function TabObj:CreateToggle(opts: { Name: string, Default: boolean?, Callback: ((boolean) -> ())? })
			local state = opts.Default or false
			local cb = opts.Callback or function() end

			local Card = new("Frame", {
				Size = UDim2.new(1, 0, 0, IsMobile and 44 or 48),
				BackgroundColor3 = THEME.Card,
				BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, 0, 0, IsMobile and 14 or 16, IsMobile and 14 or 16)

			new("TextLabel", {
				Size = UDim2.new(1, -60, 1, 0),
				BackgroundTransparency = 1,
				Text = opts.Name,
				TextColor3 = THEME.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = Card,
			})

			local Track = new("Frame", {
				Size = UDim2.fromOffset(44, 24),
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = state and THEME.SwitchOn or THEME.SwitchOff,
				BorderSizePixel = 0,
				Parent = Card,
			})
			corner(12, Track)

			local Thumb = new("Frame", {
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.fromOffset(state and 22 or 2, 2),
				BackgroundColor3 = state and THEME.ThumbDark or THEME.ThumbLight,
				BorderSizePixel = 0,
				Parent = Track,
			})
			corner(10, Thumb)

			local function update(newState: boolean)
				state = newState
				tween(Track, 0.14, { BackgroundColor3 = state and THEME.SwitchOn or THEME.SwitchOff })
				tween(Thumb, 0.14, { Position = UDim2.fromOffset(state and 22 or 2, 2), BackgroundColor3 = state and THEME.ThumbDark or THEME.ThumbLight })
			end

			local Btn = new("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				Parent = Card,
			})
			Btn.MouseButton1Click:Connect(function()
				update(not state)
				task.spawn(cb, state)
			end)

			Card.MouseEnter:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
			Card.MouseLeave:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.Card }) end)

			return {
				GetValue = function() return state end,
				SetValue = function(_, v: boolean) update(v) end,
			}
		end

		-- ---------- SLIDER (shadcn) ----------
		function TabObj:CreateSlider(opts: { Name: string, Min: number, Max: number, Default: number?, Increment: number?, Callback: ((number) -> ())? })
			local minV = opts.Min or 0
			local maxV = opts.Max or 100
			local inc = opts.Increment or 1
			local value = opts.Default or minV
			local cb = opts.Callback or function() end

			local Card = new("Frame", {
				Size = UDim2.new(1, 0, 0, IsMobile and 62 or 68),
				BackgroundColor3 = THEME.Card,
				BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 10 or 12, IsMobile and 10 or 12, IsMobile and 14 or 16, IsMobile and 14 or 16)

			local NameLabel = new("TextLabel", {
				Size = UDim2.new(1, -40, 0, IsMobile and 16 or 18),
				BackgroundTransparency = 1,
				Text = opts.Name,
				TextColor3 = THEME.Text,
				Font = Enum.Font.GothamBold,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = Card,
			})

			local ValueLabel = new("TextLabel", {
				Size = UDim2.fromOffset(36, IsMobile and 16 or 18),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = tostring(value),
				TextColor3 = THEME.SubText,
				Font = Enum.Font.Gotham,
				TextSize = IsMobile and 12 or 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = Card,
			})

			local TrackBg = new("Frame", {
				Size = UDim2.new(1, 0, 0, 6),
				Position = UDim2.new(0, 0, 1, -(IsMobile and 8 or 10)),
				BackgroundColor3 = THEME.TrackOff,
				BorderSizePixel = 0,
				Parent = Card,
			})
			corner(3, TrackBg)

			local Fill = new("Frame", {
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = THEME.TrackOn,
				BorderSizePixel = 0,
				Parent = TrackBg,
			})
			corner(3, Fill)

			local ThumbSize = IsMobile and 16 or 18
			local Thumb = new("Frame", {
				Size = UDim2.fromOffset(ThumbSize, ThumbSize),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = THEME.ThumbLight,
				BorderSizePixel = 0,
				Parent = TrackBg,
			})
			corner(ThumbSize / 2, Thumb)
			stroke(THEME.Border, 1, Thumb, 0.5)

			local function setVisual(v: number)
				local pct = math.clamp((v - minV) / (maxV - minV), 0, 1)
				local trackW = TrackBg.AbsoluteSize.X
				Fill.Size = UDim2.new(pct, 0, 1, 0)
				Thumb.Position = UDim2.new(pct, 0, 0.5, 0)
				ValueLabel.Text = tostring(v)
			end
			setVisual(value)

			local dragging: InputObject? = nil
			local function update(input: InputObject)
				local rel = input.Position.X - TrackBg.AbsolutePosition.X
				local pct = math.clamp(rel / TrackBg.AbsoluteSize.X, 0, 1)
				local raw = minV + pct * (maxV - minV)
				local stepped = math.floor(raw / inc + 0.5) * inc
				stepped = math.clamp(stepped, minV, maxV)
				if stepped ~= value then
					value = stepped
					setVisual(value)
					task.spawn(cb, value)
				end
			end

			TrackBg.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = input
					update(input)
					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then dragging = nil end
					end)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if input == dragging then update(input) end
			end)

			Card.MouseEnter:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
			Card.MouseLeave:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.Card }) end)

			return {
				GetValue = function() return value end,
				SetValue = function(_, v: number)
					value = math.clamp(v, minV, maxV)
					setVisual(value)
				end,
			}
		end

		-- ---------- BUTTON ----------
		function TabObj:CreateButton(opts: { Name: string, Description: string?, Callback: (() -> ())? })
			local cb = opts.Callback or function() end
			local Card = new("TextButton", {
				Size = UDim2.new(1, 0, 0, opts.Description and (IsMobile and 58 or 64) or (IsMobile and 44 or 48)),
				BackgroundColor3 = THEME.Card,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Text = "",
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 10 or 12, IsMobile and 10 or 12, IsMobile and 14 or 16, IsMobile and 14 or 16)

			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, IsMobile and 16 or 18),
				BackgroundTransparency = 1,
				Text = opts.Name,
				TextColor3 = THEME.Text,
				Font = Enum.Font.GothamBold,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = Card,
			})
			if opts.Description then
				new("TextLabel", {
					Size = UDim2.new(1, 0, 0, IsMobile and 14 or 16),
					Position = UDim2.new(0, 0, 0, IsMobile and 18 or 20),
					BackgroundTransparency = 1,
					Text = opts.Description,
					TextColor3 = THEME.SubText,
					Font = Enum.Font.Gotham,
					TextSize = IsMobile and 11 or 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = Card,
				})
			end
			Card.MouseEnter:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
			Card.MouseLeave:Connect(function() tween(Card, 0.12, { BackgroundColor3 = THEME.Card }) end)
			Card.MouseButton1Click:Connect(function() task.spawn(cb) end)
		end

		-- ---------- PARAGRAPH ----------
		function TabObj:CreateParagraph(opts: { Title: string?, Content: string? })
			local Card = new("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = THEME.Card,
				BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 10 or 12, IsMobile and 10 or 12, IsMobile and 14 or 16, IsMobile and 14 or 16)
			new("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Parent = Card,
			})

			if opts.Title and opts.Title ~= "" then
				new("TextLabel", {
					Size = UDim2.new(1, 0, 0, IsMobile and 18 or 20),
					BackgroundTransparency = 1,
					Text = opts.Title,
					TextColor3 = THEME.Text,
					Font = Enum.Font.GothamBold,
					TextSize = IsMobile and 14 or 15,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					Parent = Card,
				})
			end
			local body = new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = opts.Content or "",
				TextColor3 = THEME.SubText,
				Font = Enum.Font.Gotham,
				TextSize = IsMobile and 12 or 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				LayoutOrder = 2,
				Parent = Card,
			})
			return {
				SetContent = function(_, s: string) body.Text = s or "" end,
			}
		end

		-- ---------- INPUT (textbox) ----------
		function TabObj:CreateInput(opts: {
			Name: string,
			Default: string?,
			Placeholder: string?,
			Numeric: boolean?,
			Callback: ((string) -> ())?,
		})
			local cb = opts.Callback or function() end
			local Card = new("Frame", {
				Size = UDim2.new(1, 0, 0, IsMobile and 62 or 68),
				BackgroundColor3 = THEME.Card,
				BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
				Parent = Page,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 10 or 12, IsMobile and 10 or 12, IsMobile and 14 or 16, IsMobile and 14 or 16)
			new("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Parent = Card,
			})

			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, IsMobile and 16 or 18),
				BackgroundTransparency = 1,
				Text = opts.Name,
				TextColor3 = THEME.Text,
				Font = Enum.Font.GothamBold,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Parent = Card,
			})

			local InputHolder = new("Frame", {
				Size = UDim2.new(1, 0, 0, IsMobile and 28 or 30),
				BackgroundColor3 = THEME.SwitchOff,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Parent = Card,
			})
			corner(8, InputHolder)
			stroke(THEME.BorderSoft, 1, InputHolder, 0.88)

			local Box = new("TextBox", {
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				BackgroundTransparency = 1,
				Text = opts.Default or "",
				PlaceholderText = opts.Placeholder or "",
				TextColor3 = THEME.Text,
				PlaceholderColor3 = THEME.SubText,
				Font = Enum.Font.Gotham,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				Parent = InputHolder,
			})

			if opts.Numeric then
				Box:GetPropertyChangedSignal("Text"):Connect(function()
					local t = Box.Text:gsub("[^%d%.%-]", "")
					if Box.Text ~= t then Box.Text = t end
				end)
			end

			Box.FocusLost:Connect(function()
				task.spawn(cb, Box.Text)
			end)

			return {
				GetValue = function() return Box.Text end,
				SetValue = function(_, v: string) Box.Text = tostring(v or "") end,
			}
		end

		-- ---------- DROPDOWN (single-select, expandable list) ----------
		function TabObj:CreateDropdown(opts: {
			Name: string,
			Values: {string},
			Default: string?,
			Callback: ((string) -> ())?,
		})
			local cb = opts.Callback or function() end
			local values = opts.Values or {}
			local current = opts.Default

			local Card = new("Frame", {
				Size = UDim2.new(1, 0, 0, IsMobile and 62 or 68),
				BackgroundColor3 = THEME.Card,
				BorderSizePixel = 0,
				LayoutOrder = nextOrder(),
				Parent = Page,
				ClipsDescendants = true,
			})
			corner(12, Card)
			stroke(THEME.BorderSoft, 1, Card, 0.92)
			padding(Card, IsMobile and 10 or 12, IsMobile and 10 or 12, IsMobile and 14 or 16, IsMobile and 14 or 16)
			local list = new("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Parent = Card,
			})

			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, IsMobile and 16 or 18),
				BackgroundTransparency = 1,
				Text = opts.Name,
				TextColor3 = THEME.Text,
				Font = Enum.Font.GothamBold,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Parent = Card,
			})

			local Button = new("TextButton", {
				Size = UDim2.new(1, 0, 0, IsMobile and 28 or 30),
				BackgroundColor3 = THEME.SwitchOff,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Text = "",
				LayoutOrder = 2,
				Parent = Card,
			})
			corner(8, Button)
			stroke(THEME.BorderSoft, 1, Button, 0.88)

			local Selected = new("TextLabel", {
				Size = UDim2.new(1, -36, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = current or "Select...",
				TextColor3 = current and THEME.Text or THEME.SubText,
				Font = Enum.Font.Gotham,
				TextSize = IsMobile and 13 or 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = Button,
			})

			local Chevron = new("TextLabel", {
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.new(1, -24, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = "v",
				TextColor3 = THEME.SubText,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Parent = Button,
			})

			-- Scrollable list that expands inside the card
			local ListBox = new("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = THEME.SwitchOff,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Color3.fromRGB(120, 120, 125),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				LayoutOrder = 3,
				Visible = false,
				Parent = Card,
			})
			corner(8, ListBox)
			stroke(THEME.BorderSoft, 1, ListBox, 0.88)
			new("UIListLayout", {
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = ListBox,
			})
			new("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				Parent = ListBox,
			})

			local open = false
			local rowH = IsMobile and 26 or 28

			local function collapsedHeight()
				return IsMobile and 62 or 68
			end
			local function expandedHeight()
				local visible = math.min(#values, 5)
				return collapsedHeight() + 6 + (visible * (rowH + 2)) + 8
			end

			local function rebuildRows()
				for _, child in ipairs(ListBox:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				for i, v in ipairs(values) do
					local row = new("TextButton", {
						Size = UDim2.new(1, -4, 0, rowH),
						BackgroundTransparency = 1,
						AutoButtonColor = false,
						Text = tostring(v),
						TextColor3 = THEME.Text,
						Font = Enum.Font.Gotham,
						TextSize = IsMobile and 12 or 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = i,
						Parent = ListBox,
					})
					new("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = row })
					row.MouseEnter:Connect(function()
						row.BackgroundTransparency = 0.8
						row.BackgroundColor3 = Color3.fromRGB(80, 80, 86)
					end)
					row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)
					row.MouseButton1Click:Connect(function()
						current = tostring(v)
						Selected.Text = current
						Selected.TextColor3 = THEME.Text
						open = false
						ListBox.Visible = false
						Card.Size = UDim2.new(1, 0, 0, collapsedHeight())
						Chevron.Rotation = 0
						task.spawn(cb, current)
					end)
				end
			end
			rebuildRows()

			Button.MouseButton1Click:Connect(function()
				if #values == 0 then return end
				open = not open
				ListBox.Visible = open
				if open then
					Card.Size = UDim2.new(1, 0, 0, expandedHeight())
					Chevron.Rotation = 180
				else
					Card.Size = UDim2.new(1, 0, 0, collapsedHeight())
					Chevron.Rotation = 0
				end
			end)

			return {
				GetValue = function() return current end,
				SetValue = function(_, v: string)
					current = v
					Selected.Text = v or "Select..."
					Selected.TextColor3 = (v and THEME.Text) or THEME.SubText
				end,
				SetValues = function(_, vs: {string})
					values = vs or {}
					rebuildRows()
					if current and not table.find(values, current) then
						current = nil
						Selected.Text = "Select..."
						Selected.TextColor3 = THEME.SubText
					end
				end,
			}
		end

		return TabObj
	end

	return WindowObj
end

-- Expose globally
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
