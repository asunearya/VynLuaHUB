--[[
    VynLua Hub v1.0
     WARNING DO NOT CHANGE IT IN THE LITTLE BIT
     
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

if env.VynLuaCleanup then pcall(env.VynLuaCleanup) end

local conns = {}
local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(conns, c)
    return c
end

local C = {
    bg      = Color3.fromRGB(5, 9, 19),
    panel   = Color3.fromRGB(10, 19, 36),
    panel2  = Color3.fromRGB(16, 30, 55),
    line    = Color3.fromRGB(24, 56, 92),
    accent  = Color3.fromRGB(56, 200, 255),
    accent2 = Color3.fromRGB(0, 120, 255),
    accent3 = Color3.fromRGB(110, 100, 255),
    text    = Color3.fromRGB(225, 240, 255),
    dim     = Color3.fromRGB(105, 140, 180),
    off     = Color3.fromRGB(30, 46, 72),
    danger  = Color3.fromRGB(255, 70, 120),
    warn    = Color3.fromRGB(255, 190, 70),
}

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function round(o, r)
    return make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o)
end

local function stroke(o, col, th, tr)
    return make("UIStroke", {
        Color = col, Thickness = th or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

local animGrads = {}
local function glowStroke(o, th)
    local s = stroke(o, C.accent, th or 1.5, 0)
    local g = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.accent),
            ColorSequenceKeypoint.new(0.35, C.accent2),
            ColorSequenceKeypoint.new(0.65, C.accent3),
            ColorSequenceKeypoint.new(1, C.accent),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, s)
    table.insert(animGrads, g)
    return s
end

local function place(page, obj)
    local n = (page:GetAttribute("n") or 0) + 1
    page:SetAttribute("n", n)
    obj.LayoutOrder = n
    obj.Parent = page
    return obj
end

local function getParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    return lp:WaitForChild("PlayerGui")
end

local S = {
    fly = false, flySpeed = 60,
    walk = false, walkSpeed = 50,
    jump = false, jumpPower = 100,
    infJump = false, noclip = false, afk = true,
}

local function hum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local startHum = hum()
local defWalk = startHum and startHum.WalkSpeed or 16
local defJump = startHum and startHum.JumpPower or 50

local parent = getParent()
local old = parent:FindFirstChild("VynLua")
if old then old:Destroy() end

local gui = make("ScreenGui", {
    Name = "VynLua", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
gui.Parent = parent

local GLOW = "rbxassetid://5028857084"
local function addGlow(target, pad, transp)
    return make("ImageLabel", {
        Size = UDim2.new(1, pad * 2, 1, pad * 2), Position = UDim2.fromOffset(-pad, -pad),
        BackgroundTransparency = 1, Image = GLOW, ImageColor3 = C.accent,
        ImageTransparency = transp, ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(24, 24, 276, 276), ZIndex = 0,
    }, target)
end

-- toast
local toast = make("TextLabel", {
    Size = UDim2.fromOffset(260, 32), AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -24), BackgroundColor3 = C.panel,
    TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13,
    Visible = false, ZIndex = 50,
}, gui)
round(toast, 8); glowStroke(toast, 1.5)
local toastId = 0
local function notify(t)
    toastId += 1
    local id = toastId
    toast.Text = t
    toast.Visible = true
    task.delay(2, function()
        if id == toastId then toast.Visible = false end
    end)
end

local function drag(handle, target, onTap, clamp)
    local active, start, origin, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            active, moved = true, false
            start, origin = i.Position, target.Position
        end
    end)
    bind(UIS.InputChanged, function(i)
        if not active then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - start
            if d.Magnitude > 5 then moved = true end
            if moved then
                local x, y = origin.X.Offset + d.X, origin.Y.Offset + d.Y
                if clamp then
                    local vp = Workspace.CurrentCamera.ViewportSize
                    x = math.clamp(x, 0, vp.X - target.AbsoluteSize.X)
                    y = math.clamp(y, 0, vp.Y - target.AbsoluteSize.Y)
                end
                target.Position = UDim2.new(origin.X.Scale, x, origin.Y.Scale, y)
            end
        end
    end)
    bind(UIS.InputEnded, function(i)
        if active and (i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch) then
            active = false
            if not moved and onTap then onTap() end
        end
    end)
end
l
local vp = Workspace.CurrentCamera.ViewportSize
local baseScale = math.clamp(math.min(vp.X / 540, vp.Y / 335), 0.6, 1)
local RAD = 10 

local holder = make("Frame", {
    Name = "Holder", Size = UDim2.fromOffset(520, 310),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1, Visible = false,
}, gui)
local scale = make("UIScale", { Scale = baseScale }, holder)
addGlow(holder, 22, 0.72)

local win = make("Frame", {
    Name = "Window", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, holder)
round(win, RAD)
glowStroke(win, 1.6)

local headerGrad = ColorSequence.new(C.panel2, C.panel)
local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, win)
round(header, RAD)
make("UIGradient", { Color = headerGrad }, header)
local hCover = make("Frame", {
    Size = UDim2.new(1, 0, 0, RAD), Position = UDim2.new(0, 0, 1, -RAD),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, header)
make("UIGradient", { Color = headerGrad }, hCover)

local hLine = make("Frame", {
    Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
    BackgroundColor3 = C.accent, BorderSizePixel = 0,
}, header)
make("UIGradient", {
    Color = ColorSequence.new(C.accent, C.accent3),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.92),
    }),
}, hLine)

-- logo kecil
local logo = make("Frame", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(12, 7),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, header)
round(logo, 7); glowStroke(logo, 1.5)
make("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "V",
    Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = C.accent,
}, logo)

