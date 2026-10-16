--[[
    🌸 VZNAM HUB - LẤY DỮ LIỆU GAME 🌸
    Tab 1: Data | Tab 2: Event | Tab 3: Combined
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

-- ═══ PARENT (gethui cho Delta X) ═══
local ParentGui
if typeof(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then ParentGui = h end
end
if not ParentGui then
    ParentGui = lp:WaitForChild("PlayerGui", 5)
end
if not ParentGui then return warn("Không có parent GUI") end

-- Xóa cũ
pcall(function()
    local old = ParentGui:FindFirstChild("VzNamDataDumper")
    if old then old:Destroy() end
end)
if _G.VzNamDumperCleanup then pcall(_G.VzNamDumperCleanup) end

-- ═══ STATE ═══
local State = {
    EventLog    = {},
    MaxLog      = 300,
    HooksOK     = false,
    OldNC       = nil,
    CurrentTab  = 1,
    DataText    = "",
}

-- ═══ HELPER: FORMAT ═══
local function fmtArg(a)
    local t = typeof(a)
    if t == "Instance" then
        local ok, n = pcall(function() return a:GetFullName() end)
        return ok and n or "[Inst]"
    elseif t == "string" then
        if #a > 50 then a = a:sub(1,47).."..." end
        return '"'..a..'"'
    elseif t == "table" then
        local n = 0
        for _ in pairs(a) do n = n + 1 end
        return "{tbl:"..n.."}"
    elseif t == "nil" then return "nil"
    else return tostring(a) end
end

local function fmtArgs(args)
    local p = {}
    for i = 1, #args do p[#p+1] = fmtArg(args[i]) end
    return table.concat(p, ", ")
end

-- ═══ TAB 1: DATA COLLECTOR ═══
local function CollectData()
    local out = {}
    local function w(s) out[#out+1] = tostring(s) end
    local function hr() w(string.rep("=", 50)) end
    local function ln() w(string.rep("-", 50)) end

    hr()
    w("VZNAM HUB - GAME DATA DUMP")
    w("Time: "..os.date("%Y-%m-%d %H:%M:%S"))
    w("Player: "..lp.Name.." ("..lp.UserId..")")
    w("PlaceId: "..game.PlaceId)
    hr()

    -- Workspace
    w(""); w("[1] WORKSPACE"); ln()
    for _, v in ipairs(workspace:GetChildren()) do
        w(string.format("%-40s | %s", v.Name, v.ClassName))
    end

    -- Plot
    w(""); w("[2] PLOT"); ln()
    local pc = 0
    for _, p in ipairs(Players:GetPlayers()) do
        local plot = workspace:FindFirstChild(p.Name)
        if plot then
            pc = pc + 1
            w("PLOT: "..plot:GetFullName().." | "..p.Name)
        end
    end
    w("Tổng: "..pc.." plot")

    -- Prompts
    w(""); w("[3] PROMPTS"); ln()
    local prc = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            prc = prc + 1
            if prc <= 40 then
                w("["..prc.."] "..(v.Parent and v.Parent:GetFullName() or "nil"))
                w("    A=\""..v.ActionText.."\" O=\""..v.ObjectText.."\" H="..tostring(v.HoldDuration))
            end
        end
    end
    w("Tổng: "..prc.." prompt")

    -- Remotes
    w(""); w("[4] REMOTES"); ln()
    local rc = 0
    local function scan(parent, depth)
        if depth > 4 then return end
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                rc = rc + 1
                w(v.ClassName.." | "..v:GetFullName())
            end
            if v:IsA("Folder") or v:IsA("Model") then
                scan(v, depth + 1)
            end
        end
    end
    scan(game:GetService("ReplicatedStorage"), 0)
    w("Tổng: "..rc.." remote")

    -- Attribute
    w(""); w("[5] ATTRIBUTES"); ln()
    for _, v in ipairs(workspace:GetChildren()) do
        local attrs = v:GetAttributes()
        local has = false
        for _ in pairs(attrs) do has = true; break end
        if has then
            w("-> "..v.Name.." ("..v.ClassName..")")
            for k, val in pairs(attrs) do
                w("   @"..k.." = "..tostring(val).." ("..typeof(val)..")")
            end
        end
    end

    -- GUI
    w(""); w("[6] PLAYERGUI"); ln()
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetChildren()) do
            w("GUI: "..v.Name)
        end
    end

    hr(); w("END")
    return table.concat(out, "\n")
end

-- ═══ TAB 2: EVENT LOGGER ═══
local function AddLog(remote, method, args)
    local e = {
        time = os.date("%H:%M:%S"),
        name = remote:GetFullName(),
        method = method,
        argsStr = fmtArgs(args),
    }
    table.insert(State.EventLog, 1, e)
    while #State.EventLog > State.MaxLog do
        table.remove(State.EventLog)
    end
    if State.OnAdd then State.OnAdd() end
end

local function InstallHooks()
    if State.HooksOK then return true end
    if typeof(hookmetamethod) ~= "function" then return false end
    local ok, err = pcall(function()
        State.OldNC = hookmetamethod(game, "__namecall", function(self, ...)
            local m = getnamecallmethod()
            if m == "FireServer" or m == "InvokeServer" then
                pcall(AddLog, self, m, {...})
            end
            return State.OldNC(self, ...)
        end)
    end)
    if ok then
        State.HooksOK = true
        return true
    else
        warn("[VzNam] Hook fail: "..tostring(err))
        return false
    end
end

local function UninstallHooks()
    if not State.HooksOK then return end
    pcall(function() hookmetamethod(game, "__namecall", State.OldNC) end)
    State.HooksOK = false
end
_G.VzNamDumperCleanup = UninstallHooks

local function GetLogText()
    if #State.EventLog == 0 then
        if State.HooksOK then
            return "Hook đã bật. Chơi game để bắt event..."
        end
        return "(Chưa hook được. Executor không hỗ trợ hookmetamethod.)"
    end
    local lines = {}
    for _, e in ipairs(State.EventLog) do
        lines[#lines+1] = "["..e.time.."] "..e.name..":"..e.method.."("..e.argsStr..")"
    end
    return table.concat(lines, "\n")
end

-- ═══ BUILD UI ═══
local sg = Instance.new("ScreenGui")
sg.Name = "VzNamDataDumper"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = ParentGui

-- Nút hoa
local flower = Instance.new("TextButton", sg)
flower.Size = UDim2.new(0, 50, 0, 50)
flower.Position = UDim2.new(0, 20, 0.4, 0)
flower.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
flower.Text = "🌸"
flower.TextSize = 26
flower.TextColor3 = Color3.fromRGB(255, 255, 255)
flower.Font = Enum.Font.GothamBold
flower.Active = true
flower.Draggable = true
Instance.new("UICorner", flower).CornerRadius = UDim.new(1, 0)
local fs = Instance.new("UIStroke", flower)
fs.Thickness = 2.5
fs.Color = Color3.fromRGB(255, 105, 180)

-- Main
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 560, 0, 460)
main.Position = UDim2.new(0.5, -280, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
local ms = Instance.new("UIStroke", main)
ms.Color = Color3.fromRGB(0, 191, 255)
ms.Thickness = 2

-- Title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 34)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
title.BorderSizePixel = 0
title.Text = "🌸 LẤY DỮ LIỆU GAME VZNAMHUB 🌸"
title.TextColor3 = Color3.fromRGB(0, 200, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

-- Tab bar
local tabBar = Instance.new("Frame", main)
tabBar.Size = UDim2.new(1, -16, 0, 30)
tabBar.Position = UDim2.new(0, 8, 0, 40)
tabBar.BackgroundTransparency = 1
local tbl = Instance.new("UIListLayout", tabBar)
tbl.FillDirection = Enum.FillDirection.Horizontal
tbl.Padding = UDim.new(0, 5)

local function mkTab(order, txt)
    local b = Instance.new("TextButton", tabBar)
    b.LayoutOrder = order
    b.Size = UDim2.new(0, 174, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local tab1 = mkTab(1, "📊 Dữ Liệu Game")
local tab2 = mkTab(2, "📡 Quét Event")
local tab3 = mkTab(3, "📦 Tất Cả Gộp Lại")

-- Content
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -16, 1, -138)
content.Position = UDim2.new(0, 8, 0, 76)
content.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
content.BorderSizePixel = 0
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 6)

-- Scroll 1
local s1 = Instance.new("ScrollingFrame", content)
s1.Size = UDim2.new(1, -8, 1, -8)
s1.Position = UDim2.new(0, 4, 0, 4)
s1.BackgroundTransparency = 1
s1.ScrollBarThickness = 6
s1.CanvasSize = UDim2.new(0, 0, 0, 0)
s1.AutomaticCanvasSize = Enum.AutomaticSize.Y
local l1 = Instance.new("TextLabel", s1)
l1.Size = UDim2.new(1, -10, 0, 0)
l1.Position = UDim2.new(0, 5, 0, 5)
l1.BackgroundTransparency = 1
l1.Text = "Đang thu thập..."
l1.TextColor3 = Color3.fromRGB(220, 220, 230)
l1.TextSize = 10
l1.Font = Enum.Font.Code
l1.TextXAlignment = Enum.TextXAlignment.Left
l1.TextYAlignment = Enum.TextYAlignment.Top
l1.AutomaticSize = Enum.AutomaticSize.Y

-- Scroll 2
local s2 = Instance.new("ScrollingFrame", content)
s2.Size = UDim2.new(1, -8, 1, -8)
s2.Position = UDim2.new(0, 4, 0, 4)
s2.BackgroundTransparency = 1
s2.ScrollBarThickness = 6
s2.CanvasSize = UDim2.new(0, 0, 0, 0)
s2.AutomaticCanvasSize = Enum.AutomaticSize.Y
s2.Visible = false
local l2 = Instance.new("TextLabel", s2)
l2.Size = UDim2.new(1, -10, 0, 0)
l2.Position = UDim2.new(0, 5, 0, 5)
l2.BackgroundTransparency = 1
l2.Text = "(Chưa có event)"
l2.TextColor3 = Color3.fromRGB(220, 220, 230)
l2.TextSize = 10
l2.Font = Enum.Font.Code
l2.TextXAlignment = Enum.TextXAlignment.Left
l2.TextYAlignment = Enum.TextYAlignment.Top
l2.AutomaticSize = Enum.AutomaticSize.Y

-- Tab 3
local t3f = Instance.new("Frame", content)
t3f.Size = UDim2.new(1, -8, 1, -8)
t3f.Position = UDim2.new(0, 4, 0, 4)
t3f.BackgroundTransparency = 1
t3f.Visible = false
local t3l = Instance.new("UIListLayout", t3f)
t3l.Padding = UDim.new(0, 5)
t3l.HorizontalAlignment = Enum.HorizontalAlignment.Center

local combBtn = Instance.new("TextButton", t3f)
combBtn.Size = UDim2.new(1, -10, 0, 34)
combBtn.LayoutOrder = 1
combBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
combBtn.Text = "🔄 GỘP TẤT CẢ"
combBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
combBtn.TextSize = 12
combBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", combBtn).CornerRadius = UDim.new(0, 6)

local t3s = Instance.new("ScrollingFrame", t3f)
t3s.Size = UDim2.new(1, -10, 1, -48)
t3s.LayoutOrder = 2
t3s.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
t3s.BorderSizePixel = 0
t3s.ScrollBarThickness = 6
t3s.CanvasSize = UDim2.new(0, 0, 0, 0)
t3s.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", t3s).CornerRadius = UDim.new(0, 6)

local l3 = Instance.new("TextLabel", t3s)
l3.Size = UDim2.new(1, -10, 0, 0)
l3.Position = UDim2.new(0, 5, 0, 5)
l3.BackgroundTransparency = 1
l3.Text = "(Bấm GỘP TẤT CẢ để xem data + log)"
l3.TextColor3 = Color3.fromRGB(180, 180, 200)
l3.TextSize = 10
l3.Font = Enum.Font.Code
l3.TextXAlignment = Enum.TextXAlignment.Left
l3.TextYAlignment = Enum.TextYAlignment.Top
l3.AutomaticSize = Enum.AutomaticSize.Y

-- Switch tabs
local function ShowTab(n)
    State.CurrentTab = n
    s1.Visible = (n == 1)
    s2.Visible = (n == 2)
    t3f.Visible = (n == 3)
    for i, b in ipairs({tab1, tab2, tab3}) do
        b.BackgroundColor3 = (i == n)
            and Color3.fromRGB(0, 150, 200)
            or Color3.fromRGB(45, 45, 60)
    end
end
tab1.MouseButton1Click:Connect(function() ShowTab(1) end)
tab2.MouseButton1Click:Connect(function() ShowTab(2) end)
tab3.MouseButton1Click:Connect(function() ShowTab(3) end)

-- Footer
local footer = Instance.new("Frame", main)
footer.Size = UDim2.new(1, -16, 0, 40)
footer.Position = UDim2.new(0, 8, 1, -48)
footer.BackgroundTransparency = 1
local fl = Instance.new("UIListLayout", footer)
fl.FillDirection = Enum.FillDirection.Horizontal
fl.Padding = UDim.new(0, 5)

local function mkFoot(order, txt, c)
    local b = Instance.new("TextButton", footer)
    b.LayoutOrder = order
    b.Size = UDim2.new(0, 128, 1, 0)
    b.BackgroundColor3 = c
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local copyB  = mkFoot(1, "📋 COPY", Color3.fromRGB(50, 180, 50))
local saveB  = mkFoot(2, "💾 LƯU FILE", Color3.fromRGB(50, 120, 220))
local clearB = mkFoot(3, "🗑️ XÓA LOG", Color3.fromRGB(180, 80, 50))
local hideB  = mkFoot(4, "✕ ẨN", Color3.fromRGB(180, 50, 50))

-- ═══ LOGIC ═══
task.spawn(function()
    local ok, res = pcall(CollectData)
    if ok then
        State.DataText = res
        l1.Text = res
    else
        l1.Text = "Lỗi collect: "..tostring(res)
    end
end)

local pending = false
State.OnAdd = function()
    if pending then return end
    pending = true
    task.defer(function()
        pending = false
        l2.Text = GetLogText()
    end)
end

task.spawn(function()
    task.wait(0.3)
    InstallHooks()
    l2.Text = GetLogText()
end)

local function GetCurrentText()
    if State.CurrentTab == 1 then return l1.Text
    elseif State.CurrentTab == 2 then return GetLogText()
    else return l3.Text end
end

copyB.MouseButton1Click:Connect(function()
    local t = GetCurrentText()
    local ok = false
    if typeof(setclipboard) == "function" then
        ok = pcall(setclipboard, t)
    end
    if ok then
        copyB.Text = "✅ ĐÃ COPY"
        copyB.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    else
        copyB.Text = "❌ LỖI"
        copyB.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
    task.wait(1.5)
    copyB.Text = "📋 COPY"
    copyB.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
end)

saveB.MouseButton1Click:Connect(function()
    if typeof(writefile) ~= "function" then
        saveB.Text = "❌ Không hỗ trợ"
        task.wait(1.5)
        saveB.Text = "💾 LƯU FILE"
        return
    end
    local fname = "VzNamDump_"..os.date("%Y%m%d_%H%M%S")..".txt"
    local ok = pcall(writefile, fname, GetCurrentText())
    saveB.Text = ok and "✅ Đã lưu!" or "❌ Lỗi"
    saveB.BackgroundColor3 = ok and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(200, 50, 50)
    task.wait(2)
    saveB.Text = "💾 LƯU FILE"
    saveB.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
end)

clearB.MouseButton1Click:Connect(function()
    State.EventLog = {}
    l2.Text = "(Đã xóa log)"
    clearB.Text = "✅ ĐÃ XÓA"
    task.wait(1)
    clearB.Text = "🗑️ XÓA LOG"
end)

hideB.MouseButton1Click:Connect(function()
    main.Visible = false
    flower.Text = "🌸"
    fs.Color = Color3.fromRGB(255, 105, 180)
end)

combBtn.MouseButton1Click:Connect(function()
    local out = {}
    out[#out+1] = "═"..string.rep("═", 40)
    out[#out+1] = "  VZNAM HUB - COMBINED DUMP"
    out[#out+1] = "  Time: "..os.date("%Y-%m-%d %H:%M:%S")
    out[#out+1] = "═"..string.rep("═", 40)
    out[#out+1] = ""
    out[#out+1] = "═══ PHẦN 1: DATA ═══"
    out[#out+1] = State.DataText
    out[#out+1] = ""
    out[#out+1] = "═══ PHẦN 2: EVENT LOG ("..#State.EventLog.." events) ═══"
    out[#out+1] = GetLogText()
    l3.Text = table.concat(out, "\n")
    combBtn.Text = "✅ ĐÃ GỘP"
    task.wait(1)
    combBtn.Text = "🔄 GỘP TẤT CẢ"
end)

flower.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
    if main.Visible then
        flower.Text = "✕"
        fs.Color = Color3.fromRGB(255, 80, 80)
    else
        flower.Text = "🌸"
        fs.Color = Color3.fromRGB(255, 105, 180)
    end
end)

-- ═══ RESIZE ═══
local rsz = Instance.new("TextButton", main)
rsz.Size = UDim2.new(0, 22, 0, 22)
rsz.Position = UDim2.new(1, -22, 1, -22)
rsz.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
rsz.Text = "◢"
rsz.TextColor3 = Color3.fromRGB(255, 255, 255)
rsz.TextSize = 14
rsz.Font = Enum.Font.GothamBold
rsz.ZIndex = 10
Instance.new("UICorner", rsz).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", rsz).Color = Color3.fromRGB(0, 200, 255)

local resizing, rStart, rSize = false, nil, nil
rsz.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
       or i.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        rStart = i.Position
        rSize = main.AbsoluteSize
        rsz.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
       or i.UserInputType == Enum.UserInputType.Touch then
        if resizing then
            resizing = false
            rsz.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
        end
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement
       or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - rStart
        main.Size = UDim2.new(0,
            math.clamp(rSize.X + d.X, 400, 900), 0,
            math.clamp(rSize.Y + d.Y, 320, 700))
    end
end)

ShowTab(1)
print("[VzNamDumper] LOAD XONG")
