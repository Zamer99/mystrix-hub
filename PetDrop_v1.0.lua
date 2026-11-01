--[[
	MENU TEMPLATE — только визуал, без логики

	Куда класть: LocalScript в StarterPlayer > StarterPlayerScripts
	Открыть / закрыть: клавиша CONFIG.ToggleKey (по умолчанию RightShift) или кнопка ✕
	Ассеты не нужны: всё собрано из Frame + UICorner / UIStroke / UIGradient.

	Как добавлять элементы на страницу вкладки (pages[1], pages[2], ...):
		Section(page, "Название секции")
		Toggle(page, ICON.Bolt, "Заголовок", "Описание", true, function(state) end)
		Dropdown(page, ICON.Cube, "Заголовок", "Описание", function(open) end)
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")

local player = Players.LocalPlayer

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local running = true
local states = {
    coins = false, gears = false, piggy = false,
    speed = false, noclip = false, inf_jump = false, fly = false,
    buy_basic = false, buy_heavy = false,
    buy_bouncy = false, buy_elemental = false, buy_unstable = false,
}

local SPEED_VAL = 50
local FLY_SPEED = 55
local BUY_DELAY = 0.5

-- ===== CONFIG: загрузка при запуске =====
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "PetDrop_config.json"
local savedConfig = {}
local selectedPalette = 1
local configStatusLabel = nil

local function loadConfig()
    if type(readfile) ~= "function" then
        warn("[PetDrop] Executor не поддерживает readfile; используются настройки по умолчанию")
        return
    end

    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then
        return
    end

    local decoded, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not decoded or type(data) ~= "table" then
        warn("[PetDrop] Config повреждён или имеет неверный формат")
        return
    end

    savedConfig = data

    if type(data.states) == "table" then
        for key in pairs(states) do
            if type(data.states[key]) == "boolean" then
                states[key] = data.states[key]
            end
        end
    end

    if type(data.speed) == "number" then
        SPEED_VAL = math.clamp(math.floor(data.speed), 1, 500)
    end

    if type(data.flySpeed) == "number" then
        FLY_SPEED = math.clamp(math.floor(data.flySpeed), 1, 500)
    end

    if type(data.palette) == "number" then
        selectedPalette = math.clamp(math.floor(data.palette), 1, 10)
    end
end

loadConfig()

local Remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Request") -- RemoteFunction, используем InvokeServer

local theme = {
    accent  = Color3.fromRGB(255, 105, 180),
    bg      = Color3.fromRGB(16, 15, 23),
    sidebar = Color3.fromRGB(21, 19, 30),
    btn_off = Color3.fromRGB(39, 37, 50),
    text    = Color3.fromRGB(249, 248, 253),
    subtext = Color3.fromRGB(205, 202, 218),
}

local themes = {
    { name = "Pink",   accent = Color3.fromRGB(255, 105, 180) },
    { name = "Red",    accent = Color3.fromRGB(220, 60,  60)  },
    { name = "Blue",   accent = Color3.fromRGB(60,  120, 220) },
    { name = "Green",  accent = Color3.fromRGB(50,  180, 80)  },
    { name = "Purple", accent = Color3.fromRGB(140, 60,  220) },
    { name = "Gold",   accent = Color3.fromRGB(220, 170, 30)  },
}

-- ======== ПОЛЁТ ========
local flightVelocity = nil
local flightGyro = nil
local flightKeys = {
    W = false, A = false, S = false, D = false,
    Up = false, Down = false,
}

local function clearFlight()
    if flightVelocity then
        flightVelocity:Destroy()
        flightVelocity = nil
    end
    if flightGyro then
        flightGyro:Destroy()
        flightGyro = nil
    end
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function setFlight(on)
    states.fly = on
    if not on then
        clearFlight()
        return
    end

    if not root or not hum then return end

    clearFlight()
    hum.PlatformStand = true

    flightVelocity = Instance.new("BodyVelocity")
    flightVelocity.Name = "PetDropFlightVelocity"
    flightVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flightVelocity.P = 1e4
    flightVelocity.Velocity = Vector3.zero
    flightVelocity.Parent = root

    flightGyro = Instance.new("BodyGyro")
    flightGyro.Name = "PetDropFlightGyro"
    flightGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flightGyro.P = 1e4
    flightGyro.CFrame = root.CFrame
    flightGyro.Parent = root
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.W then flightKeys.W = true end
    if input.KeyCode == Enum.KeyCode.A then flightKeys.A = true end
    if input.KeyCode == Enum.KeyCode.S then flightKeys.S = true end
    if input.KeyCode == Enum.KeyCode.D then flightKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then flightKeys.Up = true end
    if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
        flightKeys.Down = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then flightKeys.W = false end
    if input.KeyCode == Enum.KeyCode.A then flightKeys.A = false end
    if input.KeyCode == Enum.KeyCode.S then flightKeys.S = false end
    if input.KeyCode == Enum.KeyCode.D then flightKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then flightKeys.Up = false end
    if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
        flightKeys.Down = false
    end
end)

player.CharacterAdded:Connect(function(c)
    char = c
    root = c:WaitForChild("HumanoidRootPart")
    hum = c:WaitForChild("Humanoid")
    if states.speed then hum.WalkSpeed = SPEED_VAL end
    if states.fly then
        task.wait(0.2)
        if states.fly then setFlight(true) end
    end
end)

local function touch(part)
    pcall(function()
        firetouchinterest(root, part, false)
        task.wait(0.02)
        firetouchinterest(root, part, true)
    end)
end

RunService.Stepped:Connect(function()
    if not running then return end
    if states.noclip and char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if states.inf_jump and char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local capsules = {
    { key = "buy_basic",     id = "basic"     },
    { key = "buy_heavy",     id = "heavy"     },
    { key = "buy_bouncy",    id = "bouncy"    },
    { key = "buy_elemental", id = "elemental" },
    { key = "buy_unstable",  id = "unstable"  },
}
local capTimers = {}
for _, c in ipairs(capsules) do capTimers[c.key] = 0 end

RunService.Heartbeat:Connect(function()
    if not running then return end
    char = player.Character
    if not char then return end
    root = char:FindFirstChild("HumanoidRootPart")
    hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if states.speed then hum.WalkSpeed = SPEED_VAL end

    if states.fly then
        if not flightVelocity or flightVelocity.Parent ~= root
            or not flightGyro or flightGyro.Parent ~= root then
            setFlight(true)
        end

        if flightVelocity and flightGyro then
            local camera = workspace.CurrentCamera
            if camera then
                local direction = Vector3.zero
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector

                if flightKeys.W then direction += forward end
                if flightKeys.S then direction -= forward end
                if flightKeys.D then direction += right end
                if flightKeys.A then direction -= right end
                if flightKeys.Up then direction += Vector3.yAxis end
                if flightKeys.Down then direction -= Vector3.yAxis end

                if direction.Magnitude > 0 then
                    direction = direction.Unit
                end

                flightVelocity.Velocity = direction * FLY_SPEED
                flightGyro.CFrame = CFrame.lookAt(root.Position, root.Position + camera.CFrame.LookVector)
            end
        end
    end

    local folder = workspace:FindFirstChild("GoldenCoins")
    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            local name = obj.Name:lower()
            local part = obj:IsA("BasePart") and obj
                or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
            if part then
                if states.coins and name == "coin" then touch(part) end
                if states.gears and name == "gear" then touch(part) end
            end
        end
    end

    if states.piggy then
        local ok, pad = pcall(function()
            return workspace.Plots.Plot3.Furniture.Piggy.Pad
        end)
        if ok and pad then touch(pad) end
    end

    local now = tick()
    for _, c in ipairs(capsules) do
        if states[c.key] and (now - capTimers[c.key]) >= BUY_DELAY then
            capTimers[c.key] = now
            pcall(function()
                Remote:InvokeServer("buyCapsule", { id = c.id, n = 1 })
            end)
        end
    end
end)



----------------------------------------------------------------------


local function shutdownFeatures()
    running = false
    for key in pairs(states) do states[key] = false end
    clearFlight()
    if hum then
        hum.WalkSpeed = 50
        hum.PlatformStand = false
    end
end

-- НАСТРОЙКИ
----------------------------------------------------------------------
local CONFIG = {
	ToggleKey      = Enum.KeyCode.RightShift, -- открыть / закрыть меню
	CollapseKey    = Enum.KeyCode.RightControl, -- свернуть / развернуть в мини-меню
	StartOpen      = true,                    -- показывать меню при запуске
	Size           = Vector2.new(760, 460),   -- размер окна (px)
	SidebarWidth   = 208,                     -- ширина левой панели
	BackgroundBlur = true,                    -- размытие мира за меню
	BlurSize       = 16,
}

-- ===== CONFIG: сохранение =====
local function saveConfig()
    if type(writefile) ~= "function" then
        local message = "Executor не поддерживает writefile"
        if configStatusLabel then configStatusLabel.Text = message end
        warn("[PetDrop] " .. message)
        return false, message
    end

    local data = {
        version = 1,
        states = states,
        speed = SPEED_VAL,
        flySpeed = FLY_SPEED,
        palette = selectedPalette,
        collapseKey = CONFIG.CollapseKey.Name,
    }

    local ok, err = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)

    if ok then
        if configStatusLabel then
            configStatusLabel.Text = "Автосохранение включено · PetDrop_config.json"
        end
        return true
    end

    local message = "Ошибка сохранения: " .. tostring(err)
    if configStatusLabel then configStatusLabel.Text = message end
    warn("[PetDrop] " .. message)
    return false, err
end

-- Восстанавливаем клавишу сворачивания.
if type(savedConfig.collapseKey) == "string" then
    local key = Enum.KeyCode[savedConfig.collapseKey]
    if key and key ~= Enum.KeyCode.Unknown and key ~= CONFIG.ToggleKey then
        CONFIG.CollapseKey = key
    end
end

-- Текст-заглушки
local TEXT = {
	Title    = "PET DROP",
	Subtitle = "v 1.0",
	Tabs     = { "Main", "Player", "Shop", "Settings" },
	User     = player.DisplayName,
	Status   = "ONLINE",
}

-- Иконки-заглушки: символ ИЛИ картинка вида "rbxassetid://123456789"
local ICON = {
	Logo    = "●",
	Tabs    = { "M", "P", "$", "ST" },
	Bolt    = "C",
	Target  = "G",
	Shield  = "P",
	Cube    = "B",
	Note    = "N",
	Palette = "T",
}

-- Цвета
local WHITE = Color3.fromRGB(255, 255, 255)
local THEME = {
	Sidebar   = Color3.fromRGB(12, 12, 14),
	Content   = Color3.fromRGB(28, 28, 32),
	Text      = Color3.fromRGB(248, 248, 250),
	SubText   = Color3.fromRGB(174, 174, 182),
	TabIdle   = Color3.fromRGB(190, 190, 198),
	ToggleOn  = Color3.fromRGB(225, 225, 230),
	ToggleOff = Color3.fromRGB(35, 35, 40),
	KnobOn    = Color3.fromRGB(255, 255, 255),
	KnobOff   = Color3.fromRGB(125, 125, 133),
}

local SB_W  = CONFIG.SidebarWidth
local ROW_H = 44
local TAB_H = 44

----------------------------------------------------------------------
-- ХЕЛПЕРЫ
----------------------------------------------------------------------
local function create(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function tween(obj, duration, goal, style, direction)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

-- animate = true -> плавно, иначе сразу
local function apply(obj, goal, animate)
	if animate then
		tween(obj, 0.18, goal)
	else
		for key, value in pairs(goal) do
			obj[key] = value
		end
	end
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(transparency, thickness)
	return create("UIStroke", {
		Color = WHITE,
		Transparency = transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, -- обводка рамки, а не текста
	})
end

local function text(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in pairs(props) do
		p[key] = value
	end
	return create("TextLabel", p)
end

-- иконка: символ-заглушка или картинка "rbxassetid://..."
local function icon(parent, value, size, color, props)
	local p = {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	}
	for key, val in pairs(props or {}) do
		p[key] = val
	end
	if string.sub(value, 1, 13) == "rbxassetid://" then
		p.Image = value
		p.ImageColor3 = color
		return create("ImageLabel", p)
	end
	p.Text = value
	p.TextColor3 = color
	p.TextSize = (value == "1.0") and 15 or math.floor(size * 0.62)
	p.Font = Enum.Font.GothamSemibold
	p.TextXAlignment = Enum.TextXAlignment.Center
	p.TextYAlignment = Enum.TextYAlignment.Center
	return create("TextLabel", p)
end

local function tintOf(obj)
	return obj:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
end

----------------------------------------------------------------------
-- ЭЛЕМЕНТЫ КОНТЕНТА: Section / Toggle / Dropdown
----------------------------------------------------------------------
local function nextOrder(page)
	local n = (page:GetAttribute("Order") or 0) + 1
	page:SetAttribute("Order", n)
	return n
end

-- Заголовок секции (вертикальная «таблетка» + текст)
local function Section(page, title)
	local holder = create("Frame", {
		Name = "Section",
		LayoutOrder = nextOrder(page),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local line = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 18),
		BackgroundColor3 = THEME.Text,
		BorderSizePixel = 0,
		Parent = line,
	}, { corner(2) })
	text({
		Parent = line,
		Position = UDim2.fromOffset(13, 0),
		Size = UDim2.new(1, -13, 1, 0),
		Font = Enum.Font.GothamSemibold,
		TextSize = 17,
		Text = title,
	})
	return holder
end

-- Общая основа строки: иконка + заголовок + описание
local function baseRow(page, iconValue, title, desc)
	local row = create("TextButton", {
		Name = "Row",
		LayoutOrder = nextOrder(page),
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = page,
	}, { corner(14), stroke(0.88, 1) })

	text({
		Name = "Title",
		Parent = row,
		Position = UDim2.fromOffset(16, 7),
		Size = UDim2.new(1, -100, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		Text = title,
	})
	text({
		Name = "Desc",
		Parent = row,
		Position = UDim2.fromOffset(16, 25),
		Size = UDim2.new(1, -100, 0, 14),
		TextSize = 11,
		TextColor3 = THEME.SubText,
		Text = desc,
	})

	row.MouseEnter:Connect(function()
		tween(row, 0.15, { BackgroundTransparency = 0.88 })
	end)
	row.MouseLeave:Connect(function()
		tween(row, 0.15, { BackgroundTransparency = 0.93 })
	end)
	return row
end

-- Строка с переключателем
local function Toggle(page, iconValue, title, desc, default, callback)
	local row = baseRow(page, iconValue, title, desc)
	local state = (default == true)

	local track = create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(46, 26),
		BorderSizePixel = 0,
		Parent = row,
	}, { corner(13), stroke(0.6, 1.2) })

	local knob = create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(10) })

	local function render(animate)
		apply(track, {
			BackgroundColor3 = state and THEME.ToggleOn or THEME.ToggleOff,
		}, animate)
		apply(knob, {
			Position = state and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and THEME.KnobOn or THEME.KnobOff,
		}, animate)
	end
	render(false)

	row.Activated:Connect(function()
		state = not state
		render(true)
		if callback then
			callback(state)
		end
		saveConfig()
	end)
	return row
