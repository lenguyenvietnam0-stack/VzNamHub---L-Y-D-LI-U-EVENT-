--[[
    🌸 VZNAM HUB - LẤY DỮ LIỆU GAME 🌸
    Fix: UI vừa màn hình + Hook nhẹ không lag
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

-- ═══ PARENT ═══
local ParentGui
if typeof(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then ParentGui = h end
end
if not ParentGui then ParentGui = lp:WaitForChild("PlayerGui", 5) end
if not ParentGui then return warn("Không có parent") end

for _, gui in ipairs(ParentGui:GetChildren()) do
    if gui.Name == "VzNamDataDumper" then pcall(function() gui:Destroy() end) end
end
if _G.VzNamDumperCleanup then pcall(_G.VzNamDumperCleanup) end

-- ═══ STATE ═══
local State = {
    EventLog = {},
    MaxLog = 200,
    HooksOK = false,
    OldNC = nil,
    CurrentTab = 1,
    DataText = "",
    FilterMode = "All",  -- All / Important / Custom
}

-- ═══ DANH SÁCH REMOTE CẦN LỌC (bỏ qua để đỡ lag) ═══
local IGNORE_KEYWORDS = {
    "Analytics", "Telemetry", "Observability", "UserGenerated",
    "IdleHop", "SubmitIdle", "Fps", "LibMP", "ClientKit",
    "SharedABTests", "SharedFastFlags", "SoundBus", "SharedFx",
    "Toasts", "ChatFeed", "ProfileMirror", "Preferences", "AwayEarnings",
}

local IMPORTANT_KEYWORDS = {
    "EggWorld", "EggCapture", "Steal", "PetSatchel", "Haul",
    "Fusery", "Bloomery", "Storefront", "Gifting", "Codex",
}

local function ShouldLog(remoteName)
    if State.FilterMode == "All" then return true end
    if State.FilterMode == "Important" then
        for _, k in ipairs(IMPORTANT_KEYWORDS) do
            if string.find(remoteName, k, 1, true) then return true end
        end
        return false
    end
    -- Custom mode: skip only ignore list
    for _, k in ipairs(IGNORE_KEYWORDS) do
        if string.find(remoteName, k, 1, true) then return false end
    end
    return true
end

-- ═══ HELPERS ═══
local function fmtArg(a)
    local t = typeof(a)
    if t == "Instance" then
        local ok, n = pcall(function() return a.Name end)
        return ok and ("["..n.."]") or "[Inst]"
    elseif t == "string" then
        if #a > 40 then a = a:sub(1,37).."..." end
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
    for i = 1, math.min(#args, 8) do p[#p+1] = fmtArg(args[i]) end
    if #args > 8 then p[#p+1] = "..." end
    return table.concat(p, ", ")
end

-- ═══ COLLECT DATA ═══
local function CollectData()
    local out = {}
    local function w(s) out[#out+1] = tostring(s) end
    local function hr() w(string.rep("=", 50)) end
    local function ln() w(string.rep("-", 50)) end

    hr()
    w("VZNAM HUB - GAME DATA DUMP")
    w("Time: "..os.date("%Y-%m-%d %H:%M:%S"))
    w("Player: "..lp.Name)
    w("PlaceId: "..game.PlaceId)
    hr()

    w(""); w("[1] WORKSPACE"); ln()
    for _, v in ipairs(workspace:GetChildren()) do
        w("• "..v.Name.."  ["..v.ClassName.."]")
    end

    w(""); w("[2] PLOT"); ln()
    local pc = 0
    for _, p in ipairs(Players:GetPlayers()) do
        local plot = workspace:FindFirstChild(p.Name)
        if plot then
            pc = pc + 1
            w("• "..plot:GetFullName().."  [Owner: "..p.Name.."]")
        end
    end
    w("Tổng: "..pc.." plot")

    w(""); w("[3] PROMPTS"); ln()
    local prc = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            prc = prc + 1
            if prc <= 30 then
                w("["..prc.."] "..(v.Parent and v.Parent:GetFullName() or "?"))
                w("     Action=\""..v.ActionText.."\" Obj=\""..v.ObjectText.."\"")
                w("     Hold="..tostring(v.HoldDuration).."s")
            end
        end
    end
    w("Tổng: "..prc.." prompt")

    w(""); w("[4] REMOTES QUAN TRỌNG"); ln()
    local rc = 0
    for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local name = v:GetFullName()
            if ShouldLog(name) then
                rc = rc + 1
                w("• "..v.ClassName..": "..name)
            end
        end
    end
    w("Tổng: "..rc.." remote quan trọng")

    w(""); w("[5] PLAYERGUI"); ln()
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetChildren()) do
            w("• "..v.Name)
        end
    end

    hr(); w("END")
    return table.concat(out, "\n")
end

-- ═══ EVENT LOG ═══
local logBuffer = {}
local flushPending = false

local function FlushLog()
    flushPending = false
    if #logBuffer == 0 then return end
    -- Thêm tất cả vào đầu State.EventLog
    for i = #logBuffer, 1, -1 do
        table.insert(State.EventLog, 1, logBuffer[i])
    end
    logBuffer = {}
    while #State.EventLog > State.MaxLog do table.remove(State.EventLog) end
    if State.OnAdd then State.OnAdd() end
end

local function AddLog(remoteName, method, args)
    table.insert(logBuffer, {
        time = os.date("%H:%M:%S"),
        name = remoteName,
        method = method,
        argsStr = fmtArgs(args),
    })
    if not flushPending then
        flushPending = true
        task.delay(0.3, FlushLog)  -- Gom log lại, flush mỗi 0.3s
    end
end

local function InstallHooks()
    if State.HooksOK then return true end
    if typeof(hookmetamethod) ~= "function" then return false end
    local ok = pcall(function()
        State.OldNC = hookmetamethod(game, "__namecall", function(self, ...)
            local m = getnamecallmethod()
            -- CHỈ log remote, bỏ qua tất cả thứ khác
            if (m == "FireServer" or m == "InvokeServer") then
                local cls = typeof(self)
                if cls == "Instance" then
                    local ok2, isRemote = pcall(function()
                        return self:IsA("RemoteEvent") or self:IsA("RemoteFunction")
                    end)
                    if ok2 and isRemote then
                        local name = self:GetFullName()
                        if ShouldLog(name) then
                            pcall(AddLog, name, m, {...})
                        end
                    end
                end
            end
            return State.OldNC(self, ...)
        end)
    end)
    if ok then State.HooksOK = true; return true end
    return false
end

local function UninstallHooks()
    if not State.HooksOK then return end
    pcall(function() hookmetamethod(game, "__namecall", State.OldNC) end)
    State.HooksOK = false
end
_G.VzNamDumperCleanup = UninstallHooks

local function GetLogText()
    if #State.EventLog == 0 then
        return State.HooksOK and "Hook đã bật. Chơi game để bắt event..." or "(Chưa hook)"
    end
    local lines = {}
    for _, e in ipairs(State.EventLog) do
        lines[#lines+1] = "["..e.time.."] "..e.method
        lines[#lines+1] = "  "..e.name
        lines[#lines+1] = "  Args: "..e.argsStr
        lines[#lines+1] = ""
    end
    return table.concat(lines, "\n")
end

-- ═══ UI ═══
local sg = Instance.new("ScreenGui")
sg.Name = "VzNamDataDumper"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = ParentGui

-- ĐỢI 1 FRAME ĐỂ SCREENGUI BIẾT SIZE THẬT
RunService.RenderStepped:Wait()
RunService.RenderStepped:Wait()

local screenSize = sg.AbsoluteSize
if screenSize.X < 100 then screenSize = Vector2.new(800, 600) end

-- Bảng = 92% ngang, 80% dọc
local W = math.floor(screenSize.X * 0.92)
local H = math.floor(screenSize.Y * 0.80)

-- Nút hoa
local flower = Instance.new("TextButton", sg)
flower.Size = UDim2.new(0, 50, 0, 50)
flower.Position = UDim2.new(0, 15, 0.4, 0)
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

-- Main frame
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, W, 0, H)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
local ms = Instance.new("UIStroke", main)
ms.Color = Color3.fromRGB(0, 191, 255)
ms.Thickness = 2

-- Title bar
local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 2
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🌸 VZNAM HUB DATA"
titleLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 3
titleLbl.TextTruncate = Enum.TextTruncate.AtEnd

local fullCloseBtn = Instance.new("TextButton", titleBar)
fullCloseBtn.Size = UDim2.new(0, 24, 0, 24)
fullCloseBtn.Position = UDim2.new(1, -28, 0.5, -12)
fullCloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
fullCloseBtn.Text = "✕"
fullCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
fullCloseBtn.TextSize = 14
fullCloseBtn.Font = Enum.Font.GothamBold
fullCloseBtn.ZIndex = 10
Instance.new("UICorner", fullCloseBtn).CornerRadius = UDim.new(0, 6)

fullCloseBtn.MouseButton1Click:Connect(function()
    UninstallHooks()
    sg:Destroy()
end)

-- Tab bar (3 tab)
local tabBar = Instance.new("Frame", main)
tabBar.Size = UDim2.new(1, -12, 0, 28)
tabBar.Position = UDim2.new(0, 6, 0, 38)
tabBar.BackgroundTransparency = 1
local tbl = Instance.new("UIListLayout", tabBar)
tbl.FillDirection = Enum.FillDirection.Horizontal
tbl.Padding = UDim.new(0, 4)
tbl.SortOrder = Enum.SortOrder.LayoutOrder

local function mkTab(order, txt)
    local b = Instance.new("TextButton", tabBar)
    b.LayoutOrder = order
    b.Size = UDim2.new(0.33, -3, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.TextTruncate = Enum.TextTruncate.AtEnd
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local tab1 = mkTab(1, "📊 Data")
local tab2 = mkTab(2, "📡 Event")
local tab3 = mkTab(3, "📦 Gộp")

-- Content
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -12, 1, -134)
content.Position = UDim2.new(0, 6, 0, 72)
content.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
content.BorderSizePixel = 0
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 6)

local function mkScroll()
    local s = Instance.new("ScrollingFrame", content)
    s.Size = UDim2.new(1, -6, 1, -6)
    s.Position = UDim2.new(0, 3, 0, 3)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 5
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Visible = false
    s.ScrollingDirection = Enum.ScrollingDirection.Y
    local lbl = Instance.new("TextLabel", s)
    lbl.Size = UDim2.new(1, -16, 0, 0)
    lbl.Position = UDim2.new(0, 6, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = ""
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.SourceSans
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = true
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.LineHeight = 1.1
    return s, lbl
end

local s1, l1 = mkScroll()
local s2, l2 = mkScroll()

-- Tab 3
local t3f = Instance.new("Frame", content)
t3f.Size = UDim2.new(1, -6, 1, -6)
t3f.Position = UDim2.new(0, 3, 0, 3)
t3f.BackgroundTransparency = 1
t3f.Visible = false
local t3l = Instance.new("UIListLayout", t3f)
t3l.Padding = UDim.new(0, 5)
t3l.HorizontalAlignment = Enum.HorizontalAlignment.Center

local filterBtn = Instance.new("TextButton", t3f)
filterBtn.Size = UDim2.new(1, -6, 0, 32)
filterBtn.LayoutOrder = 1
filterBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
filterBtn.Text = "🎯 Filter: Tất cả"
filterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
filterBtn.TextSize = 11
filterBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0, 6)

local combBtn = Instance.new("TextButton", t3f)
combBtn.Size = UDim2.new(1, -6, 0, 32)
combBtn.LayoutOrder = 2
combBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
combBtn.Text = "🔄 GỘP TẤT CẢ"
combBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
combBtn.TextSize = 12
combBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", combBtn).CornerRadius = UDim.new(0, 6)

local t3s = Instance.new("ScrollingFrame", t3f)
t3s.Size = UDim2.new(1, -6, 1, -76)
t3s.LayoutOrder = 3
t3s.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
t3s.BorderSizePixel = 0
t3s.ScrollBarThickness = 5
t3s.CanvasSize = UDim2.new(0, 0, 0, 0)
t3s.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", t3s).CornerRadius = UDim.new(0, 6)

local l3 = Instance.new("TextLabel", t3s)
l3.Size = UDim2.new(1, -16, 0, 0)
l3.Position = UDim2.new(0, 6, 0, 6)
l3.BackgroundTransparency = 1
l3.Text = "(Bấm GỘP TẤT CẢ)"
l3.TextColor3 = Color3.fromRGB(180, 180, 200)
l3.TextSize = 11
l3.Font = Enum.Font.SourceSans
l3.TextXAlignment = Enum.TextXAlignment.Left
l3.TextYAlignment = Enum.TextYAlignment.Top
l3.TextWrapped = true
l3.AutomaticSize = Enum.AutomaticSize.Y
l3.LineHeight = 1.1

local function ShowTab(n)
    State.CurrentTab = n
    s1.Visible = (n == 1)
    s2.Visible = (n == 2)
    t3f.Visible = (n == 3)
    for i, b in ipairs({tab1, tab2, tab3}) do
        b.BackgroundColor3 = (i == n) and Color3.fromRGB(0, 150, 200) or Color3.fromRGB(45, 45, 60)
    end
end
tab1.MouseButton1Click:Connect(function() ShowTab(1) end)
tab2.MouseButton1Click:Connect(function() ShowTab(2) end)
tab3.MouseButton1Click:Connect(function() ShowTab(3) end)

-- Filter cycle
local filterModes = {"Tất cả", "Quan trọng", "Lọc lag"}
local filterIdx = 1
filterBtn.MouseButton1Click:Connect(function()
    filterIdx = filterIdx + 1
    if filterIdx > #filterModes then filterIdx = 1 end
    local mode = filterModes[filterIdx]
    filterBtn.Text = "🎯 Filter: "..mode
    if mode == "Tất cả" then State.FilterMode = "All"
    elseif mode == "Quan trọng" then State.FilterMode = "Important"
    else State.FilterMode = "Custom" end
end)

-- Footer
local footer = Instance.new("Frame", main)
footer.Size = UDim2.new(1, -12, 0, 38)
footer.Position = UDim2.new(0, 6, 1, -44)
footer.BackgroundTransparency = 1
local fl = Instance.new("UIListLayout", footer)
fl.FillDirection = Enum.FillDirection.Horizontal
fl.Padding = UDim.new(0, 4)
fl.SortOrder = Enum.SortOrder.LayoutOrder

local function mkFoot(order, txt, c)
    local b = Instance.new("TextButton", footer)
    b.LayoutOrder = order
    b.Size = UDim2.new(0.25, -3, 1, 0)
    b.BackgroundColor3 = c
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.TextTruncate = Enum.TextTruncate.AtEnd
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local copyB  = mkFoot(1, "📋 COPY",   Color3.fromRGB(50, 180, 50))
local saveB  = mkFoot(2, "💾 LƯU",    Color3.fromRGB(50, 120, 220))
local clearB = mkFoot(3, "🗑️ XÓA",    Color3.fromRGB(180, 80, 50))
local hideB  = mkFoot(4, "👁 ẨN",    Color3.fromRGB(100, 100, 130))

-- ═══ LOGIC ═══
task.spawn(function()
    local ok, res = pcall(CollectData)
    if ok then
        State.DataText = res
        l1.Text = res
    else
        l1.Text = "Lỗi: "..tostring(res)
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
    local ok = false
    if typeof(setclipboard) == "function" then ok = pcall(setclipboard, GetCurrentText()) end
    copyB.Text = ok and "✅" or "❌"
    task.wait(1.5)
    copyB.Text = "📋 COPY"
end)

saveB.MouseButton1Click:Connect(function()
    if typeof(writefile) ~= "function" then
        saveB.Text = "❌"; task.wait(1.5); saveB.Text = "💾 LƯU"; return
    end
    local fname = "VzNamDump_"..os.date("%Y%m%d_%H%M%S")..".txt"
    local ok = pcall(writefile, fname, GetCurrentText())
    saveB.Text = ok and "✅" or "❌"
    task.wait(2)
    saveB.Text = "💾 LƯU"
end)

clearB.MouseButton1Click:Connect(function()
    State.EventLog = {}
    logBuffer = {}
    l2.Text = "(Đã xóa)"
    clearB.Text = "✅"; task.wait(1); clearB.Text = "🗑️ XÓA"
end)

hideB.MouseButton1Click:Connect(function()
    main.Visible = false
    flower.Text = "🌸"
    fs.Color = Color3.fromRGB(255, 105, 180)
end)

combBtn.MouseButton1Click:Connect(function()
    local out = {}
    out[#out+1] = string.rep("═", 50)
    out[#out+1] = "  VZNAM HUB - COMBINED DUMP"
    out[#out+1] = "  Time: "..os.date("%Y-%m-%d %H:%M:%S")
    out[#out+1] = string.rep("═", 50)
    out[#out+1] = ""
    out[#out+1] = "═══ PHẦN 1: DATA ═══"
    out[#out+1] = State.DataText
    out[#out+1] = ""
    out[#out+1] = "═══ PHẦN 2: EVENT LOG ("..#State.EventLog.." events) ═══"
    out[#out+1] = GetLogText()
    l3.Text = table.concat(out, "\n")
    combBtn.Text = "✅"
    task.wait(1)
    combBtn.Text = "🔄 GỘP TẤT CẢ"
end)

flower.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
    if main.Visible then
        flower.Text = "✕"; fs.Color = Color3.fromRGB(255, 80, 80)
    else
        flower.Text = "🌸"; fs.Color = Color3.fromRGB(255, 105, 180)
    end
end)

-- Resize
local rsz = Instance.new("TextButton", main)
rsz.Size = UDim2.new(0, 22, 0, 22)
rsz.Position = UDim2.new(1, -24, 1, -24)
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
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        resizing = true; rStart = i.Position; rSize = main.AbsoluteSize
        rsz.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        if resizing then resizing = false; rsz.BackgroundColor3 = Color3.fromRGB(0, 150, 200) end
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - rStart
        main.Size = UDim2.new(0,
            math.clamp(rSize.X + d.X, 300, screenSize.X * 0.95), 0,
            math.clamp(rSize.Y + d.Y, 250, screenSize.Y * 0.9))
    end
end)

ShowTab(1)
print("[VzNamDumper] LOAD XONG - Size: "..W.."x"..H)
