-- clean_unknown_recipe/init.lua
-- Remove recipes referencing to unknown items
-- Copyright (C) 2024  1F616EMO
-- SPDX-License-Identifier: LGPL-3.0-or-later

-- minetest.get_all_craft_recipes(query item)

local logger = logging.logger("clean_unknown_recipe")

if not minetest.features.get_all_craft_recipes_works then
    logger:raise("You are using an old or incompactible version of Minetest. " ..
        "Please use Minetest 0.4.7 or later.")
end

minetest.register_on_mods_loaded(function()
    local groups_found = {}
    local recipes_found = {}

    for name, def in pairs(minetest.registered_items) do
        if def.groups then
            for group, rating in pairs(def.groups) do
                if rating > 0 then
                    groups_found[group] = true
                end
            end
        end

        local recipes = minetest.get_all_craft_recipes(name)
        if recipes then
            table.insert_all(recipes_found, recipes)
        end
    end

    -- Put here for proper garbage collection
    local function recipe_is_unknown(table)
        for _, item in ipairs(table) do
            if string.sub(item, 1, 6) == "group:" then
                local groupnames = string.split(string.sub(item, 7))
                for _, groupname in ipairs(groupnames) do
                    if not groups_found[groupname] then
                        logger:warning("Found unknown group %s from item name %s", groupname, item)
                        return true
                    end
                end
            elseif not minetest.registered_items[item] and not minetest.registered_aliases[item] then
                logger:warning("Found unknown item %s", item)
                return true
            end
        end
        return false
    end

    local function construct_recipe(raw_recipe)
        local recipe = {}
        if raw_recipe.method == "normal" then
            if raw_recipe.width == 0 then
                recipe.type = "shapeless"
                recipe.recipe = raw_recipe.items
            else
                recipe.type = "shaped"
                recipe.recipe = {}
                for i = 1, #raw_recipe.items, raw_recipe.width do
                    local row = {}
                    for j = 0, raw_recipe.width - 1 do
                        row[#row+1] = raw_recipe.items[i + j] or ""
                    end
                    recipe.recipe[#recipe.recipe+1] = row
                end
            end
        elseif raw_recipe.method == "fuel" or raw_recipe.method == "cooking" then
            recipe.type = raw_recipe.method
            recipe.recipe = raw_recipe.items[1]
        else
            logger:warning("Found invalid recipe type %s", raw_recipe.method)
            return nil
        end
        return recipe
    end

    local function safe_concat(tb, sep)
        local rtn = ""
        for i = 1, #tb do
            rtn = rtn .. (tb[i] or "")
            if i ~= #tb then
                rtn = rtn .. sep
            end
        end
        return rtn
    end

    for _, recipe in ipairs(recipes_found) do
        if recipe_is_unknown(recipe.items) then
            logger:warning("Cleared recipe with unknown item: method=%s, output=%s, width=%i, recipe={\"%s\"}",
                recipe.method, recipe.output, recipe.width, safe_concat(recipe.items, "\",\""))
            local craft_recipe = construct_recipe(recipe)
            if craft_recipe then
                minetest.clear_craft(craft_recipe)
            end
        end
    end
end)