end

-- Строка с переключателем + кнопка ≡ для настроек (число в поле ввода)
local function ToggleWithSettings(page, iconValue, title, desc, default, settingLabel, settingMin, settingMax, settingDefault, callback, onSettingChanged)
	local row = create("Frame", {
		Name = "ToggleSettingsRow",
		LayoutOrder = nextOrder(page),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = page,
	})

	local expanded = false
	local settingPanel = nil

	-- основная строка
	local mainRow = create("TextButton", {
		Name = "Main",
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	}, { corner(14), stroke(0.88, 1) })

	-- три полоски слева
	local linesHolder = create("Frame", {
		Name = "LinesLeft",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Parent = mainRow,
	})
	for li = 0, 2 do
		create("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, li * 6),
			Size = UDim2.fromOffset(li == 1 and 12 or 16, 2),
			BackgroundColor3 = THEME.SubText,
			BorderSizePixel = 0,
			Parent = linesHolder,
		}, { corner(1) })
	end

	text({
		Name = "Title",
		Parent = mainRow,
		Position = UDim2.fromOffset(36, 7),
		Size = UDim2.new(1, -150, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		Text = title,
	})
	text({
		Name = "Desc",
		Parent = mainRow,
		Position = UDim2.fromOffset(36, 25),
		Size = UDim2.new(1, -150, 0, 14),
		TextSize = 11,
		TextColor3 = THEME.SubText,
		Text = desc,
	})

	mainRow.MouseEnter:Connect(function() tween(mainRow, 0.15, { BackgroundTransparency = 0.88 }) end)
	mainRow.MouseLeave:Connect(function() tween(mainRow, 0.15, { BackgroundTransparency = 0.93 }) end)

	-- тогл
	local state = (default == true)
	local track = create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0.5, 0),
		Size = UDim2.fromOffset(46, 26),
		BorderSizePixel = 0,
		Parent = mainRow,
	}, { corner(13), stroke(0.6, 1.2) })
	local knob = create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(10) })

	local function renderToggle(animate)
		apply(track, { BackgroundColor3 = state and THEME.ToggleOn or THEME.ToggleOff }, animate)
		apply(knob, {
			Position = state and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and THEME.KnobOn or THEME.KnobOff,
		}, animate)
	end
	renderToggle(false)

	local blockToggle = false

	mainRow.Activated:Connect(function()
		if blockToggle then return end
		state = not state
		renderToggle(true)
		if callback then callback(state) end
		saveConfig()
	end)

	-- кнопка ≡ (три полоски)
	local settingsBtn = create("TextButton", {
		Name = "SettingsBtn",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "≡",
		TextColor3 = THEME.SubText,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		ZIndex = 3,
		Parent = mainRow,
	}, { corner(9), stroke(0.8, 1) })

	settingsBtn.MouseEnter:Connect(function() tween(settingsBtn, 0.12, { BackgroundTransparency = 0.75 }) end)
	settingsBtn.MouseLeave:Connect(function() tween(settingsBtn, 0.12, { BackgroundTransparency = 0.88 }) end)

	-- панель настроек (раскрывается под строкой)
	local currentValue = settingDefault

	settingsBtn.MouseButton1Down:Connect(function()
		blockToggle = true
	end)

	settingsBtn.Activated:Connect(function()
		blockToggle = true
		task.delay(0.05, function() blockToggle = false end)
		expanded = not expanded

		if expanded then
			-- создаём панель
			settingPanel = create("Frame", {
				Name = "SettingPanel",
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.91,
				BorderSizePixel = 0,
				Parent = row,
			}, { corner(12), stroke(0.88, 1) })

			text({
				Parent = settingPanel,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -130, 1, 0),
				TextSize = 12,
				TextColor3 = THEME.SubText,
				Text = settingLabel .. "  (" .. settingMin .. "–" .. settingMax .. ")",
			})

			local box = create("TextBox", {
				Name = "Input",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(88, 30),
				BackgroundColor3 = THEME.ToggleOff,
				BackgroundTransparency = 0.05,
				BorderSizePixel = 0,
				TextColor3 = THEME.Text,
				PlaceholderColor3 = THEME.SubText,
				PlaceholderText = tostring(settingDefault),
				Text = tostring(currentValue),
				ClearTextOnFocus = false,
				Font = Enum.Font.GothamSemibold,
				TextSize = 13,
				Parent = settingPanel,
			}, { corner(9), stroke(0.78, 1) })

			box.FocusLost:Connect(function()
				local v = tonumber(box.Text)
				if not v then box.Text = tostring(currentValue); return end
				v = math.clamp(math.floor(v), settingMin, settingMax)
				currentValue = v
				box.Text = tostring(v)
				if onSettingChanged then onSettingChanged(v) end
				saveConfig()
			end)

			row.Size = UDim2.new(1, 0, 0, ROW_H + 54)
			settingPanel.Position = UDim2.fromOffset(0, ROW_H + 6)
			tween(settingsBtn, 0.15, { TextColor3 = THEME.Text })
		else
			if settingPanel then
				settingPanel:Destroy()
				settingPanel = nil
			end
			row.Size = UDim2.new(1, 0, 0, ROW_H)
			tween(settingsBtn, 0.15, { TextColor3 = THEME.SubText })
		end
	end)

	return row