make("TextLabel", {
    Size = UDim2.new(0, 160, 0, 20), Position = UDim2.fromOffset(48, 4),
    BackgroundTransparency = 1, RichText = true,
    Text = 'VYN<font color="#38c8ff">LUA</font>',
    Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
make("TextLabel", {
    Size = UDim2.new(0, 180, 0, 12), Position = UDim2.fromOffset(48, 24),
    BackgroundTransparency = 1, Text = "SCRIPT HUB  //  V1.0",
    Font = Enum.Font.Code, TextSize = 10, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

-- chip status
local chip = make("Frame", {
    Size = UDim2.fromOffset(70, 22), Position = UDim2.new(1, -118, 0.5, -11),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, header)
round(chip, 11); stroke(chip, C.line, 1)
local dot = make("Frame", {
    Size = UDim2.fromOffset(7, 7), Position = UDim2.fromOffset(9, 7.5),
    BackgroundColor3 = C.accent, BorderSizePixel = 0,
}, chip)
round(dot, 4)
make("TextLabel", {
    Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(20, 0),
    BackgroundTransparency = 1, Text = "ONLINE", Font = Enum.Font.Code,
    TextSize = 10, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
}, chip)
TweenService:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { BackgroundTransparency = 0.75 }):Play()

local closeBtn = make("TextButton", {
    Size = UDim2.fromOffset(30, 24), Position = UDim2.new(1, -40, 0.5, -12),
    BackgroundColor3 = C.panel2, Text = "X", Font = Enum.Font.GothamBold,
    TextSize = 12, TextColor3 = C.danger, AutoButtonColor = false,
}, header)
round(closeBtn, 6); stroke(closeBtn, C.danger, 1, 0.6)
closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(60, 20, 40) }):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.12), { BackgroundColor3 = C.panel2 }):Play()
end)
drag(header, holder)

-- sidebar: cuma pojok kiri bawah yang bulat
local sidebar = make("Frame", {
    Size = UDim2.new(0, 140, 1, -42), Position = UDim2.fromOffset(0, 42),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, win)
round(sidebar, RAD)
make("Frame", {
    Size = UDim2.new(1, 0, 0, RAD), BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, sidebar)
make("Frame", {
    Size = UDim2.new(0, RAD, 1, 0), Position = UDim2.new(1, -RAD, 0, 0),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, sidebar)
make("Frame", {
    Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = C.line, BorderSizePixel = 0,
}, sidebar)

local tabHolder = make("Frame", {
    Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1,
}, sidebar)
make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, tabHolder)
make("UIPadding", {
    PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9),
}, tabHolder)

make("TextLabel", {
    Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 8, 1, -28),
    BackgroundTransparency = 1, Text = "@" .. lp.Name, Font = Enum.Font.Code,
    TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, sidebar)

local content = make("Frame", {
    Size = UDim2.new(1, -140, 1, -42), Position = UDim2.fromOffset(140, 42),
    BackgroundTransparency = 1,
}, win)

local pages, tabs, tabCount = {}, {}, 0

local function newPage(name)
    local p = make("ScrollingFrame", {
        Name = name, Size = UDim2.new(1, -16, 1, -14), Position = UDim2.fromOffset(8, 7),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, content)
    make("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, p)
    make("UIPadding", { PaddingRight = UDim.new(0, 6) }, p)
    pages[name] = p
    return p
end

local tabHooks = {}

local function selectTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, t in pairs(tabs) do
        local on = (n == name)
        local ti = TweenInfo.new(0.15)
        TweenService:Create(t.btn, ti, {
            BackgroundTransparency = on and 0 or 1,
            TextColor3 = on and C.accent or C.dim,
        }):Play()
        TweenService:Create(t.stroke, ti, { Transparency = on and 0.5 or 1 }):Play()
        TweenService:Create(t.gem, ti, { BackgroundColor3 = on and C.accent or C.off }):Play()
        t.bar.Visible = on
    end
    if tabHooks[name] then tabHooks[name]() end
end

local function newTab(name)
    tabCount += 1
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.panel2, BackgroundTransparency = 1,
        Text = string.upper(name),
        Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
        LayoutOrder = tabCount,
    }, tabHolder)
    make("UIPadding", { PaddingLeft = UDim.new(0, 27) }, b)
    round(b, 7)
    local st = stroke(b, C.accent, 1, 1)
    -- belah ketupat kecil di kiri teks, gantinya angka
    local gem = make("Frame", {
        Size = UDim2.fromOffset(6, 6), Position = UDim2.new(0, -15, 0.5, -3),
        BackgroundColor3 = C.off, BorderSizePixel = 0, Rotation = 45,
    }, b)
    local bar = make("Frame", {
        Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, -24, 0.5, -8),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false,
    }, b)
    round(bar, 2)
    tabs[name] = { btn = b, bar = bar, stroke = st, gem = gem }
    b.Activated:Connect(function() selectTab(name) end)
end

local function section(page, text)
    local f = place(page, make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }))
    local ln = make("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = C.line, BorderSizePixel = 0,
    }, f)
    make("UIGradient", {
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
    }, ln)
    local l = make("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Text = "// " .. string.upper(text), Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = C.accent,
    }, f)
    make("UIPadding", { PaddingRight = UDim.new(0, 8) }, l)
    return f
end

local function row(page, h)
    local f = place(page, make("Frame", {
        Size = UDim2.new(1, 0, 0, h or 40), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    }))
    round(f, 8); stroke(f, C.line, 1)
    make("UIGradient", { Color = ColorSequence.new(C.panel2, C.panel) }, f)
    return f
end

local function toggle(page, text, default, cb)
    local f = row(page, 40)
    make("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
    local sw = make("Frame", {
        Size = UDim2.fromOffset(42, 22), Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = C.off, BorderSizePixel = 0,
    }, f)
    round(sw, 11)
    local sws = stroke(sw, C.accent, 1, 1)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, sw)
    round(knob, 8)
    local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, f)

    local state = default
    local function paint()
        local ti = TweenInfo.new(0.15)
        TweenService:Create(sw, ti, { BackgroundColor3 = state and C.accent2 or C.off }):Play()
        TweenService:Create(sws, ti, { Transparency = state and 0.2 or 1 }):Play()
        TweenService:Create(knob, ti, {
            Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        }):Play()
    end
    paint()
    hit.Activated:Connect(function()
        state = not state
        paint()
        cb(state)
    end)
    return function(v) state = v; paint() end
end

local function slider(page, text, min, max, default, cb)
    local f = row(page, 56)
    make("TextLabel", {
        Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(14, 5),
        BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
    local val = make("TextLabel", {
        Size = UDim2.fromOffset(60, 24), Position = UDim2.new(1, -74, 0, 5),
        BackgroundTransparency = 1, Text = tostring(default), Font = Enum.Font.Code,
        TextSize = 13, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    }, f)
    local bar = make("Frame", {
        Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 0, 40),
        BackgroundColor3 = C.off, BorderSizePixel = 0,
    }, f)
    round(bar, 3)
    local p0 = (default - min) / (max - min)
    local fill = make("Frame", { Size = UDim2.fromScale(p0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, bar)
    round(fill, 3)
    make("UIGradient", { Color = ColorSequence.new(C.accent2, C.accent) }, fill)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(p0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, bar)
    round(knob, 8); stroke(knob, C.accent, 2)
    local hit = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1, Text = "",
    }, f)

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.fromScale(rel, 1)
        knob.Position = UDim2.fromScale(rel, 0.5)
        val.Text = tostring(v)
        cb(v)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            page.ScrollingEnabled = false  slider
            setFromX(i.Position.X)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            setFromX(i.Position.X)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            page.ScrollingEnabled = true
        end
    end)
