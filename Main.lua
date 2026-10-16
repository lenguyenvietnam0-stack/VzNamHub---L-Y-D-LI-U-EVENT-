-- ═══ TEST MINIMAL - CHẠY CÁI NÀY TRƯỚC ═══
print("[TEST] Bắt đầu...")

-- Cách lấy parent an toàn nhất cho Delta X
local parent
if typeof(gethui) == "function" then
    parent = gethui()
    print("[TEST] Dùng gethui()")
elseif typeof(get_hidden_gui) == "function" then
    parent = get_hidden_gui()
    print("[TEST] Dùng get_hidden_gui()")
else
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        parent = cg
        print("[TEST] Dùng CoreGui")
    else
        parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
        print("[TEST] Dùng PlayerGui")
    end
end

print("[TEST] Parent =", parent and parent:GetFullName() or "nil")

-- Xóa cũ
pcall(function()
    local old = parent:FindFirstChild("TestUI")
    if old then old:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "TestUI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = parent

print("[TEST] ScreenGui parent =", sg.Parent and sg.Parent:GetFullName() or "nil")

local frame = Instance.new("Frame", sg)
frame.Size = UDim2.new(0, 300, 0, 150)
frame.Position = UDim2.new(0.5, -150, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1, 0, 0, 50)
label.Position = UDim2.new(0, 0, 0, 10)
label.BackgroundTransparency = 1
label.Text = "✅ EXECUTOR CHẠY ĐƯỢC!"
label.TextColor3 = Color3.fromRGB(0, 255, 100)
label.TextSize = 18
label.Font = Enum.Font.GothamBold

local info = Instance.new("TextLabel", frame)
info.Size = UDim2.new(1, -20, 0, 80)
info.Position = UDim2.new(0, 10, 0, 55)
info.BackgroundTransparency = 1
info.Text = "Parent: " .. (parent and parent.Name or "nil") .. "\n"
    .. "setclipboard: " .. (typeof(setclipboard) == "function" and "✅" or "❌") .. "\n"
    .. "writefile: " .. (typeof(writefile) == "function" and "✅" or "❌") .. "\n"
    .. "hookmetamethod: " .. (typeof(hookmetamethod) == "function" and "✅" or "❌")
info.TextColor3 = Color3.fromRGB(220, 220, 230)
info.TextSize = 13
info.Font = Enum.Font.Code
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top

local btn = Instance.new("TextButton", frame)
btn.Size = UDim2.new(1, -20, 0, 30)
btn.Position = UDim2.new(0, 10, 1, -40)
btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
btn.Text = "✕ ĐÓNG TEST"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextSize = 13
btn.Font = Enum.Font.GothamBold
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
btn.MouseButton1Click:Connect(function()
    sg:Destroy()
    print("[TEST] Đã đóng")
end)

print("[TEST] ✅✅✅ HOÀN TẤT. Nhìn màn hình phải thấy ô test.")