end

-- Строка с выпадающим списком (пока только стрелка-шеврон)
local function Dropdown(page, iconValue, title, desc, callback)
	local row = baseRow(page, iconValue, title, desc)
	local open = false

	local chevron = create("Frame", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -26, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Parent = row,
	})
	-- шеврон «v» из двух повёрнутых палочек
	for _, side in ipairs({ -1, 1 }) do
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + side * 0.22, 0, 0.5, 0),
			Size = UDim2.fromOffset(10, 2),
			Rotation = side * -45,
			BackgroundColor3 = THEME.Text,
			BorderSizePixel = 0,
			Parent = chevron,
		}, { corner(1) })
	end

	row.Activated:Connect(function()
		open = not open
		tween(chevron, 0.2, { Rotation = open and 180 or 0 })
		if callback then
			callback(open)
		end
	end)
	return row
end

----------------------------------------------------------------------
-- ОКНО
----------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "PetDropGlassMonochrome",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local uiScale = create("UIScale")

local window = create("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CONFIG.Size.X, CONFIG.Size.Y),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.08, -- более плотный фон: меню не теряется на яркой карте
	BorderSizePixel = 0,
	Active = true, -- не пропускать клики в игру
	Visible = false,
	Parent = gui,
}, {
	corner(28),
	uiScale,
	-- левая панель темнее, правая светлее
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.Sidebar),
			ColorSequenceKeypoint.new(SB_W / CONFIG.Size.X, THEME.Sidebar),
			ColorSequenceKeypoint.new(SB_W / CONFIG.Size.X + 0.0005, THEME.Content),
			ColorSequenceKeypoint.new(1, THEME.Content),
		}),
	}),
})

