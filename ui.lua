--!strict
--[[
	AsusLib - Roblox UI Library
	Supports PC + Mobile (touch drag, large hit targets)
	Real Lucide icons via rbxassetid://
	
	API:
		local AsusLib = loadstring(game:HttpGet("..."))()
		local Window = AsusLib:CreateWindow("Asus Hub | Game | Delta")
		local Tab    = Window:CreateTab("Visuals", "eye")
		Tab:CreateSection("Visuals")
		Tab:CreateToggle({ Name = "Esp Crates", Description = "View all crates.", Default = false, Callback = function(v) end })
		Tab:CreateSlider({ Name = "Range (studs)", Description = "Detection radius.", Min = 0, Max = 100, Default = 30, Callback = function(v) end })
		Tab:CreateLabel("Kill Aura")
--]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local IsMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================================================
-- THEME
-- ==========================================================================
local THEME = {
	Window       = Color3.fromRGB(24, 24, 24),
	Sidebar      = Color3.fromRGB(24, 24, 24),
	Content      = Color3.fromRGB(24, 24, 24),
	Card         = Color3.fromRGB(40, 40, 40),
	CardHover    = Color3.fromRGB(48, 48, 48),
	Accent       = Color3.fromRGB(255, 255, 255),
	Text         = Color3.fromRGB(255, 255, 255),
	SubText      = Color3.fromRGB(170, 170, 170),
	ToggleOff    = Color3.fromRGB(70, 70, 70),
	ToggleOn     = Color3.fromRGB(255, 255, 255),
	Knob         = Color3.fromRGB(255, 255, 255),
	Divider      = Color3.fromRGB(50, 50, 50),
}

-- ==========================================================================
-- LUCIDE ICONS (Roblox asset IDs)
-- ==========================================================================
local ICONS = {
	eye       = "rbxassetid://10709790644",
	swords    = "rbxassetid://15514724064",
	users     = "rbxassetid://10734896206",
	basket    = "rbxassetid://10734924856",
	settings  = "rbxassetid://10734950309",
	x         = "rbxassetid://10747384394",
	minus     = "rbxassetid://10734898355",
	home      = "rbxassetid://10723415903",
	star      = "rbxassetid://10723425465",
	shield    = "rbxassetid://10747374960",
	bolt      = "rbxassetid://10723346959",
	info      = "rbxassetid://10734895698",
	user      = "rbxassetid://10747384394",
	folder    = "rbxassetid://10734923835",
	search    = "rbxassetid://10747372999",
	heart     = "rbxassetid://10747380311",
	bell      = "rbxassetid://10734889607",
	chevron   = "rbxassetid://10709790787",
}

local function resolveIcon(id: string?): string
	if not id then return ICONS.eye end
	if typeof(id) == "string" and ICONS[id] then
		return ICONS[id]
	end
	if typeof(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://" then
		return id
	end
	if typeof(id) == "number" then
		return "rbxassetid://" .. tostring(id)
	end
	return ICONS.eye
end

-- ==========================================================================
-- HELPERS
-- ==========================================================================
local function new(class: string, props: {[string]: any}, children: {Instance}?): Instance
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	return inst
end

local function corner(radius: number, parent: Instance): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(color: Color3, thickness: number, parent: Instance): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent: Instance, all: number?, top: number?, bottom: number?, left: number?, right: number?)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, top    or all or 0)
	p.PaddingBottom = UDim.new(0, bottom or all or 0)
	p.PaddingLeft   = UDim.new(0, left   or all or 0)
	p.PaddingRight  = UDim.new(0, right  or all or 0)
	p.Parent = parent
	return p
end

local function tween(inst: Instance, time: number, props: {[string]: any})
	local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Draggable (supports mouse + touch)
local function makeDraggable(frame: GuiObject, handle: GuiObject)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
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

