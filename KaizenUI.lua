--[[
    KaizenUI — A shadcn-inspired, dark solid UI library for Roblox (Lua)
    Style reference: KaizenHub (dark sidebar, card toggles, fluent/lucide icons)

    Features:
      • Dark solid theme (shadcn-like cards, borders, typography)
      • Fluent / Lucide icons (Roblox asset IDs)
      • Sidebar navigation with tabs
      • Responsive (mobile + desktop) — auto-scales, touch support
      • Draggable window (mouse + touch)
      • Components: Section, Toggle, Button, Slider, Dropdown, Label, Keybind, Textbox
      • Loading / status indicator in the sidebar footer
      • Your logo baked in: rbxassetid://124205601170943

    Usage (bottom of file has a full example):
      local KaizenUI = loadstring(game:HttpGet("<your-url>/KaizenUI.lua"))()
      local Window = KaizenUI:CreateWindow({
          Title    = "KaizenHub",
          Subtitle = "[ UPD ] • A Sobreviva o Apocalipse • Delta",
          LogoId   = "rbxassetid://124205601170943",
      })
      local Tab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })
      Tab:AddToggle({ Name = "Item ESP", Description = "Highlights items in the world.", Default = false,
          Callback = function(v) print(v) end })
]]

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local GuiService        = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 5) or nil

