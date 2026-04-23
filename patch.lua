--[[
    Fluent UI -- Runtime Patch
    --------------------------------------------------------------------------
    Fixes:
      1. Slider drag reliability
         * Works correctly with Touch input (mobile / tablets).
         * Uses the input instance's own Changed signal instead of
           UserInputService:IsMouseButtonPressed, which never returns true
           for touch and is the root cause of "the slider sometimes can't
           be dragged" on mobile.
         * Tracks the *active* input, so a second finger / second click
           cannot hijack or cancel the drag mid-gesture.
         * Adds an invisible, slightly oversized hit-box on touch devices
           so the slider is easy to grab with a finger.
         * Re-clamps the value every frame from the input's live Position,
           so the knob follows your finger even when it leaves the bar.

      2. Responsive window sizing (mobile + desktop)
         * On phones / small viewports: the window fills the screen
           (with safe padding for the status bar).
         * On desktop: the window is sized proportionally to the
           viewport and re-flows when the window is resized.

    Usage:
      local Fluent = loadstring(game:HttpGet(
          "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
      ))()

      -- Load the patch and apply it to Fluent:
      loadstring(game:HttpGet("<url to this patch.lua>"))(Fluent)

      -- Then build your UI as usual:
      local Window = Fluent:CreateWindow({ ... })
      local Tab    = Window:AddTab({ ... })
      Tab:AddSlider("MySlider", { ... })  -- automatically patched
--]]

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")

local applyPatch -- forward declare so `return applyPatch` works at the bottom

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function isTouchPrimary()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function safeDisconnect(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function() conn:Disconnect() end)
    end
end

local function findFluentScreenGui()
    -- Fluent parents its ScreenGui to CoreGui (exploit contexts) or
    -- PlayerGui (normal contexts). Check both.
    local sg = CoreGui:FindFirstChild("Fluent")
    if sg then return sg end
    local lp = Players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChildWhichIsA("PlayerGui")
        if pg then return pg:FindFirstChild("Fluent") end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Slider rewiring
--
-- Given a Fluent slider object (or a shim with just .SliderFrame / .Min /
-- .Max / .Rounding), replace its input handling with a robust, touch-aware
-- implementation.
--------------------------------------------------------------------------------

