-- LibDBIcon-1.0
-- Minimal implementation of LibDBIcon for minimap button management.
-- Full version: https://www.curseforge.com/wow/addons/libdbicon-1-0
-- License: Public Domain

local MAJOR, MINOR = "LibDBIcon-1.0", 47
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or {}
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}

local minimapButtons = {}

--- Calculates minimap button position from an angle.
-- @param angle number Angle in degrees
-- @return number, number x, y offsets
local function getPosition(angle)
    local radius = 80
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    return x, y
end

--- Creates a minimap button for a data object.
-- @param name string The data object name
-- @param dataobj table The LibDataBroker data object
-- @param db table SavedVariables table for position persistence
local function createButton(name, dataobj, db)
    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(32, 32)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight

    -- Button overlay border
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetTexture(136430) -- Interface\\Minimap\\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT")

    -- Icon texture
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture(dataobj.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetPoint("CENTER")
    button.icon = icon

    -- Position
    db.minimapPos = db.minimapPos or 220
    local x, y = getPosition(db.minimapPos)
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)

    -- Drag to reposition
    local isDragging = false
    button:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            db.minimapPos = angle
            local nx, ny = getPosition(angle)
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", nx, ny)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- Click handler
    button:SetScript("OnClick", function(self, btn)
        if dataobj.OnClick then
            dataobj.OnClick(self, btn)
        end
    end)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        if dataobj.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            dataobj.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Visibility
    if db.hide then
        button:Hide()
    else
        button:Show()
    end

    minimapButtons[name] = button
    return button
end

--- Registers a data object for minimap button display.
-- @param name string The data object name
-- @param dataobj table The LibDataBroker data object
-- @param db table SavedVariables table for button state
function lib:Register(name, dataobj, db)
    if not db then db = {} end
    lib.objects[name] = {dataobj = dataobj, db = db}

    -- Create the button immediately if Minimap exists
    if Minimap then
        createButton(name, dataobj, db)
    else
        lib.notCreated[name] = true
    end
end

--- Shows a previously hidden minimap button.
-- @param name string The data object name
function lib:Show(name)
    local obj = lib.objects[name]
    if obj then
        obj.db.hide = false
        if minimapButtons[name] then
            minimapButtons[name]:Show()
        end
    end
end

--- Hides a minimap button.
-- @param name string The data object name
function lib:Hide(name)
    local obj = lib.objects[name]
    if obj then
        obj.db.hide = true
        if minimapButtons[name] then
            minimapButtons[name]:Hide()
        end
    end
end

--- Returns the minimap button frame.
-- @param name string The data object name
-- @return Frame|nil The button frame
function lib:GetMinimapButton(name)
    return minimapButtons[name]
end
