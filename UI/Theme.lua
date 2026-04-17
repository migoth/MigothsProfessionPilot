-- Theme.lua
-- Modern UI theme system for MigothsProfessionPilot.
-- Provides reusable styled components: windows, buttons, tabs, progress bars, etc.
-- No Blizzard standard templates - flat, dark, modern design.

local ADDON_NAME, PP = ...

PP.Theme = {}
local T = PP.Theme

------------------------------------------------------------------------
-- Color palette
------------------------------------------------------------------------
T.palette = {
    -- Backgrounds
    bg          = { 0.04, 0.04, 0.06, 0.97 },
    surface     = { 0.07, 0.07, 0.10, 0.95 },
    surfaceAlt  = { 0.09, 0.09, 0.13, 0.95 },
    card        = { 0.10, 0.10, 0.14, 0.90 },
    hover       = { 0.14, 0.14, 0.20, 0.95 },

    -- Borders
    border      = { 0.18, 0.18, 0.25, 0.70 },
    borderLight = { 0.25, 0.25, 0.35, 0.50 },

    -- Accent (cyan-blue)
    accent      = { 0.00, 0.67, 1.00, 1.00 },
    accentDim   = { 0.00, 0.45, 0.70, 0.80 },
    accentGlow  = { 0.00, 0.67, 1.00, 0.15 },

    -- Text
    textBright  = { 1.00, 1.00, 1.00, 1.00 },
    textPrimary = { 0.88, 0.88, 0.92, 1.00 },
    textSecondary = { 0.55, 0.55, 0.65, 1.00 },
    textMuted   = { 0.35, 0.35, 0.42, 1.00 },

    -- Status
    success     = { 0.30, 0.85, 0.45, 1.00 },
    warning     = { 1.00, 0.70, 0.20, 1.00 },
    danger      = { 1.00, 0.30, 0.35, 1.00 },

    -- Difficulty
    diffOrange  = { 1.00, 0.50, 0.25, 1.00 },
    diffYellow  = { 1.00, 0.90, 0.20, 1.00 },
    diffGreen   = { 0.30, 0.80, 0.35, 1.00 },
    diffGray    = { 0.45, 0.45, 0.50, 1.00 },

    -- Rows
    rowEven     = { 0.08, 0.08, 0.11, 0.50 },
    rowOdd      = { 0.06, 0.06, 0.08, 0.30 },
    rowHover    = { 0.15, 0.15, 0.22, 0.70 },

    -- Buttons
    btnNormal   = { 0.12, 0.12, 0.18, 0.90 },
    btnHover    = { 0.18, 0.18, 0.25, 0.95 },
    btnAccent   = { 0.00, 0.50, 0.75, 0.90 },
    btnAccentHover = { 0.00, 0.60, 0.85, 0.95 },
    btnDisabled = { 0.08, 0.08, 0.10, 0.60 },

    -- Tab
    tabActive   = { 0.00, 0.55, 0.80, 0.25 },
    tabInactive = { 0.08, 0.08, 0.12, 0.60 },
    tabHover    = { 0.12, 0.12, 0.18, 0.80 },

    -- Progress bars
    barBg       = { 0.06, 0.06, 0.08, 0.90 },
    barFill     = { 0.00, 0.60, 0.90, 0.90 },
    barMaxed    = { 0.25, 0.75, 0.40, 0.90 },
    barIncomplete = { 0.85, 0.55, 0.10, 0.90 },
}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

--- Unpacks a color table for use with SetColorTexture, SetTextColor, etc.
local function C(colorTable)
    return unpack(colorTable)
end
T.C = C

--- Sets a texture to a palette color.
local function ApplyColor(texture, colorTable)
    texture:SetColorTexture(C(colorTable))
end

------------------------------------------------------------------------
-- Window (standalone + floating panel)
------------------------------------------------------------------------

--- Creates a modern frameless window.
-- @param name string|nil Global frame name
-- @param width number
-- @param height number
-- @param parent Frame|nil Parent frame (default UIParent)
-- @return Frame
function T:CreateWindow(name, width, height, parent)
    local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Dark background with thin border
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(C(T.palette.bg))
    f:SetBackdropBorderColor(C(T.palette.border))

    -- Subtle shadow (layered larger frame behind)
    local shadow = CreateFrame("Frame", nil, f, "BackdropTemplate")
    shadow:SetPoint("TOPLEFT", -3, 3)
    shadow:SetPoint("BOTTOMRIGHT", 3, -3)
    shadow:SetFrameLevel(f:GetFrameLevel() - 1)
    shadow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    shadow:SetBackdropColor(0, 0, 0, 0.5)
    shadow:SetBackdropBorderColor(0, 0, 0, 0.4)

    return f
