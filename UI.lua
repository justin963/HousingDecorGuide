-- UI Components
local mainFrame = nil
local currentProfession = "Inscription"
local currentExpansion = "all"
local selectedRecipe = nil

-- Color Palette for consistent theming
local COLORS = {
    backdrop = {0.02, 0.02, 0.05, 0.9},
    border = {0.3, 0.3, 0.4, 1},
    buttonDefault = {0.08, 0.08, 0.12, 0.9},
    buttonHover = {0.15, 0.15, 0.20, 0.95},
    buttonSelected = {0.05, 0.18, 0.08, 0.9},
    recipeKnown = {0, 0.18, 0.08, 0.7},
    recipeKnownHover = {0, 0.25, 0, 0.8},
    recipeUnknown = {0.05, 0.05, 0.08, 0.6},
    recipeUnknownHover = {0.1, 0.1, 0.1, 0.7},
    materialHave = {0, 0.2, 0, 0.7},
    materialNeed = {0.2, 0, 0, 0.6},
    materialLumber = {0.15, 0.1, 0, 0.6},
}

-- Profession icons mapping
local professionIcons = {
    Alchemy = "Interface/Icons/Trade_Alchemy",
    Blacksmithing = "Interface/Icons/Trade_Blacksmithing",
    Cooking = "Interface/Icons/INV_Misc_Food_15",
    Enchanting = "Interface/Icons/Trade_Engraving",
    Engineering = "Interface/Icons/Trade_Engineering",
    Inscription = "Interface/Icons/INV_Inscription_Tradeskill01",
    Jewelcrafting = "Interface/Icons/INV_Misc_Gem_01",
    Leatherworking = "Interface/Icons/Trade_LeatherWorking",
    Tailoring = "Interface/Icons/Trade_Tailoring",
}

-- Cache for recipe output items to avoid repeated API calls
local recipeOutputCache = {}

-- Recipe name lookup table for O(1) access
local recipeNameLookup = {}

-- Helper function to build recipe lookup table
local function BuildRecipeLookup()
    recipeNameLookup = {}
    for profession, recipes in pairs(HousingDecorGuide.recipes) do
        for _, recipe in ipairs(recipes) do
            recipeNameLookup[recipe.name] = recipe
        end
    end
end

-- Helper function to clear scroll frame contents
local function ClearScrollFrame(scrollChild)
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({scrollChild:GetRegions()}) do
        if region:GetObjectType() == "FontString" then
            region:Hide()
            region:SetParent(nil)
        end
    end
end

-- Helper function to set item icon with async loading
local function SetItemIcon(iconTexture, itemID, fallbackTexture)
    if not itemID then
        iconTexture:SetTexture(fallbackTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        return
    end
    
    local itemIcon = C_Item.GetItemIconByID(itemID)
    if itemIcon then
        iconTexture:SetTexture(itemIcon)
    else
        iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        C_Item.RequestLoadItemDataByID(itemID)
        C_Timer.After(0.5, function()
            local loadedIcon = C_Item.GetItemIconByID(itemID)
            if loadedIcon then
                iconTexture:SetTexture(loadedIcon)
            end
        end)
    end
end

-- Helper function to get recipe output itemID using WoW API
local function GetRecipeOutputItemID(recipe)
    if not recipe or not recipe.recipeID then
        return recipe and recipe.itemID or nil
    end
    
    -- Check if player knows this recipe
    local isKnown = HousingDecorGuide:PlayerKnowsRecipe(recipe.recipeID)
    if not isKnown then
        -- For unknown recipes, API won't work, return nil to show profession icon
        return nil
    end
    
    -- Check cache first
    if recipeOutputCache[recipe.recipeID] then
        return recipeOutputCache[recipe.recipeID]
    end
    
    local itemID = nil
    
    -- Try to get output item from recipe using WoW API (only works for known recipes)
    local success, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipe.recipeID)
    if success and recipeInfo and recipeInfo.outputItemID then
        itemID = recipeInfo.outputItemID
    end
    
    -- Alternative method if first doesn't work
    if not itemID then
        success, itemID = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipe.recipeID)
        if success and itemID and type(itemID) == "table" and itemID.itemID then
            itemID = itemID.itemID
        elseif not success or type(itemID) ~= "number" then
            itemID = nil
        end
    end
    
    -- Cache the result (even if nil to avoid repeated failed lookups)
    recipeOutputCache[recipe.recipeID] = itemID
    
    return itemID
end

