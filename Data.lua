-- Recipe database - Initialize profession tables
-- Individual profession data is loaded from separate files

-- Initialize the main recipes table
if not HousingDecorGuide then HousingDecorGuide = {} end
if not HousingDecorGuide.recipes then HousingDecorGuide.recipes = {} end

-- This function will be called after all Data_*.lua files have loaded
function HousingDecorGuide:LoadAllRecipeData()
    -- Load Alchemy
    if HousingDecorGuide_AlchemyData then
        self.recipes.Alchemy = HousingDecorGuide_AlchemyData
    else
        self.recipes.Alchemy = {}
    end
    
    -- Load Blacksmithing
    if HousingDecorGuide_BlacksmithingData then
        self.recipes.Blacksmithing = HousingDecorGuide_BlacksmithingData
    else
        self.recipes.Blacksmithing = {}
    end
    
    -- Load Cooking
    if HousingDecorGuide_CookingData then
        self.recipes.Cooking = HousingDecorGuide_CookingData
    else
        self.recipes.Cooking = {}
    end
    
    -- Load Enchanting
    if HousingDecorGuide_EnchantingData then
        self.recipes.Enchanting = HousingDecorGuide_EnchantingData
    else
        self.recipes.Enchanting = {}
    end
    
    -- Load Engineering
    if HousingDecorGuide_EngineeringData then
        self.recipes.Engineering = HousingDecorGuide_EngineeringData
    else
        self.recipes.Engineering = {}
    end
    
    -- Load Inscription
    if HousingDecorGuide_InscriptionData then
        self.recipes.Inscription = HousingDecorGuide_InscriptionData
    else
        self.recipes.Inscription = {}
    end
    
    -- Load Jewelcrafting
    if HousingDecorGuide_JewelcraftingData then
        self.recipes.Jewelcrafting = HousingDecorGuide_JewelcraftingData
    else
        self.recipes.Jewelcrafting = {}
    end
    
    -- Load Leatherworking
    if HousingDecorGuide_LeatherworkingData then
        self.recipes.Leatherworking = HousingDecorGuide_LeatherworkingData
    else
        self.recipes.Leatherworking = {}
    end
    
    -- Load Tailoring
    if HousingDecorGuide_TailoringData then
        self.recipes.Tailoring = HousingDecorGuide_TailoringData
    else
        self.recipes.Tailoring = {}
    end
    
    -- Normalize recipe data (convert materials format)
    for profession, recipes in pairs(self.recipes) do
        for _, recipe in ipairs(recipes) do
            -- Ensure materials field exists
            if not recipe.materials then
                recipe.materials = {}
            end
            
            -- Normalize material format: {id=X, amt=Y} -> {itemID=X, count=Y, name="..."}
            for i, mat in ipairs(recipe.materials) do
                if mat.id and not mat.itemID then
                    -- Convert old format to new format
                    recipe.materials[i] = {
                        itemID = mat.id,
                        count = mat.amt or 1,
                        name = C_Item.GetItemNameByID(mat.id) or ("Item " .. mat.id)
                    }
                elseif mat.itemID and not mat.count then
                    -- Add count if missing
                    mat.count = mat.amt or 1
                    -- Add name if missing
                    if not mat.name then
                        mat.name = C_Item.GetItemNameByID(mat.itemID) or ("Item " .. mat.itemID)
                    end
                end
            end
        end
    end
end

-- Helper function to get recipes by profession
function HousingDecorGuide:GetRecipesByProfession(profession)
    if not profession then return {} end
    return self.recipes[profession] or {}
end

-- Helper function to get recipes by profession and expansion
function HousingDecorGuide:GetRecipesByProfessionAndExpansion(profession, expansionID)
    local allRecipes = self:GetRecipesByProfession(profession)
    local filtered = {}
    
    for _, recipe in ipairs(allRecipes) do
        if recipe.expansion == expansionID then
            table.insert(filtered, recipe)
        end
    end
    
    return filtered
end

-- Helper function to search recipes
function HousingDecorGuide:SearchRecipes(profession, searchText)
    local allRecipes = self:GetRecipesByProfession(profession)
    local results = {}
    
    searchText = string.lower(searchText or "")
    
    for _, recipe in ipairs(allRecipes) do
        if searchText == "" or string.find(string.lower(recipe.name), searchText, 1, true) then
            table.insert(results, recipe)
        end
    end
    
    return results
end

-- Debug function to check if recipes loaded
function HousingDecorGuide:DebugRecipeCounts()
    print("=== Housing Decor Guide Recipe Counts ===")
    local total = 0
    for profession, recipes in pairs(self.recipes) do
        local count = #recipes
        total = total + count
        if count > 0 then
            print("|cFF00FF00" .. profession .. ":|r " .. count .. " recipes")
        else
            print("|cFFFF0000" .. profession .. ":|r " .. count .. " recipes (NO DATA)")
        end
    end
    print("|cFFFFFF00Total:|r " .. total .. " recipes")
    
    -- Check global variables
    print("\n=== Global Data Variables ===")
    local globals = {
        {"Alchemy", HousingDecorGuide_AlchemyData},
        {"Blacksmithing", HousingDecorGuide_BlacksmithingData},
        {"Cooking", HousingDecorGuide_CookingData},
        {"Enchanting", HousingDecorGuide_EnchantingData},
        {"Engineering", HousingDecorGuide_EngineeringData},
        {"Inscription", HousingDecorGuide_InscriptionData},
        {"Jewelcrafting", HousingDecorGuide_JewelcraftingData},
        {"Leatherworking", HousingDecorGuide_LeatherworkingData},
        {"Tailoring", HousingDecorGuide_TailoringData},
    }
    
    for _, data in ipairs(globals) do
        local name, var = data[1], data[2]
        if var and type(var) == "table" then
            print("|cFF00FF00" .. name .. ":|r Found (" .. #var .. " items)")
        else
            print("|cFFFF0000" .. name .. ":|r NOT FOUND")
        end
    end
    
    print("\nRun /hdg reload to force reload the data")
end

-- Check if player has a specific profession
function HousingDecorGuide:PlayerHasProfession(professionName)
    -- Get player's professions (returns two profession IDs)
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    
    -- Profession name to skill line ID mapping
    local professionIDs = {
        ["Alchemy"] = 171,
        ["Blacksmithing"] = 164,
        ["Cooking"] = 185,
        ["Enchanting"] = 333,
        ["Engineering"] = 202,
        ["Inscription"] = 773,
        ["Jewelcrafting"] = 755,
        ["Leatherworking"] = 165,
        ["Tailoring"] = 197,
    }
    
    local targetID = professionIDs[professionName]
    if not targetID then return false end
    
    -- Check primary professions
    local profIndexes = {prof1, prof2}
    for _, profIndex in ipairs(profIndexes) do
        if profIndex then
            local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine = GetProfessionInfo(profIndex)
            if skillLine == targetID then
                return true
            end
        end
    end
    
    -- Check cooking separately
    if professionName == "Cooking" and cooking then
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine = GetProfessionInfo(cooking)
        if skillLine == 185 then
            return true
        end
    end
    
    return false
end