end

------------------------------------------------------------------------
-- Title bar
------------------------------------------------------------------------

--- Creates a modern title bar inside a window.
-- @param parent Frame The window frame
-- @param titleText string
-- @return Frame The title bar frame
-- @return FontString The title text object
function T:CreateTitleBar(parent, titleText)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(36)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    ApplyColor(bar.bg, T.palette.surface)

    -- Accent line at bottom of title bar
    bar.accent = bar:CreateTexture(nil, "ARTWORK")
    bar.accent:SetHeight(1)
    bar.accent:SetPoint("BOTTOMLEFT")
    bar.accent:SetPoint("BOTTOMRIGHT")
    ApplyColor(bar.accent, T.palette.accentDim)

    -- Title text
    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(titleText)
    title:SetTextColor(C(T.palette.accent))

    -- Version badge
    local ver = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
    ver:SetText("v" .. PP.VERSION)
    ver:SetTextColor(C(T.palette.textMuted))

    return bar, title
end

------------------------------------------------------------------------
-- Close button
------------------------------------------------------------------------

--- Creates a modern flat close button.
-- @param parent Frame The title bar or window
-- @param onClick function
-- @return Button
function T:CreateCloseButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(28, 28)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText("x")
    btn.text:SetTextColor(C(T.palette.textSecondary))

    btn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(C(T.palette.danger))
    end)
    btn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(C(T.palette.textSecondary))
    end)
    btn:SetScript("OnClick", onClick)

    return btn
end

------------------------------------------------------------------------
-- Tab bar
------------------------------------------------------------------------

--- Creates a modern tab bar with pill-style buttons.
-- @param parent Frame
-- @param tabs table Array of {id=string, label=string}
-- @param onTabChanged function(tabID)
-- @return Frame tabBar
-- @return table tabButtons (keyed by id)
function T:CreateTabBar(parent, tabs, onTabChanged)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(30)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    ApplyColor(bar.bg, T.palette.surface)

    local buttons = {}
    local barWidth = parent:GetWidth() - 2  -- account for window border
    local tabWidth = math.floor(barWidth / #tabs)
    local padding = 3

    for i, tabDef in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetSize(tabWidth - padding * 2, 24)
        btn:SetPoint("LEFT", (i - 1) * tabWidth + padding, 0)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        ApplyColor(btn.bg, T.palette.tabInactive)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabDef.label)
        btn.text:SetTextColor(C(T.palette.textSecondary))

        -- Active indicator line at top
        btn.indicator = btn:CreateTexture(nil, "OVERLAY")
        btn.indicator:SetHeight(2)
        btn.indicator:SetPoint("TOPLEFT")
        btn.indicator:SetPoint("TOPRIGHT")
        ApplyColor(btn.indicator, T.palette.accent)
        btn.indicator:Hide()

        btn:SetScript("OnClick", function()
            onTabChanged(tabDef.id)
        end)
        btn:SetScript("OnEnter", function(self)
            if not self._active then
                ApplyColor(self.bg, T.palette.tabHover)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self._active then
                ApplyColor(self.bg, T.palette.tabInactive)
            end
        end)

        btn._active = false
        buttons[tabDef.id] = btn
    end

    return bar, buttons
end

--- Updates tab button states.
-- @param buttons table Tab buttons keyed by id
-- @param activeID string The active tab id
function T:SetActiveTab(buttons, activeID)
    for id, btn in pairs(buttons) do
        if id == activeID then
            btn._active = true
            ApplyColor(btn.bg, T.palette.tabActive)
            btn.text:SetTextColor(C(T.palette.accent))
            btn.indicator:Show()
        else
            btn._active = false
            ApplyColor(btn.bg, T.palette.tabInactive)
            btn.text:SetTextColor(C(T.palette.textSecondary))
            btn.indicator:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Flat button
------------------------------------------------------------------------

--- Creates a modern flat button.
-- @param parent Frame
-- @param text string
-- @param width number
-- @param height number
-- @param accent boolean|nil Use accent color
-- @return Button
function T:CreateButton(parent, text, width, height, accent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height or 24)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()

    local normalColor = accent and T.palette.btnAccent or T.palette.btnNormal
    local hoverColor = accent and T.palette.btnAccentHover or T.palette.btnHover
    ApplyColor(btn.bg, normalColor)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(C(accent and T.palette.textBright or T.palette.textPrimary))

    btn._normalColor = normalColor
    btn._hoverColor = hoverColor
    btn._enabled = true

    btn:SetScript("OnEnter", function(self)
        if self._enabled then
            ApplyColor(self.bg, self._hoverColor)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self._enabled then
            ApplyColor(self.bg, self._normalColor)
        end
    end)

    --- Disable/enable override
    function btn:SetEnabled(enabled)
        self._enabled = enabled
        if enabled then
            ApplyColor(self.bg, self._normalColor)
            self.text:SetTextColor(C(accent and T.palette.textBright or T.palette.textPrimary))
        else
            ApplyColor(self.bg, T.palette.btnDisabled)
            self.text:SetTextColor(C(T.palette.textMuted))
        end
        if enabled then self:Enable() else self:Disable() end
    end

    return btn
