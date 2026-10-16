--[[
    ═══════════════════════════════════════════════════════
    🌸 VZNAM HUB - LẤY DỮ LIỆU GAME 🌸
    📊 Tab 1: Dữ liệu game (workspace, prompt, remote, GUI)
    📡 Tab 2: Quét event (SimpleSpy style - hook remote)
    📦 Tab 3: Gộp tất cả (Data + Event log)
    ═══════════════════════════════════════════════════════
]]

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local lp           = Players.LocalPlayer

-- Cleanup
if CoreGui:FindFirstChild("VzNamDataDumper") then
    CoreGui.VzNamDataDumper:Destroy()
end
if _G.VzNamDumperCleanup then pcall(_G.VzNamDumperCleanup) end

-- ═══════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════
local State = {
    EventLog     = {},
    MaxLog       = 500,
    HooksActive  = false,
    OldNamecall  = nil,
    LogPaused    = false,
    CurrentTab   = 1,
    GameDataText = "",
}

-- ═══════════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════════
local function FormatArg(a)
    local t = typeof(a)
    if t == "Instance" then return a:GetFullName()
    elseif t == "string" then
        if #a > 60 then a = a:sub(1, 57) .. "..." end
        return string.format("%q", a)
    elseif t == "table" then
        local n = 0
        for _ in pairs(a) do n = n + 1 end
        return "{table:" .. n .. "}"
    elseif t == "nil" then return "nil"
    else return tostring(a)
    end
end

