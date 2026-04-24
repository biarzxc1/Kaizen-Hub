--[[
    KaizenUI — Glassmorphism UI library for Roblox (Fluent-compatible API)

    Highlights:
      • Glassmorphism surfaces (translucent dark frosted cards)
      • True mobile-first responsiveness + viewport clamping
      • Reliable touch drag (window + logo pill) and touch sliders
      • Animated chevron dropdown, hover/press transitions
      • Scrollable sidebar + scrollable pages (no edge-stitched cards)
      • Minimize collapses to JUST a draggable logo pill
      • Built-in loader animation (rotating ring + logo)
      • No profile / nickname / executions card
      • Drop-in Fluent-compatible API:
          Window:AddTab({ Title, Icon })
          Tab:AddSection("Name")
          Section:AddToggle(id, { Title, Default, Callback })
          Section:AddSlider(id, { Title, Default, Min, Max, Rounding, Callback })
          Section:AddButton({ Title, Description, Callback })
          Section:AddDropdown(id, { Title, Values, Multi, Default, Callback })
          Section:AddInput(id, { Title, Default, Placeholder, Numeric, Finished, Callback })
          Section:AddParagraph({ Title, Content })
          KaizenUI:Notify({ Title, Content, Duration })
          KaizenUI.Options[id]:SetValue(v)
          Window:SelectTab(n)

    Logo baked in: rbxassetid://124205601170943
]]

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 5) or nil

----------------------------------------------------------------
-- Theme (glassmorphism dark)
----------------------------------------------------------------
local Theme = {
    -- Solid fallbacks
    Background     = Color3.fromRGB(12, 12, 14),
    Sidebar        = Color3.fromRGB(16, 16, 20),
    SidebarActive  = Color3.fromRGB(32, 32, 40),

    -- Glass surfaces
    Glass          = Color3.fromRGB(22, 22, 28),
    GlassStrong    = Color3.fromRGB(28, 28, 36),
    GlassHighlight = Color3.fromRGB(255, 255, 255), -- used at low alpha for top shine

    Card           = Color3.fromRGB(26, 26, 32),
    CardHover      = Color3.fromRGB(34, 34, 42),

    Border         = Color3.fromRGB(56, 56, 68),
    BorderSubtle   = Color3.fromRGB(38, 38, 48),

    Text           = Color3.fromRGB(248, 248, 252),
    SubText        = Color3.fromRGB(170, 170, 180),
    Muted          = Color3.fromRGB(120, 120, 132),

    ToggleOff      = Color3.fromRGB(48, 48, 58),
    ToggleOn       = Color3.fromRGB(240, 240, 245),
    ToggleKnobOff  = Color3.fromRGB(170, 170, 180),
    ToggleKnobOn   = Color3.fromRGB(12, 12, 14),

    Accent         = Color3.fromRGB(240, 240, 245),
    Danger         = Color3.fromRGB(239, 68, 68),
    Success        = Color3.fromRGB(34, 197, 94),
}

----------------------------------------------------------------
-- Icon map (Lucide / Fluent — Roblox asset IDs)
----------------------------------------------------------------
local Icons = {
    -- navigation / common
    eye          = "rbxassetid://10723346959",
    ["eye-off"]  = "rbxassetid://10723346823",
    user         = "rbxassetid://10747373176",
    users        = "rbxassetid://10747386118",
    swords       = "rbxassetid://10734975692",
    sword        = "rbxassetid://10734975486",
    activity     = "rbxassetid://10709752035",
    zap          = "rbxassetid://10709752035",
    settings     = "rbxassetid://10734950309",
    cog          = "rbxassetid://10709810948",
    home         = "rbxassetid://10723407389",
    shield       = "rbxassetid://10734951847",
    target       = "rbxassetid://10734977012",
    crosshair    = "rbxassetid://10709818534",
    bell         = "rbxassetid://10709775704",
    folder       = "rbxassetid://10723387563",
    palette      = "rbxassetid://10734910430",
    sliders      = "rbxassetid://10734963400",
    info         = "rbxassetid://10723415903",
    search       = "rbxassetid://10734943674",
    power        = "rbxassetid://10734930466",
    save         = "rbxassetid://10734941499",
    trash        = "rbxassetid://10747362393",
    wrench       = "rbxassetid://10747383470",
    code         = "rbxassetid://10709810463",
    keyboard     = "rbxassetid://10723416765",
    mouse        = "rbxassetid://10734898592",
    gamepad      = "rbxassetid://10723395457",
    list         = "rbxassetid://10723433811",
    grid         = "rbxassetid://10723404936",
    loader       = "rbxassetid://10723434070",
    menu         = "rbxassetid://10734887784",
    plus         = "rbxassetid://10734924532",
    minus        = "rbxassetid://10734896206",
    x            = "rbxassetid://10747384394",
    chevron      = "rbxassetid://10709791437",
    ["chevron-down"]  = "rbxassetid://10709791437",
    ["chevron-up"]    = "rbxassetid://10709791551",
    ["chevron-right"] = "rbxassetid://10709791519",
    ["chevron-left"]  = "rbxassetid://10709791471",
    command      = "rbxassetid://10709811365",
    star         = "rbxassetid://10723415099",
    heart        = "rbxassetid://10723404983",
    bolt         = "rbxassetid://10709752035",
    box          = "rbxassetid://10709790642",
    layers       = "rbxassetid://10723431873",
    map          = "rbxassetid://10734858335",
    package      = "rbxassetid://10734898866",
    backpack     = "rbxassetid://10734898866",
    briefcase    = "rbxassetid://10709790900",
    play         = "rbxassetid://10734930410",
    pause        = "rbxassetid://10734910214",
    refresh      = "rbxassetid://10734932288",
    ["rotate-cw"]= "rbxassetid://10734932288",
    rocket       = "rbxassetid://10747386280",
    lock         = "rbxassetid://10723432175",
    unlock       = "rbxassetid://10723432355",
    bug          = "rbxassetid://10709790900",
    flag         = "rbxassetid://10723386423",
    flame        = "rbxassetid://10723386637",
    ghost        = "rbxassetid://10723404286",
    skull        = "rbxassetid://10709815260",
    crown        = "rbxassetid://10709818772",
    diamond      = "rbxassetid://10709820144",
    coins        = "rbxassetid://10709810061",
    wallet       = "rbxassetid://10747383286",
    download     = "rbxassetid://10723345036",
    upload       = "rbxassetid://10723372953",
    link         = "rbxassetid://10723432637",
    ["external-link"] = "rbxassetid://10709818050",
    discord      = "rbxassetid://10723345036",
    check        = "rbxassetid://10709790644",
    ["check-circle"] = "rbxassetid://10709790866",
    ["alert-triangle"] = "rbxassetid://10723345553",
    ["alert-circle"]   = "rbxassetid://10723345428",
    person       = "rbxassetid://10747373176",
    footprints   = "rbxassetid://10723387175",
    run          = "rbxassetid://10723387175",
    ["arrow-up"] = "rbxassetid://10709790644",
    ["arrow-down"] = "rbxassetid://10709791437",
}