-- Safe parent (works in exploit envs + studio)
local function getParent(): Instance
	local ok, cg = pcall(function()
		if gethui then return gethui() end
		return CoreGui
	end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- ==========================================================================
-- LIBRARY
-- ==========================================================================
local AsusLib = {}
AsusLib.__index = AsusLib

function AsusLib:CreateWindow(title: string)
	-- Clean old
	local existing = getParent():FindFirstChild("AsusLibGui")
	if existing then existing:Destroy() end

	local ScreenGui = new("ScreenGui", {
		Name              = "AsusLibGui",
		IgnoreGuiInset    = true,
		ResetOnSpawn      = false,
		ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
		DisplayOrder      = 9999,
		Parent            = getParent(),
	})

	-- Sizes adapt to device
	local winSize: UDim2
	if IsMobile then
		winSize = UDim2.new(0.9, 0, 0.7, 0)
	else
		winSize = UDim2.fromOffset(720, 480)
	end

	local Window = new("Frame", {
		Name                     = "Window",
		Size                     = winSize,
		Position                 = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint              = Vector2.new(0.5, 0.5),
		BackgroundColor3         = THEME.Window,
		BorderSizePixel          = 0,
		Parent                   = ScreenGui,
		ClipsDescendants         = true,
	})
	corner(12, Window)
	stroke(Color3.fromRGB(60, 60, 60), 1, Window)

	-- Title bar
	local TitleBar = new("Frame", {
		Name             = "TitleBar",
		Size             = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent           = Window,
	})
	padding(TitleBar, nil, nil, nil, 16, 12)

	local TitleLabel = new("TextLabel", {
		Name                = "Title",
		Size                = UDim2.new(1, -90, 1, 0),
		BackgroundTransparency = 1,
		Text                = title or "Asus Hub",
		TextColor3          = THEME.Text,
		Font                = Enum.Font.GothamBold,
		TextSize            = 16,
		TextXAlignment      = Enum.TextXAlignment.Left,
		TextYAlignment      = Enum.TextYAlignment.Center,
		Parent              = TitleBar,
	})

	-- Minimize button
	local MinBtn = new("ImageButton", {
		Name                   = "Minimize",
		Size                   = UDim2.fromOffset(28, 28),
		Position               = UDim2.new(1, -64, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image                  = ICONS.minus,
		ImageColor3            = THEME.Text,
		Parent                 = TitleBar,
	})

	-- Close button
	local CloseBtn = new("ImageButton", {
		Name                   = "Close",
		Size                   = UDim2.fromOffset(28, 28),
		Position               = UDim2.new(1, -28, 0.5, 0),
		AnchorPoint            = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Image                  = ICONS.x,
		ImageColor3            = THEME.Text,
		Parent                 = TitleBar,
	})

	CloseBtn.MouseButton1Click:Connect(function()
		tween(Window, 0.2, { Size = UDim2.new(0, 0, 0, 0) })
		task.wait(0.22)
		ScreenGui:Destroy()
	end)

	-- Minimize state
	local minimized = false
	local originalSize = Window.Size
	MinBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			tween(Window, 0.2, { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 44) })
		else
			tween(Window, 0.2, { Size = originalSize })
		end
	end)

	makeDraggable(Window, TitleBar)

	-- Body container
	local Body = new("Frame", {
		Name                   = "Body",
		Size                   = UDim2.new(1, 0, 1, -44),
		Position               = UDim2.new(0, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent                 = Window,
	})

	-- Sidebar
	local sidebarWidth = IsMobile and 150 or 180
	local Sidebar = new("Frame", {
		Name                   = "Sidebar",
		Size                   = UDim2.new(0, sidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent                 = Body,
	})
	padding(Sidebar, nil, 8, 12, 12, 8)

	local TabList = new("Frame", {
		Name = "TabList",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = Sidebar,
	})
	local TabListLayout = new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = TabList,
	})

	-- Content area
	local Content = new("Frame", {
		Name                   = "Content",
		Size                   = UDim2.new(1, -sidebarWidth, 1, 0),
		Position               = UDim2.new(0, sidebarWidth, 0, 0),
		BackgroundTransparency = 1,
		Parent                 = Body,
	})
	padding(Content, nil, 8, 16, 8, 20)

	local WindowObj = {}
	WindowObj.Tabs    = {}
	WindowObj.Current = nil
	WindowObj._gui    = ScreenGui

	-- ----------------------------------------------------------------------
	-- TAB
	-- ----------------------------------------------------------------------
	function WindowObj:CreateTab(name: string, iconName: string?)
		local tabButton = new("Frame", {
			Name = "TabButton_" .. name,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			Parent = TabList,
		})

		-- Selected accent bar
		local accent = new("Frame", {
			Name                   = "Accent",
			Size                   = UDim2.new(0, 2, 0.6, 0),
			Position               = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundColor3       = THEME.Accent,
			BorderSizePixel        = 0,
			BackgroundTransparency = 1,
			Parent                 = tabButton,
		})
		corner(2, accent)

		local icon = new("ImageLabel", {
			Name                   = "Icon",
			Size                   = UDim2.fromOffset(20, 20),
			Position               = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image                  = resolveIcon(iconName),
			ImageColor3            = THEME.SubText,
			Parent                 = tabButton,
		})

		local label = new("TextLabel", {
			Name                   = "Label",
			Size                   = UDim2.new(1, -46, 1, 0),
			Position               = UDim2.new(0, 42, 0, 0),
			BackgroundTransparency = 1,
			Text                   = "| " .. name,
			TextColor3             = THEME.SubText,
			Font                   = Enum.Font.GothamMedium,
			TextSize               = 15,
			TextXAlignment         = Enum.TextXAlignment.Left,
			Parent                 = tabButton,
		})

		local clickZone = new("TextButton", {
			Name                   = "ClickZone",
			Size                   = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text                   = "",
			AutoButtonColor        = false,
			Parent                 = tabButton,
		})

		-- Page (scrollable content)
		local Page = new("ScrollingFrame", {
			Name                   = "Page_" .. name,
			Size                   = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
			ScrollBarThickness     = 3,
			ScrollBarImageColor3   = Color3.fromRGB(80, 80, 80),
			CanvasSize             = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize    = Enum.AutomaticSize.Y,
			Visible                = false,
			Parent                 = Content,
		})

		-- Header (big tab name at top of page)
		local Header = new("TextLabel", {
			Name                   = "Header",
			Size                   = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Text                   = name,
			TextColor3             = THEME.Text,
			Font                   = Enum.Font.GothamBold,
			TextSize               = 22,
			TextXAlignment         = Enum.TextXAlignment.Left,
			LayoutOrder            = 0,
			Parent                 = Page,
		})

		local Layout = new("UIListLayout", {
			Padding    = UDim.new(0, 10),
			SortOrder  = Enum.SortOrder.LayoutOrder,
			Parent     = Page,
		})
		padding(Page, nil, 0, 12, 0, 12)

		local TabObj = {}
		TabObj._page  = Page
		TabObj._order = 1

		local function nextOrder(): number
			TabObj._order = TabObj._order + 1
			return TabObj._order
		end

		-- Selection behavior
		local function select()
			for _, t in ipairs(WindowObj.Tabs) do
				t.page.Visible = false
				t.label.TextColor3 = THEME.SubText
				t.icon.ImageColor3 = THEME.SubText
				t.accent.BackgroundTransparency = 1
			end
			Page.Visible = true
			label.TextColor3 = THEME.Text
			icon.ImageColor3 = THEME.Text
			accent.BackgroundTransparency = 0
			WindowObj.Current = TabObj
		end

		clickZone.MouseButton1Click:Connect(select)

		table.insert(WindowObj.Tabs, {
			page   = Page,
			label  = label,
			icon   = icon,
			accent = accent,
			select = select,
		})

		-- First tab auto-selected
		if #WindowObj.Tabs == 1 then
			select()
		end

		-- --------------------------------------------------------------
		-- SECTION (just a big label like "Kill Aura")
		-- --------------------------------------------------------------
		function TabObj:CreateSection(text: string)
			local Section = new("Frame", {
				Name                   = "Section",
				Size                   = UDim2.new(1, 0, 0, 48),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Section)

			new("TextLabel", {
				Size                   = UDim2.new(1, -24, 1, 0),
				Position               = UDim2.new(0, 16, 0, 0),
				BackgroundTransparency = 1,
				Text                   = text,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 16,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Section,
			})
			return Section
		end

		-- --------------------------------------------------------------
		-- LABEL (non-interactive line)
		-- --------------------------------------------------------------
		function TabObj:CreateLabel(text: string)
			local Lbl = new("Frame", {
				Name                   = "Label",
				Size                   = UDim2.new(1, 0, 0, 44),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Lbl)
			local tl = new("TextLabel", {
				Size                   = UDim2.new(1, -24, 1, 0),
				Position               = UDim2.new(0, 16, 0, 0),
				BackgroundTransparency = 1,
				Text                   = text,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamMedium,
				TextSize               = 14,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Lbl,
			})
			return {
				SetText = function(_, s) tl.Text = s end,
			}
		end

		-- --------------------------------------------------------------
		-- TOGGLE
		-- --------------------------------------------------------------
		function TabObj:CreateToggle(opts: {
			Name: string,
			Description: string?,
			Default: boolean?,
			Callback: ((boolean) -> ())?
		})
			local state = opts.Default == true
			local cb    = opts.Callback or function() end

			local Card = new("Frame", {
				Name                   = "Toggle",
				Size                   = UDim2.new(1, 0, 0, 68),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			padding(Card, nil, 12, 12, 16, 16)

			local Title = new("TextLabel", {
				Size                   = UDim2.new(1, -70, 0, 20),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})

			local Desc = new("TextLabel", {
				Position               = UDim2.new(0, 0, 0, 22),
				Size                   = UDim2.new(1, -70, 0, 18),
				BackgroundTransparency = 1,
				Text                   = opts.Description or "",
				TextColor3             = THEME.SubText,
				Font                   = Enum.Font.Gotham,
				TextSize               = 13,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})

			-- Switch
			local Switch = new("Frame", {
				Size                   = UDim2.fromOffset(46, 24),
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
				BackgroundColor3       = THEME.Knob,
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

			local function render()
				if state then
					tween(Switch, 0.15, { BackgroundColor3 = THEME.ToggleOn })
					tween(Knob,   0.15, { Position = UDim2.fromOffset(25, 3), BackgroundColor3 = Color3.fromRGB(30,30,30) })
				else
					tween(Switch, 0.15, { BackgroundColor3 = THEME.ToggleOff })
					tween(Knob,   0.15, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = THEME.Knob })
				end
			end

			Btn.MouseButton1Click:Connect(function()
				state = not state
				render()
				task.spawn(cb, state)
			end)

			render()

			return {
				Set = function(_, v: boolean)
					state = v and true or false
					render()
					task.spawn(cb, state)
				end,
				Get = function() return state end,
			}
		end

		-- --------------------------------------------------------------
		-- SLIDER
		-- --------------------------------------------------------------
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

			local Card = new("Frame", {
				Name                   = "Slider",
				Size                   = UDim2.new(1, 0, 0, 84),
				BackgroundColor3       = THEME.Card,
				BorderSizePixel        = 0,
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)
			padding(Card, nil, 12, 12, 16, 16)

			local Title = new("TextLabel", {
				Size                   = UDim2.new(1, -140, 0, 20),
				BackgroundTransparency = 1,
				Text                   = opts.Name,
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamBold,
				TextSize               = 15,
				TextXAlignment         = Enum.TextXAlignment.Left,
				Parent                 = Card,
			})

			local Desc = new("TextLabel", {
				Position               = UDim2.new(0, 0, 0, 22),
				Size                   = UDim2.new(1, -140, 0, 18),
				BackgroundTransparency = 1,
				Text                   = opts.Description or "",
				TextColor3             = THEME.SubText,
				Font                   = Enum.Font.Gotham,
				TextSize               = 13,
				TextXAlignment         = Enum.TextXAlignment.Left,
				TextWrapped            = true,
				Parent                 = Card,
			})

			local ValueLabel = new("TextLabel", {
				Size                   = UDim2.fromOffset(40, 20),
				Position               = UDim2.new(1, -130, 0, 4),
				BackgroundTransparency = 1,
				Text                   = tostring(value),
				TextColor3             = THEME.Text,
				Font                   = Enum.Font.GothamMedium,
				TextSize               = 14,
				TextXAlignment         = Enum.TextXAlignment.Right,
				Parent                 = Card,
			})

			local Track = new("Frame", {
				Size                   = UDim2.fromOffset(90, 4),
				Position               = UDim2.new(1, -85, 0, 13),
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
				Size                   = UDim2.fromOffset(12, 12),
				Position               = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint            = Vector2.new(0.5, 0.5),
				BackgroundColor3       = THEME.Accent,
				BorderSizePixel        = 0,
				Parent                 = Track,
			})
			corner(6, Knob)

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

			-- Drag on track (mouse + touch)
			local dragging = false
			local function updateFromInput(input: InputObject)
				local pos    = input.Position.X
				local abs    = Track.AbsolutePosition.X
				local size   = Track.AbsoluteSize.X
				local alpha  = math.clamp((pos - abs) / size, 0, 1)
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
				Set = function(_, v) setValue(v, true) end,
				Get = function() return value end,
			}
		end

		-- --------------------------------------------------------------
		-- BUTTON
		-- --------------------------------------------------------------
		function TabObj:CreateButton(opts: { Name: string, Description: string?, Callback: (() -> ())? })
			local cb = opts.Callback or function() end
			local Card = new("TextButton", {
				Name                   = "Button",
				Size                   = UDim2.new(1, 0, 0, 52),
				BackgroundColor3       = THEME.Card,
				AutoButtonColor        = false,
				BorderSizePixel        = 0,
				Text                   = "",
				LayoutOrder            = nextOrder(),
				Parent                 = Page,
			})
			corner(10, Card)

			new("TextLabel", {
				Size                   = UDim2.new(1, -24, 0, 20),
				Position               = UDim2.new(0, 16, 0, 8),
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
					Size                   = UDim2.new(1, -24, 0, 16),
					Position               = UDim2.new(0, 16, 0, 28),
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
