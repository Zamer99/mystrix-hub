-- MYSTRIX HUB / GLASS ROSE v1.3
-- Execute this entire file on the client. F4 toggles the window.
-- Add your scripts to SCRIPTS below. No external UI libraries are used.

local SCRIPTS = {
    {
        Id = "petdrop-v1",
        Name = "PetDrop",
        Version = "1.0",
        Category = "Pet Drop",
        Author = "Zamer99",
        Description = "Твой скрипт для Pet Drop. Открывает отдельное меню с разделами Main, Player, Shop и Settings.",
        Url = "https://raw.githubusercontent.com/Zamer99/mystrix-hub/main/PetDrop_v1.0.lua?v=mini3",
        GuiName = "PetDropGlassMonochrome",
        -- Prevent the script from waiting forever for a missing game remote.
        RequiredPaths = { { "ReplicatedStorage", "Remotes", "Request" } },
    },
}

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
assert(player, "[MYSTRIX] Запусти хаб на клиенте.")
local playerGui = player:WaitForChild("PlayerGui")

local function findMenu(entry)
    if not entry.GuiName then return nil end
    local menu = playerGui:FindFirstChild(entry.GuiName)
    if menu and menu:FindFirstChild("Window") and menu:GetAttribute("MystrixReady") ~= false then
        return menu
    end
end

local function openMenu(menu)
    local bridge = menu:FindFirstChild("MystrixOpen")
    if bridge and bridge:IsA("BindableFunction") then
        local ok, opened = pcall(function() return bridge:Invoke() end)
        return ok and opened == true
    end
    -- Compatibility with PetDrop instances started before the v1.2 integration.
    local frame = menu:FindFirstChild("Window")
    if not frame then return false end
    menu.Enabled = true
    frame.Visible = true
    local size = frame:FindFirstChildOfClass("UIScale")
    if size and size.Scale <= 0 then size.Scale = 1 end
    for _, name in ipairs({ "MiniMenu", "ReopenMenu" }) do
        local mini = menu:FindFirstChild(name)
        if mini then mini.Visible = false end
    end
    return true
end

local function state(record, value, message)
    record:SetAttribute("Message", message)
    record.Value = value
end

local function reconcile(entry, record)
    if entry.GuiName and record.Value == "started" and not findMenu(entry) then
        state(record, "idle", "Меню закрыто или отсутствует. Можно запустить снова.")
    elseif findMenu(entry) and (record.Value == "idle" or record.Value == "error" or record.Value == "unconfirmed") then
        state(record, "started", "Меню уже создано. Нажми «Открыть меню».")
    end
end

local function make(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

-- The session survives reopening the hub, so running scripts are not duplicated.
local session = playerGui:FindFirstChild("MystrixHubSession")
if not session then
    session = make("ScreenGui", { Name = "MystrixHubSession", ResetOnSpawn = false }, playerGui)
end
local old = playerGui:FindFirstChild("MystrixHub")
if old then old:Destroy() end

local gui = make("ScreenGui", {
    Name = "MystrixHub", ResetOnSpawn = false, DisplayOrder = 50,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local connections, alive = {}, true
local blur
local launching = false
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
connect(gui.Destroying, function()
    alive = false
    if blur then blur:Destroy(); blur = nil end
    for _, connection in ipairs(connections) do connection:Disconnect() end
end)

local C = {
    Background = Color3.fromRGB(28, 28, 32), Panel = Color3.fromRGB(25, 25, 28),
    Card = Color3.fromRGB(65, 62, 68), Line = Color3.fromRGB(106, 73, 96),
    White = Color3.fromRGB(249, 248, 253), Muted = Color3.fromRGB(174, 171, 183),
    Accent = Color3.fromRGB(255, 105, 180), Selected = Color3.fromRGB(102, 70, 91),
}
local function round(object, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, object)
end
local function outline(object, color)
    return make("UIStroke", { Color = color or C.Line, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, object)
end
local function label(parent, text, x, y, w, h, size, color)
    return make("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), Text = text, TextSize = size or 14,
        TextColor3 = color or C.White, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end
local function button(parent, text, x, y, w, h, primary)
    local b = make("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = primary and C.Selected or C.Card, BorderSizePixel = 0,
        Text = text, TextSize = 13, Font = Enum.Font.GothamMedium,
        TextColor3 = C.White, AutoButtonColor = false,
    }, parent)
    round(b, 14)
    connect(b.MouseEnter, function()
        local idle = b:GetAttribute("IdleTransparency") or 0
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = idle >= 0.9 and 0.88 or math.min(1, idle + 0.1) }):Play()
    end)
    connect(b.MouseLeave, function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = b:GetAttribute("IdleTransparency") or 0 }):Play()
    end)
    return b