local function resolveIcon(nameOrId)
    if not nameOrId then return nil end
    if typeof(nameOrId) ~= "string" then return nil end
    if Icons[nameOrId] then return Icons[nameOrId] end
    if nameOrId:match("^rbxassetid://") or nameOrId:match("^rbxasset://") then return nameOrId end
    if nameOrId:match("^%d+$") then return "rbxassetid://" .. nameOrId end
    return nameOrId
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function new(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, t, r, b, l)
    return new("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft   = UDim.new(0, l or 0),
        Parent = parent,
    })
end

local function tween(obj, t, props, style, direction)
    local info = TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

-- Adds a subtle top-to-bottom highlight gradient for a glass feel.
local function glassify(frame, baseTransparency)
    baseTransparency = baseTransparency or 0.12
    frame.BackgroundTransparency = baseTransparency
    local g = new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,    0.55),
            NumberSequenceKeypoint.new(0.35, 0.85),
            NumberSequenceKeypoint.new(1,    1),
        }),
        Color = ColorSequence.new(Theme.GlassHighlight, Theme.GlassHighlight),
        Parent = frame,
    })
    return g
end

----------------------------------------------------------------
-- Parenting (gethui → CoreGui → PlayerGui)
----------------------------------------------------------------
local function parentGui(gui, name)
    local function tryParent(target)
        if not target then return false end
        local ok = pcall(function()
            local existing = target:FindFirstChild(name)
            if existing then existing:Destroy() end
            gui.Parent = target
        end)
        return ok and gui.Parent == target
    end

    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and tryParent(hui) then return end
    end
    if tryParent(CoreGui) then return end
    if tryParent(PlayerGui) then return end
    warn("[KaizenUI] Could not parent " .. name)
    if PlayerGui then gui.Parent = PlayerGui end
end

----------------------------------------------------------------
-- Draggable (mouse + touch)
-- Returns a state table { isDragging, moved } so callers (like the
-- minimized logo pill) can distinguish a tap from a drag.
----------------------------------------------------------------
local function makeDraggable(handle, target)
    local state = { isDragging = false, moved = false }
    local dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            state.isDragging = true
            state.moved      = false
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
-- Library table
----------------------------------------------------------------
local KaizenUI = {}
KaizenUI.__index = KaizenUI
KaizenUI.Theme   = Theme
KaizenUI.Icons   = Icons
KaizenUI.Options = {} -- Fluent-compatible options map

----------------------------------------------------------------
-- Notify (Fluent-compatible)
----------------------------------------------------------------
local _notifyGui
local _notifyStack = {}
local function ensureNotifyGui()
    if _notifyGui and _notifyGui.Parent then return _notifyGui end
    _notifyGui = new("ScreenGui", {
        Name = "KaizenUINotify",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 1000,
    })
    parentGui(_notifyGui, "KaizenUINotify")
    return _notifyGui
end

local function relayoutNotifies()
    local y = 20
    for i = #_notifyStack, 1, -1 do
        local frame = _notifyStack[i]
        if frame.Parent then
            tween(frame, 0.18, { Position = UDim2.new(1, -20, 0, y) })
            y = y + frame.AbsoluteSize.Y + 10
        end
    end
end

function KaizenUI:Notify(cfg)
    cfg = cfg or {}
    local title    = cfg.Title    or "Notification"
    local content  = cfg.Content  or ""
    local duration = cfg.Duration or 4

    local gui = ensureNotifyGui()
    local card = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.fromOffset(280, 62),
        Position = UDim2.new(1, 20, 0, 20),
        BackgroundColor3 = Theme.Glass,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(card, 10)
    stroke(card, Theme.Border, 1, 0.4)
    glassify(card, 0.08)
    padding(card, 10, 12, 10, 12)

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.fromOffset(0, 18),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })

    table.insert(_notifyStack, card)
    relayoutNotifies()

    task.delay(duration, function()
        tween(card, 0.25, { Position = UDim2.new(1, 300, 0, card.Position.Y.Offset), BackgroundTransparency = 1 })
        task.wait(0.27)
        for i, v in ipairs(_notifyStack) do
            if v == card then table.remove(_notifyStack, i); break end
        end
        card:Destroy()
        relayoutNotifies()
    end)
