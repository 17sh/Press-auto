--[[
  Auto Helper v2 (Roblox / Delta)
  - Auto Click: แตะที่จุดบนจอ หรือ ใช้ของที่ถืออยู่ (Tool)
  - Anti-AFK, กระโดดกันหลุด, Auto Rejoin, โหมดประหยัดแบต
  - ย่อหน้าต่างเป็นปุ่มกลมลอย (AH) ลากได้ แตะเพื่อเปิดกลับ
  - ย่ออัตโนมัติตอนเริ่มคลิก (ปิดได้) / แตะปุ่มลอยตอนกำลังคลิก = หยุดคลิก + เปิดหน้าต่าง
  - คีย์ลัดบน PC: F6 = เริ่ม/หยุดคลิก
  หมายเหตุ: อย่าตั้งจุดคลิกไว้ใต้หน้าต่างหรือปุ่มลอย
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")

-- ถ้ารันซ้ำ ให้ปิดตัวเก่าก่อน
local env = (getgenv and getgenv()) or _G
if env.AutoHelperCleanup then pcall(env.AutoHelperCleanup) end

local player = Players.LocalPlayer
local alive = true
local connections = {}

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

----------------------------------------------------------------
-- สถานะ
----------------------------------------------------------------
local S = {
	clicking = false,
	mode = 1,          -- 1 = แตะที่จุด, 2 = ใช้ของในมือ
	delayIdx = 7,      -- ดูตาราง DELAYS
	picking = false,
	point = Vector2.new(0, 0),
	antiAfk = true,
	jump = false,
	rejoin = false,
	saver = false,
	autoMin = true,
}
local DELAYS = { 5, 2, 1, 0.5, 0.3, 0.2, 0.1, 0.05, 0.03 }

----------------------------------------------------------------
-- สีธีม
----------------------------------------------------------------
local ACCENT1 = Color3.fromRGB(88, 101, 242)
local ACCENT2 = Color3.fromRGB(150, 80, 240)
local ON = Color3.fromRGB(46, 160, 110)
local OFF = Color3.fromRGB(50, 54, 70)
local STOP = Color3.fromRGB(205, 70, 80)
local WHITE = Color3.new(1, 1, 1)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency
	s.Thickness = thickness
	s.Parent = inst
	return s
end

local function gradient(inst, c1, c2, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation
	g.Parent = inst
	return g
end

----------------------------------------------------------------
-- ScreenGui + หน้าต่างหลัก
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AutoHelperGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okParent = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
if not okParent or not gui.Parent then
	gui.Parent = player:WaitForChild("PlayerGui")
end

local WIDTH, TITLE_H = 230, 34

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(WIDTH, 300)
frame.Position = UDim2.fromOffset(12, 60)
frame.BackgroundTransparency = 1
frame.Active = true
frame.Parent = gui

-- พื้นหลัง: ไล่สี + ลายเส้นเฉียง + ขอบเรืองแสง
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = WHITE
bg.BorderSizePixel = 0
bg.ClipsDescendants = true
bg.ZIndex = 0
bg.Parent = frame
corner(bg, 14)
gradient(bg, Color3.fromRGB(36, 39, 58), Color3.fromRGB(15, 16, 23), 90)
stroke(bg, ACCENT1, 0.45, 1.5)

for i = -8, 22 do
	local s = Instance.new("Frame")
	s.Size = UDim2.new(0, 2, 0, 900)
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.new(0, i * 14, 0.5, 0)
	s.Rotation = 35
	s.BackgroundColor3 = WHITE
	s.BackgroundTransparency = 0.95
	s.BorderSizePixel = 0
	s.Parent = bg
end

-- แถบหัว (ลากได้)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, TITLE_H)
title.BackgroundColor3 = WHITE
title.BorderSizePixel = 0
title.Active = true
title.Parent = frame
corner(title, 14)
gradient(title, ACCENT1, ACCENT2, 0)

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(10, 10)
dot.AnchorPoint = Vector2.new(0, 0.5)
dot.Position = UDim2.new(0, 12, 0.5, 0)
dot.BackgroundColor3 = Color3.fromRGB(170, 175, 195)
dot.BorderSizePixel = 0
dot.Parent = title
corner(dot, 5)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 30, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Auto Helper"
titleLabel.TextColor3 = WHITE
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = title

local function smallBtn(text, xOffset)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(28, 24)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, xOffset, 0.5, 0)
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	b.BackgroundTransparency = 0.45
	b.TextColor3 = WHITE
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	b.Parent = title
	corner(b, 7)
	return b
end
local minBtn = smallBtn("–", -42)
local closeBtn = smallBtn("✕", -8)

-- ตัวเนื้อหา
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 0, 0)
body.Position = UDim2.fromOffset(0, TITLE_H)
body.AutomaticSize = Enum.AutomaticSize.Y
body.BackgroundTransparency = 1
body.Parent = frame

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = body

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Padding = UDim.new(0, 5)
bodyLayout.Parent = body