-- Create main window with new layout
function HousingDecorGuide:CreateMainWindow()
    if mainFrame then return mainFrame end
    
    -- Build recipe name lookup table for fast O(1) access
    BuildRecipeLookup()
    
    -- Main frame - custom modern design
    mainFrame = CreateFrame("Frame", "HousingDecorGuideFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(1250, 700)  -- Optimized width
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    mainFrame:SetBackdropColor(0.03, 0.03, 0.06, 0.98)
    mainFrame:SetBackdropBorderColor(0.35, 0.35, 0.45, 1)
    
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save window position
        local point, _, _, x, y = self:GetPoint()
        HousingDecorGuideDB.windowPosition = {point = point, x = x, y = y}
    end)
    
    -- Restore saved position or center
    if HousingDecorGuideDB.windowPosition then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(
            HousingDecorGuideDB.windowPosition.point,
            UIParent,
            HousingDecorGuideDB.windowPosition.point,
            HousingDecorGuideDB.windowPosition.x,
            HousingDecorGuideDB.windowPosition.y
        )
    end
    
    mainFrame:Hide()
    
    -- Make ESC key close the window
    table.insert(UISpecialFrames, "HousingDecorGuideFrame")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -3, -3)
    closeBtn:SetSize(32, 32)
    
    -- Title bar background
    local titleBg = mainFrame:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 4, -4)
    titleBg:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)
    titleBg:SetHeight(28)
    titleBg:SetColorTexture(0.1, 0.1, 0.15, 0.9)
    titleBg:SetGradient("VERTICAL", CreateColor(0.15, 0.15, 0.22, 0.9), CreateColor(0.05, 0.05, 0.08, 0.9))
    
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY")
    mainFrame.title:SetFontObject("GameFontNormalLarge")
    mainFrame.title:SetPoint("TOP", mainFrame, "TOP", 0, -10)
    mainFrame.title:SetText("|cFFFFD700Housing Decor Crafting Guide|r")
    
    -- LEFT - Profession icons (icon-only, narrower)
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 8, -38)
    sidebar:SetSize(100, 630)  -- Narrower for icon-only layout
    sidebar:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    sidebar:SetBackdropColor(unpack(COLORS.backdrop))
    sidebar:SetBackdropBorderColor(unpack(COLORS.border))
    mainFrame.sidebar = sidebar
    
    -- Store sidebar title for later update
    local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY")
    sidebarTitle:SetFontObject("GameFontNormal")
    sidebarTitle:SetPoint("TOP", sidebar, "TOP", 0, -8)
    mainFrame.sidebarTitle = sidebarTitle
    
    -- Create profession buttons (icon-only with count below) - Only for professions player has
    local yOffset = -30
    mainFrame.professionButtons = {}
    
    -- Filter to only professions the player has
    local playerProfessions = {}
    for i, prof in ipairs(self.professions) do
        if self:PlayerHasProfession(prof) then
            table.insert(playerProfessions, prof)
        end
    end
    
    -- If player has no professions, show a message
    if #playerProfessions == 0 then
        mainFrame.sidebarTitle:SetText("|cFFFF6666No Profs|r")
        local noProfText = sidebar:CreateFontString(nil, "OVERLAY")
        noProfText:SetFontObject("GameFontNormal")
        noProfText:SetPoint("CENTER", sidebar, "CENTER", 0, 0)
        noProfText:SetText("|cFFFF6666No crafting\nprofessions found|r")
        noProfText:SetJustifyH("CENTER")
    else
        -- Set title with count
        mainFrame.sidebarTitle:SetText("|cFFFFD700Profs (" .. #playerProfessions .. ")|r")
        -- Set default profession to first one player has
        currentProfession = playerProfessions[1]
    end
    
    for i, prof in ipairs(playerProfessions) do
        local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        btn:SetSize(84, 60)  -- Wider, shorter for icon + count
        btn:SetPoint("TOP", sidebar, "TOP", 0, yOffset)
        btn:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        btn:SetBackdropColor(unpack(COLORS.buttonDefault))
        btn:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.8)
        
        -- Profession icon (centered, larger)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(40, 40)
        icon:SetPoint("TOP", btn, "TOP", 0, -6)
        icon:SetTexture(professionIcons[prof])
        
        -- Recipe count (below icon, no name shown)
        local count = btn:CreateFontString(nil, "OVERLAY")
        count:SetFontObject("GameFontHighlightSmall")
        count:SetPoint("BOTTOM", btn, "BOTTOM", 0, 4)
        local recipeCount = #(self.recipes[prof] or {})
        count:SetText("|cFF888888" .. recipeCount .. "|r")
        btn.countLabel = count
        btn.recipeCount = recipeCount
        
        btn.profession = prof
        btn:SetScript("OnEnter", function(self)
            -- Show tooltip with profession name and details
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.profession, 1, 1, 1)
            local recipes = HousingDecorGuide.recipes[self.profession] or {}
            local totalCount = #recipes
            local learnedCount = 0
            for _, recipe in ipairs(recipes) do
                if HousingDecorGuide:PlayerKnowsRecipe(recipe.recipeID) then
                    learnedCount = learnedCount + 1
                end
            end
            if totalCount > 0 then
                local percentage = math.floor((learnedCount / totalCount) * 100)
                GameTooltip:AddLine(string.format("%d/%d recipes (%d%%)", learnedCount, totalCount, percentage), 0.5, 1, 0.5)
            end
            GameTooltip:Show()
            
            if currentProfession ~= self.profession then
                self:SetBackdropColor(unpack(COLORS.buttonHover))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if currentProfession ~= self.profession then
                self:SetBackdropColor(unpack(COLORS.buttonDefault))
            end
        end)
        btn:SetScript("OnClick", function(self)
            currentProfession = self.profession
            HousingDecorGuide:UpdateProfessionButtons()
            HousingDecorGuide:RefreshRecipeList()
        end)
        
        mainFrame.professionButtons[prof] = btn
        yOffset = yOffset - 66  -- Spacing between buttons
    end
    
    -- CENTER - Recipe list area (optimized)
    local centerPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    centerPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 5, 0)
    centerPanel:SetSize(490, 630)  -- Reduced from 520 for better fit
    centerPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    centerPanel:SetBackdropColor(0.02, 0.02, 0.05, 0.9)
    centerPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)
    mainFrame.centerPanel = centerPanel
    
    -- Filter bar
    local filterBar = CreateFrame("Frame", nil, centerPanel, "BackdropTemplate")
    filterBar:SetPoint("TOPLEFT", centerPanel, "TOPLEFT", 8, -8)
    filterBar:SetPoint("TOPRIGHT", centerPanel, "TOPRIGHT", -8, -8)
    filterBar:SetHeight(65)
    filterBar:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    filterBar:SetBackdropColor(0, 0, 0, 0.3)
    
    -- Expansion dropdown
    local expansionLabel = filterBar:CreateFontString(nil, "OVERLAY")
    expansionLabel:SetFontObject("GameFontNormalSmall")
    expansionLabel:SetPoint("TOPLEFT", filterBar, "TOPLEFT", 10, -8)
    expansionLabel:SetText("Expansion:")
    
    local expansionDropdown = CreateFrame("Frame", "HousingDecorGuideExpansionDropdown", filterBar, "UIDropDownMenuTemplate")
    expansionDropdown:SetPoint("TOPLEFT", expansionLabel, "BOTTOMLEFT", -15, -2)
    UIDropDownMenu_SetWidth(expansionDropdown, 140)
    UIDropDownMenu_SetText(expansionDropdown, "All")
    
    UIDropDownMenu_Initialize(expansionDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Expansions"
        info.func = function()
            currentExpansion = "all"
            UIDropDownMenu_SetText(expansionDropdown, "All")
            HousingDecorGuide:RefreshRecipeList()
        end
        UIDropDownMenu_AddButton(info)
        
        for _, exp in ipairs(HousingDecorGuide.expansions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = exp.name
            info.func = function()
                currentExpansion = exp.name  -- Use full name to match recipe data
                UIDropDownMenu_SetText(expansionDropdown, exp.name)
                HousingDecorGuide:RefreshRecipeList()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Search box
    local searchLabel = filterBar:CreateFontString(nil, "OVERLAY")
    searchLabel:SetFontObject("GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", filterBar, "TOPLEFT", 200, -8)
    searchLabel:SetText("Search:")
    
    local searchBox = CreateFrame("EditBox", "HousingDecorGuideSearchBox", filterBar, "SearchBoxTemplate")
    searchBox:SetSize(180, 25)
    searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 5, -5)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        HousingDecorGuide:RefreshRecipeList()
    end)
    
    -- Filter checkboxes
    local showKnownCheck = CreateFrame("CheckButton", "HousingDecorGuideShowKnown", filterBar, "UICheckButtonTemplate")
    showKnownCheck:SetPoint("TOPLEFT", filterBar, "TOPLEFT", 390, -15)
    showKnownCheck:SetSize(20, 20)
    showKnownCheck:SetChecked(HousingDecorGuideDB.showKnownRecipes)
    showKnownCheck.text:SetText("Known")
    showKnownCheck.text:SetFontObject("GameFontNormalSmall")
    showKnownCheck:SetScript("OnClick", function(self)
        HousingDecorGuideDB.showKnownRecipes = self:GetChecked()
        HousingDecorGuide:RefreshRecipeList()
    end)
    
    local showUnknownCheck = CreateFrame("CheckButton", "HousingDecorGuideShowUnknown", filterBar, "UICheckButtonTemplate")
    showUnknownCheck:SetPoint("TOPLEFT", showKnownCheck, "BOTTOMLEFT", 0, 0)
    showUnknownCheck:SetSize(20, 20)
    showUnknownCheck:SetChecked(HousingDecorGuideDB.showUnknownRecipes)
    showUnknownCheck.text:SetText("Unknown")
    showUnknownCheck.text:SetFontObject("GameFontNormalSmall")
    showUnknownCheck:SetScript("OnClick", function(self)
        HousingDecorGuideDB.showUnknownRecipes = self:GetChecked()
        HousingDecorGuide:RefreshRecipeList()
    end)
    
    -- Favorites filter
    if not HousingDecorGuideDB.showFavoritesOnly then
        HousingDecorGuideDB.showFavoritesOnly = false
    end
    local showFavoritesCheck = CreateFrame("CheckButton", "HousingDecorGuideShowFavorites", filterBar, "UICheckButtonTemplate")
    showFavoritesCheck:SetPoint("TOPLEFT", showUnknownCheck, "BOTTOMLEFT", 0, 0)
    showFavoritesCheck:SetSize(20, 20)
    showFavoritesCheck:SetChecked(HousingDecorGuideDB.showFavoritesOnly)
    showFavoritesCheck.text:SetText("⭐ Favorites")
    showFavoritesCheck.text:SetFontObject("GameFontNormalSmall")
    showFavoritesCheck:SetScript("OnClick", function(self)
        HousingDecorGuideDB.showFavoritesOnly = self:GetChecked()
        HousingDecorGuide:RefreshRecipeList()
    end)
    
    -- Recipe count
    local recipeCount = centerPanel:CreateFontString(nil, "OVERLAY")
    recipeCount:SetFontObject("GameFontNormal")
    recipeCount:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 10, -8)
    recipeCount:SetText("Recipes: 0")
    mainFrame.recipeCount = recipeCount
    
    -- Recipe scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "HousingDecorGuideScrollFrame", centerPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 8, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", centerPanel, "BOTTOMRIGHT", -28, 8)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(445, 1)  -- Updated for 490px wide panel
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild
    
    -- RIGHT - Shopping list (full height)
    local shoppingPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    shoppingPanel:SetPoint("TOPLEFT", centerPanel, "TOPRIGHT", 5, 0)
    shoppingPanel:SetSize(280, 630)  -- Slightly wider for better fit
    shoppingPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    shoppingPanel:SetBackdropColor(0.02, 0.02, 0.05, 0.9)
    shoppingPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)
    mainFrame.shoppingPanel = shoppingPanel
    
    local shoppingTitle = shoppingPanel:CreateFontString(nil, "OVERLAY")
    shoppingTitle:SetFontObject("GameFontNormalLarge")
    shoppingTitle:SetPoint("TOP", shoppingPanel, "TOP", 0, -10)
    shoppingTitle:SetText("|cFFFFD700Shopping List|r")
    
    -- Item count label
    local itemCount = shoppingPanel:CreateFontString(nil, "OVERLAY")
    itemCount:SetFontObject("GameFontHighlight")
    itemCount:SetPoint("TOP", shoppingPanel, "TOP", 0, -32)
    itemCount:SetText("|cFF888888No items|r")
    shoppingPanel.itemCount = itemCount
    
    -- Shopping list scroll frame (recipes only)
    local shoppingScroll = CreateFrame("ScrollFrame", "HousingDecorGuideShoppingScroll", shoppingPanel, "UIPanelScrollFrameTemplate")
    shoppingScroll:SetPoint("TOPLEFT", shoppingPanel, "TOPLEFT", 8, -55)
    shoppingScroll:SetPoint("BOTTOMRIGHT", shoppingPanel, "BOTTOMRIGHT", -28, 35)
    
    local shoppingScrollChild = CreateFrame("Frame", nil, shoppingScroll)
    shoppingScrollChild:SetSize(240, 1)  -- Updated for 280px wide panel
    shoppingScroll:SetScrollChild(shoppingScrollChild)
    shoppingPanel.scrollChild = shoppingScrollChild
    
    -- Clear button
    local clearBtn = CreateFrame("Button", nil, shoppingPanel, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 24)
    clearBtn:SetPoint("BOTTOMLEFT", shoppingPanel, "BOTTOMLEFT", 10, 8)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        if #HousingDecorGuideDB.shoppingList > 0 then
            StaticPopupDialogs["HOUSINGDECOR_CLEAR_LIST"] = {
                text = "Clear shopping list?",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    HousingDecorGuideDB.shoppingList = {}
                    HousingDecorGuide:RefreshShoppingList()
                    print("|cFF00FF00Shopping list cleared.|r")
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("HOUSINGDECOR_CLEAR_LIST")
        end
    end)
    
    -- Export button
    local exportBtn = CreateFrame("Button", nil, shoppingPanel, "UIPanelButtonTemplate")
    exportBtn:SetSize(60, 24)
    exportBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        if #HousingDecorGuideDB.shoppingList == 0 then
            print("|cFFFF6666Shopping list is empty!|r")
            return
        end
        
        -- Create export frame
        if not HousingDecorGuideExportFrame then
            local exportFrame = CreateFrame("Frame", "HousingDecorGuideExportFrame", UIParent, "BasicFrameTemplateWithInset")
            exportFrame:SetSize(400, 300)
            exportFrame:SetPoint("CENTER")
            exportFrame:SetMovable(true)
            exportFrame:EnableMouse(true)
            exportFrame:RegisterForDrag("LeftButton")
            exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
            exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
            
            exportFrame.title = exportFrame:CreateFontString(nil, "OVERLAY")
            exportFrame.title:SetFontObject("GameFontHighlightLarge")
            exportFrame.title:SetPoint("TOP", exportFrame, "TOP", 0, -5)
            exportFrame.title:SetText("Export Shopping List")
            
            local scrollFrame = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 8, -30)
            scrollFrame:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -28, 40)
            
            local editBox = CreateFrame("EditBox", nil, scrollFrame)
            editBox:SetSize(360, 230)
            editBox:SetMultiLine(true)
            editBox:SetAutoFocus(false)
            editBox:SetFontObject("ChatFontNormal")
            editBox:SetScript("OnEscapePressed", function(self)
                exportFrame:Hide()
            end)
            scrollFrame:SetScrollChild(editBox)
            exportFrame.editBox = editBox
            
            local closeBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
            closeBtn:SetSize(80, 24)
            closeBtn:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 10)
            closeBtn:SetText("Close")
            closeBtn:SetScript("OnClick", function()
                exportFrame:Hide()
            end)
        end
        
        -- Generate export text
        local text = "=== Housing Decor Shopping List ===\n\n"
        text = text .. "RECIPES:\n"
        for _, item in ipairs(HousingDecorGuideDB.shoppingList) do
            text = text .. string.format("  %dx %s (%s)\n", item.quantity, item.name, item.profession)
        end
        
        -- Always add materials
        text = text .. "\nMATERIALS NEEDED:\n"
        local totalMaterials = {}
            
            for _, item in ipairs(HousingDecorGuideDB.shoppingList) do
                local recipeData = nil
                for _, recipe in ipairs(HousingDecorGuide:GetRecipesByProfession(item.profession) or {}) do
                    if recipe.name == item.name then
                        recipeData = recipe
                        break
                    end
                end
                
                if recipeData and recipeData.materials then
                    for _, mat in ipairs(recipeData.materials) do
                        if not totalMaterials[mat.itemID] then
                            totalMaterials[mat.itemID] = {
                                itemID = mat.itemID,
                                name = mat.name,
                                needed = 0,
                                have = HousingDecorGuide:GetItemCount(mat.itemID)
                            }
                        end
                        totalMaterials[mat.itemID].needed = totalMaterials[mat.itemID].needed + (mat.count * item.quantity)
                    end
                end
            end
            
            -- Convert to sorted array
            local matArray = {}
            for _, mat in pairs(totalMaterials) do
                table.insert(matArray, mat)
            end
            table.sort(matArray, function(a, b) return a.name < b.name end)
            
            for _, mat in ipairs(matArray) do
                local toBuy = math.max(0, mat.needed - mat.have)
                local status = toBuy > 0 and string.format("(Need %d more)", toBuy) or "(COMPLETE)"
                text = text .. string.format("  %dx %s - Have: %d %s\n", mat.needed, mat.name, mat.have, status)
            end
        
        HousingDecorGuideExportFrame.editBox:SetText(text)
        HousingDecorGuideExportFrame.editBox:HighlightText()
        HousingDecorGuideExportFrame:Show()
    end)
    
    -- FAR RIGHT - Materials panel (beside shopping, not below)
    local materialsPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    materialsPanel:SetPoint("TOPLEFT", shoppingPanel, "TOPRIGHT", 5, 0)  -- To the right of shopping
    materialsPanel:SetSize(280, 630)  -- Match shopping panel width
    materialsPanel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    materialsPanel:SetBackdropColor(0.02, 0.02, 0.05, 0.9)
    materialsPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)
    mainFrame.materialsPanel = materialsPanel
    
    local materialsTitle = materialsPanel:CreateFontString(nil, "OVERLAY")
    materialsTitle:SetFontObject("GameFontNormalLarge")
    materialsTitle:SetPoint("TOP", materialsPanel, "TOP", 0, -10)
    materialsTitle:SetText("|cFFFFD700Materials Needed|r")
    
    -- Materials count label
    local matsCount = materialsPanel:CreateFontString(nil, "OVERLAY")
    matsCount:SetFontObject("GameFontHighlight")
    matsCount:SetPoint("TOP", materialsPanel, "TOP", 0, -32)
    matsCount:SetText("|cFF888888No materials|r")
    materialsPanel.matsCount = matsCount
    
    -- Materials scroll frame
    local materialsScroll = CreateFrame("ScrollFrame", "HousingDecorGuideMaterialsScroll", materialsPanel, "UIPanelScrollFrameTemplate")
    materialsScroll:SetPoint("TOPLEFT", materialsPanel, "TOPLEFT", 8, -55)
    materialsScroll:SetPoint("BOTTOMRIGHT", materialsPanel, "BOTTOMRIGHT", -28, 8)
    
    local materialsScrollChild = CreateFrame("Frame", nil, materialsScroll)
    materialsScrollChild:SetSize(240, 1)  -- Updated for 280px wide panel
    materialsScroll:SetScrollChild(materialsScrollChild)
    materialsPanel.scrollChild = materialsScrollChild
    
    self:UpdateProfessionButtons()
    self:RefreshRecipeList()
    self:RefreshShoppingList()
    
    return mainFrame