end

local window = make("Frame", {
    Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(760, 460), BackgroundColor3 = C.Background, BorderSizePixel = 0,
    BackgroundTransparency = 0.09,
    ClipsDescendants = true,
}, gui)
round(window, 28)
outline(window, C.Accent).Transparency = 0.32
make("UIGradient", { Rotation = 120,
    Color = ColorSequence.new(Color3.fromRGB(210, 210, 215), Color3.fromRGB(255, 255, 255)),
}, window)
local scale = make("UIScale", { Scale = 1 }, window)
blur = make("BlurEffect", { Name = "MystrixHubBlur", Size = 12 }, Lighting)

local sidebar = make("Frame", {
    Size = UDim2.new(0, 208, 1, 0), BackgroundColor3 = C.Panel, BorderSizePixel = 0,
    BackgroundTransparency = 0.22,
}, window)
round(sidebar, 28)
make("Frame", { Position = UDim2.fromOffset(180, 0), Size = UDim2.new(0, 28, 1, 0),
    BackgroundColor3 = C.Panel, BackgroundTransparency = 0.22, BorderSizePixel = 0 }, sidebar)
make("Frame", { Position = UDim2.fromOffset(207, 0), Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = C.White, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, sidebar)
local logo = label(sidebar, "●", 32, 23, 24, 32, 20)
logo.Font = Enum.Font.GothamBold
label(sidebar, "MYSTRIX HUB", 70, 20, 130, 26, 16).Font = Enum.Font.GothamBold
label(sidebar, "v 1.3", 70, 46, 120, 16, 10, C.Muted)
local libraryTab = button(sidebar, "    Скрипты", 14, 82, 182, 46, true)
local favoriteTab = button(sidebar, "    Избранное", 14, 130, 182, 46)
local aboutTab = button(sidebar, "    О хабе", 14, 178, 182, 46)
for _, tab in ipairs({ libraryTab, favoriteTab, aboutTab }) do
    tab.TextXAlignment = Enum.TextXAlignment.Left
end
make("Frame", { Position = UDim2.fromOffset(18, 380), Size = UDim2.fromOffset(172, 1),
    BackgroundColor3 = C.White, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, sidebar)
local avatar = make("ImageLabel", { Position = UDim2.fromOffset(22, 397),
    Size = UDim2.fromOffset(42, 42), BackgroundColor3 = C.Card, BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150",
}, sidebar)
round(avatar, 21)
outline(avatar, C.Accent).Transparency = 0.45
label(sidebar, player.DisplayName, 74, 398, 124, 21, 13)
label(sidebar, "● ONLINE  /  F4", 74, 422, 124, 14, 9, C.Muted)

local content = make("Frame", {
    Position = UDim2.fromOffset(230, 0), Size = UDim2.fromOffset(508, 460),
    BackgroundTransparency = 1,
}, window)
local sectionMark = make("Frame", { Position = UDim2.fromOffset(0, 31), Size = UDim2.fromOffset(4, 18),
    BackgroundColor3 = C.White, BorderSizePixel = 0 }, content)
round(sectionMark, 2)
label(content, "КОЛЛЕКЦИЯ СКРИПТОВ", 14, 25, 390, 30, 14)
local minimize = button(content, "—", 442, 14, 32, 32)
local close = button(content, "×", 482, 14, 32, 32)
round(minimize, 10); round(close, 10)
outline(minimize); outline(close)

local search = make("TextBox", {
    Position = UDim2.fromOffset(0, 66), Size = UDim2.fromOffset(508, 36),
    BackgroundColor3 = C.Card, BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "",
    PlaceholderText = "Поиск по названию или игре...", ClearTextOnFocus = false,
    TextColor3 = C.White, PlaceholderColor3 = C.Muted, Font = Enum.Font.Gotham,
    TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
}, content)
round(search, 10)
outline(search)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, search)

local list = make("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 116), Size = UDim2.fromOffset(508, 146),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.Muted, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, content)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2),
    PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 2) }, list)
local empty = label(content, "Здесь пока нет скриптов.", 14, 146, 480, 54, 13, C.Muted)
empty.Visible = false

