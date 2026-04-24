--[[
    KaizenUI — a glassmorphism, Fluent-API-compatible UI library for Roblox.

      • Drop-in replacement for `Fluent`: CreateWindow / AddTab / AddSection /
        AddToggle / AddSlider / AddDropdown / AddInput / AddButton / AddParagraph
        / Notify / Options / SelectTab.
      • Modern dark glass theme with subtle strokes and rounded corners.
      • Built-in branded loader animation (rotating ring + logo).
      • Touch-first sliders that drag reliably on mobile.
      • Draggable window + draggable minimized logo pill.
      • Scrollable sidebar and content pages.
      • Uses your logo (rbxassetid://124205601170943) and Lucide icons.

    Usage:
      local KaizenUI = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/biarzxc1/Kaizen-Hub/refs/heads/main/KaizenUI.lua"
      ))()

      KaizenUI:Loader({ Title = "Kaizen Hub", Subtitle = "Loading scripts...", Duration = 2 })

      local Window = KaizenUI:CreateWindow({
          Title = "Kaizen Hub", SubTitle = "v1.0.0", TabWidth = 160,
      })
      local Tab     = Window:AddTab({ Title = "Combat", Icon = "crosshair" })
      local Section = Tab:AddSection("Aim")
      Section:AddToggle("KillAura", { Title = "Kill Aura", Default = false, Callback = function(v) end })
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
-- Theme (glassmorphism dark)
----------------------------------------------------------------
local Theme = {
    Background     = Color3.fromRGB(10, 10, 12),     -- window shell
    Glass          = Color3.fromRGB(18, 18, 22),     -- frosted surface
    GlassStrong    = Color3.fromRGB(24, 24, 28),     -- sidebar / stronger glass
    Card           = Color3.fromRGB(20, 20, 24),     -- option cards
    CardHover      = Color3.fromRGB(28, 28, 32),
    SidebarActive  = Color3.fromRGB(32, 32, 38),
    Border         = Color3.fromRGB(48, 48, 56),
    BorderSubtle   = Color3.fromRGB(32, 32, 38),
    Text           = Color3.fromRGB(245, 245, 250),
    SubText        = Color3.fromRGB(161, 161, 170),
    Muted          = Color3.fromRGB(115, 115, 125),
    Accent         = Color3.fromRGB(255, 255, 255),
    ToggleOff      = Color3.fromRGB(44, 44, 52),
    ToggleOn       = Color3.fromRGB(240, 240, 245),
    SliderFill     = Color3.fromRGB(240, 240, 245),
    Danger         = Color3.fromRGB(239, 68, 68),
    Success        = Color3.fromRGB(34, 197, 94),
    Warn           = Color3.fromRGB(234, 179, 8),
}

local FontSans = Enum.Font.Gotham
local FontBold = Enum.Font.GothamBold

----------------------------------------------------------------
-- Icons (Lucide — asset IDs resolved from the Icons library)
----------------------------------------------------------------
local Icons = {
    activity     = "rbxassetid://10709752035",
    backpack     = "rbxassetid://10709769841",
    ["chevron-down"] = "rbxassetid://10709790948",
    ["chevron-up"]   = "rbxassetid://10709791523",
    cog          = "rbxassetid://10709810948",
    crosshair    = "rbxassetid://10709818534",
    eye          = "rbxassetid://10723346959",
    info         = "rbxassetid://10723415903",
    loader       = "rbxassetid://10723434070",
    minus        = "rbxassetid://10734896206",
    package      = "rbxassetid://10734909540",
    refresh      = "rbxassetid://10734933222",
    ["refresh-cw"] = "rbxassetid://10734933222",
    save         = "rbxassetid://10734941499",
    settings     = "rbxassetid://10734950309",
    shield       = "rbxassetid://10734951847",
    sword        = "rbxassetid://10734975486",
    swords       = "rbxassetid://10734975692",
    target       = "rbxassetid://10734977012",
    user         = "rbxassetid://10747373176",
    x            = "rbxassetid://10747384394",
    zap          = "rbxassetid://10709752035", -- reuse activity as fallback
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
        style or Enum.EasingStyle.Quad,
        dir   or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

-- Adds a subtle glassmorphism tint gradient to a frame.
local function glassify(frame, strength)
    strength = strength or 0.12
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
    })
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1 - strength),
        NumberSequenceKeypoint.new(1, 1),
    })
    grad.Rotation = 90
    grad.Parent = frame
    return grad
end