end

----------------------------------------------------------------
-- Loader (rotating ring + logo) — glassmorphism card
----------------------------------------------------------------
function KaizenUI:Loader(cfg)
    cfg = cfg or {}
    local Title    = cfg.Title    or "KaizenHub"
    local Subtitle = cfg.Subtitle or "Loading..."
    local LogoId   = cfg.LogoId   or "rbxassetid://124205601170943"
    local Duration = cfg.Duration or 2

    local Gui = new("ScreenGui", {
        Name = "KaizenUILoader",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
    })
    parentGui(Gui, "KaizenUILoader")

    -- Dim backdrop
    local Dim = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = Gui,
    })
    tween(Dim, 0.3, { BackgroundTransparency = 0.35 })

    local Card = new("Frame", {
        Size = UDim2.fromOffset(240, 200),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Glass,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = Gui,
    })
    corner(Card, 16)
    stroke(Card, Theme.Border, 1, 0.4)
    glassify(Card, 0.1)

    -- Rotating ring
    local Ring = new("ImageLabel", {
        Size = UDim2.fromOffset(86, 86),
        Position = UDim2.new(0.5, 0, 0, 30),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Image = resolveIcon("loader"),
        ImageColor3 = Theme.Text,
        ImageTransparency = 1,
        Parent = Card,
    })

    -- Logo in center
    local Logo = new("ImageLabel", {
        Size = UDim2.fromOffset(44, 44),
        Position = UDim2.new(0.5, 0, 0, 51),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(22, 22, 28),
        BorderSizePixel = 0,
        Image = LogoId,
        ScaleType = Enum.ScaleType.Fit,
        ImageTransparency = 1,
        BackgroundTransparency = 1,
        Parent = Card,
    })
    corner(Logo, 10)
    stroke(Logo, Theme.Border, 1, 0.5)

    local TitleLbl = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 10, 1, -56),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextTransparency = 1,
        Parent = Card,
    })
    local SubLbl = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 10, 1, -32),
        BackgroundTransparency = 1,
        Text = Subtitle,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextTransparency = 1,
        Parent = Card,
    })

    -- Fade-in
    tween(Card, 0.25, { BackgroundTransparency = 0.1 })
    tween(Ring, 0.25, { ImageTransparency = 0 })
    tween(Logo, 0.25, { ImageTransparency = 0, BackgroundTransparency = 0 })
    tween(TitleLbl, 0.3, { TextTransparency = 0 })
    tween(SubLbl, 0.3, { TextTransparency = 0.2 })

    -- Spinner rotation loop
    local alive = true
    task.spawn(function()
        while alive and Ring.Parent do
            Ring.Rotation = (Ring.Rotation + 4) % 360
            RunService.RenderStepped:Wait()
        end
    end)

    task.wait(Duration)

    -- Fade out
    alive = false
    tween(Dim, 0.25, { BackgroundTransparency = 1 })
    tween(Card, 0.25, { BackgroundTransparency = 1 })
    tween(Ring, 0.25, { ImageTransparency = 1 })
    tween(Logo, 0.25, { ImageTransparency = 1, BackgroundTransparency = 1 })
    tween(TitleLbl, 0.25, { TextTransparency = 1 })
    tween(SubLbl, 0.25, { TextTransparency = 1 })
    task.wait(0.3)
    Gui:Destroy()
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function KaizenUI:CreateWindow(cfg)
    cfg = cfg or {}
    local Title    = cfg.Title    or cfg.Name or "KaizenHub"
    local Subtitle = cfg.Subtitle or cfg.SubTitle or "[ UPD ] • Script Hub"
    local LogoId   = cfg.LogoId   or "rbxassetid://124205601170943"
    local MinimizeKey = cfg.MinimizeKey or Enum.KeyCode.LeftControl

    ----------------------------------------------------------------
    -- ScreenGui + Root
    ----------------------------------------------------------------
    local ScreenGui = new("ScreenGui", {
        Name = "KaizenUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
    })
    parentGui(ScreenGui, "KaizenUI")

    local Root = new("Frame", {
        Name = "Root",
        Size = UDim2.fromOffset(820, 520),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = ScreenGui,
    })
    corner(Root, 14)
    stroke(Root, Theme.Border, 1, 0.3)
    glassify(Root, 0.08)

    -- Fade in
    Root.BackgroundTransparency = 1
    tween(Root, 0.25, { BackgroundTransparency = 0.08 })

    ----------------------------------------------------------------
    -- Top bar
    ----------------------------------------------------------------
    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.GlassStrong,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Parent = Root,
    })
    local TopBarPad = padding(TopBar, 0, 14, 0, 14)

    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    local Logo = new("ImageLabel", {
        Name = "Logo",
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(22, 22, 28),
        BorderSizePixel = 0,
        Image = LogoId,
        ScaleType = Enum.ScaleType.Fit,
        Active = false, -- IMPORTANT: let drag pass through to TopBar
        Parent = TopBar,
    })
    corner(Logo, 8)
    stroke(Logo, Theme.Border, 1, 0.4)

    local TitleLabel = new("TextLabel", {
        Name = "Title",
        Size = UDim2.fromOffset(140, 24),
        Position = UDim2.new(0, 40, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local SubtitleLabel = new("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(1, -280, 0, 18),
        Position = UDim2.new(0, 186, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = Subtitle,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = TopBar,
    })

    -- Window controls
    local function makeIconButton(iconKey, posOffset)
        local btn = new("ImageButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, posOffset, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Card,
            BackgroundTransparency = 1,
            Image = resolveIcon(iconKey),
            ImageColor3 = Theme.SubText,
            Parent = TopBar,
        })
        corner(btn, 7)
        btn.MouseEnter:Connect(function()
            tween(btn, 0.12, { BackgroundTransparency = 0.2, ImageColor3 = Theme.Text })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.12, { BackgroundTransparency = 1, ImageColor3 = Theme.SubText })
        end)
        return btn
    end

    local CloseBtn = makeIconButton("x", 0)
    local MinBtn   = makeIconButton("minus", -32)

    makeDraggable(TopBar, Root)

    ----------------------------------------------------------------
    -- Body (sidebar + content)
    ----------------------------------------------------------------
    local Body = new("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -52),
        Position = UDim2.fromOffset(0, 52),
        BackgroundTransparency = 1,
        Parent = Root,
    })

    local Sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Parent = Body,
    })
    local SidebarPad = padding(Sidebar, 12, 10, 12, 10)
    new("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    -- Scrollable tab list (fills full sidebar since profile card is removed)
    local TabList = new("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = Sidebar,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabList,
    })

    -- Content
    local Content = new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -200, 1, 0),
        Position = UDim2.fromOffset(200, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = Body,
    })
    local ContentPad = padding(Content, 14, 14, 14, 14)

    local Pages = new("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = Content,
    })

    ----------------------------------------------------------------
    -- Responsive resizing (mobile-first)
    ----------------------------------------------------------------
    local function updateResponsive()
        local cam = workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
        local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        local narrow = touchOnly or vp.X < 900 or vp.Y < 560

        SubtitleLabel.Visible = not narrow

        if narrow then
            local w = math.clamp(math.floor(vp.X * 0.92), 320, 640)
            local h = math.clamp(math.floor(vp.Y * 0.86), 320, 480)
            Root.Size = UDim2.fromOffset(w, h)

            local sw = math.clamp(math.floor(w * 0.32), 120, 170)
            Sidebar.Size      = UDim2.new(0, sw, 1, 0)
            Content.Size      = UDim2.new(1, -sw, 1, 0)
            Content.Position  = UDim2.fromOffset(sw, 0)

            ContentPad.PaddingTop    = UDim.new(0, 10)
            ContentPad.PaddingBottom = UDim.new(0, 10)
            ContentPad.PaddingLeft   = UDim.new(0, 10)
            ContentPad.PaddingRight  = UDim.new(0, 10)
            TopBarPad.PaddingLeft    = UDim.new(0, 12)
            TopBarPad.PaddingRight   = UDim.new(0, 12)
            SidebarPad.PaddingLeft   = UDim.new(0, 8)
            SidebarPad.PaddingRight  = UDim.new(0, 8)
            SidebarPad.PaddingTop    = UDim.new(0, 8)
            SidebarPad.PaddingBottom = UDim.new(0, 8)

            TitleLabel.TextSize = 14
            TitleLabel.Size     = UDim2.fromOffset(110, 22)
        else
            Root.Size = UDim2.fromOffset(820, 520)
            Sidebar.Size      = UDim2.new(0, 200, 1, 0)
            Content.Size      = UDim2.new(1, -200, 1, 0)
            Content.Position  = UDim2.fromOffset(200, 0)

            ContentPad.PaddingTop    = UDim.new(0, 18)
            ContentPad.PaddingBottom = UDim.new(0, 18)
            ContentPad.PaddingLeft   = UDim.new(0, 18)
            ContentPad.PaddingRight  = UDim.new(0, 18)
            TopBarPad.PaddingLeft    = UDim.new(0, 14)
            TopBarPad.PaddingRight   = UDim.new(0, 14)
            SidebarPad.PaddingLeft   = UDim.new(0, 10)
            SidebarPad.PaddingRight  = UDim.new(0, 10)
            SidebarPad.PaddingTop    = UDim.new(0, 12)
            SidebarPad.PaddingBottom = UDim.new(0, 12)

            TitleLabel.TextSize = 15
            TitleLabel.Size     = UDim2.fromOffset(140, 24)
        end

        -- Clamp window inside viewport
        local s = Root.AbsoluteSize
        local p = Root.Position
        if p.X.Scale ~= 0.5 or p.Y.Scale ~= 0.5 then
            local px = math.clamp(p.X.Offset, s.X / 2, vp.X - s.X / 2)
            local py = math.clamp(p.Y.Offset, s.Y / 2, vp.Y - s.Y / 2)
            Root.Position = UDim2.fromOffset(px, py)
        end
    end

    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive)
    end
    UserInputService.LastInputTypeChanged:Connect(updateResponsive)
    updateResponsive()

    ----------------------------------------------------------------
    -- Minimize → collapse to JUST a draggable logo pill
    ----------------------------------------------------------------
    local minimized = false
    local lastSize  = Root.Size
    local lastPos   = Root.Position

    -- Pill used when minimized — a circular frame that shows only the logo
    -- and is independently draggable so the user can reposition it.
    local Pill = new("ImageButton", {
        Name = "MinPill",
        Size = UDim2.fromOffset(56, 56),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Glass,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Image = LogoId,
        ScaleType = Enum.ScaleType.Fit,
        ImageRectOffset = Vector2.new(0, 0),
        AutoButtonColor = false,
        Visible = false,
        Parent = ScreenGui,
    })
    corner(Pill, 14)
    stroke(Pill, Theme.Border, 1, 0.3)
    glassify(Pill, 0.08)
    padding(Pill, 8, 8, 8, 8)
    local pillDrag = makeDraggable(Pill, Pill)

    local function openFromMin()
        if not minimized then return end
        minimized = false
        -- Restore the window where the pill currently is (respects drag)
        local p = Pill.Position
        Pill.Visible = false
        Root.Visible = true
        Root.Position = p
        Root.Size = UDim2.fromOffset(0, 0)
        tween(Root, 0.22, { Size = lastSize })
        task.wait(0.05)
        updateResponsive()
    end

    MinBtn.MouseButton1Click:Connect(function()
        if minimized then
            openFromMin()
        else
            minimized = true
            lastSize = Root.Size
            lastPos  = Root.Position
            -- Place the pill where the window currently is, then hide root
            Pill.Position = lastPos
            Pill.Visible = true
            Pill.Size = UDim2.fromOffset(0, 0)
            Root.Visible = false
            tween(Pill, 0.2, { Size = UDim2.fromOffset(56, 56) })
        end
    end)

    Pill.MouseButton1Click:Connect(function()
        -- Only restore if the user tapped without dragging
        if pillDrag and pillDrag.moved then
            pillDrag.moved = false
            return
        end
        openFromMin()
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        tween(Root, 0.18, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
        tween(Pill, 0.18, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
        task.wait(0.2)
        ScreenGui:Destroy()
    end)

    -- MinimizeKey toggle (desktop)
    if MinimizeKey then
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == MinimizeKey then
                if minimized then
                    openFromMin()
                else
                    MinBtn.MouseButton1Click:Fire()
                end
            end
        end)
    end

    ----------------------------------------------------------------
    -- Window API
    ----------------------------------------------------------------
    local Window = {}
    Window.Tabs = {}
    Window._activeTab = nil
    Window.ScreenGui = ScreenGui
    Window.Root = Root

    function Window:SetStatus() end
    function Window:Destroy() ScreenGui:Destroy() end
    function Window:SelectTab(idx)
        local t = self.Tabs[tonumber(idx) or 1]
        if t and t._setActive then
            if self._activeTab and self._activeTab ~= t then
                self._activeTab._setActive(false)
            end
            self._activeTab = t
            t._setActive(true)
        end
    end

    ----------------------------------------------------------------
    -- Tab
    ----------------------------------------------------------------
    local function registerTab(tabCfg)
        tabCfg = tabCfg or {}
        local Name = tabCfg.Title or tabCfg.Name or "Tab"
        local Icon = resolveIcon(tabCfg.Icon or "grid")

        -- Sidebar button
        local TabBtn = new("TextButton", {
            Name = "Tab_" .. Name,
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = Theme.Sidebar,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Parent = TabList,
        })
        corner(TabBtn, 8)
        padding(TabBtn, 0, 10, 0, 10)

        local TabIcon = new("ImageLabel", {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Image = Icon,
            ImageColor3 = Theme.SubText,
            Parent = TabBtn,
        })
        local TabLabel = new("TextLabel", {
            Size = UDim2.new(1, -24, 1, 0),
            Position = UDim2.fromOffset(24, 0),
            BackgroundTransparency = 1,
            Text = Name,
            TextColor3 = Theme.SubText,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = TabBtn,
        })

        -- Page (scrollable). Proper left+right padding so cards don't stitch to edges.
        local Page = new("ScrollingFrame", {
            Name = "Page_" .. Name,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Border,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = Pages,
        })
        -- (top, right, bottom, left) — balanced horizontal padding so
        -- cards don't stitch to the window/scrollbar edges.
        padding(Page, 2, 10, 14, 2)
        new("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Page,
        })

        -- Page header
        local HeaderHolder = new("Frame", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundTransparency = 1,
            LayoutOrder = -1,
            Parent = Page,
        })
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = Name,
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 20,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = HeaderHolder,
        })
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            Position = UDim2.fromOffset(0, 28),
            BackgroundTransparency = 1,
            Text = tabCfg.Description or ("Configure " .. Name:lower() .. " options."),
            TextColor3 = Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = HeaderHolder,
        })
        new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -1),
            BackgroundColor3 = Theme.BorderSubtle,
            BorderSizePixel = 0,
            Parent = HeaderHolder,
        })

        local Tab = { Name = Name, Button = TabBtn, Page = Page }

        local function setActive(active)
            if active then
                tween(TabBtn, 0.15, { BackgroundTransparency = 0.1, BackgroundColor3 = Theme.SidebarActive })
                tween(TabIcon, 0.15, { ImageColor3 = Theme.Text })
                tween(TabLabel, 0.15, { TextColor3 = Theme.Text })
                TabLabel.Font = Enum.Font.GothamBold
                Page.Visible = true
            else
                tween(TabBtn, 0.15, { BackgroundTransparency = 1 })
                tween(TabIcon, 0.15, { ImageColor3 = Theme.SubText })
                tween(TabLabel, 0.15, { TextColor3 = Theme.SubText })
                TabLabel.Font = Enum.Font.GothamMedium
                Page.Visible = false
            end
        end

        TabBtn.MouseEnter:Connect(function()
            if Window._activeTab ~= Tab then
                tween(TabBtn, 0.12, { BackgroundTransparency = 0.4, BackgroundColor3 = Theme.Card })
                tween(TabLabel, 0.12, { TextColor3 = Theme.Text })
                tween(TabIcon, 0.12, { ImageColor3 = Theme.Text })
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if Window._activeTab ~= Tab then setActive(false) end
        end)
        TabBtn.MouseButton1Click:Connect(function()
            if Window._activeTab and Window._activeTab ~= Tab then
                Window._activeTab._setActive(false)
            end
            Window._activeTab = Tab
            setActive(true)
        end)

        Tab._setActive = setActive
        if not Window._activeTab then
            Window._activeTab = Tab
            setActive(true)
        end
        table.insert(Window.Tabs, Tab)

        ----------------------------------------------------------
        -- Section container
        ----------------------------------------------------------
        local function buildSection(sectionName)
            -- Section header label
            if sectionName and sectionName ~= "" then
                local holder = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    Parent = Page,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = sectionName,
                    TextColor3 = Theme.Muted,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = holder,
                })
            end

            local Section = {}

            ------------------------------------------------------
            -- Card builder (glass card, proper margin)
            ------------------------------------------------------
            local function makeCard(height)
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, height or 60),
                    BackgroundColor3 = Theme.Card,
                    BackgroundTransparency = 0.15,
                    BorderSizePixel = 0,
                    Parent = Page,
                })
                corner(card, 10)
                stroke(card, Theme.BorderSubtle, 1, 0.3)
                glassify(card, 0.15)
                padding(card, 12, 14, 12, 14)
                card.MouseEnter:Connect(function()
                    tween(card, 0.12, { BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 0.1 })
                end)
                card.MouseLeave:Connect(function()
                    tween(card, 0.12, { BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.15 })
                end)
                return card
            end

            ------------------------------------------------------
            -- Toggle
            ------------------------------------------------------
            function Section:AddToggle(id, opts)
                opts = opts or {}
                local value = opts.Default == true
                local card = makeCard(60)

                new("TextLabel", {
                    Size = UDim2.new(1, -64, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Title or opts.Name or "Toggle",
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, -64, 0, 14),
                    Position = UDim2.fromOffset(0, 18),
                    BackgroundTransparency = 1,
                    Text = opts.Description or "",
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = card,
                })

                local sw = new("TextButton", {
                    Size = UDim2.fromOffset(40, 22),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = value and Theme.ToggleOn or Theme.ToggleOff,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = card,
                })
                corner(sw, 11)

                local knob = new("Frame", {
                    Size = UDim2.fromOffset(16, 16),
                    Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = value and Theme.ToggleKnobOn or Theme.ToggleKnobOff,
                    BorderSizePixel = 0,
                    Parent = sw,
                })
                corner(knob, 8)

                local api = { Value = value }
                function api:SetValue(v)
                    value = v and true or false
                    self.Value = value
                    tween(sw,   0.16, { BackgroundColor3 = value and Theme.ToggleOn or Theme.ToggleOff })
                    tween(knob, 0.16, {
                        Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                        BackgroundColor3 = value and Theme.ToggleKnobOn or Theme.ToggleKnobOff,
                    })
                    if opts.Callback then task.spawn(opts.Callback, value) end
                end
                function api:OnChanged(cb) opts.Callback = cb end
                api.Set = api.SetValue
                api.Get = function() return value end

                sw.MouseButton1Click:Connect(function() api:SetValue(not value) end)
                if id then KaizenUI.Options[id] = api end
                return api
            end

            ------------------------------------------------------
            -- Button
            ------------------------------------------------------
            function Section:AddButton(opts)
                opts = opts or {}
                local card = makeCard(60)

                new("TextLabel", {
                    Size = UDim2.new(1, -110, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Title or opts.Name or "Button",
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, -110, 0, 14),
                    Position = UDim2.fromOffset(0, 18),
                    BackgroundTransparency = 1,
                    Text = opts.Description or "",
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = card,
                })

                local btn = new("TextButton", {
                    Size = UDim2.fromOffset(96, 28),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Theme.Accent,
                    AutoButtonColor = false,
                    Text = opts.ButtonText or "Run",
                    TextColor3 = Color3.fromRGB(12, 12, 14),
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    Parent = card,
                })
                corner(btn, 7)
                btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Color3.fromRGB(220,220,225) }) end)
                btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Theme.Accent }) end)
                btn.MouseButton1Click:Connect(function()
                    if opts.Callback then task.spawn(opts.Callback) end
                end)
                return btn
            end

            ------------------------------------------------------
            -- Slider (reliable touch + desktop)
            ------------------------------------------------------
            function Section:AddSlider(id, opts)
                opts = opts or {}
                local min = opts.Min or 0
                local max = opts.Max or 100
                local rounding = opts.Rounding or 0
                local value = opts.Default or min
                local card = makeCard(74)

                new("TextLabel", {
                    Size = UDim2.new(1, -70, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Title or opts.Name or "Slider",
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                local valLabel = new("TextLabel", {
                    Size = UDim2.fromOffset(70, 16),
                    Position = UDim2.new(1, 0, 0, 0),
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(value),
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = card,
                })

                -- Larger hit area around the visible track for easier mobile dragging
                local hit = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    Position = UDim2.new(0, 0, 1, -8),
                    AnchorPoint = Vector2.new(0, 1),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    Parent = card,
                })

                local track = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 6),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = Theme.ToggleOff,
                    BorderSizePixel = 0,
                    Parent = hit,
                })
                corner(track, 4)

                local fill = new("Frame", {
                    Size = UDim2.fromScale((value - min) / math.max(1e-6, (max - min)), 1),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    Parent = track,
                })
                corner(fill, 4)

                local api = { Value = value }

                local function format(v)
                    if rounding <= 0 then
                        return tostring(math.floor(v + 0.5))
                    end
                    return string.format("%." .. rounding .. "f", v)
                end

                local function applyValue(v)
                    if rounding <= 0 then
                        v = math.floor(v + 0.5)
                    else
                        local mult = 10 ^ rounding
                        v = math.floor(v * mult + 0.5) / mult
                    end
                    v = math.clamp(v, min, max)
                    value = v
                    api.Value = v
                    local rel = (v - min) / math.max(1e-6, (max - min))
                    fill.Size = UDim2.fromScale(rel, 1)
                    valLabel.Text = format(v)
                    if opts.Callback then task.spawn(opts.Callback, v) end
                end

                local function update(inputX)
                    local trackPos  = track.AbsolutePosition.X
                    local trackSize = track.AbsoluteSize.X
                    if trackSize <= 0 then return end
                    local relX = math.clamp((inputX - trackPos) / trackSize, 0, 1)
                    applyValue(min + (max - min) * relX)
                end

                function api:SetValue(v) applyValue(tonumber(v) or min) end
                api.Set = api.SetValue

                local activeInput
                hit.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        activeInput = input
                        update(input.Position.X)
                        local conn
                        conn = input.Changed:Connect(function()
                            if input.UserInputState == Enum.UserInputState.End then
                                if activeInput == input then activeInput = nil end
                                conn:Disconnect()
                            end
                        end)
                    end
                end)
                hit.InputChanged:Connect(function(input)
                    if activeInput and (input.UserInputType == Enum.UserInputType.MouseMovement
                                     or input.UserInputType == Enum.UserInputType.Touch) then
                        update(input.Position.X)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if activeInput and input.UserInputType == Enum.UserInputType.MouseMovement then
                        update(input.Position.X)
                    end
                end)

                applyValue(value)
                if id then KaizenUI.Options[id] = api end
                return api
            end

            ------------------------------------------------------
            -- Dropdown (animated chevron, resizable values)
            ------------------------------------------------------
            function Section:AddDropdown(id, opts)
                opts = opts or {}
                local options = opts.Values or opts.Options or {}
                local value = opts.Default
                if value == nil and #options > 0 and not opts.Multi then
                    value = nil -- default to unselected like Fluent does
                end
                local card = makeCard(56)

                new("TextLabel", {
                    Size = UDim2.new(1, -170, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Title or opts.Name or "Dropdown",
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, -170, 0, 14),
                    Position = UDim2.fromOffset(0, 18),
                    BackgroundTransparency = 1,
                    Text = opts.Description or "",
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })

                local btn = new("TextButton", {
                    Size = UDim2.fromOffset(150, 30),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Theme.Background,
                    BackgroundTransparency = 0.2,
                    AutoButtonColor = false,
                    Text = tostring(value or "Select..."),
                    TextColor3 = value and Theme.Text or Theme.Muted,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ClipsDescendants = true,
                    Parent = card,
                })
                corner(btn, 7)
                stroke(btn, Theme.Border, 1, 0.4)
                padding(btn, 0, 26, 0, 10)

                local chevron = new("ImageLabel", {
                    Size = UDim2.fromOffset(12, 12),
                    Position = UDim2.new(1, -20, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Image = resolveIcon("chevron-down"),
                    ImageColor3 = Theme.SubText,
                    Rotation = 0,
                    Parent = card,
                })

                -- Menu lives at the ScreenGui level so it's never clipped
                local menu = new("Frame", {
                    Size = UDim2.fromOffset(150, 0),
                    BackgroundColor3 = Theme.Card,
                    BackgroundTransparency = 0.05,
                    BorderSizePixel = 0,
                    Visible = false,
                    ClipsDescendants = true,
                    ZIndex = 50,
                    Parent = ScreenGui,
                })
                corner(menu, 8)
                stroke(menu, Theme.Border, 1, 0.3)
                glassify(menu, 0.08)
                local menuList = new("UIListLayout", { Padding = UDim.new(0, 2), Parent = menu })
                padding(menu, 6, 6, 6, 6)

                local function optionCount() return #options end
                local function menuHeight() return (optionCount() * 28) + 12 end

                local function reposMenu()
                    local pos  = btn.AbsolutePosition
                    local size = btn.AbsoluteSize
                    menu.Position = UDim2.fromOffset(pos.X, pos.Y + size.Y + 4)
                    menu.Size     = UDim2.fromOffset(size.X, menuHeight())
                end

                local open = false
                local function setOpen(o)
                    open = o
                    if open then
                        reposMenu()
                        menu.Visible = true
                        tween(chevron, 0.18, { Rotation = 180 })
                        menu.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 0)
                        tween(menu, 0.18, { Size = UDim2.fromOffset(btn.AbsoluteSize.X, menuHeight()) })
                    else
                        tween(chevron, 0.18, { Rotation = 0 })
                        local t = tween(menu, 0.16, { Size = UDim2.fromOffset(menu.Size.X.Offset, 0) })
                        t.Completed:Connect(function()
                            if not open then menu.Visible = false end
                        end)
                    end
                end

                local api = { Value = value }
                local function rebuildItems()
                    for _, child in ipairs(menu:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                    end
                    for _, opt in ipairs(options) do
                        local it = new("TextButton", {
                            Size = UDim2.new(1, 0, 0, 26),
                            BackgroundColor3 = Theme.CardHover,
                            BackgroundTransparency = 1,
                            AutoButtonColor = false,
                            Text = tostring(opt),
                            TextColor3 = Theme.Text,
                            Font = Enum.Font.GothamMedium,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 51,
                            Parent = menu,
                        })
                        corner(it, 6)
                        padding(it, 0, 0, 0, 10)
                        it.MouseEnter:Connect(function() tween(it, 0.1, { BackgroundTransparency = 0.2 }) end)
                        it.MouseLeave:Connect(function() tween(it, 0.1, { BackgroundTransparency = 1 }) end)
                        it.MouseButton1Click:Connect(function()
                            value = opt
                            api.Value = opt
                            btn.Text = tostring(opt)
                            btn.TextColor3 = Theme.Text
                            setOpen(false)
                            if opts.Callback then task.spawn(opts.Callback, opt) end
                        end)
                    end
                end
                rebuildItems()

                function api:SetValues(list)
                    options = list or {}
                    rebuildItems()
                    if value and not table.find(options, value) then
                        value = nil
                        api.Value = nil
                        btn.Text = "Select..."
                        btn.TextColor3 = Theme.Muted
                    end
                    if open then reposMenu() end
                end
                api.Refresh = api.SetValues

                function api:SetValue(v)
                    value = v
                    api.Value = v
                    btn.Text = tostring(v or "Select...")
                    btn.TextColor3 = v and Theme.Text or Theme.Muted
                    if opts.Callback then task.spawn(opts.Callback, v) end
                end
                api.Set = api.SetValue

                btn.MouseButton1Click:Connect(function() setOpen(not open) end)

                -- Close when clicking outside
                UserInputService.InputBegan:Connect(function(input)
                    if not open then return end
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then return end
                    local mp = input.Position
                    local mpos = Vector2.new(mp.X, mp.Y)
                    local function inside(o)
                        local p = o.AbsolutePosition; local s = o.AbsoluteSize
                        return mpos.X >= p.X and mpos.X <= p.X + s.X and mpos.Y >= p.Y and mpos.Y <= p.Y + s.Y
                    end
                    if not inside(menu) and not inside(btn) then
                        setOpen(false)
                    end
                end)

                -- Re-position menu if the window moves
                btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                    if open then reposMenu() end
                end)

                if id then KaizenUI.Options[id] = api end
                return api
            end

            ------------------------------------------------------
            -- Input (textbox)
            ------------------------------------------------------
            function Section:AddInput(id, opts)
                opts = opts or {}
                local card = makeCard(60)

                new("TextLabel", {
                    Size = UDim2.new(1, -170, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Title or opts.Name or "Input",
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                new("TextLabel", {
                    Size = UDim2.new(1, -170, 0, 14),
                    Position = UDim2.fromOffset(0, 18),
                    BackgroundTransparency = 1,
                    Text = opts.Description or "",
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                local tb = new("TextBox", {
                    Size = UDim2.fromOffset(150, 30),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Theme.Background,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    Text = opts.Default or "",
                    PlaceholderText = opts.Placeholder or "Type…",
                    PlaceholderColor3 = Theme.Muted,
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false,
                    Parent = card,
                })
                corner(tb, 7)
                stroke(tb, Theme.Border, 1, 0.4)
                padding(tb, 0, 10, 0, 10)

                local api = { Value = tb.Text }
                function api:SetValue(v)
                    tb.Text = tostring(v or "")
                    api.Value = tb.Text
                    if opts.Callback then task.spawn(opts.Callback, tb.Text) end
                end
                api.Set = api.SetValue

                if opts.Finished then
                    tb.FocusLost:Connect(function(enter)
                        api.Value = tb.Text
                        if opts.Callback then task.spawn(opts.Callback, tb.Text, enter) end
                    end)
                else
                    tb:GetPropertyChangedSignal("Text"):Connect(function()
                        api.Value = tb.Text
                        if opts.Callback then task.spawn(opts.Callback, tb.Text) end
                    end)
                end

                if id then KaizenUI.Options[id] = api end
                return api
            end

            ------------------------------------------------------
            -- Paragraph
            ------------------------------------------------------
            function Section:AddParagraph(opts)
                opts = opts or {}
                local card = makeCard(72)

                new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Title or "",
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = card,
                })
                local body = new("TextLabel", {
                    Size = UDim2.new(1, 0, 1, -20),
                    Position = UDim2.fromOffset(0, 20),
                    BackgroundTransparency = 1,
                    Text = opts.Content or "",
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent = card,
                })
                -- Auto-grow card to fit text
                body:GetPropertyChangedSignal("TextBounds"):Connect(function()
                    card.Size = UDim2.new(1, 0, 0, math.max(60, body.TextBounds.Y + 36))
                end)
                card.Size = UDim2.new(1, 0, 0, math.max(60, body.TextBounds.Y + 36))
                return card
            end

            ------------------------------------------------------
            -- Label (simple text)
            ------------------------------------------------------
            function Section:AddLabel(text)
                local lbl = new("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = text or "",
                    TextColor3 = Theme.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Page,
                })
                return lbl
            end

            return Section
        end

        -- Default section exposed directly on the Tab (Fluent compatibility)
        local defaultSection = buildSection(nil)
        function Tab:AddSection(name) return buildSection(name or "Section") end
        -- Expose direct Add* calls too
        Tab.AddToggle    = function(self, id, o) return defaultSection:AddToggle(id, o) end
        Tab.AddSlider    = function(self, id, o) return defaultSection:AddSlider(id, o) end
        Tab.AddButton    = function(self, o)     return defaultSection:AddButton(o) end
        Tab.AddDropdown  = function(self, id, o) return defaultSection:AddDropdown(id, o) end
        Tab.AddInput     = function(self, id, o) return defaultSection:AddInput(id, o) end
        Tab.AddParagraph = function(self, o)     return defaultSection:AddParagraph(o) end
        Tab.AddLabel     = function(self, t)     return defaultSection:AddLabel(t) end

        return Tab
    end

    function Window:AddTab(tabCfg)   return registerTab(tabCfg) end
    function Window:CreateTab(tabCfg) return registerTab(tabCfg) end

    return Window
end

-- Allow both `KaizenUI:CreateWindow(...)` and `Fluent:CreateWindow(...)` style
KaizenUI.KaizenUI = KaizenUI
return KaizenUI