-- блик «стекла»
create("Frame", {
	Name = "Sheen",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = window,
}, {
	corner(28),
	create("UIGradient", {
		Rotation = 60,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(0.5, 0.97),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}),
})

-- светлая кромка окна
local rim = stroke(0, 1.5)
create("UIGradient", {
	Rotation = 45,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 0.5),
	}),
	Parent = rim,
})
rim.Parent = window

-- разделитель между панелью и контентом
create("Frame", {
	Name = "Divider",
	Position = UDim2.fromOffset(SB_W, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	Parent = window,
})

----------------------------------------------------------------------
-- ЛЕВАЯ ПАНЕЛЬ: логотип, вкладки, профиль
----------------------------------------------------------------------
local sidebar = create("Frame", {
	Name = "Sidebar",
	Size = UDim2.new(0, SB_W, 1, 0),
	BackgroundTransparency = 1,
	Parent = window,
})

icon(sidebar, ICON.Logo, 44, THEME.Text, {
	Name = "VersionMark",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(18, 16),
})
text({
	Name = "Title",
	Parent = sidebar,
	Position = UDim2.fromOffset(70, 19),
	Size = UDim2.new(1, -80, 0, 24),
	Font = Enum.Font.GothamBold,
	TextSize = 19,
	Text = TEXT.Title,
})
text({
	Name = "Subtitle",
	Parent = sidebar,
	Position = UDim2.fromOffset(70, 43),
	Size = UDim2.new(1, -80, 0, 14),
	TextSize = 11,
	TextColor3 = THEME.SubText,
	Text = TEXT.Subtitle,
})

-- Профиль внизу
create("Frame", {
	Name = "ProfileLine",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -80),
	Size = UDim2.new(1, -36, 0, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.92,
	BorderSizePixel = 0,
	Parent = sidebar,
})

local profile = create("Frame", {
	Name = "Profile",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -14),
	Size = UDim2.new(1, -28, 0, 56),
	BackgroundTransparency = 1,
	Parent = sidebar,
})

