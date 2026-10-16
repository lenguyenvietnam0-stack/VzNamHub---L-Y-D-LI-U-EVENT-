local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local lp = Players.LocalPlayer

local parent
if typeof(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok then parent = h end
end
if not parent then parent = lp:WaitForChild("PlayerGui") end

local old = parent:FindFirstChild("VzSimple")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "VzSimple"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.Parent = parent

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 500, 0, 400)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", main).Color = Color3.fromRGB(0, 200, 255)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
title.BorderSizePixel = 0
title.Text = "🌸 VZNAM DUMPER"
title.TextColor3 = Color3.fromRGB(0, 200, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, -16, 1, -90)
scroll.Position = UDim2.new(0, 8, 0, 36)
scroll.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
scroll.ScrollingEnabled = true
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scroll.ClipsDescendants = true
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local txt = Instance.new("TextLabel", scroll)
txt.Position = UDim2.new(0, 10, 0, 10)
txt.BackgroundTransparency = 1
txt.Text = "Đang thu thập..."
txt.TextColor3 = Color3.fromRGB(220, 220, 230)
txt.TextSize = 12
txt.Font = Enum.Font.SourceSans
txt.TextXAlignment = Enum.TextXAlignment.Left
txt.TextYAlignment = Enum.TextYAlignment.Top
txt.TextWrapped = true

local function updateScroll()
    local availableW = scroll.AbsoluteSize.X - 30
    if availableW < 50 then availableW = 400 end
    local size = TextService:GetTextSize(
        txt.Text, txt.TextSize, txt.Font, Vector2.new(availableW, math.huge)
    )
    txt.Size = UDim2.new(0, availableW, 0, size.Y + 10)
    scroll.CanvasSize = UDim2.new(0, 0, 0, size.Y + 30)
end

local function mkBtn(x, text, color)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0.3, -8, 0, 40)
    b.Position = UDim2.new(x, 0, 1, -48)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local copyBtn = mkBtn(0.02, "📋 COPY", Color3.fromRGB(50, 180, 50))
local saveBtn = mkBtn(0.35, "💾 LƯU", Color3.fromRGB(50, 120, 220))
local closeBtn = mkBtn(0.68, "✕ TẮT", Color3.fromRGB(200, 50, 50))

local flower = Instance.new("TextButton", sg)
flower.Size = UDim2.new(0, 50, 0, 50)
flower.Position = UDim2.new(0, 20, 0.5, 0)
flower.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
flower.Text = "🌸"
flower.TextSize = 26
flower.TextColor3 = Color3.fromRGB(255, 255, 255)
flower.Font = Enum.Font.GothamBold
flower.Active = true
flower.Draggable = true
Instance.new("UICorner", flower).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", flower).Color = Color3.fromRGB(255, 105, 180)
flower.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

local function collect()
    local out = {}
    local function w(s) out[#out+1] = tostring(s) end
    w("VZNAM DATA DUMP")
    w("Time: "..os.date("%H:%M:%S"))
    w("Player: "..lp.Name)
    w("")
    w("=== WORKSPACE ===")
    for _, v in ipairs(workspace:GetChildren()) do
        w("• "..v.Name.."  ["..v.ClassName.."]")
    end
    w("")
    w("=== REMOTES ===")
    for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            w("• "..v.ClassName..": "..v:GetFullName())
        end
    end
    w("")
    w("=== PROMPTS ===")
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            w("• "..v.ActionText.." / "..v.ObjectText)
        end
    end
    return table.concat(out, "\n")
end

txt:GetPropertyChangedSignal("Text"):Connect(updateScroll)
txt:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)

task.spawn(function()
    local ok, res = pcall(collect)
    txt.Text = ok and res or ("Lỗi: "..tostring(res))
    task.wait(0.1)
    updateScroll()
end)

copyBtn.MouseButton1Click:Connect(function()
    local ok = false
    if typeof(setclipboard) == "function" then
        ok = pcall(setclipboard, txt.Text)
    end
    copyBtn.Text = ok and "✅ OK" or "❌ LỖI"
    task.wait(1.5)
    copyBtn.Text = "📋 COPY"
end)

saveBtn.MouseButton1Click:Connect(function()
    if typeof(writefile) ~= "function" then
        saveBtn.Text = "❌ KO HỖ TRỢ"
        task.wait(1.5)
        saveBtn.Text = "💾 LƯU"
        return
    end
    local fname = "VzDump_"..os.date("%Y%m%d_%H%M%S")..".txt"
    local ok = pcall(writefile, fname, txt.Text)
    saveBtn.Text = ok and "✅ ĐÃ LƯU" or "❌ LỖI"
    task.wait(2)
    saveBtn.Text = "💾 LƯU"
end)

closeBtn.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

print("[VzNam] ✅ LOAD XONG")