-- ให้กรอบหลักสูงตามเนื้อหา
local function resize()
	frame.Size = UDim2.fromOffset(WIDTH, TITLE_H + body.AbsoluteSize.Y)
end
connect(body:GetPropertyChangedSignal("AbsoluteSize"), resize)

local function makeButton(text, parent, order, height)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height or 30)
	b.BackgroundColor3 = OFF
	b.BackgroundTransparency = 0.15
	b.TextColor3 = WHITE
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.Text = text
	b.LayoutOrder = order
	b.Parent = parent
	corner(b, 8)
	stroke(b, WHITE, 0.88, 1)
	return b
end

----------------------------------------------------------------
-- ปุ่มลอย (ตอนย่อหน้าต่าง)
----------------------------------------------------------------
local bubble = Instance.new("TextButton")
bubble.Size = UDim2.fromOffset(46, 46)
bubble.Position = frame.Position
bubble.BackgroundColor3 = Color3.fromRGB(36, 39, 58)
bubble.BackgroundTransparency = 0.1
bubble.TextColor3 = WHITE
bubble.Font = Enum.Font.GothamBold
bubble.TextSize = 14
bubble.Text = "AH"
bubble.AutoButtonColor = false
bubble.Visible = false
bubble.Parent = gui
corner(bubble, 23)
local bubbleStroke = stroke(bubble, ACCENT1, 0.1, 2)

local function refreshBubble()
	bubble.BackgroundColor3 = S.clicking and ON or Color3.fromRGB(36, 39, 58)
	bubble.Text = S.clicking and "■" or "AH"
	bubbleStroke.Color = S.clicking and Color3.fromRGB(120, 255, 180) or ACCENT1
end

-- จุดแดงบอกตำแหน่งที่จะคลิก
local marker = Instance.new("Frame")
marker.Size = UDim2.fromOffset(16, 16)
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
marker.BackgroundTransparency = 0.25
marker.ZIndex = 10
marker.Active = false
marker.Parent = gui
corner(marker, 8)
stroke(marker, WHITE, 0.3, 1.5)

local function setPoint(guiPos)
	S.point = guiPos
	marker.Position = UDim2.fromOffset(guiPos.X, guiPos.Y)
end

do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
	setPoint(Vector2.new(vp.X / 2, vp.Y / 2) - GuiService:GetGuiInset())
end

----------------------------------------------------------------
-- ย่อ / ขยาย
----------------------------------------------------------------
local function minimize()
	if S.picking then return end
	bubble.Position = frame.Position
	frame.Visible = false
	bubble.Visible = true
end

local function expand()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
	local x = math.clamp(bubble.Position.X.Offset, 4, math.max(4, vp.X - WIDTH - 4))
	local y = math.clamp(bubble.Position.Y.Offset, 4, math.max(4, vp.Y - frame.Size.Y.Offset - 4))
	frame.Position = UDim2.fromOffset(x, y)
	bubble.Visible = false
	frame.Visible = true
