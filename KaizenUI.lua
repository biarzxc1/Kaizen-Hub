--[[
    KaizenUI v2 — a flat, solid, Fluent-API-compatible UI library for Roblox.

      • Drop-in replacement for `Fluent`:
          CreateWindow / AddTab / AddSection /
          AddToggle / AddSlider / AddDropdown / AddInput / AddButton /
          AddParagraph / Notify / Options / SelectTab.
      • Modern flat dark theme (no glassmorphism, no blur).
      • Smooth responsive sizing for PC, laptop and mobile.
      • Branded loader splash + in-window "Injecting..." status pill.
      • Dotted rotating ring spinner.
      • Touch-first sliders and scrollable pages.
      • Draggable window + draggable minimized logo pill.
      • Uses your logo (rbxassetid://124205601170943) and Lucide icons.

    Usage:
      local KaizenUI = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/biarzxc1/Kaizen-Hub/refs/heads/main/KaizenUI.lua"
      ))()

      KaizenUI:Loader({ Title = "Kaizen Hub", Subtitle = "Loading scripts...", Duration = 2 })

      local Window = KaizenUI:CreateWindow({
          Title = "KaizenHub",
          SubTitle = "[ UPD ] · A Sobreviva o Apocalipse · Delta",
          TabWidth = 180,
      })
      local Tab     = Window:AddTab({ Title = "Visuals", Icon = "eye" })
      local Section = Tab:AddSection("ESP")
      Section:AddToggle("ItemESP", { Title = "Item ESP", Description = "Highlights items in the world.", Callback = function(v) end })
]]

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 5) or nil

----------------------------------------------------------------
-- Theme (flat dark, no glassmorphism)
----------------------------------------------------------------
local Theme = {
    Background     = Color3.fromRGB(16, 16, 18),     -- main window
    Surface        = Color3.fromRGB(16, 16, 18),     -- sidebar (matches bg for seamless look)
    Elevated       = Color3.fromRGB(24, 24, 28),     -- cards / raised controls
    Hover          = Color3.fromRGB(30, 30, 34),
    Active         = Color3.fromRGB(34, 34, 40),     -- active sidebar item
    LogoBG         = Color3.fromRGB(26, 26, 30),     -- logo backplate
    Border         = Color3.fromRGB(38, 38, 44),
    BorderSubtle   = Color3.fromRGB(28, 28, 32),
    Divider        = Color3.fromRGB(36, 36, 42),
    Text           = Color3.fromRGB(245, 245, 250),
    SubText        = Color3.fromRGB(161, 161, 170),
    Muted          = Color3.fromRGB(115, 115, 125),
    Accent         = Color3.fromRGB(255, 255, 255),
    ToggleOff      = Color3.fromRGB(48, 48, 54),
    ToggleOn       = Color3.fromRGB(240, 240, 245),
    SliderTrack    = Color3.fromRGB(38, 38, 44),
    SliderFill     = Color3.fromRGB(240, 240, 245),
    Danger         = Color3.fromRGB(239, 68, 68),
    Success        = Color3.fromRGB(34, 197, 94),
    Warn           = Color3.fromRGB(234, 179, 8),
}

local FontSans = Enum.Font.Gotham
local FontBold = Enum.Font.GothamBold
local FontSemi = Enum.Font.GothamMedium

----------------------------------------------------------------
-- Icons (Lucide — asset IDs resolved from the Icons library)
----------------------------------------------------------------
local Icons = {
    activity         = "rbxassetid://10709752035",
    backpack         = "rbxassetid://10709769841",
    ["chevron-down"] = "rbxassetid://10709790948",
    ["chevron-up"]   = "rbxassetid://10709791523",
    cog              = "rbxassetid://10709810948",
    crosshair        = "rbxassetid://10709818534",
    eye              = "rbxassetid://10723346959",
    info             = "rbxassetid://10723415903",
    loader           = "rbxassetid://10723434070",
    minus            = "rbxassetid://10734896206",
    package          = "rbxassetid://10734909540",
    refresh          = "rbxassetid://10734933222",
    ["refresh-cw"]   = "rbxassetid://10734933222",
    save             = "rbxassetid://10734941499",
    settings         = "rbxassetid://10734950309",
    shield           = "rbxassetid://10734951847",
    sword            = "rbxassetid://10734975486",
    swords           = "rbxassetid://10734975692",
    target           = "rbxassetid://10734977012",
    user             = "rbxassetid://10747373176",
    x                = "rbxassetid://10747384394",
    zap              = "rbxassetid://10709752035",
}

local LOGO_ASSET = "rbxassetid://124205601170943"

local function resolveIcon(key)
    if not key or key == "" then return "" end
    key = tostring(key)
    if key:match("^rbxassetid://") or key:match("^rbxasset://") or key:match("^http") then
        return key
    end
    if tonumber(key) then
        return "rbxassetid://" .. key
    end
    return Icons[key:lower()] or ""
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function padding(obj, top, right, bottom, left)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top or 0)
    p.PaddingRight  = UDim.new(0, right or 0)
    p.PaddingBottom = UDim.new(0, bottom or 0)
    p.PaddingLeft   = UDim.new(0, left or 0)
    p.Parent = obj
    return p
end