end

local function styleButton(b, danger)
    round(b, 8)
    local st = stroke(b, danger and C.danger or C.accent, 1, 0.55)
    local base = danger and Color3.fromRGB(30, 14, 28) or C.panel
    local hi = danger and Color3.fromRGB(55, 20, 40) or C.panel2
    b.BackgroundColor3 = base
    b.MouseButton1Down:Connect(function()
        b.BackgroundColor3 = hi
        st.Transparency = 0.1
    end)
    local function up() b.BackgroundColor3 = base; st.Transparency = 0.55 end
    b.MouseButton1Up:Connect(up)
    b.MouseLeave:Connect(up)
end

local function button(page, text, cb, danger)
    local b = place(page, make("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), Text = text,
        Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = danger and C.danger or C.text, AutoButtonColor = false,
    }))
    styleButton(b, danger)
    b.Activated:Connect(cb)
    return b
end

local flyBV, flyBG
local flyUp, flyDown = false, false

local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local h = hum()
    if h then h.PlatformStand = false end
end

local function startFly()
    local r, h = root(), hum()
    if not r or not h then return end
    stopFly()
    flyBV = make("BodyVelocity", { MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero }, r)
    flyBG = make("BodyGyro", { MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, CFrame = r.CFrame }, r)
    h.PlatformStand = true
end

local home = newPage("Home")

local card = row(home, 92)
local avatar = make("ImageLabel", {
    Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(11, 11),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Image = "",
}, card)
round(avatar, 10); glowStroke(avatar, 2)

task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size150x150)
    end)
    if ok and img then avatar.Image = img end
end)

local exec = "Unknown"
if identifyexecutor then
    local ok, n = pcall(identifyexecutor)
    if ok and n then exec = tostring(n) end
end