----------------------------------------------------------------
-- Theme (shadcn dark — solid, no gradients)
----------------------------------------------------------------
local Theme = {
    Background     = Color3.fromRGB(10, 10, 10),   -- window bg
    Sidebar        = Color3.fromRGB(14, 14, 14),   -- sidebar bg
    SidebarActive  = Color3.fromRGB(26, 26, 26),   -- active tab bg
    Card           = Color3.fromRGB(18, 18, 18),   -- setting card
    CardHover      = Color3.fromRGB(26, 26, 26),
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
-- Icon map (Lucide / Fluent-style, from your Icons.lua)
-- Use short keys in your code; library resolves the asset id.
----------------------------------------------------------------
local Icons = {
    -- navigation / common
    eye        = "rbxassetid://10723346959",
    user       = "rbxassetid://10747373176",
    swords     = "rbxassetid://10734975692",
    sword      = "rbxassetid://10734975486",
    activity   = "rbxassetid://10709752035", -- lightning-ish pulse (Exploits)
    zap        = "rbxassetid://10709752035",
    settings   = "rbxassetid://10734950309",
    cog        = "rbxassetid://10709810948",
    home       = "rbxassetid://10723407389",
    shield     = "rbxassetid://10734951847",
    target     = "rbxassetid://10734977012",
    crosshair  = "rbxassetid://10709818534",
    bell       = "rbxassetid://10709775704",
    folder     = "rbxassetid://10723387563",
    palette    = "rbxassetid://10734910430",
    sliders    = "rbxassetid://10734963400",
    info       = "rbxassetid://10723415903",
    search     = "rbxassetid://10734943674",
    power      = "rbxassetid://10734930466",
    save       = "rbxassetid://10734941499",
    trash      = "rbxassetid://10747362393",
    wrench     = "rbxassetid://10747383470",
    code       = "rbxassetid://10709810463",
    keyboard   = "rbxassetid://10723416765",
    mouse      = "rbxassetid://10734898592",
    gamepad    = "rbxassetid://10723395457",
    list       = "rbxassetid://10723433811",
    grid       = "rbxassetid://10723404936",
    loader     = "rbxassetid://10723434070",
    menu       = "rbxassetid://10734887784",
    plus       = "rbxassetid://10734924532",
    minus      = "rbxassetid://10734896206",
    x          = "rbxassetid://10747384394",
    chevron    = "rbxassetid://10709791437",
    command    = "rbxassetid://10709811365",
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

local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

----------------------------------------------------------------
-- Draggable (mouse + touch)
----------------------------------------------------------------
local function makeDraggable(dragHandle, dragTarget)
    local dragging, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = dragTarget.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            dragTarget.Position = UDim2.new(
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
-- Window
----------------------------------------------------------------
function KaizenUI:CreateWindow(cfg)
    cfg = cfg or {}
    local Title    = cfg.Title    or "KaizenHub"
    local Subtitle = cfg.Subtitle or "[ UPD ] • Script Hub • Delta"
    local LogoId   = cfg.LogoId   or "rbxassetid://124205601170943"

    -- responsive defaults
    local mobile = isMobile()
    local defaultSize = mobile and UDim2.fromOffset(360, 420) or UDim2.fromOffset(820, 520)

    -- parent (try CoreGui via gethui, fallback to PlayerGui)
    local guiParent
    local ok = pcall(function()
        if gethui then guiParent = gethui() end
    end)
    if not guiParent then
        ok = pcall(function() guiParent = CoreGui end)
        if not ok or not guiParent then guiParent = PlayerGui end
    end

    -- destroy any existing instance
    local existing = guiParent:FindFirstChild("KaizenUI")
    if existing then existing:Destroy() end

    local ScreenGui = new("ScreenGui", {
        Name = "KaizenUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = guiParent,
    })

    -- Root window
    local Root = new("Frame", {
        Name = "Root",
        Size = defaultSize,
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = ScreenGui,
    })
    corner(Root, 12)
    stroke(Root, Theme.Border, 1)

    -- Top bar
    local TopBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = Root,
    })
    padding(TopBar, 0, 16, 0, 16)

    -- bottom border for topbar
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    -- Logo
    local Logo = new("ImageLabel", {
        Name = "Logo",
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        BorderSizePixel = 0,
        Image = LogoId,
        ScaleType = Enum.ScaleType.Fit,
        Parent = TopBar,
    })
    corner(Logo, 8)
    stroke(Logo, Theme.Border, 1)

    -- Title
    local TitleLabel = new("TextLabel", {
        Name = "Title",
        Size = UDim2.fromOffset(140, 28),
        Position = UDim2.new(0, 44, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    -- Subtitle (hidden on mobile)
    local SubtitleLabel = new("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(1, -280, 0, 20),
        Position = UDim2.new(0, 190, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = Subtitle,
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Visible = not mobile,
        Parent = TopBar,
    })

    -- Window controls (minimize / close)
    local function makeIconButton(iconKey, posOffset)
        local btn = new("ImageButton", {
            Size = UDim2.fromOffset(28, 28),
            Position = UDim2.new(1, posOffset, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Theme.Background,
            BackgroundTransparency = 1,
            Image = resolveIcon(iconKey),
            ImageColor3 = Theme.SubText,
            Parent = TopBar,
        })
        corner(btn, 6)
        btn.MouseEnter:Connect(function()
            tween(btn, 0.12, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Card, ImageColor3 = Theme.Text })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.12, { BackgroundTransparency = 1, ImageColor3 = Theme.SubText })
        end)
        return btn
    end

    local CloseBtn = makeIconButton("x", 0)
    local MinBtn   = makeIconButton("minus", -36)

    local minimized = false
    local fullSize = defaultSize
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            fullSize = Root.Size
            tween(Root, 0.22, { Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 56) })
        else
            tween(Root, 0.22, { Size = fullSize })
        end
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        tween(Root, 0.18, { Size = UDim2.fromOffset(0, 0) }).Completed:Connect(function()
            ScreenGui:Destroy()
        end)
    end)

    makeDraggable(TopBar, Root)

    ----------------------------------------------------------------
    -- Body layout: Sidebar + Content
    ----------------------------------------------------------------
    local Body = new("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -56),
        Position = UDim2.fromOffset(0, 56),
        BackgroundTransparency = 1,
        Parent = Root,
    })

    local sidebarWidth = mobile and 160 or 220
    local Sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = Body,
    })
    padding(Sidebar, 12, 12, 12, 12)
    -- right border of sidebar
    new("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.BorderSubtle,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    local TabList = new("Frame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -80),
        BackgroundTransparency = 1,
        Parent = Sidebar,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabList,
    })

    -- Footer status card (like "Injecting... Please wait")
    local Status = new("Frame", {
        Name = "Status",
        Size = UDim2.new(1, 0, 0, 64),
        Position = UDim2.new(0, 0, 1, -64),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })
    corner(Status, 10)
    stroke(Status, Theme.BorderSubtle, 1)
    padding(Status, 10, 10, 10, 10)

    local Spinner = new("ImageLabel", {
        Name = "Spinner",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = resolveIcon("loader"),
        ImageColor3 = Theme.Text,
        Parent = Status,
    })
    local StatusTitle = new("TextLabel", {
        Size = UDim2.new(1, -36, 0, 16),
        Position = UDim2.fromOffset(36, 2),
        BackgroundTransparency = 1,
        Text = "Ready",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Status,
    })
    local StatusDesc = new("TextLabel", {
        Size = UDim2.new(1, -36, 0, 14),
        Position = UDim2.fromOffset(36, 22),
        BackgroundTransparency = 1,
        Text = "All systems nominal",
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Status,
    })

    -- rotate spinner
    task.spawn(function()
        while Spinner.Parent do
            Spinner.Rotation = (Spinner.Rotation + 6) % 360
            RunService.RenderStepped:Wait()
        end
    end)

    -- Content area
    local Content = new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -sidebarWidth, 1, 0),
        Position = UDim2.fromOffset(sidebarWidth, 0),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = Body,
    })
    padding(Content, 24, 24, 24, 24)

    local Pages = new("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = Content,
    })

    ----------------------------------------------------------------
    -- Responsive resizing
    ----------------------------------------------------------------
    local function updateResponsive()
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local narrow = vp.X < 700
        SubtitleLabel.Visible = not narrow
        if narrow then
            Root.Size = UDim2.fromOffset(math.min(vp.X - 20, 380), math.min(vp.Y - 40, 460))
            Sidebar.Size = UDim2.new(0, 150, 1, 0)
            Content.Size = UDim2.new(1, -150, 1, 0)
            Content.Position = UDim2.fromOffset(150, 0)
        else
            Sidebar.Size = UDim2.new(0, 220, 1, 0)
            Content.Size = UDim2.new(1, -220, 1, 0)
            Content.Position = UDim2.fromOffset(220, 0)
        end
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive)
    end
    updateResponsive()

    ----------------------------------------------------------------
    -- Window API
    ----------------------------------------------------------------
    local Window = {}
    Window.Tabs = {}
    Window._activeTab = nil
    Window.ScreenGui = ScreenGui
    Window.Root = Root

    function Window:SetStatus(title, desc, iconKey)
        StatusTitle.Text = title or StatusTitle.Text
        StatusDesc.Text = desc or StatusDesc.Text
        if iconKey then Spinner.Image = resolveIcon(iconKey) end
    end

    function Window:Destroy()
        ScreenGui:Destroy()
    end

    ------------------------------------------------------------
    -- Tab
    ------------------------------------------------------------
    function Window:CreateTab(tabCfg)
        tabCfg = tabCfg or {}
        local Name = tabCfg.Name or "Tab"
        local Icon = resolveIcon(tabCfg.Icon or "grid")

        -- Sidebar button
        local TabBtn = new("TextButton", {
            Name = "Tab_" .. Name,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Theme.Sidebar,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Parent = TabList,
        })
        corner(TabBtn, 8)
        padding(TabBtn, 0, 12, 0, 12)

        local TabIcon = new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Image = Icon,
            ImageColor3 = Theme.SubText,
            Parent = TabBtn,
        })
        local TabLabel = new("TextLabel", {
            Size = UDim2.new(1, -28, 1, 0),
            Position = UDim2.fromOffset(28, 0),
            BackgroundTransparency = 1,
            Text = Name,
            TextColor3 = Theme.SubText,
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = TabBtn,
        })

        -- Page
        local Page = new("ScrollingFrame", {
            Name = "Page_" .. Name,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = Pages,
        })

        -- Page header (Visuals / Adjust visual enhancements...)
        local HeaderHolder = new("Frame", {
            Name = "Header",
            Size = UDim2.new(1, -4, 0, 70),
            BackgroundTransparency = 1,
            LayoutOrder = -1,
            Parent = Page,
        })
        local PageTitle = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = Name,
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 24,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = HeaderHolder,
        })
        local PageDesc = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            Position = UDim2.fromOffset(0, 34),
            BackgroundTransparency = 1,
            Text = tabCfg.Description or ("Configure " .. Name:lower() .. " options."),
            TextColor3 = Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = HeaderHolder,
        })
        -- thin divider
        new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -1),
            BackgroundColor3 = Theme.BorderSubtle,
            BorderSizePixel = 0,
            Parent = HeaderHolder,
        })

        local List = new("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Page,
        })
        padding(Page, 0, 8, 12, 0)

        -- activation
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
            if Window._activeTab then
                Window._activeTab._setActive(false)
            end
            Window._activeTab = Tab
            setActive(true)
        end)

        Tab._setActive = setActive

        -- auto-activate first tab
        if not Window._activeTab then
            Window._activeTab = Tab
            setActive(true)
        end

        table.insert(Window.Tabs, Tab)

        ----------------------------------------------------------
        -- Components
        ----------------------------------------------------------

        -- Section label (small uppercase-ish heading)
        function Tab:AddSection(text)
            local holder = new("Frame", {
                Size = UDim2.new(1, -4, 0, 22),
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

        -- Shared card builder
        local function makeCard(height)
            local card = new("Frame", {
                Size = UDim2.new(1, -4, 0, height or 64),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Parent = Page,
            })
            corner(card, 10)
            stroke(card, Theme.BorderSubtle, 1)
            padding(card, 14, 16, 14, 16)
            card.MouseEnter:Connect(function()
                tween(card, 0.12, { BackgroundColor3 = Theme.CardHover })
            end)
            card.MouseLeave:Connect(function()
                tween(card, 0.12, { BackgroundColor3 = Theme.Card })
            end)
            return card
        end

        -- Toggle
        function Tab:AddToggle(opts)
            opts = opts or {}
            local value = opts.Default == true

            local card = makeCard(64)

            local title = new("TextLabel", {
                Size = UDim2.new(1, -70, 0, 18),
                BackgroundTransparency = 1,
                Text = opts.Name or "Toggle",
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            local desc = new("TextLabel", {
                Size = UDim2.new(1, -70, 0, 14),
                Position = UDim2.fromOffset(0, 20),
                BackgroundTransparency = 1,
                Text = opts.Description or "",
                TextColor3 = Theme.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = card,
            })

            local sw = new("TextButton", {
                Size = UDim2.fromOffset(44, 24),
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = value and Theme.ToggleOn or Theme.ToggleOff,
                AutoButtonColor = false,
                Text = "",
                Parent = card,
            })
            corner(sw, 12)

            local knob = new("Frame", {
                Size = UDim2.fromOffset(18, 18),
                Position = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = value and Theme.ToggleKnobOn or Theme.ToggleKnobOff,
                BorderSizePixel = 0,
                Parent = sw,
            })
            corner(knob, 9)

            local api = {}
            function api:Set(v)
                value = v and true or false
                tween(sw,   0.16, { BackgroundColor3 = value and Theme.ToggleOn or Theme.ToggleOff })
                tween(knob, 0.16, {
                    Position = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    BackgroundColor3 = value and Theme.ToggleKnobOn or Theme.ToggleKnobOff,
                })
                if opts.Callback then
                    task.spawn(opts.Callback, value)
                end
            end
            function api:Get() return value end

            sw.MouseButton1Click:Connect(function() api:Set(not value) end)
            return api
        end

        -- Button
        function Tab:AddButton(opts)
            opts = opts or {}
            local card = makeCard(60)

            local title = new("TextLabel", {
                Size = UDim2.new(1, -110, 0, 18),
                BackgroundTransparency = 1,
                Text = opts.Name or "Button",
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            local desc = new("TextLabel", {
                Size = UDim2.new(1, -110, 0, 14),
                Position = UDim2.fromOffset(0, 20),
                BackgroundTransparency = 1,
                Text = opts.Description or "",
                TextColor3 = Theme.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })

            local btn = new("TextButton", {
                Size = UDim2.fromOffset(100, 30),
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Accent,
                AutoButtonColor = false,
                Text = opts.ButtonText or "Run",
                TextColor3 = Color3.fromRGB(10, 10, 10),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                Parent = card,
            })
            corner(btn, 8)
            btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Color3.fromRGB(220, 220, 220) }) end)
            btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Theme.Accent }) end)
            btn.MouseButton1Click:Connect(function()
                if opts.Callback then task.spawn(opts.Callback) end
            end)
        end

        -- Slider
        function Tab:AddSlider(opts)
            opts = opts or {}
            local min = opts.Min or 0
            local max = opts.Max or 100
            local value = opts.Default or min
            local card = makeCard(78)

            local title = new("TextLabel", {
                Size = UDim2.new(1, -60, 0, 18),
                BackgroundTransparency = 1,
                Text = opts.Name or "Slider",
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            local valLabel = new("TextLabel", {
                Size = UDim2.fromOffset(60, 18),
                Position = UDim2.new(1, 0, 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Text = tostring(value),
                TextColor3 = Theme.SubText,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = card,
            })

            local track = new("Frame", {
                Size = UDim2.new(1, 0, 0, 6),
                Position = UDim2.new(0, 0, 1, -14),
                AnchorPoint = Vector2.new(0, 1),
                BackgroundColor3 = Theme.ToggleOff,
                BorderSizePixel = 0,
                Parent = card,
            })
            corner(track, 4)

            local fill = new("Frame", {
                Size = UDim2.fromScale((value - min) / (max - min), 1),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = track,
            })
            corner(fill, 4)

            local hit = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                Position = UDim2.new(0, 0, 1, -22),
                AnchorPoint = Vector2.new(0, 1),
                BackgroundTransparency = 1,
                Text = "",
                Parent = card,
            })

            local dragging = false
            local function update(inputX)
                local relX = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                value = math.floor((min + (max - min) * relX) + 0.5)
                fill.Size = UDim2.fromScale(relX, 1)
                valLabel.Text = tostring(value)
                if opts.Callback then task.spawn(opts.Callback, value) end
            end
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    update(input.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                              or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
        end

        -- Dropdown
        function Tab:AddDropdown(opts)
            opts = opts or {}
            local options = opts.Options or {}
            local value = opts.Default or options[1]
            local card = makeCard(60)

            local title = new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 18),
                BackgroundTransparency = 1,
                Text = opts.Name or "Dropdown",
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            local desc = new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 14),
                Position = UDim2.fromOffset(0, 20),
                BackgroundTransparency = 1,
                Text = opts.Description or "",
                TextColor3 = Theme.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })

            local btn = new("TextButton", {
                Size = UDim2.fromOffset(160, 32),
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Background,
                AutoButtonColor = false,
                Text = tostring(value or "Select..."),
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            corner(btn, 8)
            stroke(btn, Theme.Border, 1)
            padding(btn, 0, 28, 0, 10)

            new("ImageLabel", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(1, -22, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = resolveIcon("chevron"),
                ImageColor3 = Theme.SubText,
                Rotation = 90,
                Parent = btn,
            })

            local menu = new("Frame", {
                Size = UDim2.fromOffset(160, 0),
                Position = UDim2.new(1, 0, 1, 6),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 10,
                Parent = card,
            })
            corner(menu, 8)
            stroke(menu, Theme.Border, 1)
            local ml = new("UIListLayout", { Padding = UDim.new(0, 2), Parent = menu })
            padding(menu, 6, 6, 6, 6)

            local open = false
            local function toggle()
                open = not open
                menu.Visible = open
                menu.Size = UDim2.fromOffset(160, (#options * 30) + 12)
            end

            for _, opt in ipairs(options) do
                local it = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = Theme.Card,
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = tostring(opt),
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 11,
                    Parent = menu,
                })
                corner(it, 6)
                padding(it, 0, 0, 0, 10)
                it.MouseEnter:Connect(function() tween(it, 0.1, { BackgroundTransparency = 0, BackgroundColor3 = Theme.CardHover }) end)
                it.MouseLeave:Connect(function() tween(it, 0.1, { BackgroundTransparency = 1 }) end)
                it.MouseButton1Click:Connect(function()
                    value = opt
                    btn.Text = tostring(opt)
                    toggle()
                    if opts.Callback then task.spawn(opts.Callback, opt) end
                end)
            end

            btn.MouseButton1Click:Connect(toggle)
        end

        -- Label (just text)
        function Tab:AddLabel(text)
            local lbl = new("TextLabel", {
                Size = UDim2.new(1, -4, 0, 20),
                BackgroundTransparency = 1,
                Text = text or "",
                TextColor3 = Theme.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Page,
            })
            return lbl
        end

        -- Textbox
        function Tab:AddTextbox(opts)
            opts = opts or {}
            local card = makeCard(60)
            new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 18),
                BackgroundTransparency = 1,
                Text = opts.Name or "Textbox",
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 14),
                Position = UDim2.fromOffset(0, 20),
                BackgroundTransparency = 1,
                Text = opts.Description or "",
                TextColor3 = Theme.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            local tb = new("TextBox", {
                Size = UDim2.fromOffset(160, 32),
                Position = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Text = opts.Default or "",
                PlaceholderText = opts.Placeholder or "Type…",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                Parent = card,
            })
            corner(tb, 8)
            stroke(tb, Theme.Border, 1)
            padding(tb, 0, 10, 0, 10)
            tb.FocusLost:Connect(function(enter)
                if opts.Callback then task.spawn(opts.Callback, tb.Text, enter) end
            end)
        end

        return Tab
    end

    return Window
end

return KaizenUI