local function tween(obj, time, props, style, dir)
    local info = TweenInfo.new(
        time or 0.2,
        style or Enum.EasingStyle.Quint,
        dir   or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

----------------------------------------------------------------
-- Dotted rotating spinner (Kaizen-branded loader)
----------------------------------------------------------------
local function makeSpinner(parent, size, color)
    size = size or 28
    color = color or Theme.Text

    local Holder = new("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    local dots = 8
    local dotSize = math.max(3, math.floor(size / 8))
    local radius  = (size / 2) - (dotSize / 2) - 1

    for i = 1, dots do
        local angle = math.rad((i - 1) * (360 / dots))
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        local dot = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, x, 0.5, y),
            Size = UDim2.fromOffset(dotSize, dotSize),
            BackgroundColor3 = color,
            BackgroundTransparency = (i - 1) / dots,
            BorderSizePixel = 0,
            Parent = Holder,
        })
        corner(dot, dotSize)
    end

    -- Rotate by rotating the holder itself
    local rotator = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = Holder,
    })
    -- reparent dots under rotator for clean rotation
    for _, d in ipairs(Holder:GetChildren()) do
        if d ~= rotator and d:IsA("Frame") then
            d.Parent = rotator
        end
    end

    local running = true
    task.spawn(function()
        while running and rotator.Parent do
            rotator.Rotation = (rotator.Rotation + 6) % 360
            RunService.Heartbeat:Wait()
        end
    end)

    return Holder, function() running = false end
end

----------------------------------------------------------------
-- Drag (mouse + touch)
----------------------------------------------------------------
local function makeDraggable(handle, target)
    local state = { isDragging = false, moved = false }
    local dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            state.isDragging = true
            state.moved = false
            dragStart = input.Position
            startPos  = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    state.isDragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if state.isDragging and input == dragInput then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
                state.moved = true
            end
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    return state
end

----------------------------------------------------------------
-- Parent detection (gethui → CoreGui → PlayerGui)
----------------------------------------------------------------
local function parentGui(guiName)
    local gui = new("ScreenGui", {
        Name = guiName or "KaizenUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    })
    local function tryParent(target)
        if not target then return false end
        local ok = pcall(function()
            local existing = target:FindFirstChild(gui.Name)
            if existing then existing:Destroy() end
            gui.Parent = target
        end)
        return ok and gui.Parent == target
    end
    local parented = false
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok then parented = tryParent(hui) end
    end
    if not parented then parented = tryParent(CoreGui) end
    if not parented then parented = tryParent(PlayerGui) end
    if not parented then
        warn("[KaizenUI] Could not parent ScreenGui; falling back to PlayerGui")
        gui.Parent = PlayerGui
    end
    return gui
end

----------------------------------------------------------------
-- KaizenUI root + Options registry (Fluent-compatible)
----------------------------------------------------------------
local KaizenUI = {}
KaizenUI.Options = {}

----------------------------------------------------------------
-- Branded logo badge (rounded dark square with "K" logo image)
----------------------------------------------------------------
local function makeLogoBadge(parent, size, logoId)
    size = size or 36
    local Badge = new("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Theme.LogoBG,
        BorderSizePixel = 0,
        Parent = parent,
    })
    corner(Badge, math.floor(size * 0.28))
    stroke(Badge, Theme.Border, 1, 0.2)

    local Img = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(math.floor(size * 0.62), math.floor(size * 0.62)),
        BackgroundTransparency = 1,
        Image = logoId or LOGO_ASSET,
        ImageColor3 = Theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        Parent = Badge,
    })
    return Badge, Img
end

----------------------------------------------------------------
-- Loader (branded splash screen with dotted ring + K badge)
----------------------------------------------------------------
function KaizenUI:Loader(opts)
    opts = opts or {}
    local title    = opts.Title    or "Kaizen Hub"
    local subtitle = opts.Subtitle or "Injecting..."
    local logoId   = opts.LogoId   or LOGO_ASSET
    local duration = tonumber(opts.Duration) or 1.8

    local gui = parentGui("KaizenUI_Loader")
    gui.DisplayOrder = 10000

    -- Dim backdrop
    local Dim = new("Frame", {
        Name = "Dim",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = gui,
    })

    local Card = new("Frame", {
        Name = "Card",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 120),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(Card, 14)
    stroke(Card, Theme.Border, 1, 0.2)
    padding(Card, 16, 18, 16, 18)

    -- Left: dotted spinner with K badge inside
    local SpinnerHolder = new("Frame", {
        Size = UDim2.fromOffset(56, 56),
        Position = UDim2.fromOffset(0, 16),
        BackgroundTransparency = 1,
        Parent = Card,
    })
    local spinner, stopSpinner = makeSpinner(SpinnerHolder, 56, Theme.Text)
    spinner.Position = UDim2.fromScale(0.5, 0.5)
    spinner.AnchorPoint = Vector2.new(0.5, 0.5)

    local Badge, BadgeImg = makeLogoBadge(SpinnerHolder, 30, logoId)
    Badge.AnchorPoint = Vector2.new(0.5, 0.5)
    Badge.Position = UDim2.fromScale(0.5, 0.5)
    Badge.BackgroundColor3 = Theme.LogoBG
    BadgeImg.ImageTransparency = 0
    BadgeImg.ImageColor3 = Theme.Text

    -- Right: title + subtitle + progress
    local TextCol = new("Frame", {
        Position = UDim2.fromOffset(72, 10),
        Size = UDim2.new(1, -72, 1, -20),
        BackgroundTransparency = 1,
        Parent = Card,
    })

    local TitleLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = TextCol,
    })

    local SubLbl = new("TextLabel", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = Theme.SubText,
        Font = FontSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = TextCol,
    })

    local BarBg = new("Frame", {
        Position = UDim2.new(0, 0, 1, -6),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        Parent = TextCol,
    })
    corner(BarBg, 2)
    local Bar = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = BarBg,
    })
    corner(Bar, 2)

    -- Animate in
    tween(Dim,  0.25, { BackgroundTransparency = 0.5 })
    tween(Card, 0.3,  { BackgroundTransparency = 0 })
    tween(TitleLbl, 0.3, { TextTransparency = 0 })
    tween(SubLbl,   0.3, { TextTransparency = 0 })
    tween(Bar, duration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)

    task.wait(duration)
    stopSpinner()

    tween(Dim,  0.25, { BackgroundTransparency = 1 })
    tween(Card, 0.25, { BackgroundTransparency = 1 })
    tween(TitleLbl, 0.2, { TextTransparency = 1 })
    tween(SubLbl,   0.2, { TextTransparency = 1 })
    task.wait(0.28)
    gui:Destroy()