local detail = make("Frame", {
    Position = UDim2.fromOffset(0, 276), Size = UDim2.fromOffset(508, 112),
    BackgroundColor3 = C.Card, BackgroundTransparency = 0.48, BorderSizePixel = 0,
}, content)
round(detail, 12)
outline(detail)
local detailName = label(detail, "", 16, 10, 470, 23, 15)
detailName.Font = Enum.Font.GothamMedium
local description = label(detail, "", 16, 39, 476, 38, 12, C.Muted)
description.TextWrapped = true
description.TextTruncate = Enum.TextTruncate.None
description.TextYAlignment = Enum.TextYAlignment.Top
local metadata = label(detail, "", 16, 87, 476, 16, 10, C.Muted)
local status = label(content, "", 0, 404, 310, 40, 11, C.Muted)
status.TextWrapped = true
status.TextTruncate = Enum.TextTruncate.None
local launch = button(content, "ЗАПУСТИТЬ  →", 326, 404, 182, 40, true)
outline(launch, C.Accent).Transparency = 0.35

local about = make("Frame", {
    Position = UDim2.fromOffset(0, 66), Size = UDim2.fromOffset(508, 322),
    BackgroundColor3 = C.Card, BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false,
}, content)
round(about, 12)
label(about, "MYSTRIX / GLASS ROSE", 22, 22, 464, 30, 18)
local aboutText = label(about,
    "Выбери скрипт в коллекции и нажми «Запустить».\n\n★ добавляет скрипт в избранное на время сессии.\nF4 или кнопка M / возвращает свёрнутое окно.\nПеретаскивай окно за верхнюю полосу.\n\nЗакрытие хаба не останавливает уже запущенные скрипты. Их функции выключаются в собственном меню.\n\nНовые скрипты добавляются в таблицу SCRIPTS в начале файла.",
    22, 66, 464, 232, 13, C.Muted)
aboutText.TextWrapped = true
aboutText.TextTruncate = Enum.TextTruncate.None
aboutText.TextYAlignment = Enum.TextYAlignment.Top

local reopen = button(gui, "M /", 16, 160, 56, 48, true)
reopen.Visible = false
local function setOpen(open)
    if launching or not alive then return end
    window.Visible = open
    reopen.Visible = not open
    if blur then blur.Size = open and 12 or 0 end
end
connect(minimize.Activated, function() setOpen(false) end)
connect(reopen.Activated, function() setOpen(true) end)
connect(close.Activated, function() gui:Destroy() end)
connect(Input.InputBegan, function(input, processed)
    if not processed and not Input:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.F4 then
        setOpen(not window.Visible)
    end
end)

local selected = SCRIPTS[1]
local activeTab, rows, records = "all", {}, {}
local messages = {
    idle = "Готов к запуску", fetching = "Загрузка с GitHub…", executing = "Скрипт запускается…",
    started = "Меню уже создано. Нажми «Открыть меню».",
    completed = "Код выполнен; у этого скрипта нет проверки меню.",
    unconfirmed = "Код завершился, но меню не появилось. Можно повторить запуск.",
    partial = "Ошибка внутри скрипта. Повтор отключён: часть кода могла выполниться.",
}
local function refreshDetails()
    if not alive then return end
    if not selected then
        detailName.Text, description.Text, metadata.Text = "Нет скриптов", "Добавь запись в таблицу SCRIPTS.", ""
        launch.Text, launch.Active = "НЕТ СКРИПТОВ", false
        return
    end
    local record = records[selected.Id]
    detailName.Text = selected.Name .. " / v" .. selected.Version
    description.Text = selected.Description
    metadata.Text = selected.Category .. "   /   @" .. selected.Author .. "   /   GitHub"
    status.Text = record:GetAttribute("Message") or messages[record.Value] or messages.idle
    local canOpen = record.Value == "started" and findMenu(selected) ~= nil
    local canRun = record.Value == "idle" or record.Value == "error" or record.Value == "unconfirmed" or canOpen
    launch.Active = canRun
    launch.Text = canOpen and "ОТКРЫТЬ МЕНЮ  →" or (canRun and "ЗАПУСТИТЬ  →" or "НЕДОСТУПНО")
    launch.BackgroundTransparency = canRun and 0 or 0.35
    launch:SetAttribute("IdleTransparency", canRun and 0 or 0.35)
    for id, row in pairs(rows) do
        row.Stroke.Color = id == selected.Id and C.Accent or C.Line
        row.Stroke.Transparency = id == selected.Id and 0.4 or 0.7
    end