local avatar = create("ImageLabel", {
	Name = "Avatar",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(70, 70, 77),
	BorderSizePixel = 0,
	Parent = profile,
}, { corner(20), stroke(0.55, 1.5) })

-- аватарка игрока (если не загрузится — останется серый кружок)
task.spawn(function()
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
	end)
	if ok then
		avatar.Image = url
	end
end)

text({
	Name = "UserName",
	Parent = profile,
	Position = UDim2.fromOffset(58, 11),
	Size = UDim2.new(1, -62, 0, 18),
	Font = Enum.Font.GothamSemibold,
	TextSize = 14,
	Text = TEXT.User,
})
create("Frame", {
	Name = "StatusDot",
	Position = UDim2.fromOffset(59, 34),
	Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = THEME.Text,
	BorderSizePixel = 0,
	Parent = profile,
}, { corner(3) })
text({
	Name = "Status",
	Parent = profile,
	Position = UDim2.fromOffset(70, 30),
	Size = UDim2.new(1, -74, 0, 14),
	TextSize = 11,
	TextColor3 = THEME.SubText,
	Text = TEXT.Status,
})

----------------------------------------------------------------------
-- ПРАВАЯ ЧАСТЬ: страницы + кнопка закрытия
----------------------------------------------------------------------
local content = create("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(SB_W + 1, 0),
	Size = UDim2.new(1, -(SB_W + 1), 1, 0),
	BackgroundTransparency = 1,
	Parent = window,
})

local function newPage(name)
	return create("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, 0, 1, -10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = WHITE,
		ScrollBarImageTransparency = 0.7,
		Visible = false,
		Parent = content,
	}, {
		create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 22),
			PaddingRight = UDim.new(0, 22),
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 14),
		}),
	})
end

local close = create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
	ZIndex = 5,
	Parent = content,
}, { corner(10), stroke(0.7, 1) })

-- крестик из двух повёрнутых палочек
for _, rot in ipairs({ 45, -45 }) do
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 2),
		Rotation = rot,
		BackgroundColor3 = THEME.Text,
		BorderSizePixel = 0,
		Parent = close,
	}, { corner(1) })
end
close.MouseEnter:Connect(function()
	tween(close, 0.15, { BackgroundTransparency = 0.8 })
end)
close.MouseLeave:Connect(function()
	tween(close, 0.15, { BackgroundTransparency = 0.9 })
end)

-- Кнопка сворачивания находится слева от X.
local setOpen -- объявляем заранее, чтобы кнопки могли вызвать функции ниже
local collapseMenu
local collapseButton = create("TextButton", {
	Name = "Collapse",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -54, 0, 14),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "—",
	TextColor3 = THEME.Text,
	TextSize = 20,
	Font = Enum.Font.GothamMedium,
	ZIndex = 5,
	Parent = content,
}, { corner(10), stroke(0.7, 1) })
collapseButton.Activated:Connect(function()
	if collapseMenu then collapseMenu() end
end)
collapseButton.MouseEnter:Connect(function() tween(collapseButton, 0.15, { BackgroundTransparency = 0.8 }) end)
collapseButton.MouseLeave:Connect(function() tween(collapseButton, 0.15, { BackgroundTransparency = 0.9 }) end)

-- Компактная кнопка возврата после полного закрытия через X.
local reopenButton = create("TextButton", {
	Name = "ReopenMenu",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.fromOffset(104, 36),
	BackgroundColor3 = THEME.Content,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "☰  MENU",
	TextColor3 = THEME.Text,
	TextSize = 13,
	Font = Enum.Font.GothamSemibold,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, { corner(10), stroke(0.35, 1.2) })
reopenButton.Activated:Connect(function()
	setOpen(true)
end)
reopenButton.MouseEnter:Connect(function()
	tween(reopenButton, 0.12, { BackgroundTransparency = 0 })
end)
reopenButton.MouseLeave:Connect(function()
	tween(reopenButton, 0.12, { BackgroundTransparency = 0.08 })
end)

-- Мини-меню в стиле игровых кнопок: яркий фон, толстая рамка и белая подпись.
local miniMenuButton = create("TextButton", {
	Name = "MiniMenu",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -55, 0.5, 180),
	Size = UDim2.fromOffset(78, 78),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	ClipsDescendants = false,
	ZIndex = 30,
	Parent = gui,
}, {
	corner(25),
	create("UIStroke", {
		Color = Color3.fromRGB(0, 0, 0), Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}),
	create("UIGradient", {
		Rotation = 70,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 155, 225)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(224, 113, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(151, 100, 255)),
		}),
	}),
	create("Frame", {
		Name = "Shine", Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(43, 7), Rotation = -6,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 32,
	}, { corner(4) }),
	create("TextLabel", {
		Name = "Monogram", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -1, 0.5, -5), Size = UDim2.fromOffset(65, 46),
		BackgroundTransparency = 1, Text = "PD", Rotation = -9,
		Font = Enum.Font.FredokaOne, TextSize = 38,
		TextColor3 = Color3.fromRGB(255, 237, 118), ZIndex = 33,
	}, {
		create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
	}),
	create("TextLabel", {
		Name = "Sparkle", Position = UDim2.fromOffset(53, 12),
		Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1,
		Text = "+", Font = Enum.Font.FredokaOne, TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 34,
	}, {
		create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
	}),
	create("TextLabel", {
		Name = "Caption", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(92, 27),
		BackgroundTransparency = 1, Text = "Pet Drop",
		Font = Enum.Font.FredokaOne, TextSize = 21,
		TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 35,
	}, {
		create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
	}),
})
do
	local miniScale = create("UIScale", { Scale = 1, Parent = miniMenuButton })
	miniMenuButton.MouseEnter:Connect(function()
		tween(miniScale, 0.12, { Scale = 1.06 })
	end)
	miniMenuButton.MouseLeave:Connect(function()
		tween(miniScale, 0.12, { Scale = 1 })
	end)