local function FormatArgs(args)
    local parts = {}
    for i = 1, #args do
        parts[#parts + 1] = FormatArg(args[i])
    end
    return table.concat(parts, ", ")
end

-- ═══════════════════════════════════════════════
-- TAB 1: GAME DATA COLLECTOR
-- ═══════════════════════════════════════════════
local function CollectGameData()
    local out = {}
    local function w(s) out[#out + 1] = tostring(s) end
    local function line() w(string.rep("═", 60)) end
    local function dash() w(string.rep("─", 60)) end

    line()
    w("VZNAM HUB - GAME DATA DUMP")
    w("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    w("Player: " .. lp.Name .. " (" .. lp.UserId .. ")")
    w("PlaceId: " .. game.PlaceId)
    w("JobId: " .. tostring(game.JobId))
    line()

    -- 1. Workspace
    w(""); w("[1] WORKSPACE - CẤP 1"); dash()
    for _, v in ipairs(workspace:GetChildren()) do
        w(string.format("%-30s | %s", v.Name, v.ClassName))
    end

    -- 2. Plots
    w(""); w("[2] PLOT / BASE CỦA PLAYER"); dash()
    local pc = 0
    for _, p in ipairs(Players:GetPlayers()) do
        local plot = workspace:FindFirstChild(p.Name)
        if plot then
            pc = pc + 1
            w(string.format("PLOT: %s | %s | Owner=%s",
                plot:GetFullName(), plot.ClassName, p.Name))
        end
    end
    w("→ Tổng: " .. pc .. " plot")

    -- 3. Prompts
    w(""); w("[3] PROXIMITYPROMPT"); dash()
    local prc = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            prc = prc + 1
            if prc <= 50 then
                w(string.format("[%d] %s", prc,
                    v.Parent and v.Parent:GetFullName() or "nil"))
                w(string.format("    Action=%q Object=%q Hold=%s Dist=%s",
                    v.ActionText, v.ObjectText,
                    tostring(v.HoldDuration), tostring(v.MaxActivationDistance)))
            end
        end
    end
    w("→ Tổng: " .. prc .. " prompt")

    -- 4. Remotes
    w(""); w("[4] REMOTE (ReplicatedStorage)"); dash()
    local rc = 0
    local function scanRemotes(parent, depth)
        if depth > 3 then return end
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction")
               or v:IsA("UnreliableRemoteEvent") then
                rc = rc + 1
                w(string.format("%s | %s", v.ClassName, v:GetFullName()))
            end
            if v:IsA("Folder") or v:IsA("Model") then
                scanRemotes(v, depth + 1)
            end
        end
    end
    scanRemotes(RS, 0)
    w("→ Tổng: " .. rc .. " remote")

    -- 5. Attributes
    w(""); w("[5] ATTRIBUTE (workspace top-level)"); dash()
    for _, v in ipairs(workspace:GetChildren()) do
        local has = false
        for _ in pairs(v:GetAttributes()) do has = true; break end
        if has then
            w("→ " .. v.Name .. " (" .. v.ClassName .. ")")
            for k, val in pairs(v:GetAttributes()) do
                w(string.format("     @%s = %s (%s)", k, tostring(val), typeof(val)))
            end
        end
    end

    -- 6. PlayerGui
    w(""); w("[6] PLAYERGUI"); dash()
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetChildren()) do
            w("GUI: " .. v.Name .. " (" .. v.ClassName .. ")")
        end
    end

    line(); w("END DUMP")
    return table.concat(out, "\n")
end

-- ═══════════════════════════════════════════════
-- TAB 2: EVENT LOGGER
-- ═══════════════════════════════════════════════
local function AddLogEntry(remote, method, args)
    if State.LogPaused then return end
    local entry = {
        time    = os.date("%H:%M:%S"),
        name    = remote:GetFullName(),
        method  = method,
        args    = args,
        argsStr = FormatArgs(args),
    }
    table.insert(State.EventLog, 1, entry)
    while #State.EventLog > State.MaxLog do
        table.remove(State.EventLog)
    end
    if State.OnEventAdded then State.OnEventAdded() end
end

local function InstallHooks()
    if State.HooksActive then return true end
    if typeof(hookmetamethod) ~= "function" then return false end

    local ok = pcall(function()
        State.OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                pcall(function()
                    AddLogEntry(self, method, {...})
                end)
            end
            return State.OldNamecall(self, ...)
        end)
    end)
    if ok then
        State.HooksActive = true
        return true
    end
    return false
end

local function UninstallHooks()
    if not State.HooksActive then return end
    pcall(function()
        hookmetamethod(game, "__namecall", State.OldNamecall)
    end)
    State.HooksActive = false
end

_G.VzNamDumperCleanup = UninstallHooks

local function GetLogText()
    if #State.EventLog == 0 then
        if State.HooksActive then
            return "✅ Hook đã bật. Chơi game để bắt event...\n(Event sẽ hiện ở đây)"
        end
        return "(Chưa có event nào. Bật hook và chơi game để bắt event.)"
    end
    local lines = {}
    for i, e in ipairs(State.EventLog) do
        lines[#lines + 1] = string.format("[%s] %s:%s(%s)",
            e.time, e.name, e.method, e.argsStr)
    end
    return table.concat(lines, "\n")
end

-- ═══════════════════════════════════════════════
-- UI BUILD
-- ═══════════════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "VzNamDataDumper"
sg.ResetOnSpawn = false
sg.Parent = CoreGui

-- Nút bông hoa 🌸
local flower = Instance.new("TextButton", sg)
flower.Size = UDim2.new(0, 50, 0, 50)
flower.Position = UDim2.new(0, 20, 0.4, 0)
flower.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
flower.BackgroundTransparency = 0.1
flower.Text = "🌸"
flower.TextSize = 26
flower.TextColor3 = Color3.fromRGB(255, 255, 255)
flower.Font = Enum.Font.GothamBold
flower.Active = true
flower.Draggable = true
Instance.new("UICorner", flower).CornerRadius = UDim.new(1, 0)

local fStroke = Instance.new("UIStroke", flower)
fStroke.Thickness = 2.5
fStroke.Color = Color3.fromRGB(255, 105, 180)

local glow = Instance.new("Frame", flower)
glow.Size = UDim2.new(1, 8, 1, 8)
glow.Position = UDim2.new(0, -4, 0, -4)
glow.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
glow.BackgroundTransparency = 0.85
glow.BorderSizePixel = 0
glow.ZIndex = 0
Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    while flower.Parent do
        local tw = TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {Size = UDim2.new(1, 14, 1, 14), Position = UDim2.new(0, -7, 0, -7), BackgroundTransparency = 0.7})
        tw:Play(); task.wait(1.2)
        if not flower.Parent then break end
        local tw2 = TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {Size = UDim2.new(1, 8, 1, 8), Position = UDim2.new(0, -4, 0, -4), BackgroundTransparency = 0.85})
        tw2:Play(); task.wait(1.2)
    end