end

------------------------------------------------------------------------
-- Progress bar
------------------------------------------------------------------------

--- Creates a modern thin progress bar.
-- @param parent Frame
-- @param width number
-- @param height number (default 10)
-- @return Frame bar with :SetProgress(current, max) and :SetBarColor(r,g,b,a)
function T:CreateProgressBar(parent, width, height)
    height = height or 10

    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(width, height)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bar:SetBackdropColor(C(T.palette.barBg))
    bar:SetBackdropBorderColor(C(T.palette.border))

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("LEFT", 1, 0)
    bar.fill:SetHeight(height - 2)
    ApplyColor(bar.fill, T.palette.barFill)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.text:SetPoint("CENTER")
    bar.text:SetTextColor(C(T.palette.textPrimary))

    function bar:SetProgress(current, max)
        local pct = (max > 0) and (current / max) or 0
        pct = math.min(1, math.max(0, pct))
        self.fill:SetWidth(math.max(1, (self:GetWidth() - 2) * pct))
    end

    function bar:SetBarColor(r, g, b, a)
        self.fill:SetColorTexture(r, g, b, a or 1)
    end

    return bar
end

------------------------------------------------------------------------
-- Scroll area
------------------------------------------------------------------------

--- Creates a modern scroll area with minimal scrollbar.
-- @param parent Frame
-- @return ScrollFrame, Frame scrollChild
function T:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetAllPoints()

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or parent:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Thin scrollbar track
    local track = CreateFrame("Frame", nil, scrollFrame)
    track:SetWidth(4)
    track:SetPoint("TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", 0, 0)
    track.bg = track:CreateTexture(nil, "BACKGROUND")
    track.bg:SetAllPoints()
    ApplyColor(track.bg, T.palette.surface)

    -- Thumb
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(4)
    thumb:SetPoint("TOP")
    thumb:SetHeight(30)
    thumb.bg = thumb:CreateTexture(nil, "ARTWORK")
    thumb.bg:SetAllPoints()
    ApplyColor(thumb.bg, T.palette.borderLight)
    scrollFrame._thumb = thumb
    scrollFrame._track = track

    -- Mouse wheel scrolling
    local scrollAmount = 30
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(0, scrollChild:GetHeight() - self:GetHeight())
        local newScroll = math.max(0, math.min(maxScroll, current - delta * scrollAmount))
        self:SetVerticalScroll(newScroll)
    end)

    -- Update thumb position on scroll change
    scrollFrame:SetScript("OnScrollRangeChanged", function(self, xRange, yRange)
        local maxScroll = yRange or 0
        if maxScroll <= 0 then
            thumb:Hide()
        else
            thumb:Show()
            local trackH = track:GetHeight()
            local thumbH = math.max(20, trackH * (self:GetHeight() / scrollChild:GetHeight()))
            thumb:SetHeight(thumbH)
        end
    end)

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        local maxScroll = scrollChild:GetHeight() - self:GetHeight()
        if maxScroll > 0 then
            local trackH = track:GetHeight()
            local thumbH = thumb:GetHeight()
            local ratio = offset / maxScroll
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, -ratio * (trackH - thumbH))
        end
    end)

    return scrollFrame, scrollChild
end

------------------------------------------------------------------------
-- Row (for lists)
------------------------------------------------------------------------

--- Creates an alternating-color row frame.
-- @param parent Frame scrollChild
-- @param yOffset number
-- @param height number
-- @param index number Row index (for alternating color)
-- @return Frame row
function T:CreateRow(parent, yOffset, height, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), height)
    row:SetPoint("TOPLEFT", 0, -yOffset)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    local baseColor = (index % 2 == 0) and T.palette.rowEven or T.palette.rowOdd
    ApplyColor(row.bg, baseColor)
    row._baseColor = baseColor

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        ApplyColor(self.bg, T.palette.rowHover)
    end)
    row:SetScript("OnLeave", function(self)
        ApplyColor(self.bg, self._baseColor)
    end)

    return row
end