end

----------------------------------------------------------------
-- ฟังก์ชันการทำงาน
----------------------------------------------------------------
local function tapPoint()
	local p = S.point + GuiService:GetGuiInset()
	VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
	VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
end

local function activateTool()
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool then tool:Activate() end
end

local function setSaver(on)
	S.saver = on
	pcall(function() RunService:Set3dRenderingEnabled(not on) end)
	if setfpscap then pcall(setfpscap, on and 20 or 60) end
end

-- ลูปคลิก
task.spawn(function()
	while alive do
		if S.clicking then
			pcall(function()
				if S.mode == 1 then tapPoint() else activateTool() end
			end)
			task.wait(DELAYS[S.delayIdx])
		else
			task.wait(0.1)
		end
	end
end)

-- Anti-AFK: กันโดนเตะเมื่อไม่ขยับ 20 นาที
connect(player.Idled, function()
	if not S.antiAfk then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end)

-- กระโดดทุก ~55 วิ (เสริมกันหลุด)
task.spawn(function()
	while alive do
		task.wait(55)
		if alive and S.jump then
			pcall(function()
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
		end
	end
end)

-- Auto Rejoin: ถ้าหลุด/โดนเตะ แล้วมีหน้าต่าง Error ขึ้น ให้เข้าเกมใหม่
task.spawn(function()
	local pg = CoreGui:WaitForChild("RobloxPromptGui", 10)
	local overlay = pg and pg:WaitForChild("promptOverlay", 10)
	if not overlay then return end
	connect(overlay.ChildAdded, function(child)
		if S.rejoin and child.Name == "ErrorPrompt" then
			task.wait(3)
			pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
		end
	end)
end)

----------------------------------------------------------------
-- ปุ่มต่างๆ
----------------------------------------------------------------
local startBtn = makeButton("", body, 1, 36)
startBtn.TextSize = 15
startBtn.Font = Enum.Font.GothamBold

local function setClicking(on)
	S.clicking = on
	startBtn.Text = on and "■ หยุดคลิก" or "▶ เริ่มคลิก"
	startBtn.BackgroundColor3 = on and STOP or ON
	dot.BackgroundColor3 = on and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(170, 175, 195)
	refreshBubble()
end
setClicking(false)

local modeBtn = makeButton("", body, 2)
local function refreshMode()
	modeBtn.Text = S.mode == 1 and "โหมด: แตะที่จุด" or "โหมด: ใช้ของในมือ"
	marker.Visible = (S.mode == 1)
end
refreshMode()

-- แถวความเร็ว
local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 30)
row.BackgroundTransparency = 1
row.LayoutOrder = 3
row.Parent = body

local slowBtn = makeButton("ช้าลง", row, 0)
slowBtn.Size = UDim2.new(0.28, -3, 1, 0)
slowBtn.TextSize = 12

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(0.44, 0, 1, 0)
delayLabel.Position = UDim2.new(0.28, 0, 0, 0)
delayLabel.BackgroundTransparency = 1
delayLabel.TextColor3 = WHITE
delayLabel.Font = Enum.Font.GothamMedium
delayLabel.TextSize = 12
delayLabel.Parent = row

local fastBtn = makeButton("เร็วขึ้น", row, 0)
fastBtn.Size = UDim2.new(0.28, -3, 1, 0)
fastBtn.Position = UDim2.new(0.72, 3, 0, 0)
fastBtn.TextSize = 12

local function refreshDelay()
	delayLabel.Text = string.format("ทุก %.2f วิ", DELAYS[S.delayIdx])
end
refreshDelay()

local pointBtn = makeButton("ตั้งจุดคลิก", body, 4)