make("TextLabel", {
    Size = UDim2.new(1, -100, 0, 22), Position = UDim2.fromOffset(92, 10),
    BackgroundTransparency = 1, Text = lp.DisplayName, Font = Enum.Font.GothamBold,
    TextSize = 17, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, card)
make("TextLabel", {
    Size = UDim2.new(1, -100, 0, 16), Position = UDim2.fromOffset(92, 33),
    BackgroundTransparency = 1, Text = "@" .. lp.Name, Font = Enum.Font.Code,
    TextSize = 12, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, card)
make("TextLabel", {
    Size = UDim2.new(1, -100, 0, 30), Position = UDim2.fromOffset(92, 54),
    BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11,
    Text = ("ID %d | akun %d hari\nexecutor: %s"):format(lp.UserId, lp.AccountAge, exec),
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, card)

section(home, "system info")

local grid = place(home, make("Frame", { Size = UDim2.new(1, 0, 0, 3 * 52 + 2 * 7), BackgroundTransparency = 1 }))
make("UIGridLayout", {
    CellSize = UDim2.new(0.5, -4, 0, 52), CellPadding = UDim2.fromOffset(7, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

local function statCard(title)
    local f = make("Frame", { BackgroundColor3 = C.panel, BorderSizePixel = 0 }, grid)
    round(f, 8); stroke(f, C.line, 1)
    make("UIGradient", { Color = ColorSequence.new(C.panel2, C.panel) }, f)
    -- garis aksen kiri, sengaja dikasih jarak dari atas/bawah biar gak nabrak sudut
    local ac = make("Frame", {
        Size = UDim2.fromOffset(3, 28), Position = UDim2.fromOffset(0, 12),
        BackgroundColor3 = C.accent, BorderSizePixel = 0,
    }, f)
    round(ac, 2)
    make("TextLabel", {
        Size = UDim2.new(1, -18, 0, 16), Position = UDim2.fromOffset(13, 7),
        BackgroundTransparency = 1, Text = title, Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
    return make("TextLabel", {
        Size = UDim2.new(1, -18, 0, 22), Position = UDim2.fromOffset(13, 24),
        BackgroundTransparency = 1, Text = "...", Font = Enum.Font.GothamBold,
        TextSize = 15, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
end

local function detectDevice()
    if UIS.VREnabled then return "VR" end
    local touch, kb, pad = UIS.TouchEnabled, UIS.KeyboardEnabled, UIS.GamepadEnabled
    if touch and not kb then
        local v = Workspace.CurrentCamera.ViewportSize
        return (math.min(v.X, v.Y) >= 600) and "Tablet" or "HP (Mobile)"
    elseif pad and not kb and not touch then
        return "Console"
    elseif touch and kb then
        return "Laptop Touch"
    end
    return "PC"
end

local vDevice = statCard("DEVICE")
local vPing   = statCard("PING")
local vFps    = statCard("FPS")
local vCpu    = statCard("CPU")
local vRender = statCard("RENDER")
local vServer = statCard("PEMAIN")
vDevice.Text = detectDevice()

-- grafik FPS
section(home, "fps graph")
local gCard = row(home, 62)
local gBox = make("Frame", {
    Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 1,
}, gCard)
local N = 32
local bars, hist = {}, {}
for i = 1, N do
    hist[i] = 0
    local b = make("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / N, 0, 1, 0),
        Size = UDim2.new(1 / N, -2, 0, 2), BackgroundColor3 = C.off, BorderSizePixel = 0,
    }, gBox)
    round(b, 2)
    bars[i] = b
end

local function perfStat(name)
    local ok, v = pcall(function() return Stats.PerformanceStats[name]:GetValue() end)
    if ok and type(v) == "number" and v > 0 then return v end
end

local function msColor(ms)
    if ms > 33 then return C.danger elseif ms > 20 then return C.warn end
    return C.accent
end

local frames, lastT = 0, os.clock()
local lastRenderDt, lastHbDt = 0.016, 0.016
bind(RunService.RenderStepped, function(dt) frames += 1; lastRenderDt = dt end)
bind(RunService.Heartbeat, function(dt) lastHbDt = dt end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.5)
        local now = os.clock()
        local fps = math.floor(frames / (now - lastT) + 0.5)
        frames, lastT = 0, now
        local fcol = fps < 25 and C.danger or (fps < 45 and C.warn or C.accent)
        vFps.Text = tostring(fps)
        vFps.TextColor3 = fcol

        table.remove(hist, 1)
        table.insert(hist, fps)
        local gh = gBox.AbsoluteSize.Y / scale.Scale
        if gh <= 0 then gh = 40 end
        for i, b in ipairs(bars) do
            local f = hist[i]
            b.Size = UDim2.new(1 / N, -2, 0, math.max(2, math.floor(math.min(f, 60) / 60 * gh)))
            b.BackgroundColor3 = (f == 0) and C.off or (f < 25 and C.danger or (f < 45 and C.warn or C.accent))
        end

        local ping
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and v then ping = math.floor(v)
        else
            local ok2, v2 = pcall(function() return lp:GetNetworkPing() * 1000 end)
            if ok2 then ping = math.floor(v2) end
        end
        vPing.Text = ping and (ping .. " ms") or "n/a"
        vPing.TextColor3 = (ping and ping > 250) and C.danger or ((ping and ping > 120) and C.warn or C.accent)

        local cpu = perfStat("CPU") or (lastHbDt * 1000)
        local gpu = perfStat("GPU") or (lastRenderDt * 1000)
        vCpu.Text = ("%.1f ms"):format(cpu)
        vCpu.TextColor3 = msColor(cpu)
        vRender.Text = ("%.1f ms"):format(gpu)
        vRender.TextColor3 = msColor(gpu)
        vServer.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
    end
end)

local mv = newPage("Movement")

section(mv, "fly")
toggle(mv, "Fly", false, function(v)
    S.fly = v
    if v then startFly() else stopFly() end
end)
slider(mv, "Fly Speed", 10, 300, S.flySpeed, function(v) S.flySpeed = v end)

local ud = place(mv, make("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }))
local function holdBtn(text, xPos, setter)
    local b = make("TextButton", {
        Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(xPos, xPos == 0 and 0 or 4, 0, 0),
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = C.text, AutoButtonColor = false,
    }, ud)
    styleButton(b, false)
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            setter(true)
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then setter(false) end
            end)
        end
    end)
end
holdBtn("Naik (E)", 0, function(v) flyUp = v end)
holdBtn("Turun (Q)", 0.5, function(v) flyDown = v end)

section(mv, "speed walk")
toggle(mv, "Speed Walk", false, function(v)
    S.walk = v
    if not v then
        local h = hum()
        if h then h.WalkSpeed = defWalk end
    end
end)
slider(mv, "Walk Speed", 16, 300, S.walkSpeed, function(v) S.walkSpeed = v end)

section(mv, "jump power")
toggle(mv, "Jump Power", false, function(v)
    S.jump = v
    if not v then
        local h = hum()
        if h then h.JumpPower = defJump end
    end
end)
slider(mv, "Jump Value", 50, 500, S.jumpPower, function(v) S.jumpPower = v end)
toggle(mv, "Infinite Jump", false, function(v) S.infJump = v end)

section(mv, "lainnya")
toggle(mv, "Noclip", false, function(v) S.noclip = v end)

local tp = newPage("Teleport")
section(tp, "teleport ke player")

local searchRow = row(tp, 38)
local search = make("TextBox", {
    Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "cari nama player...",
    PlaceholderColor3 = C.dim, Font = Enum.Font.Code, TextSize = 13,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, searchRow)

local listItems = {}
local thumbs = {}
local rebuild

local function teleportTo(p)
    local r = root()
    local tr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if r and tr then
        r.CFrame = tr.CFrame * CFrame.new(0, 0, 4)
        notify("teleport ke " .. p.DisplayName)
    else
        notify("karakter target belum siap")
    end
end

button(tp, "Refresh list", function() rebuild() end)

local function playerButton(p)
    local b = place(tp, make("TextButton", {
        Size = UDim2.new(1, 0, 0, 42), Text = "", AutoButtonColor = false,
    }))
    styleButton(b, false)
    local pic = make("ImageLabel", {
        Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(8, 7),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Image = thumbs[p.UserId] or "",
    }, b)
    round(pic, 14)
    if not thumbs[p.UserId] then
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and img then
                thumbs[p.UserId] = img
                if pic.Parent then pic.Image = img end
            end
        end)
    end
    make("TextLabel", {
        Size = UDim2.new(1, -52, 0, 18), Position = UDim2.fromOffset(44, 5),
        BackgroundTransparency = 1, Text = p.DisplayName, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, b)
    make("TextLabel", {
        Size = UDim2.new(1, -52, 0, 14), Position = UDim2.fromOffset(44, 22),
        BackgroundTransparency = 1, Text = "@" .. p.Name, Font = Enum.Font.Code,
        TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, b)
    b.Activated:Connect(function() teleportTo(p) end)
    return b
end

rebuild = function()
    for _, o in ipairs(listItems) do o:Destroy() end
    table.clear(listItems)
    local q = string.lower(search.Text or "")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and (q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true)) then
            table.insert(listItems, playerButton(p))
        end
    end
    if #listItems == 0 then
        table.insert(listItems, section(tp, "gak ada player lain"))
    end
end
search:GetPropertyChangedSignal("Text"):Connect(function() rebuild() end)
bind(Players.PlayerAdded, function() task.defer(rebuild) end)
bind(Players.PlayerRemoving, function() task.defer(rebuild) end)
rebuild()

local function httpRequest(opts)
    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if not req then return nil end
    local ok, res = pcall(req, opts)
    if ok and type(res) == "table" then return res end
end

local function httpGet(url)
    local res = httpRequest({ Url = url, Method = "GET" })
    if res and res.Body and (res.StatusCode or 200) < 400 then return res.Body end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then return body end
end

local tpp = newPage("Teleport Path")

-- Read the copied path from Dex. This can be from anywhere, not just the Workspace:
-- game.Workspace.Folder.Part
-- game.ReplicatedStorage.Folder["Model Name"].Part
-- game:GetService("Lighting"):FindFirst
local function readQuoted(str, pos)
    local q = str:sub(pos, pos)
    if q ~= '"' and q ~= "'" then return nil end
    local out, i = {}, pos + 1
    while i <= #str do
        local ch = str:sub(i, i)
        if ch == "\\" then
            table.insert(out, str:sub(i + 1, i + 1))
            i += 2
        elseif ch == q then
            return table.concat(out), i + 1
        else
            table.insert(out, ch)
            i += 1
        end
    end
end

local function getService(name)
    local ok, svc = pcall(game.GetService, game, name)
    if ok and svc then return svc end
    return game:FindFirstChild(name)
end

local function findByName(parent, name)
    local c = parent:FindFirstChild(name)
    if c then return c end
    -- backup: different upper/lower case or there are stray spaces
    local low = name:lower():match("^%s*(.-)%s*$")
    for _, ch in ipairs(parent:GetChildren()) do
        if ch.Name:lower():match("^%s*(.-)%s*$") == low then return ch end
    end
    -- backup: Instance properties, e.g. Players.LocalPlayer
    local ok, v = pcall(function() return parent[name] end)
    if ok and typeof(v) == "Instance" then return v end
end

-- first name without "game.": try service, then Workspace, finally search all games
local function resolveFirst(name)
    local ok, svc = pcall(game.GetService, game, name)
    if ok and svc then return svc end
    return findByName(Workspace, name) or game:FindFirstChild(name, true)
end

-- take the nth value from the result of GetChildren()/GetDescendants()
local function pickIndex(list, parent, idx)
    local item = list[idx]
    if item then return item end
    return nil, ("%s hanya punya %d isi, nomor %d tidak ada"):format(parent.Name, #list, idx)
end

local function resolvePath(raw)
    local str = raw:match("^%s*(.-)%s*$")
    str = str:gsub(";+$", "")
    if str == "" then return nil, "kosong" end
    local low = str:lower()
    if low == "game" then return game end

    local cur, pos
    local afterGame = low:match("^game()[%.:%[]")
    local afterWs = low:match("^workspace()[%.:%[]") or low:match("^workspace()$")
    if afterGame then
        cur, pos = game, afterGame
    elseif afterWs then
        cur, pos = Workspace, afterWs
    else
        pos = 1
    end

    local first = (cur == nil)
    while pos <= #str do
        local c = str:sub(pos, pos)
        local name, recursive
        if c == "." then
            local nm = str:match("^[%w_]+", pos + 1)
            if not nm then return nil, "format path salah" end
            name, pos = nm, pos + 1 + #nm
        elseif c == "[" then
            local num = str:match("^%[%s*(%d+)%s*%]", pos)
            if num then
                -- [7] langsung = anak ke-7
                if not cur then return nil, "format path salah" end
                local _, e = str:find("^%[%s*%d+%s*%]", pos)
                pos = e + 1
                local item, err = pickIndex(cur:GetChildren(), cur, tonumber(num))
                if not item then return nil, err end
                cur = item
            else
                local val, np = readQuoted(str, pos + 1)
                if not val or str:sub(np, np) ~= "]" then return nil, "format path salah" end
                name, pos = val, np + 1
            end
        elseif c == ":" then
            local method = str:match("^:([%w_]+)%(", pos)
            if not method then return nil, "format path salah" end
            local lm = method:lower()
            local ap = pos + #method + 2
            while str:sub(ap, ap):match("%s") do ap += 1 end
            if str:sub(ap, ap) == ")" then
                -- method tanpa argumen, misal :GetChildren()[7]
                pos = ap + 1
                if (lm ~= "getchildren" and lm ~= "getdescendants") or not cur then
                    return nil, "method " .. method .. "() tidak didukung"
                end
                local idx = str:match("^%s*%[%s*(%d+)%s*%]", pos)
                if not idx then return nil, "tambahkan [angka] setelah " .. method .. "()" end
                local _, e = str:find("^%s*%[%s*%d+%s*%]", pos)
                pos = e + 1
                local list = (lm == "getchildren") and cur:GetChildren() or cur:GetDescendants()
                local item, err = pickIndex(list, cur, tonumber(idx))
                if not item then return nil, err end
                cur = item
            else
                local arg, np = readQuoted(str, ap)
                if not arg then return nil, "format path salah" end
                local close = str:find(")", np, true)
                if not close then return nil, "format path salah" end
                local rest = str:sub(np, close - 1)
                pos = close + 1
                if lm == "getservice" then
                    local svc = getService(arg)
                    if not svc then return nil, "service " .. arg .. " tidak ada" end
                    cur = svc
                elseif not cur then
                    return nil, "format path salah"
                elseif lm == "findfirstchildofclass" then
                    cur = cur:FindFirstChildOfClass(arg)
                    if not cur then return nil, "tidak ada class " .. arg end
                elseif lm == "findfirstchildwhichisa" then
                    cur = cur:FindFirstChildWhichIsA(arg, rest:find("true") ~= nil)
                    if not cur then return nil, "tidak ada class " .. arg end
                else
                    name = arg
                    recursive = (rest:find("true") ~= nil) or lm == "findfirstdescendant"
                end
            end
        elseif first and c:match("[%w_]") then
            local nm = str:match("^[%w_]+", pos)
            name, pos = nm, pos + #nm
        else
            return nil, "format path salah"
        end

        if name then
            local nxt
            if cur == nil then
                nxt = resolveFirst(name)
            elseif cur == game then
                nxt = findByName(game, name) or getService(name)
            elseif recursive then
                nxt = cur:FindFirstChild(name, true) or findByName(cur, name)
            else
                nxt = findByName(cur, name)
            end
            if not nxt then
                local hint = ""
                if cur and (cur.ClassName == "ServerStorage" or cur.ClassName == "ServerScriptService") then
                    hint = " (isi server tidak terlihat dari client)"
                end
                return nil, "tidak ada: " .. name .. " di " .. (cur and cur.Name or "game") .. hint
            end
            cur = nxt
        end
        first = false
    end
    return cur
end

local function partPos(p)
    return p.Position + Vector3.new(0, p.Size.Y / 2 + 3, 0)
end

-- find the position of any object: part, model/group, folder, value, or its parent
local function targetPos(inst, depth)
    depth = depth or 0
    if inst:IsA("BasePart") then return partPos(inst) end
    if inst:IsA("Attachment") then return inst.WorldPosition + Vector3.new(0, 3, 0) end
    if inst:IsA("CFrameValue") then return inst.Value.Position + Vector3.new(0, 3, 0) end
    if inst:IsA("Vector3Value") then return inst.Value + Vector3.new(0, 3, 0) end
    if inst:IsA("ObjectValue") and inst.Value and depth < 4 then
        local p = targetPos(inst.Value, depth + 1)
        if p then return p end
    end
    if inst:IsA("Model") then
        local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local ok, cf = pcall(function() return inst:GetPivot() end)
            if ok then return cf.Position + Vector3.new(0, 4, 0) end
            return partPos(part)
        end
    end
    -- folder, group, config, etc: take the first part in it
    local d = inst:FindFirstChildWhichIsA("BasePart", true)
    if d then return partPos(d) end
    -- last: move up to its parent (e.g. ProximityPrompt / script inside part)
    local a = inst.Parent
    while a and a ~= game do
        if a:IsA("BasePart") then return partPos(a) end
        if a:IsA("Model") then
            local part = a.PrimaryPart or a:FindFirstChildWhichIsA("BasePart", true)
            if part then return a:GetPivot().Position + Vector3.new(0, 4, 0) end
        end
        a = a.Parent
    end
end

local function describe(inst)
    local where = inst.Parent and inst.Parent:GetFullName() or "nil"
    local extra = inst:IsDescendantOf(Workspace) and "" or "  (di luar Workspace)"
    return "terdeteksi: " .. inst.Name .. " [" .. inst.ClassName .. "]" .. extra .. "\nlokasi: " .. where
end

section(tpp, "dex explorer")
button(tpp, "Buka Dex Explorer", function()
    notify("memuat Dex Explorer...")
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://scriptblox.com/raw/Universal-Script-dex-explorer-fixed-for-velocity-236826"))()
        end)
        if ok then notify("Dex Explorer dimuat") else
            notify("gagal memuat Dex")
            warn("[VynLua] dex error: " .. tostring(err))
        end
    end)
end)

section(tpp, "teleport via path")
local pathRow = row(tpp, 40)
pathRow.ClipsDescendants = true
local pathBox = make("TextBox", {
    Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "paste path from Dex here...",
    PlaceholderColor3 = C.dim, Font = Enum.Font.Code, TextSize = 12,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false, ClipsDescendants = true,
}, pathRow)

local btnRow = place(tpp, make("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }))
local goBtn = make("TextButton", {
    Size = UDim2.new(0.7, -4, 1, 0), Text = "Teleport", Font = Enum.Font.GothamMedium,
    TextSize = 13, TextColor3 = C.text, AutoButtonColor = false,
}, btnRow)
styleButton(goBtn, false)
local clearBtn = make("TextButton", {
    Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), Text = "Clear",
    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.danger, AutoButtonColor = false,
}, btnRow)
styleButton(clearBtn, true)

local pathStatus = place(tpp, make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
    Text = "menunggu path dari Dex...", Font = Enum.Font.Code, TextSize = 11,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
}))

local function setPathStatus(t, col)
    pathStatus.Text = t
    pathStatus.TextColor3 = col
end

-- automatic detection of each path change
local detectId = 0
pathBox:GetPropertyChangedSignal("Text"):Connect(function()
    detectId += 1
    local id = detectId
    task.delay(0.35, function()
        if id ~= detectId then return end
        if pathBox.Text:match("^%s*$") then
            setPathStatus("menunggu path dari Dex...", C.dim)
            return
        end
        local inst, err = resolvePath(pathBox.Text)
        if inst then
            setPathStatus(describe(inst), C.accent)
        else
            setPathStatus("path belum ketemu (" .. tostring(err) .. ")", C.danger)
        end
    end)
end)

clearBtn.Activated:Connect(function()
    pathBox.Text = ""
    setPathStatus("menunggu path dari Dex...", C.dim)
end)

goBtn.Activated:Connect(function()
    local inst, err = resolvePath(pathBox.Text)
    if not inst then
        notify("path tidak ditemukan")
        setPathStatus("path belum ketemu (" .. tostring(err) .. ")", C.danger)
        return
    end
    local pos = targetPos(inst)
    local r = root()
    if not pos then notify("objek ini tidak punya posisi") return end
    if not r then notify("karakter belum siap") return end
    r.CFrame = CFrame.new(pos) * r.CFrame.Rotation
    r.AssemblyLinearVelocity = Vector3.zero
    notify("teleport ke " .. inst.Name .. (inst:IsDescendantOf(Workspace) and "" or " (luar Workspace)"))
end)

local sv = newPage("Server Move")

local sorters = {
    { "Ping terendah", function(a, b) return (a.ping or 9e9) < (b.ping or 9e9) end },
    { "Pemain terbanyak", function(a, b) return (a.playing or 0) > (b.playing or 0) end },
    { "Pemain tersedikit", function(a, b) return (a.playing or 0) < (b.playing or 0) end },
}
local sortMode = 1
local servers, svItems = {}, {}
local regionLabels, regionCache = {}, {}
local fetchGen, loading = 0, false
local renderServers, fetchAll

local function lookupRegion(serverId)
    local res = httpRequest({
        Url = "https://gamejoin.roblox.com/v1/join-game-instance", Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["User-Agent"] = "Roblox/WinInet" },
        Body = HttpService:JSONEncode({
            placeId = game.PlaceId, isTeleport = false, gameId = serverId,
            gameJoinAttemptId = HttpService:GenerateGUID(false),
        }),
    })
    if not (res and res.Body) then return nil end
    local ok, j = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or type(j) ~= "table" then return nil end
    local js = j.joinScript
    local ip = js and ((js.UdmuxEndpoints and js.UdmuxEndpoints[1] and js.UdmuxEndpoints[1].Address) or js.MachineAddress)
    if not ip then return nil end
    local body = httpGet("https://ipinfo.io/" .. ip .. "/json")
    if not body then return nil end
    local ok2, g = pcall(function() return HttpService:JSONDecode(body) end)
    if ok2 and type(g) == "table" and g.country then
        return (g.city and (g.city .. ", ") or "") .. g.country
    end
end

local function regionWorker(gen, list)
    task.spawn(function()
        local fails = 0
        for idx, s in ipairs(list) do
            if gen ~= fetchGen then return end
            if idx > 20 or fails >= 3 then break end
            local r = regionCache[s.id]
            if not r then
                r = lookupRegion(s.id)
                if r then regionCache[s.id] = r; fails = 0 else fails += 1 end
                task.wait(0.35)
            end
            local lb = regionLabels[s.id]
            if lb and lb.Parent and r then lb.Text = "REGION  " .. r end
        end
        if gen ~= fetchGen then return end
        for _, s in ipairs(list) do
            local lb = regionLabels[s.id]
            if lb and lb.Parent and lb.Text:find("mencari") then lb.Text = "REGION  N/A" end
        end
    end)
end

local function serverRow(s)
    local isHere = (s.id == game.JobId)
    local f = row(sv, 72)
    make("TextLabel", {
        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.fromOffset(14, 8),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
        Text = "Server " .. string.upper(string.sub(s.id, 1, 6)) .. (isHere and "  (kamu di sini)" or ""),
        TextColor3 = isHere and C.accent or C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    make("TextLabel", {
        Size = UDim2.new(1, -100, 0, 14), Position = UDim2.fromOffset(14, 28),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.dim,
        Text = ("PLAYER %d/%d    PING %s"):format(s.playing or 0, s.maxPlayers or 0, s.ping and (s.ping .. " ms") or "n/a"),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
    local rl = make("TextLabel", {
        Size = UDim2.new(1, -100, 0, 14), Position = UDim2.fromOffset(14, 44),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.accent,
        Text = "REGION  " .. (regionCache[s.id] or "mencari..."),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    regionLabels[s.id] = rl

    -- bar isi server
    local barBg = make("Frame", {
        Size = UDim2.new(1, -112, 0, 3), Position = UDim2.new(0, 14, 1, -9),
        BackgroundColor3 = C.off, BorderSizePixel = 0,
    }, f)
    round(barBg, 2)
    local pct = math.clamp((s.playing or 0) / math.max(s.maxPlayers or 1, 1), 0, 1)
    local barFill = make("Frame", {
        Size = UDim2.fromScale(pct, 1), BackgroundColor3 = pct > 0.85 and C.warn or C.accent,
        BorderSizePixel = 0,
    }, barBg)
    round(barFill, 2)

    local join = make("TextButton", {
        Size = UDim2.fromOffset(72, 34), Position = UDim2.new(1, -86, 0.5, -17),
        Text = isHere and "DI SINI" or "JOIN", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = isHere and C.dim or C.accent, AutoButtonColor = false,
    }, f)
    styleButton(join, false)
    join.Activated:Connect(function()
        if isHere then notify("kamu sudah di server ini") return end
        notify("pindah ke server " .. string.upper(string.sub(s.id, 1, 6)))
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, lp) end)
    end)
    return f
end

local sortBtn
button(sv, "Refresh server", function() fetchAll() end)
sortBtn = button(sv, "Urutkan: " .. sorters[1][1], function()
    sortMode = sortMode % #sorters + 1
    sortBtn.Text = "Urutkan: " .. sorters[sortMode][1]
    renderServers()
end)
local svInfo = place(sv, make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "buka tab ini untuk memuat server",
    Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
}))

renderServers = function()
    for _, o in ipairs(svItems) do o:Destroy() end
    table.clear(svItems)
    table.clear(regionLabels)
    local list = {}
    for _, s in ipairs(servers) do table.insert(list, s) end
    table.sort(list, sorters[sortMode][2])
    local shown = {}
    for i = 1, math.min(#list, 25) do
        shown[i] = list[i]
        table.insert(svItems, serverRow(list[i]))
    end
    svInfo.Text = (#shown == 0) and "tidak ada server publik" or (#shown .. " server ditampilkan")
    svInfo.TextColor3 = C.dim
    fetchGen += 1
    regionWorker(fetchGen, shown)
end

fetchAll = function()
    if loading then return end
    loading = true
    svInfo.Text = "memuat daftar server..."
    svInfo.TextColor3 = C.dim
    task.spawn(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"):format(game.PlaceId)
        local body = httpGet(url)
        local data
        if body then
            local ok, j = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and type(j) == "table" and type(j.data) == "table" then data = j.data end
        end
        loading = false
        if not data then
            svInfo.Text = "gagal ambil server (coba lagi sebentar)"
            svInfo.TextColor3 = C.danger
            return
        end
        servers = data
        renderServers()
    end)
end

local serverLoaded = false
tabHooks["Server Move"] = function()
    if not serverLoaded then
        serverLoaded = true
        fetchAll()
    end
end


local boost = { on = false, gen = 0, items = setmetatable({}, { __mode = "k" }), conns = {}, saved = nil }

local function boostItem(o)
    if boost.items[o] then return end
    if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire")
    or o:IsA("Sparkles") or o:IsA("BloomEffect") or o:IsA("BlurEffect")
    or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") then
        if o.Enabled then
            boost.items[o] = { "enabled", true }
            o.Enabled = false
        end
    elseif o:IsA("Light") then
        if o.Shadows then
            boost.items[o] = { "shadows", true }
            o.Shadows = false
        end
    elseif o:IsA("Explosion") then
        boost.items[o] = { "visible", o.Visible }
        o.Visible = false
    elseif o:IsA("BasePart") then
        local cast, refl = o.CastShadow, o.Reflectance
        if cast or refl > 0 then
            boost.items[o] = { "part", cast, refl }
            o.CastShadow = false
            o.Reflectance = 0
        end
    end
end

local function restoreItem(o, d)
    local k = d[1]
    if k == "enabled" then o.Enabled = d[2]
    elseif k == "shadows" then o.Shadows = d[2]
    elseif k == "visible" then o.Visible = d[2]
    elseif k == "part" then o.CastShadow = d[2]; o.Reflectance = d[3] end
end

local function setProps(obj, props)
    for k, v in pairs(props) do
        pcall(function() obj[k] = v end)
    end
end

local function getProps(obj, names)
    local out = {}
    for _, n in ipairs(names) do
        local ok, v = pcall(function() return obj[n] end)
        if ok then out[n] = v end
    end
    return out
end

local LIGHT_PROPS = { "GlobalShadows", "ShadowSoftness" }
local TERRAIN_PROPS = { "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance", "Decoration" }

local function setBoost(on)
    boost.on = on
    boost.gen += 1
    local gen = boost.gen
    local terrain = Workspace:FindFirstChildOfClass("Terrain")

    if on then
        boost.saved = {
            lighting = getProps(Lighting, LIGHT_PROPS),
            terrain = terrain and getProps(terrain, TERRAIN_PROPS) or {},
        }
        local okq, q = pcall(function() return settings().Rendering.QualityLevel end)
        if okq then boost.saved.quality = q end

        setProps(Lighting, { GlobalShadows = false, ShadowSoftness = 0 })
        if terrain then
            setProps(terrain, { WaterWaveSize = 0, WaterWaveSpeed = 0, WaterReflectance = 0, Decoration = false })
        end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

        local function onAdded(o) if boost.on then pcall(boostItem, o) end end
        table.insert(boost.conns, Workspace.DescendantAdded:Connect(onAdded))
        table.insert(boost.conns, Lighting.DescendantAdded:Connect(onAdded))

        -- map gede bisa ribuan objek, jadi dicicil per frame biar gak nge-freeze
        task.spawn(function()
            for _, o in ipairs(Lighting:GetDescendants()) do pcall(boostItem, o) end
            local n = 0
            for _, o in ipairs(Workspace:GetDescendants()) do
                if gen ~= boost.gen then return end
                pcall(boostItem, o)
                n += 1
                if n % 300 == 0 then task.wait() end
            end
            if gen == boost.gen then notify("FPS Booster aktif") end
        end)
    else
        for _, c in ipairs(boost.conns) do c:Disconnect() end
        table.clear(boost.conns)

        local list = {}
        for o, d in pairs(boost.items) do list[#list + 1] = { o, d } end
        table.clear(boost.items)
        task.spawn(function()
            local n = 0
            for _, e in ipairs(list) do
                pcall(restoreItem, e[1], e[2])
                n += 1
                if n % 300 == 0 then task.wait() end
            end
        end)

        local sv = boost.saved
        if sv then
            setProps(Lighting, sv.lighting)
            if terrain then setProps(terrain, sv.terrain) end
            if sv.quality then
                pcall(function() settings().Rendering.QualityLevel = sv.quality end)
            end
        end
        notify("FPS Booster dimatikan")
    end
end

local misc = newPage("Misc")
section(misc, "utility")
toggle(misc, "Anti AFK", true, function(v) S.afk = v end)
toggle(misc, "FPS Booster (anti lag)", false, function(v) setBoost(v) end)
button(misc, "Rejoin server", function()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end)
end)
button(misc, "Reset karakter", function()
    local h = hum()
    if h then h.Health = 0 end
end)
button(misc, "Tutup & hapus VynLua", function()
    if env.VynLuaCleanup then env.VynLuaCleanup() end
end, true)

bind(lp.Idled, function()
    if S.afk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

---------------------------------------------------------------- 
newTab("Home")
newTab("Movement")
newTab("Teleport")
newTab("Teleport Path")
newTab("Server Move")
newTab("Misc")
selectTab("Home")

-----------------------------------------------------------------
local rot = 0
bind(RunService.Heartbeat, function(dt)
    rot = (rot + 70 * dt) % 360
    for _, g in ipairs(animGrads) do g.Rotation = rot end

    local h = hum()
    if not h then return end

    if S.walk and h.WalkSpeed ~= S.walkSpeed then h.WalkSpeed = S.walkSpeed end
    if S.jump then
        if not h.UseJumpPower then h.UseJumpPower = true end
        if h.JumpPower ~= S.jumpPower then h.JumpPower = S.jumpPower end
    end

    if S.fly and flyBV and flyBG then
        local cam, r = Workspace.CurrentCamera, root()
        if cam and r then
            local cf = cam.CFrame
            local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
            local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
            local md = h.MoveDirection
            local vel = Vector3.zero
            if md.Magnitude > 0.05 and flatLook.Magnitude > 0 and flatRight.Magnitude > 0 then
                local f = md:Dot(flatLook.Unit)
                local s = md:Dot(flatRight.Unit)
                vel = cf.LookVector * f + cf.RightVector * s
            end
            vel += Vector3.new(0, (flyUp and 1 or 0) - (flyDown and 1 or 0), 0)
            flyBV.Velocity = vel * S.flySpeed
            if flatLook.Magnitude > 0 then
                flyBG.CFrame = CFrame.lookAt(r.Position, r.Position + flatLook)
            end
        end
    end
end)

bind(RunService.Stepped, function()
    if S.noclip and lp.Character then
        for _, part in ipairs(lp.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

bind(UIS.JumpRequest, function()
    if S.infJump then
        local h = hum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

bind(lp.CharacterAdded, function()
    flyBV, flyBG = nil, nil
    if S.fly then
        task.wait(0.6)
        startFly()
    end
end)

-- tombol E / Q buat fly di PC
bind(UIS.InputBegan, function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.E then flyUp = true
    elseif i.KeyCode == Enum.KeyCode.Q then flyDown = true end
end)
bind(UIS.InputEnded, function(i)
    if i.KeyCode == Enum.KeyCode.E then flyUp = false
    elseif i.KeyCode == Enum.KeyCode.Q then flyDown = false end
end)

local isOpen = false
local function setOpen(v)
    isOpen = v
    if v then
        holder.Visible = true
        scale.Scale = baseScale * 0.9
        TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
    else
        TweenService:Create(scale, TweenInfo.new(0.12), { Scale = baseScale * 0.9 }):Play()
        task.delay(0.12, function()
            if not isOpen then holder.Visible = false end
        end)
    end
end

closeBtn.Activated:Connect(function() setOpen(false) end)

local floatRoot = make("Frame", {
    Name = "Float", Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(20, 140),
    BackgroundTransparency = 1, ZIndex = 20,
}, gui)
local fGlow = addGlow(floatRoot, 14, 0.55)
TweenService:Create(fGlow, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { ImageTransparency = 0.85 }):Play()
local floatBtn = make("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, Text = "V",
    Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = C.accent,
    AutoButtonColor = false, ZIndex = 21,
}, floatRoot)
round(floatBtn, 26)
glowStroke(floatBtn, 2)
drag(floatBtn, floatRoot, function() setOpen(not isOpen) end, true)

bind(UIS.InputBegan, function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then setOpen(not isOpen) end
end)

env.VynLuaCleanup = function()
    if boost.on then pcall(setBoost, false) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    S.fly, S.noclip = false, false
    stopFly()
    local h = hum()
    if h then
        if S.walk then h.WalkSpeed = defWalk end
        if S.jump then h.JumpPower = defJump end
    end
    gui:Destroy()
    env.VynLuaCleanup = nil
end

setOpen(true)
notify("VynLua siap dipakai")