end
local function filter()
    local query = string.lower(search.Text):match("^%s*(.-)%s*$")
    local visible = 0
    for _, entry in ipairs(SCRIPTS) do
        local row = rows[entry.Id]
        local matches = string.find(string.lower(entry.Name .. " " .. entry.Category), query, 1, true) ~= nil
        row.Button.Visible = matches and (activeTab ~= "favorites" or records[entry.Id]:GetAttribute("Favorite") == true)
        if row.Button.Visible then visible = visible + 1 end
    end
    empty.Text = query ~= "" and "Ничего не найдено. Попробуй другой запрос." or "Пока пусто. Добавь скрипт кнопкой ☆."
    empty.Visible = visible == 0 and activeTab ~= "about"
end
for index, entry in ipairs(SCRIPTS) do
    assert(not records[entry.Id], "[MYSTRIX] Duplicate script Id: " .. entry.Id)
    local record = session:FindFirstChild(entry.Id)
    if not record then
        record = make("StringValue", { Name = entry.Id, Value = "idle" }, session)
    end
    records[entry.Id] = record
    reconcile(entry, record)
    local card = button(list, "", 0, 0, 500, 52)
    card.Size = UDim2.new(1, 0, 0, 52)
    card.LayoutOrder = index
    local border = outline(card)
    label(card, entry.Name, 16, 6, 420, 23, 14).Font = Enum.Font.GothamMedium
    label(card, entry.Category .. "   /   v" .. entry.Version, 16, 30, 420, 16, 10, C.Muted)
    local star = button(card, record:GetAttribute("Favorite") and "★" or "☆", 448, 8, 38, 36)
    star.TextColor3 = C.Accent
    rows[entry.Id] = { Button = card, Stroke = border }
    connect(card.Activated, function() selected = entry; refreshDetails() end)
    connect(star.Activated, function()
        local favorite = not record:GetAttribute("Favorite")
        record:SetAttribute("Favorite", favorite)
        star.Text = favorite and "★" or "☆"
        filter()
    end)
    connect(record.Changed, refreshDetails)
    connect(record:GetAttributeChangedSignal("Message"), refreshDetails)
    connect(playerGui.ChildRemoved, function(child)
        if child.Name == entry.GuiName then
            reconcile(entry, record)
            refreshDetails()
        end
    end)
end
local function selectTab(tab)
    activeTab = tab
    about.Visible = tab == "about"
    for _, object in ipairs({ search, list, detail, launch, status }) do object.Visible = tab ~= "about" end
    for _, item in ipairs({ { libraryTab, "all" }, { favoriteTab, "favorites" }, { aboutTab, "about" } }) do
        local active = item[2] == tab
        item[1].BackgroundColor3 = active and C.Selected or C.Panel
        item[1].BackgroundTransparency = active and 0.12 or 1
        item[1]:SetAttribute("IdleTransparency", active and 0.12 or 1)
        item[1].TextColor3 = active and C.White or C.Accent
    end
    filter()
end
connect(libraryTab.Activated, function() selectTab("all") end)
connect(favoriteTab.Activated, function() selectTab("favorites") end)
connect(aboutTab.Activated, function() selectTab("about") end)
connect(search:GetPropertyChangedSignal("Text"), filter)

local function restoreHub()
    if alive then
        launching = false
        gui.Enabled = true
        setOpen(true)
    end