end

-- Update profession button states
function HousingDecorGuide:UpdateProfessionButtons()
    if not mainFrame or not mainFrame.professionButtons then return end
    
    for prof, btn in pairs(mainFrame.professionButtons) do
        -- Update recipe count display with learned count
        if btn.countLabel then
            local recipes = self.recipes[prof] or {}
            local totalCount = #recipes
            local learnedCount = 0
            
            for _, recipe in ipairs(recipes) do
                if self:PlayerKnowsRecipe(recipe.recipeID) then
                    learnedCount = learnedCount + 1
                end
            end
            
            if totalCount > 0 then
                local percentage = math.floor((learnedCount / totalCount) * 100)
                btn.countLabel:SetText(string.format("|cFF888888%d/%d (%d%%)|r", learnedCount, totalCount, percentage))
            else
                btn.countLabel:SetText("|cFF888888No recipes|r")
            end
        end
        
        -- Check if player has this profession
        local hasProfession = self:PlayerHasProfession(prof)
        
        -- Update highlight based on selection and profession status
        if prof == currentProfession then
            -- Selected profession
            if hasProfession then
                btn:SetBackdropColor(0.12, 0.35, 0.18, 1)  -- Modern green for selected + known
                btn:SetBackdropBorderColor(0.25, 0.7, 0.35, 1)
            else
                btn:SetBackdropColor(0.18, 0.25, 0.40, 1)  -- Modern blue for selected + unknown
                btn:SetBackdropBorderColor(0.35, 0.55, 0.85, 1)
            end
        else
            -- Not selected
            if hasProfession then
                btn:SetBackdropColor(0.05, 0.18, 0.08, 0.9)  -- Subtle modern green for known
                btn:SetBackdropBorderColor(0.15, 0.45, 0.2, 0.8)
            else
                btn:SetBackdropColor(0.08, 0.08, 0.12, 0.9)  -- Modern dark for unknown
                btn:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.8)
            end
        end
    end
