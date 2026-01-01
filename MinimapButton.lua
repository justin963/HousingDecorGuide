-- Minimap Button
local minimapButton = CreateFrame("Button", "HousingDecorGuideMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Icon
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture("Interface/Icons/INV_Misc_Statue_02") -- Housing icon
minimapButton.icon = icon

-- Border
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapButton.border = border

-- Position on minimap
minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52, -52)

-- Dragging functionality
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetMovable(true)

local function UpdatePosition()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    
    local angle = math.atan2(py - my, px - mx)
    local x = 80 * math.cos(angle)
    local y = 80 * math.sin(angle)
    
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    
    -- Save angle
    if not HousingDecorGuideDB.minimapButton then
        HousingDecorGuideDB.minimapButton = {}
    end
    HousingDecorGuideDB.minimapButton.angle = angle
end

minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", UpdatePosition)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end)

-- Click handlers
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        HousingDecorGuide:ToggleMainWindow()
    elseif button == "RightButton" then
        -- Show simple context menu using GameTooltip
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Housing Decor Guide", 1, 0.82, 0, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Left-click:", "Open window", 0.5, 1, 0.5, 1, 1, 1)
        GameTooltip:AddDoubleLine("Right-click:", "This menu", 0.5, 1, 0.5, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Type /hdg minimap to hide button", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        C_Timer.After(3, function()
            if GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
    end
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Housing Decor Guide", 1, 1, 1)
    GameTooltip:AddLine("Click to open", 0.5, 1, 0.5)
    GameTooltip:AddLine("Right-click for options", 0.5, 1, 0.5)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Restore saved position
function HousingDecorGuide:UpdateMinimapButton()
    -- Ensure minimapButton table exists
    if not HousingDecorGuideDB.minimapButton then
        HousingDecorGuideDB.minimapButton = {hide = false}
    end
    
    if HousingDecorGuideDB.minimapButton.hide then
        minimapButton:Hide()
    else
        minimapButton:Show()
        if HousingDecorGuideDB.minimapButton.angle then
            local angle = HousingDecorGuideDB.minimapButton.angle
            local x = 80 * math.cos(angle)
            local y = 80 * math.sin(angle)
            minimapButton:ClearAllPoints()
            minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
    end
end

-- Initialize on load
C_Timer.After(1, function()
    if HousingDecorGuide and HousingDecorGuide.UpdateMinimapButton then
        HousingDecorGuide:UpdateMinimapButton()
    end
end)
