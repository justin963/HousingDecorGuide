-- Core addon initialization
HousingDecorGuide = {}
HousingDecorGuide.version = "1.0.6"

-- Saved variables
HousingDecorGuideDB = HousingDecorGuideDB or {
    favorites = {},
    shoppingList = {},
    showKnownRecipes = true,
    showUnknownRecipes = true,
    windowPosition = nil,
    minimapButton = {hide = false},
}

-- Profession list
HousingDecorGuide.professions = {
    "Alchemy",
    "Blacksmithing",
    "Cooking",
    "Enchanting",
    "Engineering",
    "Inscription",
    "Jewelcrafting",
    "Leatherworking",
    "Tailoring",
}

-- Expansion list
HousingDecorGuide.expansions = {
    {id = "classic", name = "Classic", order = 1},
    {id = "tbc", name = "The Burning Crusade", order = 2},
    {id = "wrath", name = "Wrath of the Lich King", order = 3},
    {id = "cata", name = "Cataclysm", order = 4},
    {id = "mop", name = "Mists of Pandaria", order = 5},
    {id = "wod", name = "Warlords of Draenor", order = 6},
    {id = "legion", name = "Legion", order = 7},
    {id = "bfa", name = "Battle for Azeroth", order = 8},
    {id = "sl", name = "Shadowlands", order = 9},
    {id = "df", name = "Dragonflight", order = 10},
    {id = "tww", name = "The War Within", order = 11},
}

-- Helper function to check if player knows a recipe
function HousingDecorGuide:PlayerKnowsRecipe(recipeID)
    if not recipeID then return false end
    return C_TradeSkillUI.IsRecipeProfessionLearned(recipeID)
end

-- Helper function to get item count in bags
function HousingDecorGuide:GetItemCount(itemID)
    return C_Item.GetItemCount(itemID, true) -- true includes bank
end

-- Helper function to calculate total materials needed
function HousingDecorGuide:CalculateMaterialsNeeded(recipe, quantity)
    local materials = {}
    quantity = quantity or 1
    
    for _, mat in ipairs(recipe.materials) do
        local matID = mat.itemID
        if not materials[matID] then
            materials[matID] = {
                itemID = matID,
                name = mat.name,
                needed = 0,
                have = self:GetItemCount(matID),
            }
        end
        materials[matID].needed = materials[matID].needed + (mat.count * quantity)
    end
    
    return materials
end

-- Helper function to check if recipe is favorited
function HousingDecorGuide:IsRecipeFavorited(recipeName)
    return HousingDecorGuideDB.favorites[recipeName] == true
end

-- Helper function to toggle favorite
function HousingDecorGuide:ToggleFavorite(recipeName)
    if HousingDecorGuideDB.favorites[recipeName] then
        HousingDecorGuideDB.favorites[recipeName] = nil
        return false
    else
        HousingDecorGuideDB.favorites[recipeName] = true
        return true
    end
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "HousingDecorGuide" then
        -- Initialize saved variables
        if not HousingDecorGuideDB.favorites then
            HousingDecorGuideDB.favorites = {}
        end
        if not HousingDecorGuideDB.shoppingList then
            HousingDecorGuideDB.shoppingList = {}
        end
        if not HousingDecorGuideDB.minimapButton then
            HousingDecorGuideDB.minimapButton = {hide = false}
        end
        
        -- Load all recipe data from profession files
        HousingDecorGuide:LoadAllRecipeData()
        
        -- Debug recipe counts
        C_Timer.After(1, function()
            local totalRecipes = 0
            for profession, recipes in pairs(HousingDecorGuide.recipes) do
                totalRecipes = totalRecipes + #recipes
            end
            print("|cFF00FF00Housing Decor Guide|r loaded with " .. totalRecipes .. " recipes! Type /hdg to open.")
            
            -- If no recipes loaded, show detailed warning
            if totalRecipes == 0 then
                print("|cFFFF0000Warning:|r No recipes loaded. Check that all Data_*.lua files are present.")
                print("|cFFFF0000Debug:|r Run /hdg debug to see what data is available")
                
                -- Check which profession data globals exist
                local missing = {}
                if not HousingDecorGuide_AlchemyData then table.insert(missing, "Alchemy") end
                if not HousingDecorGuide_BlacksmithingData then table.insert(missing, "Blacksmithing") end
                if not HousingDecorGuide_CookingData then table.insert(missing, "Cooking") end
                if not HousingDecorGuide_EnchantingData then table.insert(missing, "Enchanting") end
                if not HousingDecorGuide_EngineeringData then table.insert(missing, "Engineering") end
                if not HousingDecorGuide_InscriptionData then table.insert(missing, "Inscription") end
                if not HousingDecorGuide_JewelcraftingData then table.insert(missing, "Jewelcrafting") end
                if not HousingDecorGuide_LeatherworkingData then table.insert(missing, "Leatherworking") end
                if not HousingDecorGuide_TailoringData then table.insert(missing, "Tailoring") end
                
                if #missing > 0 then
                    print("|cFFFF0000Missing data files:|r " .. table.concat(missing, ", "))
                end
            end
            
            -- Update UI if it's already open
            if HousingDecorGuide.UpdateProfessionButtons then
                HousingDecorGuide:UpdateProfessionButtons()
            end
        end)
    elseif event == "PLAYER_LOGIN" then
        -- Additional initialization after player is fully logged in
    end
end)

-- Slash commands
SLASH_HOUSINGDECORGUIDE1 = "/hdg"
SLASH_HOUSINGDECORGUIDE2 = "/housingdecor"
SlashCmdList["HOUSINGDECORGUIDE"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "debug" then
        HousingDecorGuide:DebugRecipeCounts()
    elseif msg == "reload" then
        -- Force reload recipe data
        HousingDecorGuide:LoadAllRecipeData()
        print("|cFF00FF00Housing Decor Guide:|r Recipe data reloaded")
        if HousingDecorGuide.UpdateProfessionButtons then
            HousingDecorGuide:UpdateProfessionButtons()
        end
        if HousingDecorGuide.RefreshRecipeList then
            HousingDecorGuide:RefreshRecipeList()
        end
    elseif msg == "minimap" then
        -- Toggle minimap button
        HousingDecorGuideDB.minimapButton.hide = not HousingDecorGuideDB.minimapButton.hide
        HousingDecorGuide:UpdateMinimapButton()
        if HousingDecorGuideDB.minimapButton.hide then
            print("|cFF00FF00Housing Decor Guide:|r Minimap button hidden")
        else
            print("|cFF00FF00Housing Decor Guide:|r Minimap button shown")
        end
    else
        HousingDecorGuide:ToggleMainWindow()
    end
end