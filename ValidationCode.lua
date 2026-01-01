-- ============================================================
-- EXPANSION ID VALIDATION FUNCTION
-- Add this to Data.lua after the LoadAllRecipeData function
-- ============================================================

-- Validate that all recipe expansion IDs match Core.lua definitions
function HousingDecorGuide:ValidateExpansionIDs()
    -- Build valid expansion lookup table
    local validExpansions = {}
    for _, exp in ipairs(self.expansions) do
        validExpansions[exp.id] = exp.name
    end
    
    -- Track results
    local totalRecipes = 0
    local invalidRecipes = {}
    local expansionCounts = {}
    
    -- Initialize expansion counters
    for _, exp in ipairs(self.expansions) do
        expansionCounts[exp.id] = 0
    end
    
    -- Check all recipes
    for profession, recipes in pairs(self.recipes) do
        for _, recipe in ipairs(recipes) do
            totalRecipes = totalRecipes + 1
            
            if not recipe.expansion then
                table.insert(invalidRecipes, {
                    profession = profession,
                    recipe = recipe.name or "Unknown",
                    expansion = "nil",
                    issue = "Missing expansion field"
                })
            elseif not validExpansions[recipe.expansion] then
                table.insert(invalidRecipes, {
                    profession = profession,
                    recipe = recipe.name,
                    expansion = recipe.expansion,
                    issue = "Invalid expansion ID"
                })
            else
                -- Valid - increment counter
                expansionCounts[recipe.expansion] = (expansionCounts[recipe.expansion] or 0) + 1
            end
        end
    end
    
    -- Print results
    print("|cFFFFFF00=== Housing Decor Guide - Expansion ID Validation ===|r")
    print(" ")
    
    if #invalidRecipes == 0 then
        print("|cFF00FF00✓ SUCCESS! All " .. totalRecipes .. " recipes have valid expansion IDs|r")
        print(" ")
        print("|cFFFFFF00Recipe Distribution by Expansion:|r")
        
        -- Sort by expansion order
        local sortedExpansions = {}
        for _, exp in ipairs(self.expansions) do
            table.insert(sortedExpansions, exp)
        end
        
        for _, exp in ipairs(sortedExpansions) do
            local count = expansionCounts[exp.id] or 0
            if count > 0 then
                print(string.format("  %s: |cFF00FF00%d recipes|r", exp.name, count))
            else
                print(string.format("  %s: |cFFFF0000%d recipes|r (WARNING: No recipes found)", exp.name, count))
            end
        end
        
        print(" ")
        print("|cFF888888Total: " .. totalRecipes .. " recipes across " .. #self.professions .. " professions|r")
        return true
    else
        print("|cFFFF0000✗ FAILED! Found " .. #invalidRecipes .. " invalid expansion IDs|r")
        print(" ")
        print("|cFFFF0000Invalid Recipes:|r")
        
        for i, invalid in ipairs(invalidRecipes) do
            if i <= 20 then -- Limit output to first 20
                print(string.format("  %s > %s: '%s' (%s)", 
                    invalid.profession, 
                    invalid.recipe, 
                    invalid.expansion,
                    invalid.issue))
            end
        end
        
        if #invalidRecipes > 20 then
            print(string.format("  ... and %d more", #invalidRecipes - 20))
        end
        
        print(" ")
        print("|cFFFFFF00Valid expansion IDs are:|r")
        for _, exp in ipairs(self.expansions) do
            print(string.format("  '%s' (%s)", exp.id, exp.name))
        end
        
        return false
    end
end

-- ============================================================
-- PROFESSION RECIPE COUNT VALIDATION
-- ============================================================

function HousingDecorGuide:ValidateProfessionData()
    print("|cFFFFFF00=== Housing Decor Guide - Profession Data Validation ===|r")
    print(" ")
    
    local totalRecipes = 0
    local professionStats = {}
    
    -- Check each profession
    for _, professionName in ipairs(self.professions) do
        local recipes = self.recipes[professionName] or {}
        local count = #recipes
        totalRecipes = totalRecipes + count
        
        table.insert(professionStats, {
            name = professionName,
            count = count,
            hasData = count > 0
        })
    end
    
    -- Print results
    for _, stat in ipairs(professionStats) do
        if stat.hasData then
            print(string.format("  %s: |cFF00FF00%d recipes|r", stat.name, stat.count))
        else
            print(string.format("  %s: |cFFFF0000%d recipes|r (WARNING: No data loaded)", stat.name, stat.count))
        end
    end
    
    print(" ")
    print("|cFF888888Total: " .. totalRecipes .. " recipes|r")
    print(" ")
    
    if totalRecipes == 0 then
        print("|cFFFF0000ERROR: No recipes loaded! Check that Data_*.lua files are present.|r")
        return false
    elseif totalRecipes < 200 then
        print("|cFFFFAA00WARNING: Only " .. totalRecipes .. " recipes loaded (expected ~246)|r")
        return false
    else
        print("|cFF00FF00✓ Profession data looks good!|r")
        return true
    end
end

-- ============================================================
-- COMPLETE VALIDATION (RUN ALL CHECKS)
-- ============================================================

function HousingDecorGuide:ValidateAll()
    local valid = true
    
    print(" ")
    print("|cFF00FFFF════════════════════════════════════════════|r")
    print("|cFF00FFFF  Housing Decor Guide - Full Validation   |r")
    print("|cFF00FFFF════════════════════════════════════════════|r")
    print(" ")
    
    -- Check profession data loaded
    if not self:ValidateProfessionData() then
        valid = false
    end
    
    print(" ")
    
    -- Check expansion IDs
    if not self:ValidateExpansionIDs() then
        valid = false
    end
    
    print(" ")
    print("|cFF00FFFF════════════════════════════════════════════|r")
    
    if valid then
        print("|cFF00FF00✓ ALL VALIDATION CHECKS PASSED!|r")
        print("|cFF888888Addon is ready to use.|r")
    else
        print("|cFFFF0000✗ VALIDATION FAILED|r")
        print("|cFF888888Please check the errors above.|r")
    end
    
    print("|cFF00FFFF════════════════════════════════════════════|r")
    print(" ")
    
    return valid
end

-- ============================================================
-- SLASH COMMAND ADDITIONS
-- Add these cases to your existing slash command handler in Core.lua
-- ============================================================

--[[
    Add to SlashCmdList["HOUSINGDECORGUIDE"] function:
    
    elseif msg == "validate" then
        HousingDecorGuide:ValidateAll()
        
    elseif msg == "validate expansions" then
        HousingDecorGuide:ValidateExpansionIDs()
        
    elseif msg == "validate professions" then
        HousingDecorGuide:ValidateProfessionData()
--]]
