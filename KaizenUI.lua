--[[
    KaizenUI — A shadcn-inspired, dark solid UI library for Roblox (Lua)
    Style reference: KaizenHub (dark sidebar, card toggles, fluent/lucide icons)

    Highlights:
      • True mobile-first responsiveness (auto-scales, fits viewport)
      • Reliable touch sliders / draggable window
      • Animated dropdown chevron, hover/press transitions
      • Scrollable sidebar + scrollable content pages
      • Minimize collapses to JUST the logo
      • Built-in loader animation (rotating ring + logo)
      • Profile card with avatar + nickname + execution counter
      • Logo baked in: rbxassetid://124205601170943

    Quick usage:
      local KaizenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/biarzxc1/Kaizen-Hub/refs/heads/main/KaizenUI.lua"))()
      KaizenUI:Loader({ Duration = 2 })
      local Window = KaizenUI:CreateWindow({ Title = "KaizenHub", Subtitle = "[ UPD ] • Survive The Apocalypse" })
      local Tab    = Window:CreateTab({ Name = "Visuals", Icon = "eye" })
      Tab:AddToggle({ Name = "Item ESP", Description = "Highlights items.", Callback = function(v) end })
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
-- Theme (shadcn dark — solid, no gradients)
----------------------------------------------------------------
local Theme = {
    Background     = Color3.fromRGB(10, 10, 10),
    Sidebar        = Color3.fromRGB(14, 14, 14),
    SidebarActive  = Color3.fromRGB(26, 26, 26),
    Card           = Color3.fromRGB(18, 18, 18),
    CardHover      = Color3.fromRGB(24, 24, 24),
    Border         = Color3.fromRGB(38, 38, 38),
    BorderSubtle   = Color3.fromRGB(28, 28, 28),
    Text           = Color3.fromRGB(250, 250, 250),
    SubText        = Color3.fromRGB(161, 161, 170),
    Muted          = Color3.fromRGB(115, 115, 115),
    ToggleOff      = Color3.fromRGB(38, 38, 38),
    ToggleOn       = Color3.fromRGB(240, 240, 240),
    ToggleKnobOff  = Color3.fromRGB(161, 161, 170),
    ToggleKnobOn   = Color3.fromRGB(10, 10, 10),
    Accent         = Color3.fromRGB(240, 240, 240),
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
    chevron      = "rbxassetid://10709791437",  -- chevron-down by default
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
    play         = "rbxassetid://10734930410",
    pause        = "rbxassetid://10734910214",
    refresh      = "rbxassetid://10734932288",
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
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
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
-- Draggable (mouse + touch, with viewport clamping)
----------------------------------------------------------------
local function makeDraggable(handle, target)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos  = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
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
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

----------------------------------------------------------------
-- Library
----------------------------------------------------------------
local KaizenUI = {}
KaizenUI.__index = KaizenUI
KaizenUI.Theme = Theme
KaizenUI.Icons = Icons

----------------------------------------------------------------
-- Loader (rotating ring + logo + title) — yields until finished
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

    local Card = new("Frame", {
        Size = UDim2.fromOffset(220, 180),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = Gui,
    })
    corner(Card, 14)
    stroke(Card, Theme.Border, 1)

    -- Animated ring (rotates) + logo in middle
    local Ring = new("ImageLabel", {
        Size = UDim2.fromOffset(78, 78),
        Position = UDim2.new(0.5, 0, 0, 26),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Image = resolveIcon("loader"),
        ImageColor3 = Theme.Text,
        ImageTransparency = 1,
        Parent = Card,
    })
    local Logo = new("ImageLabel", {
        Size = UDim2.fromOffset(38, 38),
        Position = UDim2.new(0.5, 0, 0, 46),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        BorderSizePixel = 0,
        Image = LogoId,
        ScaleType = Enum.ScaleType.Fit,
        ImageTransparency = 1,
        BackgroundTransparency = 1,
        Parent = Card,
    })
    corner(Logo, 8)

    local TitleLbl = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 10, 1, -52),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextTransparency = 1,
        Parent = Card,
    })
    local SubLbl = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 10, 1, -30),
        BackgroundTransparency = 1,
        Text = Subtitle,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextTransparency = 1,
        Parent = Card,
    })

    -- Fade-in
    tween(Card, 0.22, { BackgroundTransparency = 0 })
    tween(Ring, 0.25, { ImageTransparency = 0 })
    tween(Logo, 0.25, { ImageTransparency = 0, BackgroundTransparency = 0 })
    tween(TitleLbl, 0.3, { TextTransparency = 0 })
    tween(SubLbl, 0.3, { TextTransparency = 0.2 })

    -- Spinner rotation loop (stops when destroyed)
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
    tween(Card, 0.25, { BackgroundTransparency = 1 })
    tween(Ring, 0.25, { ImageTransparency = 1 })
    tween(Logo, 0.25, { ImageTransparency = 1, BackgroundTransparency = 1 })
    tween(TitleLbl, 0.25, { TextTransparency = 1 })
    tween(SubLbl, 0.25, { TextTransparency = 1 })
    task.wait(0.28)
    Gui:Destroy()
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function KaizenUI:CreateWindow(cfg)
    cfg = cfg or {}
    local Title    = cfg.Title    or "KaizenHub"
    local Subtitle = cfg.Subtitle or "[ UPD ] • Script Hub • Delta"
    local LogoId   = cfg.LogoId   or "rbxassetid://124205601170943"

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
        BorderSizePixel = 0,
        ClipsDescendants = true,
        BackgroundTransparency = 1,
        Parent = ScreenGui,
    })
    corner(Root, 12)
    stroke(Root, Theme.Border, 1)

    -- Fade in
    tween(Root, 0.22, { BackgroundTransparency = 0 })

    ----------------------------------------------------------------
    -- Top bar (logo + title + subtitle + min/close)
    ----------------------------------------------------------------
    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.Background,
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
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        BorderSizePixel = 0,
        Image = LogoId,
        ScaleType = Enum.ScaleType.Fit,
        Parent = TopBar,
    })
    corner(Logo, 7)
    stroke(Logo, Theme.Border, 1)

    local TitleLabel = new("TextLabel", {
        Name = "Title",
        Size = UDim2.fromOffset(140, 24),
        Position = UDim2.new(0, 38, 0.5, 0),
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
        Position = UDim2.new(0, 184, 0.5, 0),
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
    local function makeIconButton(iconKey, posOffset, accent)
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
        corner(btn, 6)
        btn.MouseEnter:Connect(function()
            tween(btn, 0.12, {
                BackgroundTransparency = 0,
                BackgroundColor3 = accent or Theme.Card,
                ImageColor3 = accent and Color3.fromRGB(255,255,255) or Theme.Text,
            })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.12, { BackgroundTransparency = 1, ImageColor3 = Theme.SubText })
        end)
        return btn
    end

    local CloseBtn = makeIconButton("x", 0, Theme.Danger)
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
        Size = UDim2.new(0, 220, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = Body,
    })
    local SidebarPad = padding(Sidebar, 12, 12, 12, 12)
    new("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    -- Scrollable tab list
    local TabList = new("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -80),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
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

    -- Profile card (avatar + nickname + executions)
    local Profile = new("Frame", {
        Name = "Profile",
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 1, -60),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })
    corner(Profile, 10)
    stroke(Profile, Theme.BorderSubtle, 1)
    padding(Profile, 10, 10, 10, 10)

    local Avatar = new("ImageLabel", {
        Name = "Avatar",
        Size = UDim2.fromOffset(34, 34),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
        Parent = Profile,
    })
    corner(Avatar, 17)
    stroke(Avatar, Theme.BorderSubtle, 1)

    local NameLabel = new("TextLabel", {
        Size = UDim2.new(1, -44, 0, 16),
        Position = UDim2.fromOffset(44, 3),
        BackgroundTransparency = 1,
        Text = (LocalPlayer and LocalPlayer.DisplayName) or "Player",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Profile,
    })
    local ExecLabel = new("TextLabel", {
        Size = UDim2.new(1, -44, 0, 14),
        Position = UDim2.fromOffset(44, 22),
        BackgroundTransparency = 1,
        Text = "Executions: 0",
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Profile,
    })

    task.spawn(function()
        if not LocalPlayer then return end
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok and url then Avatar.Image = url end
    end)

    -- Content
    local Content = new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -220, 1, 0),
        Position = UDim2.fromOffset(220, 0),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = Body,
    })
    local ContentPad = padding(Content, 18, 18, 18, 18)

    local Pages = new("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = Content,
    })

    ----------------------------------------------------------------
    -- Responsive resizing (true mobile-first)
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

            ContentPad.PaddingTop    = UDim.new(0, 12)
            ContentPad.PaddingBottom = UDim.new(0, 12)
            ContentPad.PaddingLeft   = UDim.new(0, 12)
            ContentPad.PaddingRight  = UDim.new(0, 12)
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
            Sidebar.Size      = UDim2.new(0, 220, 1, 0)
            Content.Size      = UDim2.new(1, -220, 1, 0)
            Content.Position  = UDim2.fromOffset(220, 0)

            ContentPad.PaddingTop    = UDim.new(0, 22)
            ContentPad.PaddingBottom = UDim.new(0, 22)
            ContentPad.PaddingLeft   = UDim.new(0, 22)
            ContentPad.PaddingRight  = UDim.new(0, 22)
            TopBarPad.PaddingLeft    = UDim.new(0, 14)
            TopBarPad.PaddingRight   = UDim.new(0, 14)
            SidebarPad.PaddingLeft   = UDim.new(0, 12)
            SidebarPad.PaddingRight  = UDim.new(0, 12)
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
    -- Minimize → collapse to JUST the logo
    ----------------------------------------------------------------
    local minimized = false
    local lastSize  = Root.Size
    local lastPos   = Root.Position

    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            lastSize = Root.Size
            lastPos  = Root.Position
            -- Hide non-logo elements
            Body.Visible = false
            TitleLabel.Visible = false
            SubtitleLabel.Visible = false
            MinBtn.Visible = false
            CloseBtn.Visible = false
            -- Collapse to a small logo pill
            tween(Root, 0.22, { Size = UDim2.fromOffset(56, 56) })
        else
            tween(Root, 0.22, { Size = lastSize })
            task.wait(0.22)
            Body.Visible = true
            TitleLabel.Visible = true
            MinBtn.Visible = true
            CloseBtn.Visible = true
            updateResponsive()
        end
    end)

    -- Click logo while minimized to restore
    local LogoBtn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
        Parent = Logo,
    })
    LogoBtn.MouseButton1Click:Connect(function()
        if minimized then
            minimized = false
            tween(Root, 0.22, { Size = lastSize })
            task.wait(0.22)
            Body.Visible = true
            TitleLabel.Visible = true
            MinBtn.Visible = true
            CloseBtn.Visible = true
            updateResponsive()
        end
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        tween(Root, 0.18, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
        task.wait(0.2)
        ScreenGui:Destroy()
    end)

    ----------------------------------------------------------------
    -- Window API
    ----------------------------------------------------------------
    local Window = {}
    Window.Tabs = {}
    Window._activeTab = nil
    Window.ScreenGui = ScreenGui
    Window.Root = Root
    Window.Executions = 0

    function Window:SetProfile(c)
        c = c or {}
        if c.Name   then NameLabel.Text = tostring(c.Name) end
        if c.Avatar then Avatar.Image   = tostring(c.Avatar) end
    end
    function Window:SetExecutions(n)
        self.Executions = tonumber(n) or 0
        ExecLabel.Text  = "Executions: " .. self.Executions
    end
    function Window:AddExecution()
        self.Executions += 1
        ExecLabel.Text  = "Executions: " .. self.Executions
    end
    function Window:SetStatus() end -- back-compat no-op
    function Window:Destroy() ScreenGui:Destroy() end

    ----------------------------------------------------------------
    -- Tab
    ----------------------------------------------------------------
    function Window:CreateTab(tabCfg)
        tabCfg = tabCfg or {}
        local Name = tabCfg.Name or "Tab"
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

        -- Page (scrollable)
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
        padding(Page, 0, 10, 12, 0) -- right padding leaves room for scrollbar
        new("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Page,
        })

        -- Page header
        local HeaderHolder = new("Frame", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 64),
            BackgroundTransparency = 1,
            LayoutOrder = -1,
            Parent = Page,
        })
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = Name,
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = HeaderHolder,
        })
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            Position = UDim2.fromOffset(0, 32),
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

        -- Tab activation
        local Tab = { Name = Name, Button = TabBtn, Page = Page }

        local function setActive(active)
            if active then
                tween(TabBtn, 0.15, { BackgroundTransparency = 0, BackgroundColor3 = Theme.SidebarActive })
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
                tween(TabBtn, 0.12, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Card })
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
        -- Card builder
        ----------------------------------------------------------
        local function makeCard(height)
            local card = new("Frame", {
                Size = UDim2.new(1, 0, 0, height or 64),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Parent = Page,
            })
            corner(card, 10)
            stroke(card, Theme.BorderSubtle, 1)
            padding(card, 12, 14, 12, 14)
            card.MouseEnter:Connect(function() tween(card, 0.12, { BackgroundColor3 = Theme.CardHover }) end)
            card.MouseLeave:Connect(function() tween(card, 0.12, { BackgroundColor3 = Theme.Card }) end)
            return card
        end

        ----------------------------------------------------------
        -- Section
        ----------------------------------------------------------
        function Tab:AddSection(text)
            local holder = new("Frame", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Parent = Page,
            })
            new("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = text or "Section",
                TextColor3 = Theme.Muted,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })
            return holder
        end

        ----------------------------------------------------------
        -- Toggle
        ----------------------------------------------------------
        function Tab:AddToggle(opts)
            opts = opts or {}
            local value = opts.Default == true
            local card = makeCard(60)

            new("TextLabel", {
                Size = UDim2.new(1, -64, 0, 16),
                BackgroundTransparency = 1,
                Text = opts.Name or "Toggle",
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

            local api = {}
            function api:Set(v)
                value = v and true or false
                tween(sw,   0.16, { BackgroundColor3 = value and Theme.ToggleOn or Theme.ToggleOff })
                tween(knob, 0.16, {
                    Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    BackgroundColor3 = value and Theme.ToggleKnobOn or Theme.ToggleKnobOff,
                })
                Window:AddExecution()
                if opts.Callback then task.spawn(opts.Callback, value) end
            end
            function api:Get() return value end
            sw.MouseButton1Click:Connect(function() api:Set(not value) end)
            return api
        end

        ----------------------------------------------------------
        -- Button
        ----------------------------------------------------------
        function Tab:AddButton(opts)
            opts = opts or {}
            local card = makeCard(56)

            new("TextLabel", {
                Size = UDim2.new(1, -110, 0, 16),
                BackgroundTransparency = 1,
                Text = opts.Name or "Button",
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
                Parent = card,
            })

            local btn = new("TextButton", {
                Size = UDim2.fromOffset(96, 28),
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Accent,
                AutoButtonColor = false,
                Text = opts.ButtonText or "Run",
                TextColor3 = Color3.fromRGB(10, 10, 10),
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                Parent = card,
            })
            corner(btn, 7)
            btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Color3.fromRGB(220,220,220) }) end)
            btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Theme.Accent }) end)
            btn.MouseButton1Click:Connect(function()
                Window:AddExecution()
                if opts.Callback then task.spawn(opts.Callback) end
            end)
        end

        ----------------------------------------------------------
        -- Slider (mobile + desktop reliable drag)
        ----------------------------------------------------------
        function Tab:AddSlider(opts)
            opts = opts or {}
            local min = opts.Min or 0
            local max = opts.Max or 100
            local value = opts.Default or min
            local card = makeCard(72)

            new("TextLabel", {
                Size = UDim2.new(1, -60, 0, 16),
                BackgroundTransparency = 1,
                Text = opts.Name or "Slider",
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            local valLabel = new("TextLabel", {
                Size = UDim2.fromOffset(60, 16),
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

            -- Larger hit area surrounding the visible track for easier mobile dragging
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
                Size = UDim2.fromScale((value - min) / (max - min), 1),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(fill, 4)

            local function update(inputX)
                local trackPos  = track.AbsolutePosition.X
                local trackSize = track.AbsoluteSize.X
                if trackSize <= 0 then return end
                local relX = math.clamp((inputX - trackPos) / trackSize, 0, 1)
                value = math.floor((min + (max - min) * relX) + 0.5)
                fill.Size = UDim2.fromScale(relX, 1)
                valLabel.Text = tostring(value)
                if opts.Callback then task.spawn(opts.Callback, value) end
            end

            -- Reliable cross-platform drag using the GuiObject's own input events.
            local activeInput
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    activeInput = input
                    update(input.Position.X)
                    local conn
                    conn = input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            if activeInput == input then
                                activeInput = nil
                                Window:AddExecution()
                            end
                            conn:Disconnect()
                        end
                    end)
                end
            end)
            -- Touch updates fire here on mobile
            hit.InputChanged:Connect(function(input)
                if activeInput and (input.UserInputType == Enum.UserInputType.MouseMovement
                                 or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input.Position.X)
                end
            end)
            -- Desktop fallback (mouse may leave the hitbox while dragging)
            UserInputService.InputChanged:Connect(function(input)
                if activeInput and input.UserInputType == Enum.UserInputType.MouseMovement then
                    update(input.Position.X)
                end
            end)
        end

        ----------------------------------------------------------
        -- Dropdown (animated chevron)
        ----------------------------------------------------------
        function Tab:AddDropdown(opts)
            opts = opts or {}
            local options = opts.Options or {}
            local value = opts.Default or options[1]
            local card = makeCard(56)

            new("TextLabel", {
                Size = UDim2.new(1, -170, 0, 16),
                BackgroundTransparency = 1,
                Text = opts.Name or "Dropdown",
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
                AutoButtonColor = false,
                Text = tostring(value or "Select..."),
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ClipsDescendants = true,
                Parent = card,
            })
            corner(btn, 7)
            stroke(btn, Theme.Border, 1)
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
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
                Parent = ScreenGui,
            })
            corner(menu, 8)
            stroke(menu, Theme.Border, 1)
            new("UIListLayout", { Padding = UDim.new(0, 2), Parent = menu })
            padding(menu, 6, 6, 6, 6)

            local function reposMenu()
                local pos  = btn.AbsolutePosition
                local size = btn.AbsoluteSize
                menu.Position = UDim2.fromOffset(pos.X, pos.Y + size.Y + 4)
                menu.Size     = UDim2.fromOffset(size.X, (#options * 28) + 12)
            end

            local open = false
            local function setOpen(o)
                open = o
                if open then
                    reposMenu()
                    menu.Visible = true
                    tween(chevron, 0.18, { Rotation = 180 })
                    menu.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 0)
                    tween(menu, 0.18, { Size = UDim2.fromOffset(btn.AbsoluteSize.X, (#options * 28) + 12) })
                else
                    tween(chevron, 0.18, { Rotation = 0 })
                    local t = tween(menu, 0.16, { Size = UDim2.fromOffset(menu.Size.X.Offset, 0) })
                    t.Completed:Connect(function()
                        if not open then menu.Visible = false end
                    end)
                end
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
                it.MouseEnter:Connect(function() tween(it, 0.1, { BackgroundTransparency = 0 }) end)
                it.MouseLeave:Connect(function() tween(it, 0.1, { BackgroundTransparency = 1 }) end)
                it.MouseButton1Click:Connect(function()
                    value = opt
                    btn.Text = tostring(opt)
                    setOpen(false)
                    Window:AddExecution()
                    if opts.Callback then task.spawn(opts.Callback, opt) end
                end)
            end

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
        end

        ----------------------------------------------------------
        -- Label
        ----------------------------------------------------------
        function Tab:AddLabel(text)
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

        ----------------------------------------------------------
        -- Textbox
        ----------------------------------------------------------
        function Tab:AddTextbox(opts)
            opts = opts or {}
            local card = makeCard(56)
            new("TextLabel", {
                Size = UDim2.new(1, -170, 0, 16),
                BackgroundTransparency = 1,
                Text = opts.Name or "Textbox",
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
            stroke(tb, Theme.Border, 1)
            padding(tb, 0, 10, 0, 10)
            tb.FocusLost:Connect(function(enter)
                if enter then Window:AddExecution() end
                if opts.Callback then task.spawn(opts.Callback, tb.Text, enter) end
            end)
        end

        return Tab
    end

    return Window
end

-- Allow both `loadstring(...)():CreateWindow(...)`
-- and        `loadstring(...)().KaizenUI:CreateWindow(...)`
KaizenUI.KaizenUI = KaizenUI

return KaizenUI