end)

-- Main frame
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 560, 0, 460)
main.Position = UDim2.new(0.5, -280, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = Color3.fromRGB(0, 191, 255)
mainStroke.Thickness = 2

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
local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 5)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local Tabs = {}
local function MakeTabBtn(order, name)
    local b = Instance.new("TextButton", tabBar)
    b.LayoutOrder = order
    b.Size = UDim2.new(0, 174, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    b.BorderSizePixel = 0
    b.Text = name
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local tab1Btn = MakeTabBtn(1, "📊 Dữ Liệu Game")
local tab2Btn = MakeTabBtn(2, "📡 Quét Event")
local tab3Btn = MakeTabBtn(3, "📦 Tất Cả Gộp Lại")

-- Content area
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -16, 1, -138)
content.Position = UDim2.new(0, 8, 0, 76)
content.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
content.BorderSizePixel = 0
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 6)

local function MakeScroll()
    local s = Instance.new("ScrollingFrame", content)
    s.Size = UDim2.new(1, -8, 1, -8)
    s.Position = UDim2.new(0, 4, 0, 4)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 6
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.Visible = false

    local lbl = Instance.new("TextLabel", s)
    lbl.Size = UDim2.new(1, -10, 0, 0)
    lbl.Position = UDim2.new(0, 5, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = ""
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = false
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    return s, lbl
end

local scroll1, lbl1 = MakeScroll()
local scroll2, lbl2 = MakeScroll()

-- Tab 3 frame
local tab3Frame = Instance.new("Frame", content)
tab3Frame.Size = UDim2.new(1, -8, 1, -8)
tab3Frame.Position = UDim2.new(0, 4, 0, 4)
tab3Frame.BackgroundTransparency = 1
tab3Frame.Visible = false
local tab3Layout = Instance.new("UIListLayout", tab3Frame)
tab3Layout.SortOrder = Enum.SortOrder.LayoutOrder
tab3Layout.Padding = UDim.new(0, 5)
tab3Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local combineBtn = Instance.new("TextButton", tab3Frame)
combineBtn.LayoutOrder = 1
combineBtn.Size = UDim2.new(1, -10, 0, 34)
combineBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
combineBtn.BorderSizePixel = 0
combineBtn.Text = "🔄 GỘP TẤT CẢ (Data + Event Log)"
combineBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
combineBtn.TextSize = 12
combineBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", combineBtn).CornerRadius = UDim.new(0, 6)

local tab3Scroll = Instance.new("ScrollingFrame", tab3Frame)
tab3Scroll.LayoutOrder = 2
tab3Scroll.Size = UDim2.new(1, -10, 1, -48)
tab3Scroll.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
tab3Scroll.BorderSizePixel = 0
tab3Scroll.ScrollBarThickness = 6
tab3Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tab3Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", tab3Scroll).CornerRadius = UDim.new(0, 6)

local lbl3 = Instance.new("TextLabel", tab3Scroll)
lbl3.Size = UDim2.new(1, -10, 0, 0)
lbl3.Position = UDim2.new(0, 5, 0, 5)
lbl3.BackgroundTransparency = 1
lbl3.Text = "(Bấm nút GỘP TẤT CẢ để xem data + event log gộp lại)"
lbl3.TextColor3 = Color3.fromRGB(180, 180, 200)
lbl3.TextSize = 10
lbl3.Font = Enum.Font.Code
lbl3.TextXAlignment = Enum.TextXAlignment.Left
lbl3.TextYAlignment = Enum.TextYAlignment.Top
lbl3.TextWrapped = false
lbl3.AutomaticSize = Enum.AutomaticSize.Y

-- Tab switching
local function ShowTab(n)
    State.CurrentTab = n
    scroll1.Visible = (n == 1)
    scroll2.Visible = (n == 2)
    tab3Frame.Visible = (n == 3)
    for i, b in ipairs({tab1Btn, tab2Btn, tab3Btn}) do
        b.BackgroundColor3 = (i == n)
            and Color3.fromRGB(0, 150, 200)
            or  Color3.fromRGB(45, 45, 60)
    end
end

tab1Btn.MouseButton1Click:Connect(function() ShowTab(1) end)
tab2Btn.MouseButton1Click:Connect(function() ShowTab(2) end)
tab3Btn.MouseButton1Click:Connect(function() ShowTab(3) end)

-- Footer
local footer = Instance.new("Frame", main)
footer.Size = UDim2.new(1, -16, 0, 40)
footer.Position = UDim2.new(0, 8, 1, -48)
footer.BackgroundTransparency = 1
local fLayout = Instance.new("UIListLayout", footer)
fLayout.FillDirection = Enum.FillDirection.Horizontal
fLayout.Padding = UDim.new(0, 5)
fLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function MakeFootBtn(order, text, color)
    local b = Instance.new("TextButton", footer)
    b.LayoutOrder = order
    b.Size = UDim2.new(0, 128, 1, 0)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local copyBtn  = MakeFootBtn(1, "📋 COPY",     Color3.fromRGB(50, 180, 50))
local saveBtn  = MakeFootBtn(2, "💾 LƯU FILE", Color3.fromRGB(50, 120, 220))
local clearBtn = MakeFootBtn(3, "🗑️ XÓA LOG",  Color3.fromRGB(180, 80, 50))
local hideBtn  = MakeFootBtn(4, "✕ ẨN",       Color3.fromRGB(180, 50, 50))

-- Data collection
task.spawn(function()
    lbl1.Text = "Đang thu thập dữ liệu..."
    task.wait(0.1)
    State.GameDataText = CollectGameData()
    lbl1.Text = State.GameDataText
end)

-- Log update
local pendingUpdate = false
local function ScheduleLogUpdate()
    if pendingUpdate then return end
    pendingUpdate = true
    task.defer(function()
        pendingUpdate = false
        lbl2.Text = GetLogText()
    end)
end
State.OnEventAdded = ScheduleLogUpdate

-- Auto-install hooks
task.spawn(function()
    task.wait(0.3)
    local ok = InstallHooks()
    if not ok then
        lbl2.Text = "❌ Executor không hỗ trợ hookmetamethod!\nKhông thể quét event tự động.\n\nDùng tab 1 để lấy dữ liệu tĩnh."
    end
    ScheduleLogUpdate()
end)

-- Copy / Save / Clear
local function GetCurrentText()
    if State.CurrentTab == 1 then return lbl1.Text
    elseif State.CurrentTab == 2 then return GetLogText()
    else return lbl3.Text end
end

copyBtn.MouseButton1Click:Connect(function()
    local txt = GetCurrentText()
    local ok = false
    if typeof(setclipboard) == "function" then
        ok = pcall(setclipboard, txt)
    end
    if ok then
        copyBtn.Text = "✅ ĐÃ COPY"
        copyBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    else
        copyBtn.Text = "❌ LỖI"
        copyBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
    task.wait(1.5)
    copyBtn.Text = "📋 COPY"
    copyBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
end)

saveBtn.MouseButton1Click:Connect(function()
    if typeof(writefile) ~= "function" then
        saveBtn.Text = "❌ Không hỗ trợ"
        saveBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        task.wait(1.5)
        saveBtn.Text = "💾 LƯU FILE"
        saveBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        return
    end
    local txt = GetCurrentText()
    local fname = "VzNamDump_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    local ok = pcall(function() writefile(fname, txt) end)
    if ok then
        saveBtn.Text = "✅ Đã lưu!"
        saveBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
        print("[VzNamDumper] File: " .. fname)
    else
        saveBtn.Text = "❌ Lỗi"
        saveBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
    task.wait(2)
    saveBtn.Text = "💾 LƯU FILE"
    saveBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
end)

clearBtn.MouseButton1Click:Connect(function()
    State.EventLog = {}
    lbl2.Text = "(Đã xóa log. Chơi game để bắt event mới.)"
    clearBtn.Text = "✅ ĐÃ XÓA"
    task.wait(1)
    clearBtn.Text = "🗑️ XÓA LOG"
end)

hideBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    flower.Text = "🌸"
    fStroke.Color = Color3.fromRGB(255, 105, 180)
    glow.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
end)