local function rewireSlider(sliderObject)
    if type(sliderObject) ~= "table" then return end

    -- Fluent has gone through a few field names over releases; try them all.
    local sliderFrame =
        sliderObject.SliderFrame
        or sliderObject.Slider
        or sliderObject.Bar
        or (sliderObject.Instance and sliderObject.Instance:FindFirstChild("Slider", true))

    if not (sliderFrame and sliderFrame:IsA("GuiObject")) then
        return
    end

    -- Disconnect any previous patch connections (so re-applying is safe).
    if sliderObject._patchConns then
        for _, c in ipairs(sliderObject._patchConns) do safeDisconnect(c) end
    end
    sliderObject._patchConns = {}

    local dragging    = false
    local activeInput = nil

    local function getRange()
        local min = sliderObject.Min or sliderObject.MinValue or 0
        local max = sliderObject.Max or sliderObject.MaxValue or 1
        if max <= min then max = min + 1 end
        return min, max
    end

    local function valueFromX(posX)
        local absPos  = sliderFrame.AbsolutePosition.X
        local absSize = sliderFrame.AbsoluteSize.X
        if absSize <= 0 then return nil end
        local alpha  = math.clamp((posX - absPos) / absSize, 0, 1)
        local min, max = getRange()
        local rounding = sliderObject.Rounding or 0
        local value = min + (max - min) * alpha
        if rounding > 0 then
            local mult = 10 ^ rounding
            value = math.floor(value * mult + 0.5) / mult
        else
            value = math.floor(value + 0.5)
        end
        return value
    end

    local function setValue(v)
        if v == nil then return end
        -- Try every known setter name Fluent has shipped.
        if typeof(sliderObject.SetValue) == "function" then
            pcall(sliderObject.SetValue, sliderObject, v)
        elseif typeof(sliderObject.Set) == "function" then
            pcall(sliderObject.Set, sliderObject, v)
        else
            sliderObject.Value = v
            if typeof(sliderObject.Update) == "function" then
                pcall(sliderObject.Update, sliderObject)
            end
        end
    end

    local function beginDrag(input)
        dragging    = true
        activeInput = input
        setValue(valueFromX(input.Position.X))

        -- Listen on the input *instance* directly. This is the key fix:
        -- input.Changed fires once per position update and once more with
        -- UserInputState.End, for both mouse AND touch, without any of
        -- the IsMouseButtonPressed edge cases.
        local changedConn
        changedConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End
                or input.UserInputState == Enum.UserInputState.Cancel then
                if activeInput == input then
                    dragging    = false
                    activeInput = nil
                end
                safeDisconnect(changedConn)
            end
        end)
        table.insert(sliderObject._patchConns, changedConn)
    end

    -- Start drag when the user presses on the bar.
    table.insert(sliderObject._patchConns, sliderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end))

    -- Track movement globally so the knob still follows the pointer /
    -- finger when it leaves the bar's bounds while dragging.
    table.insert(sliderObject._patchConns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        -- For touch, only follow the *same* finger that started the drag.
        if activeInput
            and input.UserInputType == Enum.UserInputType.Touch
            and input ~= activeInput then
            return
        end
        setValue(valueFromX(input.Position.X))
    end))

    -- Safety net in case input.Changed's End state is missed for any reason.
    table.insert(sliderObject._patchConns, UserInputService.InputEnded:Connect(function(input)
        if input == activeInput then
            dragging    = false
            activeInput = nil
        end
    end))

    --------------------------------------------------------------------------
    -- Enlarged touch hit-box (mobile only).
    --------------------------------------------------------------------------
    if isTouchPrimary() then
        local hit = sliderFrame:FindFirstChild("__PatchHitbox")
        if not hit then
            hit = Instance.new("Frame")
            hit.Name               = "__PatchHitbox"
            hit.BackgroundTransparency = 1
            hit.BorderSizePixel    = 0
            hit.ZIndex             = (sliderFrame.ZIndex or 1) + 1
            hit.Active             = true
            -- 16px taller than the bar (8px above, 8px below) for fat fingers.
            hit.Size               = UDim2.new(1, 0, 1, 16)
            hit.Position           = UDim2.new(0, 0, 0, -8)
            hit.Parent             = sliderFrame
        end

        table.insert(sliderObject._patchConns, hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                beginDrag(input)
            end
        end))
    end
end

--------------------------------------------------------------------------------
-- Responsive window sizing
--------------------------------------------------------------------------------

local function applyResponsive(window)
    if type(window) ~= "table" then return end

    -- Find the root frame of the window. Fluent has named this a few ways.
    local root =
        window.Root
        or window.Main
        or window.Instance
        or window.Holder
        or window.Container

    if not (root and root:IsA("GuiObject")) then
        -- Last-ditch: grab the first Frame under the Fluent ScreenGui.
        local sg = findFluentScreenGui()
        if sg then root = sg:FindFirstChildWhichIsA("Frame") end
    end
    if not (root and root:IsA("GuiObject")) then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local function recompute()
        local vp    = camera.ViewportSize
        local touch = isTouchPrimary()

        root.AnchorPoint = Vector2.new(0.5, 0.5)

        if touch or vp.X < 900 then
            -- Mobile / narrow: nearly full-screen with safe padding.
            local padX = 16
            local padY = 24 -- a little extra for notches / status bars
            root.Size     = UDim2.new(1, -padX * 2, 1, -padY * 2)
            root.Position = UDim2.fromScale(0.5, 0.5)
        else
            -- Desktop: proportional, clamped to sane min/max.
            local w = math.clamp(vp.X * 0.55, 520, 1000)
            local h = math.clamp(vp.Y * 0.65, 380, 720)
            root.Size     = UDim2.fromOffset(w, h)
            root.Position = UDim2.fromScale(0.5, 0.5)
        end
    end

    pcall(recompute)

    -- Re-flow on viewport changes (window resize, rotation, etc.)
    local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        pcall(recompute)
    end)

    -- Also re-check when touch/mouse capability changes (e.g. controller hotplug).
    UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
        pcall(recompute)
    end)
    UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(function()
        pcall(recompute)
    end)

    return conn