end

----------------------------------------------------------------------
-- ВКЛАДКИ
----------------------------------------------------------------------
local pages, tabs = {}, {}
local activeTab = 1

local function selectTab(index, instant)
	activeTab = index
	for i, tab in ipairs(tabs) do
		local on = (i == index)
		local tint = on and THEME.Text or THEME.TabIdle
		apply(tab.button, { BackgroundTransparency = on and 0.78 or 1 }, not instant)
		apply(tab.stroke, { Transparency = on and 0.7 or 1 }, not instant)
		apply(tab.label, { TextColor3 = tint }, not instant)
		pages[i].Visible = on
	end
end

local tabCount = #TEXT.Tabs
local tabList = create("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(14, 82),
	Size = UDim2.new(1, -28, 0, tabCount * TAB_H + (tabCount - 1) * 4),
	BackgroundTransparency = 1,
	Parent = sidebar,
}, {
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}),
})

for i, name in ipairs(TEXT.Tabs) do
	local button = create("TextButton", {
		Name = "Tab" .. i,
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, TAB_H),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = tabList,
	}, { corner(14) })
	local outline = stroke(1, 1)
	outline.Parent = button

	local label = text({
		Parent = button,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = THEME.TabIdle,
		Text = name,
	})

	-- заглушка иконки для совместимости с selectTab
	local tabIcon = label

	tabs[i] = { button = button, stroke = outline, icon = tabIcon, label = label }
	pages[i] = newPage("Page" .. i)

	button.Activated:Connect(function()
		selectTab(i)
	end)
	button.MouseEnter:Connect(function()
		if activeTab ~= i then
			tween(button, 0.12, { BackgroundTransparency = 0.92 })
		end
	end)
	button.MouseLeave:Connect(function()
		if activeTab ~= i then
			tween(button, 0.12, { BackgroundTransparency = 1 })
		end
	end)
end

----------------------------------------------------------------------
-- 
-- РЕАЛЬНЫЕ ФУНКЦИИ PET DROP
Section(pages[1], "СБОР РЕСУРСОВ")
Toggle(pages[1], ICON.Bolt, "Авто монеты", "Автоматически подбирать монеты", states.coins, function(v) states.coins=v end)
Toggle(pages[1], ICON.Target, "Авто шестерёнки", "Автоматически подбирать шестерёнки", states.gears, function(v) states.gears=v end)
Toggle(pages[1], ICON.Shield, "Авто копилка", "Автоматически активировать Piggy Pad", states.piggy, function(v) states.piggy=v end)

Section(pages[2], "ПЕРЕДВИЖЕНИЕ")
ToggleWithSettings(pages[2], "≡", "Ускорение", "Заданная скорость передвижения", states.speed,
    "Скорость", 1, 500, SPEED_VAL,
    function(v)
        states.speed = v
        if hum then hum.WalkSpeed = v and SPEED_VAL or 50 end
    end,
    function(v)
        SPEED_VAL = v
        if states.speed and hum then hum.WalkSpeed = v end
    end
)
Toggle(pages[2], "J", "Бесконечный прыжок", "Повторные прыжки в воздухе", states.inf_jump, function(v) states.inf_jump=v end)
Toggle(pages[2], "N", "Noclip", "Отключает столкновения персонажа", states.noclip, function(v)
    states.noclip=v
    if not v and char then
        for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end
    end
end)
ToggleWithSettings(pages[2], "≡", "Полёт", "WASD — движение, Space — вверх, Ctrl — вниз", states.fly,
    "Скорость полёта", 1, 500, FLY_SPEED,
    function(v) setFlight(v) end,
    function(v) FLY_SPEED = v end
)

local function NumberSetting(page,title,desc,initial,onChanged)
    local holder=create("Frame",{
        Name="NumberSetting",LayoutOrder=nextOrder(page),Size=UDim2.new(1,0,0,54),
        BackgroundColor3=WHITE,BackgroundTransparency=0.93,BorderSizePixel=0,Parent=page,
    },{corner(14),stroke(0.88,1)})
    text({Parent=holder,Position=UDim2.fromOffset(14,6),Size=UDim2.new(1,-112,0,19),Font=Enum.Font.GothamMedium,TextSize=14,Text=title})
    text({Parent=holder,Position=UDim2.fromOffset(14,27),Size=UDim2.new(1,-112,0,15),TextSize=10,TextColor3=THEME.SubText,Text=desc})
    local box=create("TextBox",{
        Name="Value",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),
        Size=UDim2.fromOffset(82,32),BackgroundColor3=THEME.ToggleOff,BackgroundTransparency=0.05,
        BorderSizePixel=0,TextColor3=THEME.Text,PlaceholderColor3=THEME.SubText,
        PlaceholderText="1–500",Text=tostring(initial),ClearTextOnFocus=false,
        Font=Enum.Font.GothamSemibold,TextSize=13,Parent=holder,
    },{corner(9),stroke(0.78,1)})
    box.FocusLost:Connect(function()
        local value=tonumber(box.Text)
        if not value then box.Text=tostring(initial); return end
        value=math.clamp(math.floor(value),1,500)
        initial=value; box.Text=tostring(value); onChanged(value)
        saveConfig()
    end)
end