end

----------------------------------------------------------------
-- Notify (flat toast stack in top-right)
----------------------------------------------------------------
local NotifyGui
local NotifyList
local function ensureNotifyGui()
    if NotifyGui and NotifyGui.Parent then return end
    NotifyGui = parentGui("KaizenUI_Notify")
    NotifyGui.DisplayOrder = 9999
    NotifyList = new("Frame", {
        Name = "List",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.new(0, 300, 1, -32),
        BackgroundTransparency = 1,
        Parent = NotifyGui,
    })
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = NotifyList
end

function KaizenUI:Notify(opts)
    opts = opts or {}
    ensureNotifyGui()
    local title    = opts.Title    or "Notification"
    local content  = opts.Content  or ""
    local duration = tonumber(opts.Duration) or 4

    local Card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Elevated,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = NotifyList,
    })
    corner(Card, 12)
    stroke(Card, Theme.Border, 1, 0.15)
    padding(Card, 12, 14, 12, 14)

    local TitleLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = Card,
    })
    local ContentLbl = new("TextLabel", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = Theme.SubText,
        Font = FontSans,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        Parent = Card,
    })

    tween(Card,       0.22, { BackgroundTransparency = 0 })
    tween(TitleLbl,   0.22, { TextTransparency = 0 })
    tween(ContentLbl, 0.22, { TextTransparency = 0.15 })

    task.delay(duration, function()
        if not Card.Parent then return end
        tween(Card,       0.3, { BackgroundTransparency = 1 })
        tween(TitleLbl,   0.3, { TextTransparency = 1 })
        tween(ContentLbl, 0.3, { TextTransparency = 1 })
        task.wait(0.3)
        Card:Destroy()
    end)
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function KaizenUI:CreateWindow(opts)
    opts = opts or {}
    local title    = opts.Title    or "KaizenHub"
    local subtitle = opts.SubTitle or opts.Subtitle or ""
    local logoId   = opts.LogoId   or LOGO_ASSET
    local tabW     = tonumber(opts.TabWidth) or 180
    local sizeOpt  = opts.Size

    local gui = parentGui("KaizenUI")

    ----------------------------------------------------------------
    -- Root window (solid, flat)
    ----------------------------------------------------------------
    local Root = new("Frame", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(880, 560),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = gui,
        ClipsDescendants = true,
    })
    corner(Root, 16)
    stroke(Root, Theme.Border, 1, 0.25)

    ----------------------------------------------------------------
    -- TopBar
    ----------------------------------------------------------------
    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local TopBarPad = padding(TopBar, 0, 16, 0, 16)

    local BottomBorder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    -- Branded logo badge
    local LogoWrap = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        Parent = TopBar,
    })
    local LogoBadge, LogoImg = makeLogoBadge(LogoWrap, 34, logoId)
    LogoBadge.Size = UDim2.fromScale(1, 1)

    local TitleLbl = new("TextLabel", {
        Name = "Title",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 46, 0.5, 0),
        Size = UDim2.fromOffset(120, 22),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local SubLbl = new("TextLabel", {
        Name = "Subtitle",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 172, 0.5, 0),
        Size = UDim2.new(1, -260, 0, 18),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = Theme.SubText,
        Font = FontSans,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = TopBar,
    })

    -- Window control buttons (minimize + close) — minimal, flat
    local function makeIconBtn(key, xOffset)
        local btn = new("ImageButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(26, 26),
            BackgroundColor3 = Theme.Elevated,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = resolveIcon(key),
            ImageColor3 = Theme.SubText,
            Parent = TopBar,
        })
        corner(btn, 6)
        btn.MouseEnter:Connect(function()
            tween(btn, 0.15, { BackgroundTransparency = 0, ImageColor3 = Theme.Text })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.15, { BackgroundTransparency = 1, ImageColor3 = Theme.SubText })
        end)
        return btn
    end
    local CloseBtn = makeIconBtn("x", 0)
    local MinBtn   = makeIconBtn("minus", -32)

    ----------------------------------------------------------------
    -- Sidebar (flat, same bg as window)
    ----------------------------------------------------------------
    local Sidebar = new("Frame", {
        Name = "Sidebar",
        Position = UDim2.new(0, 0, 0, 56),
        Size = UDim2.new(0, tabW, 1, -56),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local SidebarPad = padding(Sidebar, 12, 12, 12, 12)

    local SidebarDiv = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    -- Tab scroll list
    local TabList = new("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -68), -- leave room for status pill at bottom
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = Sidebar,
    })
    local tabsLayout = Instance.new("UIListLayout")
    tabsLayout.Padding = UDim.new(0, 4)
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabsLayout.Parent = TabList

    -- Status pill at bottom of sidebar ("Injecting... Please wait")
    local StatusPill = new("Frame", {
        Name = "StatusPill",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Elevated,
        BorderSizePixel = 0,
        Visible = false,
        Parent = Sidebar,
    })
    corner(StatusPill, 10)
    stroke(StatusPill, Theme.Border, 1, 0.3)
    padding(StatusPill, 0, 12, 0, 12)

    local SpinnerWrap = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Parent = StatusPill,
    })
    local statusSpinner, stopStatusSpinner = makeSpinner(SpinnerWrap, 28, Theme.Text)
    statusSpinner.AnchorPoint = Vector2.new(0.5, 0.5)
    statusSpinner.Position = UDim2.fromScale(0.5, 0.5)

    local StatusTitle = new("TextLabel", {
        Position = UDim2.fromOffset(36, 8),
        Size = UDim2.new(1, -40, 0, 18),
        BackgroundTransparency = 1,
        Text = "Injecting...",
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = StatusPill,
    })
    local StatusSub = new("TextLabel", {
        Position = UDim2.fromOffset(36, 26),
        Size = UDim2.new(1, -40, 0, 16),
        BackgroundTransparency = 1,
        Text = "Please wait",
        TextColor3 = Theme.SubText,
        Font = FontSans,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = StatusPill,
    })

    ----------------------------------------------------------------
    -- Content area
    ----------------------------------------------------------------
    local Content = new("Frame", {
        Name = "Content",
        Position = UDim2.new(0, tabW, 0, 56),
        Size = UDim2.new(1, -tabW, 1, -56),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local ContentPad = padding(Content, 22, 28, 22, 28)

    local Pages = new("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = Content,
    })

    ----------------------------------------------------------------
    -- Dragging (header) + minimize to pill
    ----------------------------------------------------------------
    makeDraggable(TopBar, Root)

    local Pill = new("ImageButton", {
        Name = "MinPill",
        Visible = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(56, 56),
        BackgroundColor3 = Theme.LogoBG,
        BorderSizePixel = 0,
        Image = logoId,
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        Parent = gui,
    })
    corner(Pill, 14)
    stroke(Pill, Theme.Border, 1, 0.2)
    padding(Pill, 10, 10, 10, 10)
    local pillDrag = makeDraggable(Pill, Pill)

    local minimized = false
    local lastSize  = Root.Size
    local function openFromMin()
        if not minimized then return end
        minimized = false
        Root.Visible = true
        Root.Position = Pill.Position
        Root.Size = UDim2.fromOffset(0, 0)
        tween(Root, 0.25, { Size = lastSize })
        Pill.Visible = false
    end

    MinBtn.MouseButton1Click:Connect(function()
        if minimized then
            openFromMin()
        else
            minimized = true
            lastSize = Root.Size
            Pill.Position = Root.Position
            Pill.Visible = true
            Pill.Size = UDim2.fromOffset(0, 0)
            Root.Visible = false
            tween(Pill, 0.22, { Size = UDim2.fromOffset(56, 56) })
        end
    end)

    Pill.MouseButton1Click:Connect(function()
        if pillDrag and pillDrag.moved then
            pillDrag.moved = false
            return
        end
        openFromMin()
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        tween(Root, 0.2, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
        task.wait(0.22)
        if stopStatusSpinner then stopStatusSpinner() end
        gui:Destroy()
    end)

    ----------------------------------------------------------------
    -- Responsive sizing (PC / laptop / mobile)
    ----------------------------------------------------------------
    local function isTouchOnly()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    local function updateResponsive()
        local cam = Workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
        local touch  = isTouchOnly()
        local small  = vp.X < 820 or vp.Y < 540
        local narrow = touch or small

        SubLbl.Visible = (vp.X >= 720) and subtitle ~= ""

        if narrow then
            local w = math.clamp(math.floor(vp.X * 0.94), 340, 620)
            local h = math.clamp(math.floor(vp.Y * 0.86), 360, 520)
            if sizeOpt and typeof(sizeOpt) == "UDim2" then
                if sizeOpt.X.Offset > 0 then w = math.min(w, sizeOpt.X.Offset) end
                if sizeOpt.Y.Offset > 0 then h = math.min(h, sizeOpt.Y.Offset) end
            end
            Root.Size = UDim2.fromOffset(w, h)

            local sw = math.clamp(math.floor(w * 0.34), 120, 170)
            Sidebar.Size     = UDim2.new(0, sw, 1, -52)
            Content.Size     = UDim2.new(1, -sw, 1, -52)
            Content.Position = UDim2.new(0, sw, 0, 52)

            TopBar.Size = UDim2.new(1, 0, 0, 52)
            Sidebar.Position = UDim2.new(0, 0, 0, 52)

            ContentPad.PaddingTop    = UDim.new(0, 16)
            ContentPad.PaddingBottom = UDim.new(0, 16)
            ContentPad.PaddingLeft   = UDim.new(0, 18)
            ContentPad.PaddingRight  = UDim.new(0, 18)

            TopBarPad.PaddingLeft  = UDim.new(0, 12)
            TopBarPad.PaddingRight = UDim.new(0, 12)

            TitleLbl.TextSize = 14
            TitleLbl.Size = UDim2.fromOffset(96, 20)
            SubLbl.Position = UDim2.new(0, 148, 0.5, 0)
            SubLbl.TextSize = 11

            SidebarPad.PaddingLeft   = UDim.new(0, 10)
            SidebarPad.PaddingRight  = UDim.new(0, 10)
            SidebarPad.PaddingTop    = UDim.new(0, 10)
            SidebarPad.PaddingBottom = UDim.new(0, 10)

            StatusPill.Size = UDim2.new(1, 0, 0, 52)
        else
            local w = 880
            local h = 560
            if sizeOpt and typeof(sizeOpt) == "UDim2" then
                if sizeOpt.X.Offset > 0 then w = sizeOpt.X.Offset end
                if sizeOpt.Y.Offset > 0 then h = sizeOpt.Y.Offset end
            end
            -- Clamp to viewport with comfortable margin
            w = math.min(w, math.floor(vp.X * 0.92))
            h = math.min(h, math.floor(vp.Y * 0.92))
            Root.Size = UDim2.fromOffset(w, h)

            Sidebar.Size     = UDim2.new(0, tabW, 1, -56)
            Content.Size     = UDim2.new(1, -tabW, 1, -56)
            Content.Position = UDim2.new(0, tabW, 0, 56)
            Sidebar.Position = UDim2.new(0, 0, 0, 56)

            TopBar.Size = UDim2.new(1, 0, 0, 56)

            ContentPad.PaddingTop    = UDim.new(0, 22)
            ContentPad.PaddingBottom = UDim.new(0, 22)
            ContentPad.PaddingLeft   = UDim.new(0, 28)
            ContentPad.PaddingRight  = UDim.new(0, 28)

            TopBarPad.PaddingLeft  = UDim.new(0, 16)
            TopBarPad.PaddingRight = UDim.new(0, 16)

            TitleLbl.TextSize = 16
            TitleLbl.Size = UDim2.fromOffset(120, 22)
            SubLbl.Position = UDim2.new(0, 172, 0.5, 0)
            SubLbl.TextSize = 13

            SidebarPad.PaddingLeft   = UDim.new(0, 12)
            SidebarPad.PaddingRight  = UDim.new(0, 12)
            SidebarPad.PaddingTop    = UDim.new(0, 12)
            SidebarPad.PaddingBottom = UDim.new(0, 12)

            StatusPill.Size = UDim2.new(1, 0, 0, 56)
        end
    end

    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive)
    end
    UserInputService.LastInputTypeChanged:Connect(updateResponsive)
    updateResponsive()

    ----------------------------------------------------------------
    -- Window object
    ----------------------------------------------------------------
    local Window = {}
    Window.Tabs = {}
    Window._ordered = {}
    Window._activeTab = nil
    Window.ScreenGui = gui
    Window.Root = Root

    -- Status pill public API
    function Window:SetStatus(opts)
        opts = opts or {}
        if opts.Visible == false then
            tween(StatusPill, 0.2, { BackgroundTransparency = 1 })
            task.delay(0.22, function()
                if StatusPill.Parent then StatusPill.Visible = false end
            end)
            return
        end
        StatusTitle.Text = tostring(opts.Title    or "Injecting...")
        StatusSub.Text   = tostring(opts.Subtitle or "Please wait")
        StatusPill.Visible = true
        StatusPill.BackgroundTransparency = 1
        tween(StatusPill, 0.2, { BackgroundTransparency = 0 })
    end
    function Window:HideStatus()
        self:SetStatus({ Visible = false })
    end

    ----------------------------------------------------------------
    -- Page title block ("Visuals / Adjust visual enhancements...")
    ----------------------------------------------------------------
    local function buildPageHeader(page, name, desc)
        local Header = new("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundTransparency = 1,
            LayoutOrder = -1000,
            Parent = page,
        })
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.Text,
            Font = FontBold,
            TextSize = 24,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Header,
        })
        new("TextLabel", {
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = desc or "",
            TextColor3 = Theme.SubText,
            Font = FontSans,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Header,
        })
        new("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.Divider,
            BorderSizePixel = 0,
            Parent = Header,
        })
    end

    local function selectTab(tab)
        if Window._activeTab == tab then return end
        for _, t in ipairs(Window._ordered) do
            tween(t._button, 0.15, { BackgroundTransparency = 1 })
            tween(t._label,  0.15, { TextColor3 = Theme.SubText })
            tween(t._icon,   0.15, { ImageColor3 = Theme.SubText })
            t._page.Visible = false
        end
        Window._activeTab = tab
        tween(tab._button, 0.18, { BackgroundColor3 = Theme.Active, BackgroundTransparency = 0 })
        tween(tab._label,  0.18, { TextColor3 = Theme.Text })
        tween(tab._icon,   0.18, { ImageColor3 = Theme.Text })
        tab._page.Visible = true
    end

    function Window:AddTab(config)
        config = config or {}
        local name = config.Title or config.Name or "Tab"
        local desc = config.Description
        local iconKey = config.Icon

        local Tab = {}
        Tab.Name = name

        -- Sidebar button
        local Btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Theme.Active,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            BorderSizePixel = 0,
            Parent = TabList,
        })
        corner(Btn, 10)

        local IconImg = new("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Image = resolveIcon(iconKey),
            ImageColor3 = Theme.SubText,
            Parent = Btn,
        })

        local Lbl = new("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 40, 0.5, 0),
            Size = UDim2.new(1, -46, 1, 0),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.SubText,
            Font = FontSemi,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = Btn,
        })

        Btn.MouseEnter:Connect(function()
            if Window._activeTab ~= Tab then
                tween(Btn, 0.15, { BackgroundColor3 = Theme.Hover, BackgroundTransparency = 0 })
                tween(Lbl, 0.15, { TextColor3 = Theme.Text })
                tween(IconImg, 0.15, { ImageColor3 = Theme.Text })
            end
        end)
        Btn.MouseLeave:Connect(function()
            if Window._activeTab ~= Tab then
                tween(Btn, 0.15, { BackgroundTransparency = 1 })
                tween(Lbl, 0.15, { TextColor3 = Theme.SubText })
                tween(IconImg, 0.15, { ImageColor3 = Theme.SubText })
            end
        end)

        -- Page (scrollable)
        local Page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Border,
            ScrollBarImageTransparency = 0.4,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false,
            Parent = Pages,
        })
        padding(Page, 0, 8, 18, 0)
        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 10)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = Page

        buildPageHeader(Page, name, desc or ("Configure " .. name:lower() .. " settings."))

        Tab._button = Btn
        Tab._icon   = IconImg
        Tab._label  = Lbl
        Tab._page   = Page

        Btn.MouseButton1Click:Connect(function() selectTab(Tab) end)

        ----------------------------------------------------------------
        -- Section
        ----------------------------------------------------------------
        function Tab:AddSection(sectionName)
            local Section = {}

            local Container = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = Page,
            })
            local contLayout = Instance.new("UIListLayout")
            contLayout.Padding = UDim.new(0, 8)
            contLayout.SortOrder = Enum.SortOrder.LayoutOrder
            contLayout.Parent = Container

            if sectionName and sectionName ~= "" then
                local Header = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    LayoutOrder = 0,
                    Parent = Container,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = sectionName,
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Header,
                })
            end

            ----------------------------------------------------------------
            -- Card primitive (solid, subtle border, no glass)
            ----------------------------------------------------------------
            local function makeCard(height)
                local Card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, height or 60),
                    BackgroundColor3 = Theme.Elevated,
                    BorderSizePixel = 0,
                    Parent = Container,
                })
                corner(Card, 10)
                stroke(Card, Theme.Border, 1, 0.35)
                padding(Card, 12, 18, 12, 18)
                return Card
            end

            ----------------------------------------------------------------
            -- Toggle
            ----------------------------------------------------------------
            function Section:AddToggle(id, o)
                o = o or {}
                local Card = makeCard(60)

                local hasDesc = o.Description and o.Description ~= ""
                local titleY = hasDesc and 0 or 6

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -70, 0, 18),
                    Position = UDim2.fromOffset(0, titleY),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Toggle",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                if hasDesc then
                    new("TextLabel", {
                        Size = UDim2.new(1, -70, 0, 16),
                        Position = UDim2.fromOffset(0, 20),
                        BackgroundTransparency = 1,
                        Text = o.Description,
                        TextColor3 = Theme.SubText,
                        Font = FontSans,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Card,
                    })
                end

                local Track = new("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(42, 24),
                    BackgroundColor3 = Theme.ToggleOff,
                    BorderSizePixel = 0,
                    Parent = Card,
                })
                corner(Track, 12)

                local Knob = new("Frame", {
                    Position = UDim2.fromOffset(3, 3),
                    Size = UDim2.fromOffset(18, 18),
                    BackgroundColor3 = Theme.Text,
                    BorderSizePixel = 0,
                    Parent = Track,
                })
                corner(Knob, 9)

                local HitBtn = new("TextButton", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "",
                    Parent = Card,
                })

                local api = { Value = o.Default and true or false }

                local function render()
                    if api.Value then
                        tween(Track, 0.18, { BackgroundColor3 = Theme.ToggleOn })
                        tween(Knob,  0.18, { Position = UDim2.fromOffset(21, 3), BackgroundColor3 = Color3.fromRGB(12,12,14) })
                    else
                        tween(Track, 0.18, { BackgroundColor3 = Theme.ToggleOff })
                        tween(Knob,  0.18, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Theme.Text })
                    end
                end
                render()

                function api:SetValue(v)
                    api.Value = v and true or false
                    render()
                    if o.Callback then task.spawn(o.Callback, api.Value) end
                end

                HitBtn.MouseButton1Click:Connect(function()
                    api:SetValue(not api.Value)
                end)

                if id then KaizenUI.Options[id] = api end
                if o.Default ~= nil and o.Callback then
                    task.spawn(o.Callback, api.Value)
                end
                return api
            end

            ----------------------------------------------------------------
            -- Slider
            ----------------------------------------------------------------
            function Section:AddSlider(id, o)
                o = o or {}
                local min  = tonumber(o.Min) or 0
                local max  = tonumber(o.Max) or 100
                local round = tonumber(o.Rounding) or 0
                local default = tonumber(o.Default) or min

                local Card = makeCard(64)

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -70, 0, 18),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Slider",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                local ValueLbl = new("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.fromOffset(64, 18),
                    BackgroundTransparency = 1,
                    Text = tostring(default),
                    TextColor3 = Theme.SubText,
                    Font = FontSemi,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Card,
                })

                local Track = new("Frame", {
                    Position = UDim2.fromOffset(0, 26),
                    Size = UDim2.new(1, 0, 0, 6),
                    BackgroundColor3 = Theme.SliderTrack,
                    BorderSizePixel = 0,
                    Parent = Card,
                })
                corner(Track, 3)

                local Fill = new("Frame", {
                    Size = UDim2.fromScale(0, 1),
                    BackgroundColor3 = Theme.SliderFill,
                    BorderSizePixel = 0,
                    Parent = Track,
                })
                corner(Fill, 3)

                local Hit = new("TextButton", {
                    Position = UDim2.fromOffset(0, 18),
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Parent = Card,
                })

                local api = { Value = default }

                local function fmt(v)
                    if round == 0 then return tostring(math.floor(v)) end
                    return string.format("%." .. round .. "f", v)
                end

                local function apply(v, silent)
                    v = math.clamp(v, min, max)
                    if round > 0 then
                        local mult = 10 ^ round
                        v = math.floor(v * mult + 0.5) / mult
                    else
                        v = math.floor(v + 0.5)
                    end
                    api.Value = v
                    local frac = (v - min) / math.max(1e-6, (max - min))
                    Fill.Size = UDim2.fromScale(frac, 1)
                    ValueLbl.Text = fmt(v)
                    if not silent and o.Callback then task.spawn(o.Callback, v) end
                end
                apply(default, true)

                local dragging = false
                local function setFromX(xPos)
                    local abs = Track.AbsolutePosition.X
                    local sz  = Track.AbsoluteSize.X
                    local frac = math.clamp((xPos - abs) / math.max(1, sz), 0, 1)
                    apply(min + (max - min) * frac)
                end

                Hit.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        setFromX(input.Position.X)
                    end
                end)
                Hit.InputChanged:Connect(function(input)
                    if dragging and (
                        input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch
                    ) then
                        setFromX(input.Position.X)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (
                        input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch
                    ) then
                        setFromX(input.Position.X)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)

                function api:SetValue(v) apply(tonumber(v) or min) end

                if id then KaizenUI.Options[id] = api end
                if o.Default ~= nil and o.Callback then
                    task.spawn(o.Callback, api.Value)
                end
                return api
            end

            ----------------------------------------------------------------
            -- Dropdown
            ----------------------------------------------------------------
            function Section:AddDropdown(id, o)
                o = o or {}
                local Card = makeCard(60)

                local hasDesc = o.Description and o.Description ~= ""
                new("TextLabel", {
                    Size = UDim2.new(1, -160, 0, 18),
                    Position = UDim2.fromOffset(0, hasDesc and 0 or 6),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Dropdown",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                if hasDesc then
                    new("TextLabel", {
                        Size = UDim2.new(1, -160, 0, 16),
                        Position = UDim2.fromOffset(0, 20),
                        BackgroundTransparency = 1,
                        Text = o.Description,
                        TextColor3 = Theme.SubText,
                        Font = FontSans,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Card,
                    })
                end

                local Btn = new("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(140, 32),
                    BackgroundColor3 = Theme.Hover,
                    BorderSizePixel = 0,
                    Text = tostring(o.Default or "Select..."),
                    TextColor3 = Theme.Text,
                    Font = FontSans,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = Card,
                })
                corner(Btn, 8)
                stroke(Btn, Theme.Border, 1, 0.25)
                padding(Btn, 0, 28, 0, 12)
                Btn.TextXAlignment = Enum.TextXAlignment.Left

                local Chev = new("ImageLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundTransparency = 1,
                    Image = resolveIcon("chevron-down"),
                    ImageColor3 = Theme.SubText,
                    Parent = Btn,
                })

                local Menu = new("Frame", {
                    Size = UDim2.fromOffset(140, 0),
                    BackgroundColor3 = Theme.Elevated,
                    BorderSizePixel = 0,
                    Visible = false,
                    ZIndex = 50,
                    Parent = gui,
                })
                corner(Menu, 8)
                stroke(Menu, Theme.Border, 1, 0.15)
                local menuLayout = Instance.new("UIListLayout")
                menuLayout.Padding = UDim.new(0, 2)
                menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
                menuLayout.Parent = Menu
                padding(Menu, 4, 4, 4, 4)

                local api = { Value = o.Default, Values = o.Values or {} }
                local open = false
                local itemBtns = {}

                local function rebuild()
                    for _, c in ipairs(itemBtns) do c:Destroy() end
                    table.clear(itemBtns)
                    for _, v in ipairs(api.Values) do
                        local It = new("TextButton", {
                            Size = UDim2.new(1, 0, 0, 28),
                            BackgroundColor3 = Theme.Hover,
                            BackgroundTransparency = 1,
                            BorderSizePixel = 0,
                            Text = tostring(v),
                            TextColor3 = Theme.Text,
                            Font = FontSans,
                            TextSize = 12,
                            AutoButtonColor = false,
                            Parent = Menu,
                            ZIndex = 51,
                        })
                        corner(It, 6)
                        padding(It, 0, 10, 0, 10)
                        It.TextXAlignment = Enum.TextXAlignment.Left
                        It.MouseEnter:Connect(function() tween(It, 0.1, { BackgroundTransparency = 0 }) end)
                        It.MouseLeave:Connect(function() tween(It, 0.1, { BackgroundTransparency = 1 }) end)
                        It.MouseButton1Click:Connect(function()
                            api.Value = v
                            Btn.Text = tostring(v)
                            open = false
                            tween(Menu, 0.15, { Size = UDim2.fromOffset(140, 0) })
                            tween(Chev, 0.15, { Rotation = 0 })
                            task.wait(0.15)
                            Menu.Visible = false
                            if o.Callback then task.spawn(o.Callback, v) end
                        end)
                        table.insert(itemBtns, It)
                    end
                end
                rebuild()

                local function toggle()
                    open = not open
                    if open then
                        Menu.Visible = true
                        local pos = Btn.AbsolutePosition
                        local sz  = Btn.AbsoluteSize
                        Menu.Size = UDim2.fromOffset(sz.X, 0)
                        Menu.Position = UDim2.fromOffset(pos.X, pos.Y + sz.Y + 4)
                        local h = math.min(#api.Values * 30 + 8, 180)
                        tween(Menu, 0.18, { Size = UDim2.fromOffset(sz.X, h) })
                        tween(Chev, 0.18, { Rotation = 180 })
                    else
                        tween(Menu, 0.15, { Size = UDim2.fromOffset(Btn.AbsoluteSize.X, 0) })
                        tween(Chev, 0.15, { Rotation = 0 })
                        task.wait(0.15)
                        Menu.Visible = false
                    end
                end

                Btn.MouseButton1Click:Connect(toggle)

                function api:SetValue(v)
                    api.Value = v
                    Btn.Text = tostring(v or "Select...")
                    if o.Callback then task.spawn(o.Callback, v) end
                end

                function api:SetValues(list)
                    api.Values = list or {}
                    rebuild()
                end

                if id then KaizenUI.Options[id] = api end
                return api
            end

            ----------------------------------------------------------------
            -- Input
            ----------------------------------------------------------------
            function Section:AddInput(id, o)
                o = o or {}
                local Card = makeCard(60)

                new("TextLabel", {
                    Size = UDim2.new(1, -160, 0, 18),
                    Position = UDim2.fromOffset(0, 6),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Input",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })

                local Box = new("TextBox", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(140, 32),
                    BackgroundColor3 = Theme.Hover,
                    BorderSizePixel = 0,
                    Text = tostring(o.Default or ""),
                    PlaceholderText = o.Placeholder or "",
                    PlaceholderColor3 = Theme.Muted,
                    TextColor3 = Theme.Text,
                    Font = FontSans,
                    TextSize = 12,
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                corner(Box, 8)
                local boxStroke = stroke(Box, Theme.Border, 1, 0.25)
                padding(Box, 0, 10, 0, 10)

                Box.Focused:Connect(function()
                    tween(boxStroke, 0.15, { Color = Theme.Text, Transparency = 0 })
                end)
                Box.FocusLost:Connect(function()
                    tween(boxStroke, 0.15, { Color = Theme.Border, Transparency = 0.25 })
                end)

                local api = { Value = Box.Text }
                local function fire(text)
                    api.Value = text
                    if o.Callback then task.spawn(o.Callback, text) end
                end

                if o.Finished then
                    Box.FocusLost:Connect(function(enter)
                        if enter then fire(Box.Text) end
                    end)
                else
                    Box:GetPropertyChangedSignal("Text"):Connect(function()
                        fire(Box.Text)
                    end)
                end

                function api:SetValue(v)
                    Box.Text = tostring(v or "")
                    fire(Box.Text)
                end

                if id then KaizenUI.Options[id] = api end
                return api
            end

            ----------------------------------------------------------------
            -- Button
            ----------------------------------------------------------------
            function Section:AddButton(o)
                o = o or {}
                local Card = makeCard(60)

                local hasDesc = o.Description and o.Description ~= ""
                new("TextLabel", {
                    Size = UDim2.new(1, -120, 0, 18),
                    Position = UDim2.fromOffset(0, hasDesc and 0 or 6),
                    BackgroundTransparency = 1,
                    Text = o.Title or "Button",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                if hasDesc then
                    new("TextLabel", {
                        Size = UDim2.new(1, -120, 0, 16),
                        Position = UDim2.fromOffset(0, 20),
                        BackgroundTransparency = 1,
                        Text = o.Description,
                        TextColor3 = Theme.SubText,
                        Font = FontSans,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Card,
                    })
                end

                local Btn = new("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(100, 30),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    Text = o.ButtonText or "Run",
                    TextColor3 = Color3.fromRGB(12, 12, 14),
                    Font = FontBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = Card,
                })
                corner(Btn, 8)
                Btn.MouseEnter:Connect(function()
                    tween(Btn, 0.12, { BackgroundColor3 = Color3.fromRGB(230, 230, 235) })
                end)
                Btn.MouseLeave:Connect(function()
                    tween(Btn, 0.12, { BackgroundColor3 = Theme.Accent })
                end)
                Btn.MouseButton1Click:Connect(function()
                    if o.Callback then task.spawn(o.Callback) end
                end)
                return { _button = Btn }
            end

            ----------------------------------------------------------------
            -- Paragraph
            ----------------------------------------------------------------
            function Section:AddParagraph(o)
                o = o or {}
                local Card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Elevated,
                    BorderSizePixel = 0,
                    Parent = Container,
                })
                corner(Card, 10)
                stroke(Card, Theme.Border, 1, 0.35)
                padding(Card, 12, 16, 14, 16)
                local lay = Instance.new("UIListLayout")
                lay.Padding = UDim.new(0, 6)
                lay.SortOrder = Enum.SortOrder.LayoutOrder
                lay.Parent = Card
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = o.Title or "",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = o.Content or "",
                    TextColor3 = Theme.SubText,
                    Font = FontSans,
                    TextSize = 12,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent = Card,
                })
                return {}
            end

            return Section
        end

        ----------------------------------------------------------------
        -- Tab-level convenience wrappers
        ----------------------------------------------------------------
        local rootSection
        local function getRootSection()
            if not rootSection then rootSection = Tab:AddSection(nil) end
            return rootSection
        end
        function Tab:AddButton(o)       return getRootSection():AddButton(o) end
        function Tab:AddParagraph(o)    return getRootSection():AddParagraph(o) end
        function Tab:AddToggle(id, o)   return getRootSection():AddToggle(id, o) end
        function Tab:AddSlider(id, o)   return getRootSection():AddSlider(id, o) end
        function Tab:AddDropdown(id, o) return getRootSection():AddDropdown(id, o) end
        function Tab:AddInput(id, o)    return getRootSection():AddInput(id, o) end

        table.insert(Window._ordered, Tab)
        Window.Tabs[name] = Tab
        if not Window._activeTab then selectTab(Tab) end
        return Tab
    end

    function Window:SelectTab(target)
        if type(target) == "number" then
            local t = Window._ordered[target]
            if t then selectTab(t) end
        elseif type(target) == "string" then
            local t = Window.Tabs[target]
            if t then selectTab(t) end
        end
    end

    function Window:Destroy() gui:Destroy() end
    function Window:Dialog() end -- back-compat

    -- Open animation
    Root.Size = UDim2.fromOffset(0, 0)
    Root.BackgroundTransparency = 1
    updateResponsive()
    local targetSize = Root.Size
    Root.Size = UDim2.fromOffset(math.floor(targetSize.X.Offset * 0.9), math.floor(targetSize.Y.Offset * 0.9))
    Root.BackgroundTransparency = 0
    tween(Root, 0.28, { Size = targetSize }, Enum.EasingStyle.Quint)

    return Window
end

-- Allow both `local X = loadstring(...)(); X:CreateWindow(...)` and
-- `local X = loadstring(...)(); X.KaizenUI:CreateWindow(...)`
KaizenUI.KaizenUI = KaizenUI

return KaizenUI