end

-- Toggle main window
function HousingDecorGuide:ToggleMainWindow()
    if not mainFrame then
        self:CreateMainWindow()
    end
    
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:RefreshRecipeList()
        self:RefreshShoppingList()
    end
end

-- Refresh recipe list
function HousingDecorGuide:RefreshRecipeList()
    if not mainFrame then return end
    
    -- Clear existing recipe frames
    for _, child in ipairs({mainFrame.scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Get recipes
    local recipes = {}
    if currentExpansion == "all" then
        recipes = self:GetRecipesByProfession(currentProfession) or {}
    else
        recipes = self:GetRecipesByProfessionAndExpansion(currentProfession, currentExpansion) or {}
    end
    
    -- Apply search filter
    local searchBox = _G["HousingDecorGuideSearchBox"]
    if searchBox then
        local searchText = searchBox:GetText()
        if searchText and searchText ~= "" then
            local filtered = {}
            searchText = string.lower(searchText)
            for _, recipe in ipairs(recipes) do
                if string.find(string.lower(recipe.name), searchText, 1, true) then
                    table.insert(filtered, recipe)
                end
            end
            recipes = filtered
        end
    end
    
    -- Apply known/unknown filter
    local filteredRecipes = {}
    for _, recipe in ipairs(recipes) do
        local isKnown = self:PlayerKnowsRecipe(recipe.recipeID)
        local isFavorited = self:IsRecipeFavorited(recipe.name)
        
        -- Check favorites filter first
        if HousingDecorGuideDB.showFavoritesOnly and not isFavorited then
            -- Skip non-favorited recipes if favorites filter is on
        elseif (isKnown and HousingDecorGuideDB.showKnownRecipes) or 
           (not isKnown and HousingDecorGuideDB.showUnknownRecipes) then
            table.insert(filteredRecipes, recipe)
        end
    end
    
    -- Update count
    mainFrame.recipeCount:SetText("Recipes: " .. #filteredRecipes)
    
    -- Create recipe entries (compact list format)
    local yOffset = -5
    for i, recipe in ipairs(filteredRecipes) do
        local entry = self:CreateRecipeListEntry(mainFrame.scrollChild, recipe, i)
        entry:SetPoint("TOPLEFT", mainFrame.scrollChild, "TOPLEFT", 0, yOffset)
        yOffset = yOffset - 42
    end
    
    mainFrame.scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- Create compact recipe list entry
function HousingDecorGuide:CreateRecipeListEntry(parent, recipe, index)
    local entry = CreateFrame("Button", nil, parent, "BackdropTemplate")
    entry:SetSize(510, 38)
    entry:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 3,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    local isKnown = self:PlayerKnowsRecipe(recipe.recipeID)
    if isKnown then
        entry:SetBackdropColor(unpack(COLORS.recipeKnown))
        entry:SetBackdropBorderColor(0.1, 0.5, 0.2, 0.8)
    else
        entry:SetBackdropColor(unpack(COLORS.recipeUnknown))
        entry:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    
    entry:SetScript("OnEnter", function(self)
        if isKnown then
            self:SetBackdropColor(unpack(COLORS.recipeKnownHover))
        else
            self:SetBackdropColor(unpack(COLORS.recipeUnknownHover))
        end
    end)
    entry:SetScript("OnLeave", function(self)
        if isKnown then
            self:SetBackdropColor(unpack(COLORS.recipeKnown))
        else
            self:SetBackdropColor(unpack(COLORS.recipeUnknown))
        end
    end)
    
    -- Icon
    local icon = entry:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", entry, "LEFT", 4, 0)
    
    -- Get correct itemID using WoW API and set icon
    local itemID = GetRecipeOutputItemID(recipe)
    SetItemIcon(icon, itemID, professionIcons[currentProfession])
    
    -- Store for reference
    entry.iconTexture = icon
    entry.itemID = itemID
    
    -- Add tooltip on hover
    entry:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        
        -- Get correct itemID
        local tooltipItemID = GetRecipeOutputItemID(recipe)
        
        if tooltipItemID then
            GameTooltip:SetItemByID(tooltipItemID)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888" .. recipe.expansion .. "|r", 1, 1, 1)
        if recipe.materials and #recipe.materials > 0 then
            GameTooltip:AddLine("|cFFFFFFFFMaterials:|r", 1, 1, 1)
            for _, mat in ipairs(recipe.materials) do
                local have = HousingDecorGuide:GetItemCount(mat.itemID)
                local color = have >= mat.count and "|cFF00FF00" or "|cFFFF6666"
                GameTooltip:AddLine(string.format("  %s%dx %s|r", color, mat.count, mat.name), 1, 1, 1)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF00FF00Click to add to shopping list|r", 0.5, 1, 0.5)
        GameTooltip:Show()
    end)
    entry:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Click to add to shopping list
    entry:SetScript("OnClick", function(self)
        HousingDecorGuide:AddToShoppingList(recipe)
        HousingDecorGuide:RefreshShoppingList()
    end)
    
    -- Name
    local name = entry:CreateFontString(nil, "OVERLAY")
    name:SetFontObject("GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 5)
    name:SetWidth(340)
    name:SetJustifyH("LEFT")
    if isKnown then
        name:SetText("|cFF00FF00" .. recipe.name .. "|r")
    else
        name:SetText(recipe.name)
    end
    
    -- Expansion tag
    local expName = ""
    for _, exp in ipairs(self.expansions) do
        if exp.id == recipe.expansion then
            expName = exp.name
            break
        end
    end
    local exp = entry:CreateFontString(nil, "OVERLAY")
    exp:SetFontObject("GameFontHighlightSmall")
    exp:SetPoint("LEFT", icon, "RIGHT", 8, -8)
    exp:SetText("|cFF888888" .. expName .. "|r")
    
    -- Materials indicator
    local matsNeeded = 0
    local matsHave = 0
    if recipe.materials and #recipe.materials > 0 then
        for _, mat in ipairs(recipe.materials) do
            matsNeeded = matsNeeded + 1
            if self:GetItemCount(mat.itemID) >= mat.count then
                matsHave = matsHave + 1
            end
        end
        
        local matsText = entry:CreateFontString(nil, "OVERLAY")
        matsText:SetFontObject("GameFontHighlightSmall")
        matsText:SetPoint("RIGHT", entry, "RIGHT", -50, 0)  -- Moved right, more space available
        if matsHave == matsNeeded then
            matsText:SetText("|cFF00FF00✓ Materials|r")
        else
            matsText:SetText("|cFFFF6666" .. matsHave .. "/" .. matsNeeded .. " mats|r")
        end
    end
    
    -- Favorite star button
    local favBtn = CreateFrame("Button", nil, entry)
    favBtn:SetSize(24, 24)
    favBtn:SetPoint("RIGHT", entry, "RIGHT", -10, 0)  -- Moved to far right since no add button
    
    local favIcon = favBtn:CreateTexture(nil, "ARTWORK")
    favIcon:SetSize(20, 20)  -- Increased from 16 to 20
    favIcon:SetPoint("CENTER")
    
    local isFavorited = self:IsRecipeFavorited(recipe.name)
    if isFavorited then
        favIcon:SetTexture("Interface/COMMON/FavoritesIcon")
        favIcon:SetVertexColor(1, 0.8, 0)  -- Gold color
    else
        favIcon:SetTexture("Interface/COMMON/FavoritesIcon")
        favIcon:SetVertexColor(0.3, 0.3, 0.3)  -- Gray color
        favIcon:SetDesaturated(true)
    end
    
    favBtn:SetScript("OnClick", function(self)
        local nowFavorited = HousingDecorGuide:ToggleFavorite(recipe.name)
        if nowFavorited then
            favIcon:SetTexture("Interface/COMMON/FavoritesIcon")
            favIcon:SetVertexColor(1, 0.8, 0)
            favIcon:SetDesaturated(false)
            print("|cFF00FF00Added to favorites:|r " .. recipe.name)
        else
            favIcon:SetTexture("Interface/COMMON/FavoritesIcon")
            favIcon:SetVertexColor(0.3, 0.3, 0.3)
            favIcon:SetDesaturated(true)
            print("|cFFFF6666Removed from favorites:|r " .. recipe.name)
        end
        
        -- Refresh if favorites filter is active
        if HousingDecorGuideDB.showFavoritesOnly then
            HousingDecorGuide:RefreshRecipeList()
        end
    end)
    
    favBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if isFavorited then
            GameTooltip:SetText("Remove from Favorites", 1, 1, 1)
        else
            GameTooltip:SetText("Add to Favorites", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    
    favBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return entry
end

-- Refresh shopping list
function HousingDecorGuide:RefreshShoppingList()
    if not mainFrame or not mainFrame.shoppingPanel then return end
    
    local shoppingPanel = mainFrame.shoppingPanel
    
    -- Clear scroll frame
    ClearScrollFrame(shoppingPanel.scrollChild)
    
    -- Update count
    local itemCount = #HousingDecorGuideDB.shoppingList
    if itemCount == 0 then
        shoppingPanel.itemCount:SetText("|cFF888888No items|r")
    else
        shoppingPanel.itemCount:SetText("|cFFFFFFFF" .. itemCount .. " item" .. (itemCount > 1 and "s" or "") .. "|r")
    end
    
    -- Always show recipes (no more tabs)
    self:ShowShoppingRecipes()
    
    -- Also refresh materials panel
    self:RefreshMaterialsPanel()
end

-- Show shopping recipes
function HousingDecorGuide:ShowShoppingRecipes()
    local shoppingPanel = mainFrame.shoppingPanel
    
    if #HousingDecorGuideDB.shoppingList == 0 then
        local empty = shoppingPanel.scrollChild:CreateFontString(nil, "OVERLAY")
        empty:SetFontObject("GameFontNormal")
        empty:SetPoint("CENTER", shoppingPanel.scrollChild, "TOP", 0, -100)
        empty:SetText("|cFF888888No recipes added yet|r")
        return
    end
    
    local yOffset = -5
    for i, item in ipairs(HousingDecorGuideDB.shoppingList) do
        local frame = CreateFrame("Button", nil, shoppingPanel.scrollChild, "BackdropTemplate")
        frame:SetSize(240, 55)  -- Updated for 280px panel
        frame:SetPoint("TOPLEFT", shoppingPanel.scrollChild, "TOPLEFT", 0, yOffset)
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 4,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.6)
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        
        -- Enable shift-click for AH search
        frame:EnableMouse(true)
        frame:RegisterForClicks("LeftButtonUp")
        
        -- Add item icon
        -- Use lookup table for O(1) access instead of linear search
        local recipeData = recipeNameLookup[item.name]
        
        if recipeData then
            -- Get correct itemID using API
            local itemID = GetRecipeOutputItemID(recipeData)
            
            if itemID then
                local icon = frame:CreateTexture(nil, "ARTWORK")
                icon:SetSize(32, 32)
                icon:SetPoint("LEFT", frame, "LEFT", 4, 0)
                
                -- Use helper function
                SetItemIcon(icon, itemID, professionIcons[item.profession])
                
                frame:SetScript("OnClick", function(self)
                    if IsShiftKeyDown() then
                        local link = select(2, C_Item.GetItemInfo(itemID))
                        if link then
                            HandleModifiedItemClick(link)
                        end
                    end
                end)
                
                frame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(itemID)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFFFFFFFFShift-Click to search AH|r", 0.5, 1, 0.5)
                    GameTooltip:Show()
                end)
                
                frame:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
            end
        end
        
        -- Name
        local name = frame:CreateFontString(nil, "OVERLAY")
        name:SetFontObject("GameFontNormalSmall")
        name:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -6)
        name:SetWidth(180)
        name:SetJustifyH("LEFT")
        name:SetText(item.quantity .. "x " .. item.name)
        
        -- Profession
        local prof = frame:CreateFontString(nil, "OVERLAY")
        prof:SetFontObject("GameFontHighlightSmall")
        prof:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        prof:SetText("|cFF888888" .. item.profession .. "|r")
        
        -- Controls
        local removeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        removeBtn:SetSize(50, 20)
        removeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        removeBtn:SetText("Remove")
        removeBtn:SetScript("OnClick", function()
            table.remove(HousingDecorGuideDB.shoppingList, i)
            HousingDecorGuide:RefreshShoppingList()
        end)
        
        local decreaseBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        decreaseBtn:SetSize(20, 20)
        decreaseBtn:SetPoint("RIGHT", removeBtn, "LEFT", -25, 0)
        decreaseBtn:SetText("-")
        decreaseBtn:SetScript("OnClick", function()
            if item.quantity > 1 then
                item.quantity = item.quantity - 1
                HousingDecorGuide:RefreshShoppingList()
            end
        end)
        
        local qtyLabel = frame:CreateFontString(nil, "OVERLAY")
        qtyLabel:SetFontObject("GameFontNormalSmall")
        qtyLabel:SetPoint("RIGHT", decreaseBtn, "LEFT", -3, 0)
        qtyLabel:SetText(item.quantity)
        
        local increaseBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        increaseBtn:SetSize(20, 20)
        increaseBtn:SetPoint("RIGHT", qtyLabel, "LEFT", -3, 0)
        increaseBtn:SetText("+")
        increaseBtn:SetScript("OnClick", function()
            item.quantity = item.quantity + 1
            HousingDecorGuide:RefreshShoppingList()
        end)
        
        yOffset = yOffset - 60
    end
    
    shoppingPanel.scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- Refresh materials panel
function HousingDecorGuide:RefreshMaterialsPanel()
    if not mainFrame or not mainFrame.materialsPanel then return end
    
    local materialsPanel = mainFrame.materialsPanel
    
    -- Clear scroll frame
    ClearScrollFrame(materialsPanel.scrollChild)
    
    -- Aggregate materials
    local totalMaterials = {}
    for _, item in ipairs(HousingDecorGuideDB.shoppingList) do
        -- Check if item has materials and they're not empty
        if item.materials and type(item.materials) == "table" and #item.materials > 0 then
            for _, mat in ipairs(item.materials) do
                local matID = mat.itemID
                if not totalMaterials[matID] then
                    totalMaterials[matID] = {
                        itemID = matID,
                        name = mat.name or C_Item.GetItemNameByID(matID) or ("Item " .. matID),
                        needed = 0,
                        have = self:GetItemCount(matID),
                    }
                end
                totalMaterials[matID].needed = totalMaterials[matID].needed + (mat.count * item.quantity)
            end
        end
    end
    
    -- Convert to array and sort
    local matArray = {}
    for _, mat in pairs(totalMaterials) do
        table.insert(matArray, mat)
    end
    table.sort(matArray, function(a, b) return a.name < b.name end)
    
    -- Update count
    if #matArray == 0 then
        materialsPanel.matsCount:SetText("|cFF888888No materials|r")
    else
        local uniqueCount = #matArray
        materialsPanel.matsCount:SetText("|cFFFFFFFF" .. uniqueCount .. " unique material" .. (uniqueCount > 1 and "s" or "") .. "|r")
    end
    
    if #matArray == 0 then
        local empty = materialsPanel.scrollChild:CreateFontString(nil, "OVERLAY")
        empty:SetFontObject("GameFontNormal")
        empty:SetPoint("CENTER", materialsPanel.scrollChild, "TOP", 0, -100)
        empty:SetText("|cFF888888No materials needed\n\n|cFFFFFFFFAdd recipes to shopping list|r")
        return
    end
    
    local yOffset = -5
    for _, mat in ipairs(matArray) do
        local toBuy = math.max(0, mat.needed - mat.have)
        
        -- Check if this is lumber (can't be purchased)
        local isLumber = mat.name:find("Lumber")
        
        local frame = CreateFrame("Button", nil, materialsPanel.scrollChild, "BackdropTemplate")
        frame:SetSize(240, 50)  -- Updated for 280px panel
        frame:SetPoint("TOPLEFT", materialsPanel.scrollChild, "TOPLEFT", 0, yOffset)
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 4,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        
        if toBuy == 0 then
            frame:SetBackdropColor(0, 0.2, 0, 0.7)
            frame:SetBackdropBorderColor(0, 0.5, 0, 1)
        elseif isLumber then
            -- Special color for lumber (can't buy, must collect)
            frame:SetBackdropColor(0.15, 0.1, 0, 0.6)
            frame:SetBackdropBorderColor(0.6, 0.4, 0, 1)
        else
            frame:SetBackdropColor(0.2, 0, 0, 0.6)
            frame:SetBackdropBorderColor(0.5, 0, 0, 1)
        end
        
        -- Add item icon
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", frame, "LEFT", 4, 0)
        icon:SetTexture(GetItemIcon(mat.itemID))
        
        -- Store data directly on the frame to avoid closure issues
        frame.matItemID = mat.itemID
        frame.matItemName = mat.name
        frame.matIsLumber = isLumber
        
        -- Enable mouse interaction for shift-click
        frame:EnableMouse(true)
        frame:RegisterForClicks("LeftButtonUp")
        frame:SetScript("OnClick", function(self)
            if IsShiftKeyDown() and not self.matIsLumber then
                -- Shift-click to search AH (but not for lumber)
                local link = select(2, C_Item.GetItemInfo(self.matItemID))
                if link then
                    HandleModifiedItemClick(link)
                end
            end
        end)
        
        frame:SetScript("OnEnter", function(self)
            GameTooltip:Hide()
            GameTooltip:ClearLines()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            
            -- Use the itemID stored on this specific frame
            local itemLink = select(2, C_Item.GetItemInfo(self.matItemID))
            if itemLink then
                GameTooltip:SetHyperlink(itemLink)
            else
                GameTooltip:SetItemByID(self.matItemID)
            end
            
            GameTooltip:AddLine(" ")
            if self.matIsLumber then
                GameTooltip:AddLine("|cFFFFAA00Cannot be purchased - must collect|r", 1, 0.8, 0.4, true)
            else
                GameTooltip:AddLine("|cFFFFFFFFShift-Click to search AH|r", 0.5, 1, 0.5)
            end
            GameTooltip:Show()
        end)
        
        frame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        -- Material name
        local name = frame:CreateFontString(nil, "OVERLAY")
        name:SetFontObject("GameFontNormalSmall")
        name:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -6)
        name:SetWidth(198)  -- Increased for 280px panel
        name:SetJustifyH("LEFT")
        name:SetText(mat.name)
        
        -- Counts
        local counts = frame:CreateFontString(nil, "OVERLAY")
        counts:SetFontObject("GameFontHighlightSmall")
        counts:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        if toBuy > 0 then
            if isLumber then
                counts:SetText(string.format("|cFFFFFFFFNeed %d  •  Have %d  •  |cFFFFAA00Collect %d|r", mat.needed, mat.have, toBuy))
            else
                counts:SetText(string.format("|cFFFFFFFFNeed %d  •  Have %d  •  |cFFFF6666Buy %d|r", mat.needed, mat.have, toBuy))
            end
        else
            -- Use WoW's built-in checkmark icon texture
            counts:SetText(string.format("|cFFFFFFFFNeed %d  •  Have %d  •  |r|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t", mat.needed, mat.have))
        end
        
        yOffset = yOffset - 55
    end
    
    materialsPanel.scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- Add to shopping list
function HousingDecorGuide:AddToShoppingList(recipe)
    for _, item in ipairs(HousingDecorGuideDB.shoppingList) do
        if item.name == recipe.name then
            item.quantity = item.quantity + 1
            print("|cFF00FF00Added another " .. recipe.name .. " (now " .. item.quantity .. "x)|r")
            return
        end
    end
    
    table.insert(HousingDecorGuideDB.shoppingList, {
        name = recipe.name,
        profession = currentProfession,
        materials = recipe.materials,
        quantity = 1,
    })
    
    print("|cFF00FF00Added " .. recipe.name .. " to shopping list|r")
end