Section(pages[3], "АВТОПОКУПКА КАПСУЛ")
Toggle(pages[3],"B","Basic Capsule","Автоматическая покупка Basic",states.buy_basic,function(v) states.buy_basic=v end)
Toggle(pages[3],"H","Heavy Capsule","Автоматическая покупка Heavy",states.buy_heavy,function(v) states.buy_heavy=v end)
Toggle(pages[3],"Y","Bouncy Capsule","Автоматическая покупка Bouncy",states.buy_bouncy,function(v) states.buy_bouncy=v end)
Toggle(pages[3],"E","Elemental Capsule","Автоматическая покупка Elemental",states.buy_elemental,function(v) states.buy_elemental=v end)
Toggle(pages[3],"U","Unstable Capsule","Автоматическая покупка Unstable",states.buy_unstable,function(v) states.buy_unstable=v end)

Section(pages[4], "НАСТРОЙКИ ИНТЕРФЕЙСА")
local extrasText=text({
    Parent=pages[4],Size=UDim2.new(1,0,0,34),TextSize=12,
    TextColor3=THEME.SubText,TextWrapped=true,
    Text="Выбери тему оформления и клавишу сворачивания меню.",
})
local palettes={
    {name="Чёрно-белая",color=Color3.fromRGB(225,225,230)},
    {name="Серебристая",color=Color3.fromRGB(190,200,210)},
    {name="Ледяная",color=Color3.fromRGB(175,215,230)},
    {name="Графитовая",color=Color3.fromRGB(145,145,155)},
    {name="Pink",color=Color3.fromRGB(255,105,180)},
    {name="Red",color=Color3.fromRGB(220,60,60)},
    {name="Blue",color=Color3.fromRGB(60,120,220)},
    {name="Green",color=Color3.fromRGB(50,180,80)},
    {name="Purple",color=Color3.fromRGB(140,60,220)},
    {name="Gold",color=Color3.fromRGB(220,170,30)},
}

-- Компактный выбор темы: нажми на текущую тему, чтобы раскрыть список.
local paletteOpen = false
local paletteHolder = create("Frame", {
    Name="ThemeDropdown",
    LayoutOrder=nextOrder(pages[4]),
    Size=UDim2.new(1,0,0,44),
    BackgroundTransparency=1,
    ClipsDescendants=true,
    Parent=pages[4],
})
local selectedPaletteButton = create("TextButton", {
    Name="SelectedTheme",
    Size=UDim2.new(1,0,0,40),
    Position=UDim2.fromOffset(0,0),
    BackgroundColor3=THEME.Content,
    BackgroundTransparency=0.12,
    BorderSizePixel=0,
    AutoButtonColor=false,
    Text="",
    Parent=paletteHolder,
}, {corner(11),stroke(0.78,1)})
local selectedPaletteText = text({
    Parent=selectedPaletteButton,
    Position=UDim2.fromOffset(14,0),
    Size=UDim2.new(1,-52,1,0),
    Text="Тема: "..palettes[selectedPalette].name,
    TextSize=13,
    Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Left,
})
local paletteArrow = text({
    Parent=selectedPaletteButton,
    AnchorPoint=Vector2.new(1,0.5),
    Position=UDim2.new(1,-14,0.5,0),
    Size=UDim2.fromOffset(22,24),
    Text="⌄",TextSize=20,Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Center,
})

local paletteButtons={}
local function applyPalette(index, shouldSave)
    index = math.clamp(math.floor(tonumber(index) or 1), 1, #palettes)
    local palette=palettes[index]
    selectedPalette=index
    selectedPaletteText.Text="Тема: "..palette.name
    THEME.ToggleOn=palette.color
    THEME.TabIdle=palette.color
    extrasText.Text="Выбрана тема: "..palette.name
    for _,item in ipairs(gui:GetDescendants()) do
        if item:IsA("UIStroke") and not item:IsDescendantOf(miniMenuButton) then
            item.Color = palette.color
        end
    end
    for i,tab in ipairs(tabs) do
        if i==activeTab then tab.button.BackgroundColor3=palette.color end
    end
    if shouldSave ~= false then
        saveConfig()
    end
end

for index,palette in ipairs(palettes) do
    local option=create("TextButton",{
        Name="ThemeOption_"..index,
        Position=UDim2.fromOffset(0,44+(index-1)*36),
        Size=UDim2.new(1,0,0,32),
        BackgroundColor3=palette.color,
        BackgroundTransparency=0.86,
        BorderSizePixel=0,
        AutoButtonColor=false,
        Text="    "..palette.name,
        TextColor3=THEME.Text,
        TextXAlignment=Enum.TextXAlignment.Left,
        Font=Enum.Font.GothamMedium,
        TextSize=12,
        Visible=false,
        Parent=paletteHolder,
    },{corner(9),stroke(0.88,1)})
    paletteButtons[index]=option
    option.Activated:Connect(function()
        applyPalette(index)
        paletteOpen=false
        for _,button in ipairs(paletteButtons) do button.Visible=false end
        paletteArrow.Text="⌄"
        TweenService:Create(paletteHolder,TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
            Size=UDim2.new(1,0,0,44)
        }):Play()
    end)
end