------------------------------------------------------------------------
-- Section header (for grouping items in lists)
------------------------------------------------------------------------

--- Creates a section header bar.
-- @param parent Frame scrollChild
-- @param yOffset number
-- @param text string
-- @return number new yOffset
function T:CreateSectionHeader(parent, yOffset, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(parent:GetWidth(), 28)
    header:SetPoint("TOPLEFT", 0, -yOffset)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    ApplyColor(header.bg, T.palette.card)

    -- Accent bar on left edge
    header.accentBar = header:CreateTexture(nil, "ARTWORK")
    header.accentBar:SetSize(3, 28)
    header.accentBar:SetPoint("LEFT")
    ApplyColor(header.accentBar, T.palette.accent)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 12, 0)
    label:SetText(text)
    label:SetTextColor(C(T.palette.textPrimary))

    return yOffset + 30
end

------------------------------------------------------------------------
-- Separator line
------------------------------------------------------------------------

--- Creates a thin horizontal separator.
-- @param parent Frame
-- @param yOffset number
-- @return number new yOffset
function T:CreateSeparator(parent, yOffset)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -yOffset)
    line:SetPoint("TOPRIGHT", 0, -yOffset)
    ApplyColor(line, T.palette.border)
    return yOffset + 1
end

------------------------------------------------------------------------
-- Checkbox (modern toggle style)
------------------------------------------------------------------------

--- Creates a modern styled checkbox.
-- @param parent Frame
-- @param label string
-- @param desc string|nil Description text
-- @param checked boolean Initial state
-- @param onChange function(checked)
-- @param yOffset number Vertical position
-- @return number new yOffset
function T:CreateCheckbox(parent, label, desc, checked, onChange, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), desc and 40 or 24)
    row:SetPoint("TOPLEFT", 0, -yOffset)

    -- Toggle track
    local track = CreateFrame("Button", nil, row)
    track:SetSize(32, 16)
    track:SetPoint("LEFT", 12, desc and 4 or 0)

    track.bg = track:CreateTexture(nil, "BACKGROUND")
    track.bg:SetAllPoints()

    -- Toggle knob
    track.knob = track:CreateTexture(nil, "ARTWORK")
    track.knob:SetSize(12, 12)

    local function UpdateVisual(isChecked)
        if isChecked then
            ApplyColor(track.bg, T.palette.accent)
            track.knob:ClearAllPoints()
            track.knob:SetPoint("RIGHT", -2, 0)
            track.knob:SetColorTexture(1, 1, 1, 0.95)
        else
            ApplyColor(track.bg, T.palette.btnNormal)
            track.knob:ClearAllPoints()
            track.knob:SetPoint("LEFT", 2, 0)
            track.knob:SetColorTexture(0.6, 0.6, 0.6, 0.8)
        end
    end

    local state = checked
    UpdateVisual(state)

    track:SetScript("OnClick", function()
        state = not state
        UpdateVisual(state)
        if onChange then onChange(state) end
    end)

    -- Label
    local labelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", track, "RIGHT", 8, 0)
    labelText:SetText(label)
    labelText:SetTextColor(C(T.palette.textPrimary))

    -- Description
    if desc then
        local descText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -2)
        descText:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
        descText:SetText(desc)
        descText:SetTextColor(C(T.palette.textSecondary))
        descText:SetJustifyH("LEFT")
    end

    return yOffset + (desc and 46 or 28)
end

------------------------------------------------------------------------
-- Utility: clear scroll child
------------------------------------------------------------------------

--- Removes all children from a scroll child frame.
-- @param scrollChild Frame
function T:ClearScrollChild(scrollChild)
    for _, child in pairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    -- Also clear any font strings attached directly
    for _, region in pairs({scrollChild:GetRegions()}) do
        if region.SetText then
            region:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Utility: empty state message
------------------------------------------------------------------------

--- Shows a centered empty-state message.
-- @param scrollChild Frame
-- @param text string Main message
-- @param hint string|nil Secondary hint
function T:ShowEmptyState(scrollChild, text, hint)
    local msg = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("CENTER", 0, hint and 10 or 0)
    msg:SetText(text)
    msg:SetTextColor(C(T.palette.textSecondary))
    msg:SetWidth(scrollChild:GetWidth() - 40)
    msg:SetJustifyH("CENTER")

    if hint then
        local h = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOP", msg, "BOTTOM", 0, -6)
        h:SetText(hint)
        h:SetTextColor(C(T.palette.textMuted))
        h:SetWidth(scrollChild:GetWidth() - 40)
        h:SetJustifyH("CENTER")
    end

    scrollChild:SetHeight(100)
end