end
connect(launch.Activated, function()
    if not selected then return end
    local entry = selected
    local record = records[entry.Id]
    reconcile(entry, record)
    local existing = findMenu(entry)
    if existing and record.Value == "started" then
        if openMenu(existing) then
            gui:Destroy()
        else
            record:SetAttribute("Message", "Не удалось открыть меню. Попробуй RightShift в PetDrop.")
        end
        return
    end
    if record.Value ~= "idle" and record.Value ~= "error" and record.Value ~= "unconfirmed" then return end
    if type(loadstring) ~= "function" then
        state(record, "error", "Среда не поддерживает loadstring. Доступен только интерфейс.")
        return
    end
    for _, path in ipairs(entry.RequiredPaths or {}) do
        local object = game:GetService(path[1])
        for i = 2, #path do object = object and object:FindFirstChild(path[i]) end
        if not object then
            state(record, "error", "Не найдены объекты игры. Открой " .. entry.Category .. " и дождись загрузки.")
            return
        end
    end
    state(record, "fetching")
    local attempt = (record:GetAttribute("Attempt") or 0) + 1
    record:SetAttribute("Attempt", attempt)
    local expired = false
    task.delay(20, function()
        if record.Parent and record.Value == "fetching" and record:GetAttribute("Attempt") == attempt then
            expired = true
            state(record, "error", "GitHub не ответил за 20 секунд. Можно повторить.")
        end
    end)
    task.spawn(function()
        local ok, source = pcall(function() return game:HttpGet(entry.Url) end)
        if expired or not record.Parent or record:GetAttribute("Attempt") ~= attempt then return end
        if not ok or type(source) ~= "string" or source == "" then
            state(record, "error", "Не удалось загрузить файл с GitHub. Можно повторить.")
            warn("[MYSTRIX] Download failed: " .. tostring(source))
            return
        end
        local compiled, chunk, compileError = pcall(loadstring, source, "@" .. entry.Name)
        if not compiled or type(chunk) ~= "function" then
            state(record, "error", "Ошибка компиляции. Подробности в консоли F9.")
            warn("[MYSTRIX] " .. tostring(compileError or chunk))
            return
        end
        state(record, "executing")
        -- Hide the whole hub (including its mini-button and blur) before invoking
        -- the downloaded script: its main function may yield indefinitely.
        if alive then
            launching = true
            gui.Enabled = false
            if blur then blur.Size = 0 end
        end
        task.delay(15, function()
            if record.Parent and record.Value == "executing" then
                record:SetAttribute("Message", "Скрипт ещё выполняется. Проверь его меню; повторный запуск заблокирован.")
                restoreHub()
            end
        end)
        local ran, runtimeError = pcall(chunk)
        if ran then
            local menu = findMenu(entry)
            if entry.GuiName then
                -- A successful pcall only means the chunk returned, not that a UI exists.
                for _ = 1, 50 do
                    if menu then break end
                    task.wait(0.1)
                    menu = findMenu(entry)
                end
                if menu and openMenu(menu) then
                    state(record, "started")
                    if alive then gui:Destroy() end
                else
                    state(record, "unconfirmed")
                    restoreHub()
                end
            else
                state(record, "completed")
                if alive then gui:Destroy() end
            end
        else
            state(record, "partial")
            restoreHub()
            warn("[MYSTRIX] " .. tostring(runtimeError))
        end
    end)
end)

-- Clamp the whole window to the usable GUI area, including after screen rotation.
local surface = make("Frame", {
    Name = "ViewportMeasure", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Active = false,
}, gui)
local function bounds(position)
    local size = surface.AbsoluteSize
    local half = Vector2.new(760, 460) * scale.Scale / 2
    return Vector2.new(
        math.clamp(position.X, half.X, math.max(half.X, size.X - half.X)),
        math.clamp(position.Y, half.Y, math.max(half.Y, size.Y - half.Y))
    )
end
local moved = false
local function fit()
    local size = surface.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return end
    scale.Scale = math.min(1, math.max(0.01, (size.X - 16) / 760), math.max(0.01, (size.Y - 16) / 460))
    if moved then
        local p = bounds(Vector2.new(window.Position.X.Offset, window.Position.Y.Offset))
        window.Position = UDim2.fromOffset(p.X, p.Y)
    end
    reopen.Position = UDim2.fromOffset(8, math.max(0, math.min(160, size.Y - 56)))
end
connect(surface:GetPropertyChangedSignal("AbsoluteSize"), fit)
local dragHandle = make("Frame", {
    Size = UDim2.new(1, -118, 0, 60), BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, window)
local drag, dragStart, origin
connect(dragHandle.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    drag, dragStart = input, input.Position
    local size = surface.AbsoluteSize
    origin = Vector2.new(window.Position.X.Scale * size.X + window.Position.X.Offset,
        window.Position.Y.Scale * size.Y + window.Position.Y.Offset)
end)
connect(Input.InputChanged, function(input)
    if not drag then return end
    local mouse = drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
    if not mouse and input ~= drag then return end
    local delta = input.Position - dragStart
    local p = bounds(origin + Vector2.new(delta.X, delta.Y))
    moved = true
    window.Position = UDim2.fromOffset(p.X, p.Y)
end)
connect(Input.InputEnded, function(input)
    if input == drag then drag = nil end
end)
connect(Input.WindowFocusReleased, function() drag = nil end)
fit()
refreshDetails()
selectTab("all")
print("[MYSTRIX] Glass Rose v1.3 loaded. F4 to toggle.")
