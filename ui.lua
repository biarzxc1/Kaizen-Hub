--!strict
--[[
	AsusLib - Roblox UI Library
	Mobile + PC support (touch drag, large hit targets, responsive)
	Icons drawn with native Frames (no asset IDs, always render correctly)

	USAGE:
		local AsusLib = loadstring(game:HttpGet("YOUR_URL/AsusLib.lua"))()
		local Window  = AsusLib:CreateWindow("Asus Hub | Game | Delta")
		local Visuals = Window:CreateTab("Visuals", "eye")
		local Combat  = Window:CreateTab("Combat",  "swords")
		local Players = Window:CreateTab("Players", "users")
		local Collect = Window:CreateTab("Collect", "basket")
		local Setting = Window:CreateTab("Settings","settings")

		Visuals:CreateLabel("Esp all Crates in map")
		Visuals:CreateToggle({ Name = "Esp Crates", Description = "View all crates.", Default = false, Callback = function(v) end })
		Combat:CreateSlider({  Name = "Range (studs)", Description = "Detection radius.", Min = 0, Max = 100, Default = 30, Callback = function(v) end })

	Available icon names: eye, swords, users, basket, settings, x, minus
--]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local IsMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================================================
-- THEME
-- ==========================================================================
local THEME = {
	Window       = Color3.fromRGB(22, 22, 22),
	Card         = Color3.fromRGB(38, 38, 38),
	CardHover    = Color3.fromRGB(46, 46, 46),
	Accent       = Color3.fromRGB(255, 255, 255),
	Text         = Color3.fromRGB(255, 255, 255),
	SubText      = Color3.fromRGB(165, 165, 165),
	TabInactive  = Color3.fromRGB(190, 190, 190),
	ToggleOff    = Color3.fromRGB(70, 70, 70),
	ToggleOn     = Color3.fromRGB(255, 255, 255),
	Border       = Color3.fromRGB(50, 50, 50),
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

-- Safe parent (gethui in executors, CoreGui in studio, fallback PlayerGui)
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
-- ICONS (drawn with native Frames - no asset IDs)
-- ==========================================================================
-- Each icon function creates a 20x20 container and draws the glyph inside it.

local function iconContainer(parent: Instance, size: number?): Frame
	local c = new("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size or 20, size or 20),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	return c :: Frame
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

ICON_DRAWERS.eye = function(c, color)
	-- Lens (almond shape approximated with a rounded pill)
	local lens = new("Frame", {
		Size                   = UDim2.fromOffset(18, 12),
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(6, lens)
	stroke(color, 1.6, lens)
	-- Pupil
	ring(c, color, 0, 0, 7, 7, 1.6)
	dot(c, color, 0, 0, 3)
end

ICON_DRAWERS.swords = function(c, color)
	-- Two crossed swords: diagonal blades + small pommels
	-- Blade 1 (top-left to bottom-right)
	line(c, color, -1, -1, 16, 2, 45)
	-- Blade 2 (top-right to bottom-left)
	line(c, color, 1, -1, 16, 2, -45)
	-- Hilts (small cross guards near the tops/bottoms)
	line(c, color, -6, -6, 5, 2, -45)
	line(c, color, 6, -6, 5, 2, 45)
	-- Pommels
	dot(c, color, -7, 7, 3)
	dot(c, color, 7, 7, 3)
end

ICON_DRAWERS.users = function(c, color)
	-- Two heads + two bodies (overlapping)
	-- Head 1
	ring(c, color, -3, -4, 6, 6, 1.6)
	-- Head 2
	ring(c, color, 4, -4, 6, 6, 1.6)
	-- Body 1 (arc approximated as a rounded rectangle top)
	local b1 = new("Frame", {
		Size                   = UDim2.fromOffset(10, 6),
		Position               = UDim2.new(0.5, -3, 0.5, 4),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(4, b1)
	stroke(color, 1.6, b1)
	-- Body 2
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
	-- Handle (arc approximated)
	local handle = new("Frame", {
		Size                   = UDim2.fromOffset(10, 8),
		Position               = UDim2.new(0.5, 0, 0.5, -3),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(6, handle)
	stroke(color, 1.6, handle)
	-- Rim (horizontal line)
	line(c, color, 0, 1, 18, 2, 0)
	-- Basket body (trapezoid approximated as rounded rect)
	local body = new("Frame", {
		Size                   = UDim2.fromOffset(16, 8),
		Position               = UDim2.new(0.5, 0, 0.5, 5),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent                 = c,
	})
	corner(2, body)
	stroke(color, 1.6, body)
	-- Slats (vertical lines)
	line(c, color, -4, 5, 1.4, 6, 0)
	line(c, color, 0,  5, 1.4, 6, 0)
	line(c, color, 4,  5, 1.4, 6, 0)
end

ICON_DRAWERS.settings = function(c, color)
	-- Gear: center circle + 8 teeth around
	ring(c, color, 0, 0, 8, 8, 1.6)
	dot(c, color, 0, 0, 2)
	-- 8 teeth at 0, 45, 90, 135, 180, 225, 270, 315 degrees
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
	if drawer then
		drawer(c, color)
	end
	return c
end

-- Recolor an already-drawn icon (re-draws it)
local function recolorIcon(container: Frame, name: string, color: Color3)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
	local drawer = ICON_DRAWERS[name]
	if drawer then
		drawer(container, color)
	end
end

-- ==========================================================================
-- LIBRARY
-- ==========================================================================
local AsusLib = {}

function AsusLib:CreateWindow(title: string)
	-- Clean up any previous instance
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

	-- Responsive sizing
	local winSize: UDim2
	if IsMobile then
		winSize = UDim2.new(0.92, 0, 0.72, 0)
	else
		winSize = UDim2.fromOffset(740, 500)
	end

	local Window = new("Frame", {
		Name                   = "Window",
		Size                   = winSize,
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundColor3       = THEME.Window,
		BorderSizePixel        = 0,
		ClipsDescendants       = true,
		Parent                 = ScreenGui,
	})
	corner(14, Window)
	stroke(THEME.Border, 1, Window, 0.4)

	-- ----------------------------------------------------------------------
	-- TITLE BAR
	-- ----------------------------------------------------------------------
	local TitleBar = new("Frame", {
		Name                   = "TitleBar",
		Size                   = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})
	padding(TitleBar, 0, 0, 18, 14)

	local TitleLabel = new("TextLabel", {
		Size                   = UDim2.new(1, -100, 1, 0),
		BackgroundTransparency = 1,
		Text                   = title or "Asus Hub",
		TextColor3             = THEME.Text,
		Font                   = Enum.Font.GothamBold,
		TextSize               = 16,
		TextXAlignment         = Enum.TextXAlignment.Left,
		TextYAlignment         = Enum.TextYAlignment.Center,
		Parent                 = TitleBar,
	})

	-- Minimize button
	local MinBtn = new("TextButton", {
		Size                   = UDim2.fromOffset(28, 28),
		Position               = UDim2.new(1, -60, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text                   = "",
		AutoButtonColor        = false,
		Parent                 = TitleBar,
	})
	local MinIcon = drawIcon(MinBtn, "minus", THEME.Text, 20)
	MinIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	MinIcon.AnchorPoint = Vector2.new(0.5, 0.5)

	-- Close button
	local CloseBtn = new("TextButton", {
		Size                   = UDim2.fromOffset(28, 28),
		Position               = UDim2.new(1, -28, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text                   = "",
		AutoButtonColor        = false,
		Parent                 = TitleBar,
	})
	local CloseIcon = drawIcon(CloseBtn, "x", THEME.Text, 20)
	CloseIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	CloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)

	CloseBtn.MouseButton1Click:Connect(function()
		tween(Window, 0.18, { Size = UDim2.new(0, 0, 0, 0) })
		task.wait(0.2)
		ScreenGui:Destroy()
	end)

	-- Minimize logic
	local minimized = false
	local originalSize = Window.Size
	MinBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			tween(Window, 0.2, { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 48) })
		else
			tween(Window, 0.2, { Size = originalSize })
		end
	end)

	makeDraggable(Window, TitleBar)

	-- ----------------------------------------------------------------------
	-- BODY
	-- ----------------------------------------------------------------------
	local Body = new("Frame", {
		Size                   = UDim2.new(1, 0, 1, -48),
		Position               = UDim2.new(0, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})

	-- Sidebar
	local sidebarWidth = IsMobile and 160 or 190
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
	padding(Content, 4, 16, 6, 22)

	local WindowObj = {}
	WindowObj.Tabs = {}
	WindowObj._gui = ScreenGui

	-- ----------------------------------------------------------------------
	-- TAB
	-- ----------------------------------------------------------------------
	function WindowObj:CreateTab(name: string, iconName: string?)
		iconName = iconName or "eye"

		-- Tab row container
		local tabRow = new("Frame", {
			Name                   = "Tab_" .. name,
			Size                   = UDim2.new(1, 0, 0, 42),
			BackgroundTransparency = 1,
			Parent                 = TabList,
		})

		-- Accent bar (left, shown when selected)
		local accent = new("Frame", {
			Size                   = UDim2.fromOffset(2, 22),
			Position               = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundColor3       = THEME.Accent,
			BorderSizePixel        = 0,
			BackgroundTransparency = 1,
			Parent                 = tabRow,
		})
		corner(1, accent)

		-- Icon
		local iconBox = new("Frame", {
			Size                   = UDim2.fromOffset(20, 20),
			Position               = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Parent                 = tabRow,
		})
		drawIcon(iconBox, iconName, THEME.TabInactive, 20).Size = UDim2.new(1, 0, 1, 0)

		-- Label (format: "| Name")
		local label = new("TextLabel", {
			Size                   = UDim2.new(1, -44, 1, 0),
			Position               = UDim2.new(0, 42, 0, 0),
			BackgroundTransparency = 1,
			Text                   = "| " .. name,
			TextColor3             = THEME.TabInactive,
			Font                   = Enum.Font.GothamMedium,
			TextSize               = 15,
			TextXAlignment         = Enum.TextXAlignment.Left,
			Parent                 = tabRow,
		})

		-- Click handler (touch-friendly)
		local click = new("TextButton", {
			Size                   = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text                   = "",
			AutoButtonColor        = false,
			Parent                 = tabRow,
		})

		-- Page
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
		padding(Page, 0, 16, 0, 8)

		-- Big header at top of page
		new("TextLabel", {
			Name                   = "Header",
			Size                   = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text                   = name,
			TextColor3             = THEME.Text,
			Font                   = Enum.Font.GothamBold,
			TextSize               = 24,
			TextXAlignment         = Enum.TextXAlignment.Left,
			LayoutOrder            = 0,
			Parent                 = Page,
		})

		new("UIListLayout", {
			Padding   = UDim.new(0, 12),
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
			page     = Page,
			label    = label,
			iconBox  = iconBox,
			iconName = iconName,
			accent   = accent,
			select   = select,
		})

		if #WindowObj.Tabs == 1 then
			select()
		end

		-- ------------------------------------------------------------------
		-- LABEL (non-interactive card, like "Kill Aura" / "Esp all Crates in map")
		-- ------------------------------------------------------------------
		function TabObj:CreateLabel(text: string)
			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, 54),
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
				TextSize               = 16,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})
			return {
				SetText = function(_, s: string) tl.Text = s end,
			}
		end

		-- ------------------------------------------------------------------
		-- TOGGLE
		-- ------------------------------------------------------------------
		function TabObj:CreateToggle(opts: {
			Name: string,
			Description: string?,
			Default: boolean?,
			Callback: ((boolean) -> ())?
		})
			local state = opts.Default == true
			local cb    = opts.Callback or function() end

			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, 74),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			padding(Card, 14, 14, 18, 18)

			new("TextLabel", {
				Size                   = UDim2.new(1, -70, 0, 22),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 16,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})

			if opts.Description and opts.Description ~= "" then
				new("TextLabel", {
					Position               = UDim2.new(0, 0, 0, 24),
					Size                   = UDim2.new(1, -70, 0, 20),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = 13,
					TextXAlignment         = Enum.TextXAlignment.Left,
					TextWrapped            = true,
					Parent                 = Card,
				})
			end

			-- iOS-style switch
			local Switch = new("Frame", {
				Size                   = UDim2.fromOffset(48, 26),
				Position               = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(1, 0.5),
				BackgroundColor3       = THEME.ToggleOff,
				BorderSizePixel        = 0,
				Parent                 = Card,
			})
			corner(13, Switch)

			local Knob = new("Frame", {
				Size                   = UDim2.fromOffset(20, 20),
				Position               = UDim2.fromOffset(3, 3),
				BackgroundColor3       = Color3.fromRGB(255, 255, 255),
				BorderSizePixel        = 0,
				Parent                 = Switch,
			})
			corner(10, Knob)

			local Btn = new("TextButton", {
				Size                   = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text                   = "",
				AutoButtonColor        = false,
				Parent                 = Card,
			})

			local function render(animated: boolean?)
				local t = animated == false and 0 or 0.16
				if state then
					tween(Switch, t, { BackgroundColor3 = THEME.ToggleOn })
					tween(Knob,   t, { Position = UDim2.fromOffset(25, 3), BackgroundColor3 = Color3.fromRGB(30, 30, 30) })
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
				Set = function(_, v: boolean)
					state = v and true or false
					render(true)
					task.spawn(cb, state)
				end,
				Get = function() return state end,
			}
		end

		-- ------------------------------------------------------------------
		-- SLIDER
		-- ------------------------------------------------------------------
		function TabObj:CreateSlider(opts: {
			Name: string,
			Description: string?,
			Min: number,
			Max: number,
			Default: number?,
			Increment: number?,
			Callback: ((number) -> ())?
		})
			local minV  = opts.Min or 0
			local maxV  = opts.Max or 100
			local inc   = opts.Increment or 1
			local value = math.clamp(opts.Default or minV, minV, maxV)
			local cb    = opts.Callback or function() end

			local hasDesc = opts.Description and opts.Description ~= ""
			local cardH   = hasDesc and 90 or 68

			local Card = new("Frame", {
				Size                   = UDim2.new(1, 0, 0, cardH),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			padding(Card, 14, 14, 18, 18)

			-- Slider visual on the right side (track)
			local trackWidth = 150
			local Track = new("Frame", {
				Size                   = UDim2.fromOffset(trackWidth, 4),
				Position               = UDim2.new(1, 0, 0, 14),
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

			-- Value number to the left of the track
			local ValueLabel = new("TextLabel", {
				Size                   = UDim2.fromOffset(50, 22),
				Position               = UDim2.new(1, -trackWidth - 12, 0, 5),
				AnchorPoint            = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text                   = tostring(value),
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamMedium,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Right,
				Parent                 = Card,
			})

			-- Title + description on the left
			new("TextLabel", {
				Size                   = UDim2.new(1, -trackWidth - 70, 0, 22),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 16,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})

			if hasDesc then
				new("TextLabel", {
					Position               = UDim2.new(0, 0, 0, 26),
					Size                   = UDim2.new(1, -trackWidth - 70, 0, 32),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = 13,
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
				local alpha = (v - minV) / (maxV - minV)
				Fill.Size     = UDim2.new(alpha, 0, 1, 0)
				Knob.Position = UDim2.new(alpha, 0, 0.5, 0)
				ValueLabel.Text = tostring(v)
				if fire ~= false then
					task.spawn(cb, v)
				end
			end

			setValue(value, false)

			-- Drag (mouse + touch)
			local dragging = false
			local function updateFromInput(input: InputObject)
				local pos   = input.Position.X
				local abs   = Track.AbsolutePosition.X
				local size  = Track.AbsoluteSize.X
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
				) then
					updateFromInput(input)
				end
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

		-- ------------------------------------------------------------------
		-- BUTTON
		-- ------------------------------------------------------------------
		function TabObj:CreateButton(opts: { Name: string, Description: string?, Callback: (() -> ())? })
			local cb = opts.Callback or function() end
			local Card = new("TextButton", {
				Size                   = UDim2.new(1, 0, 0, 54),
				BackgroundColor3       = THEME.Card,
				AutoButtonColor        = false,
				BorderSizePixel        = 0,
				Text                   = "",
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)

			new("TextLabel", {
				Size                   = UDim2.new(1, -32, 0, 22),
				Position               = UDim2.new(0, 18, 0, 8),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 16,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})
			if opts.Description then
				new("TextLabel", {
					Size                   = UDim2.new(1, -32, 0, 18),
					Position               = UDim2.new(0, 18, 0, 28),
					BackgroundTransparency = 1,
					Text                   = opts.Description,
					TextColor3             = THEME.SubText,
					Font                   = Enum.Font.Gotham,
					TextSize               = 13,
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

	function WindowObj:Destroy()
		ScreenGui:Destroy()
	end

	return WindowObj
end

return AsusLib