-- Tab 3 combine
combineBtn.MouseButton1Click:Connect(function()
    local data = State.GameDataText
    if data == "" then
        data = CollectGameData()
        State.GameDataText = data
    end
    local logText = GetLogText()
    local out = {}
    out[#out+1] = "════════════════════════════════════════"
    out[#out+1] = "  VZNAM HUB - COMBINED DUMP"
    out[#out+1] = "  Time: " .. os.date("%Y-%m-%d %H:%M:%S")
    out[#out+1] = "════════════════════════════════════════"
    out[#out+1] = ""
    out[#out+1] = "════════════════════════════════════════"
    out[#out+1] = "  PHẦN 1: DỮ LIỆU GAME"
    out[#out+1] = "════════════════════════════════════════"
    out[#out+1] = data
    out[#out+1] = ""
    out[#out+1] = "════════════════════════════════════════"
    out[#out+1] = "  PHẦN 2: EVENT LOG (" .. #State.EventLog .. " events)"
    out[#out+1] = "════════════════════════════════════════"
    out[#out+1] = logText
    lbl3.Text = table.concat(out, "\n")
    combineBtn.Text = "✅ ĐÃ GỘP"
    task.wait(1)
    combineBtn.Text = "🔄 GỘP TẤT CẢ (Data + Event Log)"
end)

-- Flower toggle
flower.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
    if main.Visible then
        flower.Text = "✕"
        fStroke.Color = Color3.fromRGB(255, 80, 80)
        glow.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    else
        flower.Text = "🌸"
        fStroke.Color = Color3.fromRGB(255, 105, 180)
        glow.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
    end
end)

-- ═══════════════════════════════════════════════
-- NÚT KÉO TO NHỎ (góc phải dưới)
-- ═══════════════════════════════════════════════
local resizeBtn = Instance.new("TextButton", main)
resizeBtn.Name = "ResizeHandle"
resizeBtn.Size = UDim2.new(0, 22, 0, 22)
resizeBtn.Position = UDim2.new(1, -22, 1, -22)
resizeBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
resizeBtn.BackgroundTransparency = 0.3
resizeBtn.BorderSizePixel = 0
resizeBtn.Text = "◢"
resizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resizeBtn.TextSize = 14
resizeBtn.Font = Enum.Font.GothamBold
resizeBtn.ZIndex = 10
resizeBtn.AutoButtonColor = false
Instance.new("UICorner", resizeBtn).CornerRadius = UDim.new(0, 5)

local resizeStroke = Instance.new("UIStroke", resizeBtn)
resizeStroke.Color = Color3.fromRGB(0, 200, 255)
resizeStroke.Thickness = 1.5

resizeBtn.MouseEnter:Connect(function()
    TweenService:Create(resizeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(0, 200, 255),
        BackgroundTransparency = 0
    }):Play()
end)
resizeBtn.MouseLeave:Connect(function()
    if not resizeBtn:GetAttribute("Dragging") then
        TweenService:Create(resizeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(0, 150, 200),
            BackgroundTransparency = 0.3
        }):Play()
    end
end)

local resizing = false
local resizeStart = nil
local startSize = nil

resizeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeBtn:SetAttribute("Dragging", true)
        resizeStart = input.Position
        startSize = main.AbsoluteSize
        TweenService:Create(resizeBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(80, 220, 80),
            BackgroundTransparency = 0
        }):Play()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        if resizing then
            resizing = false
            resizeBtn:SetAttribute("Dragging", false)
            TweenService:Create(resizeBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(0, 150, 200),
                BackgroundTransparency = 0.3
            }):Play()
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newW = math.clamp(startSize.X + delta.X, 400, 900)
        local newH = math.clamp(startSize.Y + delta.Y, 320, 700)
        main.Size = UDim2.new(0, newW, 0, newH)
    end
end)

-- ═══════════════════════════════════════════════
-- KHỞI TẠO
-- ═══════════════════════════════════════════════
ShowTab(1)
print("[VzNamDumper] ✅ Loaded.")
print("[VzNamDumper] Tab 1: Data | Tab 2: Events | Tab 3: Combined")
print("[VzNamDumper] 🌸 = Mở/đóng | ◢ = Kéo resize")