selectedPaletteButton.Activated:Connect(function()
    paletteOpen=not paletteOpen
    for _,button in ipairs(paletteButtons) do button.Visible=paletteOpen end
    paletteArrow.Text=paletteOpen and "⌃" or "⌄"
    TweenService:Create(paletteHolder,TweenInfo.new(0.22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{
        Size=UDim2.new(1,0,0,paletteOpen and (44+#palettes*36) or 44)
    }):Play()
end)

-- Применяем сохранённую тему, не создавая лишнее сохранение при запуске.
applyPalette(selectedPalette, false)

local bindButton = create("TextButton", {
	Name = "CollapseKeybind",
	LayoutOrder = nextOrder(pages[4]),
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.92,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
	Parent = pages[4],
}, { corner(12), stroke(0.82, 1) })
text({ Parent = bindButton, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -150, 1, 0), Text = "Клавиша сворачивания", TextSize = 13, Font = Enum.Font.GothamMedium })
local bindValue = text({ Parent = bindButton, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 24), Text = CONFIG.CollapseKey.Name, TextSize = 12, TextColor3 = THEME.SubText, TextXAlignment = Enum.TextXAlignment.Right })
local waitingForBind = false
bindButton.Activated:Connect(function()
	waitingForBind = true
	bindValue.Text = "Нажми клавишу..."
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not waitingForBind then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if input.KeyCode == Enum.KeyCode.Unknown then return end
	if input.KeyCode == CONFIG.ToggleKey then
		bindValue.Text = "Нельзя: ToggleKey"
		waitingForBind = false
		return
	end
	CONFIG.CollapseKey = input.KeyCode
	bindValue.Text = input.KeyCode.Name
	waitingForBind = false
	saveConfig()
end)

Section(pages[4], "КОНФИГУРАЦИЯ")
configStatusLabel = text({
    Parent = pages[4],
    Size = UDim2.new(1, 0, 0, 36),
    TextSize = 12,
    TextWrapped = true,
    TextColor3 = THEME.SubText,
    Text = type(readfile) == "function" and type(writefile) == "function"
        and "Автосохранение включено · PetDrop_config.json"
        or "Нужны функции readfile и writefile в executor",
})

local saveConfigButton = create("TextButton", {
    Name = "SaveConfigButton",
    LayoutOrder = nextOrder(pages[4]),
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = WHITE,
    BackgroundTransparency = 0.91,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "СОХРАНИТЬ КОНФИГ",
    TextColor3 = THEME.Text,
    TextSize = 13,
    Font = Enum.Font.GothamSemibold,
    Parent = pages[4],
}, { corner(12), stroke(0.82, 1) })

saveConfigButton.Activated:Connect(function()
    local ok, err = saveConfig()
    if ok then
        configStatusLabel.Text = "Конфиг сохранён · PetDrop_config.json"
        tween(saveConfigButton, 0.12, { BackgroundTransparency = 0.82 })
        task.delay(0.25, function()
            if saveConfigButton.Parent then
                tween(saveConfigButton, 0.12, { BackgroundTransparency = 0.91 })
            end
        end)
    else
        configStatusLabel.Text = "Не удалось сохранить: " .. tostring(err)
    end
end)

selectTab(1,true)

-- Перетаскивание окна мышью или пальцем за верхнюю полосу.
-- Полоса не перекрывает вкладки и кнопку закрытия.
local dragHandle = create("Frame", {
	Name = "DragHandle",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -100, 0, 62),
	BackgroundTransparency = 1,
	Active = true,
	ZIndex = 15,
	Parent = window,
})
local dragging = false
local dragStart = nil
local startPosition = nil
local dragInput = nil

dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = window.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

dragHandle.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		 or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and dragInput and input == dragInput and dragStart and startPosition then
		local delta = input.Position - dragStart
		window.Position = UDim2.new(
			startPosition.X.Scale, startPosition.X.Offset + delta.X,
			startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
		)
	end
end)

----------------------------------------------------------------------
-- ОТКРЫТИЕ / ЗАКРЫТИЕ
----------------------------------------------------------------------
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")
local fit = 1 -- масштаб, чтобы окно влезало на маленьких экранах
local isOpen = false
local isCollapsed = false

local blur = nil
if CONFIG.BackgroundBlur then
	blur = create("BlurEffect", { Name = "MenuBlur", Size = 0, Parent = Lighting })
end

local function refit()
	local view = camera.ViewportSize
	fit = math.max(0.3, math.min(1, (view.X - 24) / CONFIG.Size.X, (view.Y - 24) / CONFIG.Size.Y))
	if window.Visible then
		uiScale.Scale = fit
	end
end
refit()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)

collapseMenu = function()
	if not isOpen or isCollapsed then return end
	isCollapsed = true
	window.Visible = false
	miniMenuButton.Visible = true
	-- В свернутом режиме размытие мира полностью выключено.
	if blur then tween(blur, 0.2, { Size = 0 }) end
	tween(miniMenuButton, 0.16, { BackgroundTransparency = 0 })
end

local function expandMenu()
	if not isOpen or not isCollapsed then return end
	isCollapsed = false
	miniMenuButton.Visible = false
	window.Visible = true
	if blur and isOpen then tween(blur, 0.25, { Size = CONFIG.BlurSize }) end
	uiScale.Scale = fit * 0.94
	tween(uiScale, 0.2, { Scale = fit }, Enum.EasingStyle.Quad)
end
-- Мини-кнопка закреплена справа; нажатие открывает основное меню.
miniMenuButton.Activated:Connect(function()
    expandMenu()
end)

setOpen = function(open)
	if open == isOpen then
		if open and isCollapsed then expandMenu() end
		return
	end
	isOpen = open
	isCollapsed = false
	miniMenuButton.Visible = false
	reopenButton.Visible = false

	if open then
		window.Visible = true
		uiScale.Scale = fit * 0.94
		tween(uiScale, 0.22, { Scale = fit }, Enum.EasingStyle.Quad)
	else
		local t = tween(uiScale, 0.14, { Scale = fit * 0.94 })
		t.Completed:Connect(function()
			if not isOpen then window.Visible = false end
		end)
	end

	if blur then
		tween(blur, 0.25, { Size = open and CONFIG.BlurSize or 0 })
	end
end

close.Activated:Connect(function()
	shutdownFeatures()
	if blur then blur:Destroy() end
	gui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == CONFIG.ToggleKey then
		setOpen(not isOpen)
	elseif input.KeyCode == CONFIG.CollapseKey and isOpen then
		if isCollapsed then expandMenu() else collapseMenu() end
	end
end)

gui.Destroying:Connect(function()
    shutdownFeatures()
end)

if CONFIG.StartOpen then
    setOpen(true)
end

print("[PetDrop] Glass Monochrome v1.0 — Clean Labels + Theme Dropdown loaded.")