-- สวิตช์ 2 คอลัมน์
local grid = Instance.new("Frame")
grid.Size = UDim2.new(1, 0, 0, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.BackgroundTransparency = 1
grid.LayoutOrder = 5
grid.Parent = body

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -3, 0, 30)
gridLayout.CellPadding = UDim2.fromOffset(6, 5)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local function makeToggle(label, key, order, onChange)
	local b = makeButton("", grid, order)
	b.TextSize = 12
	local function refresh()
		b.Text = label .. ": " .. (S[key] and "เปิด" or "ปิด")
		b.BackgroundColor3 = S[key] and ON or OFF
	end
	refresh()
	b.Activated:Connect(function()
		S[key] = not S[key]
		refresh()
		if onChange then onChange(S[key]) end
	end)
end

makeToggle("Anti-AFK", "antiAfk", 1)
makeToggle("กระโดด", "jump", 2)
makeToggle("Rejoin", "rejoin", 3)
makeToggle("ประหยัดแบต", "saver", 4, setSaver)
makeToggle("ย่ออัตโนมัติ", "autoMin", 5)

----------------------------------------------------------------
-- เชื่อมปุ่มกับการทำงาน
----------------------------------------------------------------
local function toggleClicking()
	local on = not S.clicking
	S.picking = false
	pointBtn.Text = "ตั้งจุดคลิก"
	setClicking(on)
	if on and S.autoMin then minimize() end
end

startBtn.Activated:Connect(toggleClicking)

modeBtn.Activated:Connect(function()
	S.mode = (S.mode == 1) and 2 or 1
	refreshMode()
end)

slowBtn.Activated:Connect(function()
	S.delayIdx = math.max(1, S.delayIdx - 1)
	refreshDelay()
end)

fastBtn.Activated:Connect(function()
	S.delayIdx = math.min(#DELAYS, S.delayIdx + 1)
	refreshDelay()
end)

pointBtn.Activated:Connect(function()
	setClicking(false)
	S.mode = 1
	refreshMode()
	S.picking = true
	pointBtn.Text = "แตะจุดบนจอ..."
end)

minBtn.Activated:Connect(minimize)

local function inside(obj, p)
	if not obj.Visible then return false end
	local a, s = obj.AbsolutePosition, obj.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

connect(UIS.InputBegan, function(input, gp)
	local t = input.UserInputType
	if S.picking and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		if inside(frame, p) or inside(bubble, p) then return end
		S.picking = false
		setPoint(p)
		pointBtn.Text = "ตั้งจุดคลิก"
		return
	end
	if not gp and input.KeyCode == Enum.KeyCode.F6 then
		toggleClicking()
	end
end)

----------------------------------------------------------------
-- ลากได้ (หัวหน้าต่าง + ปุ่มลอย) และแตะปุ่มลอยเพื่อเปิด
----------------------------------------------------------------
local drag = nil
local function makeDraggable(handle, target, onTap)
	handle.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			local d = {
				target = target,
				start = input.Position,
				startPos = target.Position,
				moved = false,
			}
			drag = d
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if drag == d then drag = nil end
					if not d.moved and onTap then onTap() end
				end
			end)
		end
	end)
end

connect(UIS.InputChanged, function(input)
	if not drag then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
		local delta = input.Position - drag.start
		if delta.Magnitude > 8 then drag.moved = true end
		if drag.moved then
			local sp = drag.startPos
			drag.target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X,
				sp.Y.Scale, sp.Y.Offset + delta.Y)
		end
	end
end)

makeDraggable(title, frame, nil)
makeDraggable(bubble, bubble, function()
	-- ถ้ากำลังคลิกอยู่ แตะปุ่มลอย = หยุดคลิกแล้วเปิดหน้าต่าง
	if S.clicking then setClicking(false) end
	expand()
end)

resize()

----------------------------------------------------------------
-- ปิดสคริปต์
----------------------------------------------------------------
local function cleanup()
	alive = false
	S.clicking = false
	if S.saver then setSaver(false) end
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
end
env.AutoHelperCleanup = cleanup
closeBtn.Activated:Connect(cleanup)