end

--------------------------------------------------------------------------------
-- Hook into Fluent's factory methods so every slider is patched automatically.
--------------------------------------------------------------------------------

local function patchTabObject(tab)
    if type(tab) ~= "table" or tab.__SliderPatched then return end
    tab.__SliderPatched = true

    local originalAddSlider = tab.AddSlider
    if typeof(originalAddSlider) == "function" then
        tab.AddSlider = function(self, ...)
            local slider = originalAddSlider(self, ...)
            pcall(rewireSlider, slider)
            return slider
        end
    end
end

local function patchWindowObject(window)
    if type(window) ~= "table" or window.__FluentPatched then return end
    window.__FluentPatched = true

    -- Wrap AddTab so every new tab's AddSlider is patched.
    local originalAddTab = window.AddTab
    if typeof(originalAddTab) == "function" then
        window.AddTab = function(self, ...)
            local tab = originalAddTab(self, ...)
            pcall(patchTabObject, tab)
            return tab
        end
    end

    pcall(applyResponsive, window)
end

--------------------------------------------------------------------------------
-- Patch any sliders that already exist in the GUI (if the patch is loaded
-- AFTER the window has already been built). Walks the Fluent ScreenGui and
-- rewires every frame named "Slider" it finds.
--------------------------------------------------------------------------------

local function patchExistingSliders()
    task.spawn(function()
        local sg
        for _ = 1, 30 do
            sg = findFluentScreenGui()
            if sg then break end
            task.wait(0.1)
        end
        if not sg then return end

        local function tryPatch(inst)
            if inst.Name == "Slider" and inst:IsA("GuiObject") then
                local shim = {
                    SliderFrame = inst,
                    Min         = inst:GetAttribute("Min")      or 0,
                    Max         = inst:GetAttribute("Max")      or 1,
                    Rounding    = inst:GetAttribute("Rounding") or 0,
                }
                pcall(rewireSlider, shim)
            end
        end

        for _, d in ipairs(sg:GetDescendants()) do tryPatch(d) end
        sg.DescendantAdded:Connect(tryPatch)
    end)
end

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

applyPatch = function(Fluent)
    Fluent = Fluent
        or (getgenv and getgenv().Fluent)
        or _G.Fluent
    if type(Fluent) ~= "table" then
        warn("[FluentPatch] Fluent library not provided. Pass it as an argument: loadstring(...)(Fluent)")
        return
    end

    -- Hook future windows.
    local originalCreateWindow = Fluent.CreateWindow
    if typeof(originalCreateWindow) == "function" and not Fluent.__FluentPatched then
        Fluent.__FluentPatched = true
        Fluent.CreateWindow = function(self, ...)
            local window = originalCreateWindow(self, ...)
            pcall(patchWindowObject, window)
            return window
        end
    end

    -- Cover the case where the user already created a window before loading
    -- the patch: scan the live GUI and rewire anything we can find.
    patchExistingSliders()

    print("[FluentPatch] Slider + responsive patch applied")
    return Fluent
end

-- Allow two call styles:
--   loadstring(src)(Fluent)        -- immediate
--   local patch = loadstring(src)()  patch(Fluent)  -- deferred
local arg = ...
if type(arg) == "table" then
    applyPatch(arg)
    return true
end

return applyPatch