----------------------------------------------------------------
-- Drag (mouse + touch). Returns state so callers can tell a tap
-- from a drag (needed for the minimized-logo click behavior).
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
-- KaizenUI root table + Options registry (Fluent-compatible)
----------------------------------------------------------------
local KaizenUI = {}
KaizenUI.Options = {}

----------------------------------------------------------------
-- Loader (branded splash screen)
----------------------------------------------------------------
function KaizenUI:Loader(opts)
    opts = opts or {}
    local title    = opts.Title    or "Kaizen Hub"
    local subtitle = opts.Subtitle or "Loading scripts..."
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
        Size = UDim2.fromOffset(280, 140),
        BackgroundColor3 = Theme.Glass,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(Card, 16)
    stroke(Card, Theme.Border, 1, 0.35)
    glassify(Card, 0.1)

    -- Logo with a rotating ring behind it
    local LogoHolder = new("Frame", {
        Size = UDim2.fromOffset(64, 64),
        Position = UDim2.fromOffset(24, 38),
        BackgroundTransparency = 1,
        Parent = Card,
    })

    local Ring = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = resolveIcon("loader"),
        ImageColor3 = Theme.Text,
        ImageTransparency = 0.2,
        Parent = LogoHolder,
    })

    local Logo = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1,
        Image = logoId,
        ScaleType = Enum.ScaleType.Fit,
        Parent = LogoHolder,
    })
    corner(Logo, 10)

    -- Title + subtitle
    local TitleLbl = new("TextLabel", {
        Position = UDim2.fromOffset(104, 40),
        Size = UDim2.fromOffset(150, 24),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Card,
    })
    local SubLbl = new("TextLabel", {
        Position = UDim2.fromOffset(104, 64),
        Size = UDim2.fromOffset(150, 18),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = Theme.SubText,
        Font = FontSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Card,
    })

    -- Progress bar
    local BarBg = new("Frame", {
        Position = UDim2.fromOffset(104, 92),
        Size = UDim2.fromOffset(150, 4),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = Card,
    })
    corner(BarBg, 2)
    local Bar = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = BarBg,
    })
    corner(Bar, 2)

    -- Fade in
    Card.BackgroundTransparency = 1
    Dim.BackgroundTransparency = 1
    tween(Dim,  0.25, { BackgroundTransparency = 0.5 })
    tween(Card, 0.25, { BackgroundTransparency = 0.05 })

    -- Rotate the ring
    local running = true
    task.spawn(function()
        while running and Ring.Parent do
            Ring.Rotation = (Ring.Rotation + 4) % 360
            RunService.Heartbeat:Wait()
        end
    end)

    -- Drive the progress bar
    tween(Bar, duration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)

    task.wait(duration)
    running = false

    tween(Dim,  0.25, { BackgroundTransparency = 1 })
    tween(Card, 0.25, { BackgroundTransparency = 1 })
    task.wait(0.25)
    gui:Destroy()
end

----------------------------------------------------------------
-- Notify (toast stack in the top-right)
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
        BackgroundColor3 = Theme.Glass,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = NotifyList,
    })
    corner(Card, 12)
    stroke(Card, Theme.Border, 1, 0.3)
    glassify(Card, 0.1)
    padding(Card, 12, 14, 12, 14)

    local TitleLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
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
        Parent = Card,
    })

    -- Fade in
    Card.BackgroundTransparency = 1
    TitleLbl.TextTransparency = 1
    ContentLbl.TextTransparency = 1
    tween(Card, 0.2, { BackgroundTransparency = 0.05 })
    tween(TitleLbl,  0.2, { TextTransparency = 0 })
    tween(ContentLbl, 0.2, { TextTransparency = 0.2 })

    task.delay(duration, function()
        if not Card.Parent then return end
        tween(Card, 0.3, { BackgroundTransparency = 1 })
        tween(TitleLbl,  0.3, { TextTransparency = 1 })
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
    local title    = opts.Title    or "KaizenUI"
    local subtitle = opts.SubTitle or opts.Subtitle or ""
    local logoId   = opts.LogoId   or LOGO_ASSET
    local tabW     = tonumber(opts.TabWidth) or 160
    local sizeOpt  = opts.Size

    local gui = parentGui("KaizenUI")

    ----------------------------------------------------------------
    -- Root window
    ----------------------------------------------------------------
    local Root = new("Frame", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(820, 520),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = gui,
        ClipsDescendants = true,
    })
    corner(Root, 14)
    stroke(Root, Theme.Border, 1, 0.4)
    glassify(Root, 0.08)

    -- TopBar
    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.GlassStrong,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local TopBarPad = padding(TopBar, 0, 14, 0, 14)

    local BottomBorder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    local Logo = new("ImageLabel", {
        Name = "Logo",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Image = logoId,
        ScaleType = Enum.ScaleType.Fit,
        Parent = TopBar,
    })
    corner(Logo, 8)

    local TitleLbl = new("TextLabel", {
        Name = "Title",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 38, 0.5, 0),
        Size = UDim2.fromOffset(140, 24),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = FontBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })
    local SubLbl = new("TextLabel", {
        Name = "Subtitle",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 180, 0.5, 0),
        Size = UDim2.new(1, -260, 0, 18),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = Theme.SubText,
        Font = FontSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = TopBar,
    })

    -- Minimize + Close
    local function makeIconBtn(key, xOffset)
        local btn = new("ImageButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(24, 24),
            BackgroundColor3 = Theme.Card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Image = resolveIcon(key),
            ImageColor3 = Theme.Text,
            Parent = TopBar,
        })
        corner(btn, 6)
        btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundTransparency = 0.1 }) end)
        btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundTransparency = 0.5 }) end)
        return btn
    end
    local CloseBtn = makeIconBtn("x", 0)
    local MinBtn   = makeIconBtn("minus", -32)

    -- Sidebar
    local Sidebar = new("Frame", {
        Name = "Sidebar",
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(0, tabW, 1, -48),
        BackgroundColor3 = Theme.GlassStrong,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local SidebarPad = padding(Sidebar, 10, 10, 10, 10)
    local SidebarDiv = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    local TabList = new("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = Sidebar,
    })
    local tabsLayout = Instance.new("UIListLayout")
    tabsLayout.Padding = UDim.new(0, 4)
    tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabsLayout.Parent = TabList

    -- Content
    local Content = new("Frame", {
        Name = "Content",
        Position = UDim2.new(0, tabW, 0, 48),
        Size = UDim2.new(1, -tabW, 1, -48),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local ContentPad = padding(Content, 18, 18, 18, 18)

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
        BackgroundColor3 = Theme.Glass,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Image = logoId,
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        Parent = gui,
    })
    corner(Pill, 14)
    stroke(Pill, Theme.Border, 1, 0.3)
    glassify(Pill, 0.08)
    padding(Pill, 8, 8, 8, 8)
    local pillDrag = makeDraggable(Pill, Pill)

    local minimized = false
    local lastSize  = Root.Size
    local function openFromMin()
        if not minimized then return end
        minimized = false
        Root.Visible = true
        Root.Position = Pill.Position
        Root.Size = UDim2.fromOffset(0, 0)
        tween(Root, 0.22, { Size = lastSize })
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
            tween(Pill, 0.2, { Size = UDim2.fromOffset(56, 56) })
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
        tween(Root, 0.18, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
        task.wait(0.2)
        gui:Destroy()
    end)

    ----------------------------------------------------------------
    -- Responsive sizing
    ----------------------------------------------------------------
    local function isTouchOnly()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end

    local function updateResponsive()
        local cam = Workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
        local narrow = isTouchOnly() or vp.X < 900 or vp.Y < 560

        SubLbl.Visible = not narrow and subtitle ~= ""

        if narrow then
            local w = math.clamp(math.floor(vp.X * 0.92), 320, 600)
            local h = math.clamp(math.floor(vp.Y * 0.86), 340, 500)
            if sizeOpt and typeof(sizeOpt) == "UDim2" then
                w = math.min(w, sizeOpt.X.Offset > 0 and sizeOpt.X.Offset or w)
                h = math.min(h, sizeOpt.Y.Offset > 0 and sizeOpt.Y.Offset or h)
            end
            Root.Size = UDim2.fromOffset(w, h)

            local sw = math.clamp(math.floor(w * 0.32), 110, 160)
            Sidebar.Size     = UDim2.new(0, sw, 1, -48)
            Content.Size     = UDim2.new(1, -sw, 1, -48)
            Content.Position = UDim2.new(0, sw, 0, 48)

            ContentPad.PaddingTop    = UDim.new(0, 12)
            ContentPad.PaddingBottom = UDim.new(0, 12)
            ContentPad.PaddingLeft   = UDim.new(0, 14)
            ContentPad.PaddingRight  = UDim.new(0, 14)

            TopBarPad.PaddingLeft  = UDim.new(0, 10)
            TopBarPad.PaddingRight = UDim.new(0, 10)

            TitleLbl.TextSize = 14
            TitleLbl.Size = UDim2.fromOffset(100, 22)

            SidebarPad.PaddingLeft   = UDim.new(0, 8)
            SidebarPad.PaddingRight  = UDim.new(0, 8)
            SidebarPad.PaddingTop    = UDim.new(0, 8)
            SidebarPad.PaddingBottom = UDim.new(0, 8)
        else
            local w = 820
            local h = 520
            if sizeOpt and typeof(sizeOpt) == "UDim2" then
                if sizeOpt.X.Offset > 0 then w = sizeOpt.X.Offset end
                if sizeOpt.Y.Offset > 0 then h = sizeOpt.Y.Offset end
            end
            Root.Size = UDim2.fromOffset(w, h)

            Sidebar.Size     = UDim2.new(0, tabW, 1, -48)
            Content.Size     = UDim2.new(1, -tabW, 1, -48)
            Content.Position = UDim2.new(0, tabW, 0, 48)

            ContentPad.PaddingTop    = UDim.new(0, 18)
            ContentPad.PaddingBottom = UDim.new(0, 18)
            ContentPad.PaddingLeft   = UDim.new(0, 18)
            ContentPad.PaddingRight  = UDim.new(0, 18)

            TopBarPad.PaddingLeft  = UDim.new(0, 14)
            TopBarPad.PaddingRight = UDim.new(0, 14)

            TitleLbl.TextSize = 15
            TitleLbl.Size = UDim2.fromOffset(140, 24)

            SidebarPad.PaddingLeft   = UDim.new(0, 10)
            SidebarPad.PaddingRight  = UDim.new(0, 10)
            SidebarPad.PaddingTop    = UDim.new(0, 10)
            SidebarPad.PaddingBottom = UDim.new(0, 10)
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

    local function selectTab(tab)
        if Window._activeTab == tab then return end
        for _, t in ipairs(Window._ordered) do
            t._button.BackgroundTransparency = 1
            t._label.TextColor3 = Theme.SubText
            t._icon.ImageColor3 = Theme.SubText
            t._page.Visible = false
        end
        Window._activeTab = tab
        tab._button.BackgroundTransparency = 0
        tween(tab._button, 0.15, { BackgroundColor3 = Theme.SidebarActive })
        tab._label.TextColor3 = Theme.Text
        tab._icon.ImageColor3 = Theme.Text
        tab._page.Visible = true
    end

    function Window:AddTab(config)
        config = config or {}
        local name = config.Title or config.Name or "Tab"
        local iconKey = config.Icon

        local Tab = {}
        Tab.Name = name

        -- Sidebar button
        local Btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Theme.SidebarActive,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            BorderSizePixel = 0,
            Parent = TabList,
        })
        corner(Btn, 8)

        local IconImg = new("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            Image = resolveIcon(iconKey),
            ImageColor3 = Theme.SubText,
            Parent = Btn,
        })

        local Lbl = new("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 34, 0.5, 0),
            Size = UDim2.new(1, -40, 1, 0),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = Theme.SubText,
            Font = FontBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = Btn,
        })

        Btn.MouseEnter:Connect(function()
            if Window._activeTab ~= Tab then
                tween(Btn, 0.12, { BackgroundTransparency = 0.6 })
            end
        end)
        Btn.MouseLeave:Connect(function()
            if Window._activeTab ~= Tab then
                tween(Btn, 0.12, { BackgroundTransparency = 1 })
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
        -- Balanced padding on both sides so cards never stitch to the
        -- window edge (this fixes the "Combat" card-clipping bug).
        padding(Page, 2, 10, 14, 2)
        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 10)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = Page

        Tab._button = Btn
        Tab._icon   = IconImg
        Tab._label  = Lbl
        Tab._page   = Page
        Tab._layoutOrder = 0

        Btn.MouseButton1Click:Connect(function() selectTab(Tab) end)

        ----------------------------------------------------------------
        -- Section (groups related controls under a label + divider)
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
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    LayoutOrder = 0,
                    Parent = Container,
                })
                local HeaderLbl = new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = sectionName,
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Header,
                })
                local Divider = new("Frame", {
                    Position = UDim2.new(0, 0, 1, -1),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Theme.BorderSubtle,
                    BorderSizePixel = 0,
                    Parent = Header,
                })
            end

            ----------------------------------------------------------------
            -- Card primitive shared by all controls
            ----------------------------------------------------------------
            local function makeCard(height)
                local Card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, height or 54),
                    BackgroundColor3 = Theme.Card,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    Parent = Container,
                })
                corner(Card, 10)
                stroke(Card, Theme.BorderSubtle, 1, 0.2)
                padding(Card, 10, 14, 10, 14)
                return Card
            end

            ----------------------------------------------------------------
            -- Toggle
            ----------------------------------------------------------------
            function Section:AddToggle(id, o)
                o = o or {}
                local Card = makeCard(54)

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -60, 0, 16),
                    Position = UDim2.fromOffset(0, 2),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Toggle",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                if o.Description then
                    new("TextLabel", {
                        Size = UDim2.new(1, -60, 0, 14),
                        Position = UDim2.fromOffset(0, 20),
                        BackgroundTransparency = 1,
                        Text = o.Description,
                        TextColor3 = Theme.SubText,
                        Font = FontSans,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Card,
                    })
                end

                local Track = new("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(40, 22),
                    BackgroundColor3 = Theme.ToggleOff,
                    BorderSizePixel = 0,
                    Parent = Card,
                })
                corner(Track, 11)

                local Knob = new("Frame", {
                    Position = UDim2.fromOffset(2, 2),
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
                        tween(Track, 0.15, { BackgroundColor3 = Theme.ToggleOn })
                        tween(Knob,  0.15, { Position = UDim2.fromOffset(20, 2), BackgroundColor3 = Color3.fromRGB(12,12,14) })
                    else
                        tween(Track, 0.15, { BackgroundColor3 = Theme.ToggleOff })
                        tween(Knob,  0.15, { Position = UDim2.fromOffset(2, 2),  BackgroundColor3 = Theme.Text })
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
            -- Slider (touch-friendly)
            ----------------------------------------------------------------
            function Section:AddSlider(id, o)
                o = o or {}
                local min  = tonumber(o.Min) or 0
                local max  = tonumber(o.Max) or 100
                local round = tonumber(o.Rounding) or 0
                local default = tonumber(o.Default) or min

                local Card = makeCard(58)

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -60, 0, 16),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Slider",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                local ValueLbl = new("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.fromOffset(60, 16),
                    BackgroundTransparency = 1,
                    Text = tostring(default),
                    TextColor3 = Theme.SubText,
                    Font = FontSans,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Card,
                })

                local Track = new("Frame", {
                    Position = UDim2.fromOffset(0, 22),
                    Size = UDim2.new(1, 0, 0, 6),
                    BackgroundColor3 = Theme.BorderSubtle,
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

                -- Enlarged invisible hit area (easier on mobile)
                local Hit = new("TextButton", {
                    Position = UDim2.fromOffset(0, 14),
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Parent = Card,
                })

                local api = { Value = default }

                local function fmt(v)
                    if round == 0 then return tostring(math.floor(v)) end
                    local fmtStr = "%." .. round .. "f"
                    return string.format(fmtStr, v)
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
                    if not silent and o.Callback then
                        task.spawn(o.Callback, v)
                    end
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

                function api:SetValue(v)
                    apply(tonumber(v) or min)
                end

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
                local Card = makeCard(54)

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -160, 0, 16),
                    Position = UDim2.fromOffset(0, 2),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Dropdown",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                if o.Description then
                    new("TextLabel", {
                        Size = UDim2.new(1, -160, 0, 14),
                        Position = UDim2.fromOffset(0, 20),
                        BackgroundTransparency = 1,
                        Text = o.Description,
                        TextColor3 = Theme.SubText,
                        Font = FontSans,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Card,
                    })
                end

                local Btn = new("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(140, 30),
                    BackgroundColor3 = Theme.GlassStrong,
                    BorderSizePixel = 0,
                    Text = tostring(o.Default or "Select..."),
                    TextColor3 = Theme.Text,
                    Font = FontSans,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = Card,
                })
                corner(Btn, 8)
                stroke(Btn, Theme.Border, 1, 0.3)
                padding(Btn, 0, 26, 0, 10)
                Btn.TextXAlignment = Enum.TextXAlignment.Left

                local Chev = new("ImageLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundTransparency = 1,
                    Image = resolveIcon("chevron-down"),
                    ImageColor3 = Theme.SubText,
                    Parent = Btn,
                })

                local Menu = new("Frame", {
                    Size = UDim2.fromOffset(140, 0),
                    BackgroundColor3 = Theme.GlassStrong,
                    BorderSizePixel = 0,
                    Visible = false,
                    ZIndex = 50,
                    Parent = gui,
                })
                corner(Menu, 8)
                stroke(Menu, Theme.Border, 1, 0.2)
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
                            Size = UDim2.new(1, 0, 0, 26),
                            BackgroundColor3 = Theme.Card,
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
                        padding(It, 0, 8, 0, 8)
                        It.TextXAlignment = Enum.TextXAlignment.Left
                        It.MouseEnter:Connect(function() tween(It, 0.1, { BackgroundTransparency = 0.3 }) end)
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
                        local h = math.min(#api.Values * 28 + 8, 160)
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
                local Card = makeCard(54)

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -160, 0, 16),
                    Position = UDim2.fromOffset(0, 2),
                    BackgroundTransparency = 1,
                    Text = o.Title or id or "Input",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })

                local Box = new("TextBox", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(140, 30),
                    BackgroundColor3 = Theme.GlassStrong,
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
                stroke(Box, Theme.Border, 1, 0.3)
                padding(Box, 0, 10, 0, 10)

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
            -- Button (section-scoped)
            ----------------------------------------------------------------
            function Section:AddButton(o)
                o = o or {}
                local Card = makeCard(54)
                Card.BackgroundColor3 = Theme.Card

                local Title = new("TextLabel", {
                    Size = UDim2.new(1, -120, 0, 16),
                    Position = UDim2.fromOffset(0, 2),
                    BackgroundTransparency = 1,
                    Text = o.Title or "Button",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Card,
                })
                if o.Description then
                    new("TextLabel", {
                        Size = UDim2.new(1, -120, 0, 14),
                        Position = UDim2.fromOffset(0, 20),
                        BackgroundTransparency = 1,
                        Text = o.Description,
                        TextColor3 = Theme.SubText,
                        Font = FontSans,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Card,
                    })
                end

                local Btn = new("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(100, 28),
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = 0.05,
                    BorderSizePixel = 0,
                    Text = o.ButtonText or "Run",
                    TextColor3 = Color3.fromRGB(12, 12, 14),
                    Font = FontBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = Card,
                })
                corner(Btn, 8)
                Btn.MouseEnter:Connect(function() tween(Btn, 0.12, { BackgroundTransparency = 0 }) end)
                Btn.MouseLeave:Connect(function() tween(Btn, 0.12, { BackgroundTransparency = 0.05 }) end)
                Btn.MouseButton1Click:Connect(function()
                    if o.Callback then task.spawn(o.Callback) end
                end)
                return { _button = Btn }
            end

            ----------------------------------------------------------------
            -- Paragraph (section-scoped)
            ----------------------------------------------------------------
            function Section:AddParagraph(o)
                o = o or {}
                local Card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Card,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    Parent = Container,
                })
                corner(Card, 10)
                stroke(Card, Theme.BorderSubtle, 1, 0.2)
                padding(Card, 10, 14, 12, 14)
                local lay = Instance.new("UIListLayout")
                lay.Padding = UDim.new(0, 4)
                lay.SortOrder = Enum.SortOrder.LayoutOrder
                lay.Parent = Card
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = o.Title or "",
                    TextColor3 = Theme.Text,
                    Font = FontBold,
                    TextSize = 13,
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
        -- Tab-level convenience wrappers (some scripts add controls
        -- directly on the tab instead of creating an explicit section).
        ----------------------------------------------------------------
        local rootSection
        local function getRootSection()
            if not rootSection then rootSection = Tab:AddSection(nil) end
            return rootSection
        end
        function Tab:AddButton(o)    return getRootSection():AddButton(o)    end
        function Tab:AddParagraph(o) return getRootSection():AddParagraph(o) end
        function Tab:AddToggle(id, o)   return getRootSection():AddToggle(id, o)   end
        function Tab:AddSlider(id, o)   return getRootSection():AddSlider(id, o)   end
        function Tab:AddDropdown(id, o) return getRootSection():AddDropdown(id, o) end
        function Tab:AddInput(id, o)    return getRootSection():AddInput(id, o)    end

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

    -- Back-compat no-ops (SaveManager/InterfaceManager hooks etc.)
    function Window:Dialog() end

    return Window
end

-- Allow both `local X = loadstring(...)() ; X:CreateWindow(...)` and
-- `local X = loadstring(...)() ; X.KaizenUI:CreateWindow(...)`
KaizenUI.KaizenUI = KaizenUI

return KaizenUI
