local hooks = {}

local menuController = {
    initialized = false,
    menuPage = {
        pose = 2,
    },
    menuItem = {
        characterAttribute = 38,
        characterVisibleAttribute = 27,
        replacerAttribute = 9000,
        replacerAppearanceAttribute = 9001,
        replacerLabel = 'REPLACER CHARACTER',
        appearanceLabel = 'REPLACER APPEARANCE',
    },
    data = {
        currHeaderIndex = nil,
        currAppIndex = nil,
        currHeaderCount = nil,
        currAppCount = nil,
        currHeader = nil,
        currParsedApp = nil,
        currUnparsedApp = nil,
    },
    locName = {
        v = nil,
        johnny = nil,
        nibbles = nil,
    },
    list = {
        parsedApps = {},
        unparsedApps = {},
    },
}

-- Local Variables --

local isPhotoModeActive = false
local currID = nil
local parsedTable = {}
local appearanceTable = {}
local currEntity = {
    v = 1,
    j = 1,
}

-- Accessors --

---@param newV string
---@param newJ string
---@param newN string
function hooks.SetLocNames(newV, newJ, newN)
    menuController.locName.v = newV
    menuController.locName.johnny = newJ
    menuController.locName.nibbles = newN
end

function hooks.SetParsedTable(table)
    parsedTable = table
end

function SetCurrEntity(vIndex, jIndex)
    currEntity.v = vIndex
    currEntity.j = jIndex
end

-- Menu Controller Functions --

---@param this gameuiPhotoModeMenuController
local function SetupMenuControllerItems(this)
    menuController.characterMenuItem = this:GetMenuItem(menuController.menuItem.characterAttribute)
    menuController.headerMenuItem = this:GetMenuItem(menuController.menuItem.replacerAttribute)
    menuController.appearanceMenuItem = this:GetMenuItem(menuController.menuItem.replacerAppearanceAttribute)
    menuController.visibleMenuItem = this:GetMenuItem(menuController.menuItem.characterVisibleAttribute)
end

---@param character string
---@param headerMenuItem PhotoModeMenuListItem
---@param appearanceMenuItem PhotoModeMenuListItem
local function RestrictAppearanceMenuItems(character, headerMenuItem, appearanceMenuItem)
    -- If Nibbles is selected, disable menu items
    if character == menuController.locName.nibbles then
        headerMenuItem.OptionLabelRef:SetText('-')
        headerMenuItem.OptionSelector.index = 0
        appearanceMenuItem.OptionLabelRef:SetText('-')
        appearanceMenuItem.OptionSelector.index = 0
    -- If default Johnny is selected
    elseif character == menuController.locName.johnny and currEntity.j == 1 then
        appearanceMenuItem.OptionLabelRef:SetText(menuController.data.currParsedApp)
        appearanceMenuItem.OptionSelector.index = menuController.data.currAppIndex + 1
    -- For other cases where menuItems need to be restricted
    else
        headerMenuItem.OptionLabelRef:SetText(menuController.data.currHeader)
        headerMenuItem.OptionSelector.index = menuController.data.currHeaderIndex - 1
        appearanceMenuItem.OptionLabelRef:SetText(menuController.data.currParsedApp)
        appearanceMenuItem.OptionSelector.index = menuController.data.currAppIndex
    end
end

---@param headerIndex integer|nil
---@param appIndex integer|nil
---@param headerMenuItem PhotoModeMenuListItem|nil
---@param appearanceMenuItem PhotoModeMenuListItem|nil
local function UpdateMenuControllerData(headerIndex, appIndex, headerMenuItem, appearanceMenuItem)
    -- Will use current values if not being updated
    menuController.character = menuController.characterMenuItem.OptionLabelRef:GetText()
    menuController.visibleMenuIndex = menuController.visibleMenuItem.OptionSelector.index
    menuController.data.currHeaderIndex = headerIndex or menuController.data.currHeaderIndex
    menuController.data.currAppIndex = appIndex or menuController.data.currAppIndex
    menuController.data.currHeaderCount = headerMenuItem and headerMenuItem.OptionSelector:GetValuesCount() or menuController.data.currHeaderCount
    menuController.data.currAppCount = appearanceMenuItem and appearanceMenuItem.OptionSelector:GetValuesCount() or menuController.data.currAppCount
    menuController.data.currHeader = headerIndex and appearanceTable.headers[headerIndex] or menuController.data.currHeader
    menuController.data.currParsedApp = appIndex and menuController.list.parsedApps[appIndex] or menuController.data.currParsedApp
    menuController.data.currUnparsedApp = appIndex and menuController.list.unparsedApps[appIndex] or menuController.data.currUnparsedApp
end

local function ResetMenuControllerData()
    for key in pairs(menuController.data) do
        menuController.data[key] = nil
    end
    menuController.character = nil
    menuController.headerMenuItem = nil
    menuController.appearanceMenuItem = nil
    menuController.visibleMenuItem = nil
    menuController.visibleMenuIndex = nil
    menuController.list.parsedApps = {}
    menuController.list.unparsedApps = {}
    menuController.initialized = false
    currID = nil
end

-- Game Hooks --

---@param PMPR table
function hooks.Initialize(PMPR)
    Override("PhotoModeSystem", "IsPhotoModeActive", function(this, wrappedMethod)
        -- Prevent multiple calls on Override
        if isPhotoModeActive ~= wrappedMethod() then
            isPhotoModeActive = wrappedMethod()
            PMPR.modules.interface.state.isPhotoModeActive = wrappedMethod()
            if isPhotoModeActive then
                PMPR.modules.interface.SetNotificationMessage('Unavailable within Photo Mode\n')
            end
            -- Resets the condition for updating default appearance if user doesn't change replacers before reopening photo mode
            if not isPhotoModeActive and not PMPR.IsDefaultAppearance() then
                PMPR.ToggleDefaultAppearance(true)
            end
        end
        -- Needs reworked once a better Observer function is found for V's photo mode entity initialization
        if isPhotoModeActive and PMPR.IsDefaultAppearance() and currID and menuController.data.currUnparsedApp then
            local entity = PMPR.modules.util.LocatePlayerPuppet(currID)
            if entity then
                PMPR.modules.util.ChangeAppearance(entity, menuController.data.currUnparsedApp)
                PMPR.ToggleDefaultAppearance(false)
            end
        end
        if not isPhotoModeActive and menuController.initialized then
            ResetMenuControllerData()
        end
    end)

    Override("gameuiPhotoModeMenuController", "AddMenuItem", function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if page == menuController.menuPage.pose and attributeKey == menuController.menuItem.characterVisibleAttribute then
            this:AddMenuItem(menuController.menuItem.replacerLabel, menuController.menuItem.replacerAttribute, page, false)
            this:AddMenuItem(menuController.menuItem.appearanceLabel, menuController.menuItem.replacerAppearanceAttribute, page, false)
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnShow", function(this, reversedUI)
        local headerMenuItem = this:GetMenuItem(menuController.menuItem.replacerAttribute)
        local appearanceMenuItem = this:GetMenuItem(menuController.menuItem.replacerAppearanceAttribute)
        local characterMenuItem = this:GetMenuItem(menuController.menuItem.characterAttribute)
        local character = characterMenuItem.OptionLabelRef:GetText()
        local headerIndex = 0
        local appIndex = 0
        local defaultAppearance, entIndex, idIndex

        -- Initialize menu item values
        headerMenuItem.GridRoot:SetVisible(false)
        headerMenuItem.ScrollBarRef:SetVisible(false)
        headerMenuItem.OptionSelector:Clear()
        headerMenuItem.photoModeController = this
        appearanceMenuItem.GridRoot:SetVisible(false)
        appearanceMenuItem.ScrollBarRef:SetVisible(false)
        appearanceMenuItem.OptionSelector:Clear()
        appearanceMenuItem.photoModeController = this

        -- Prepare entity values
        SetCurrEntity(PMPR.GetVEntity(), PMPR.GetJEntity())

        -- Get base character (V or Johnny) based on the 'Character' menu name and get parsed table
        if character == menuController.locName.v then
            entIndex = currEntity.v
            idIndex = 1
            if entIndex == 1 then
                appearanceTable = {headers = {'-'}, data = {['-'] = {{parsed = '-', unparsed = '-'}}}}
                headerIndex = 1
                appIndex = 1
                PMPR.ToggleDefaultAppearance(false)
            else
                defaultAppearance = PMPR.modules.settings.defaultAppsV[currEntity.v]
            end
        elseif character == menuController.locName.johnny then
            entIndex = currEntity.j
            idIndex = 2
            defaultAppearance = PMPR.modules.settings.defaultAppsJ[currEntity.j]
        end

        -- Set persistent target ID data
        currID = PMPR.GetEntityID(idIndex)

        -- Populate appearance table for selected entity if not default photo mode V
        if not (character == menuController.locName.v and entIndex == 1) then
            appearanceTable = parsedTable[entIndex]
        end

        -- Update UI for default appearance settings if not default photo mode V
        if defaultAppearance then
            local censor = PMPR.modules.data.censor
            -- Convert appearanceName back to uncensored version
            for i, newTerm in ipairs(censor.newTerms) do
                if defaultAppearance:find(newTerm) then
                    defaultAppearance = defaultAppearance:gsub(newTerm, censor.oldTerms[i])
                end
            end
            local found = false
            -- Search for replacer being set
            for h, replacer in ipairs(appearanceTable.headers) do
                if found then break end
                -- Search for matching appearance
                for a, appearanceData in ipairs(appearanceTable.data[replacer]) do
                    if appearanceData.unparsed == defaultAppearance then
                        -- Return indexes of replacer and appearance
                        headerIndex = h
                        appIndex = a
                        found = true
                        break
                    end
                end
            end
            -- Fallback condition
            if not found then
                headerIndex = 1
                appIndex = 1
            end
        -- Fallback condition
        else
            headerIndex = 1
            appIndex = 1
        end

        -- Populate appearance data
        for _, appearanceData in ipairs(appearanceTable.data[appearanceTable.headers[headerIndex]]) do
            table.insert(menuController.list.parsedApps, appearanceData.parsed)
            table.insert(menuController.list.unparsedApps, appearanceData.unparsed)
        end

        -- Setup header menu item
        headerMenuItem.OptionSelector.index = headerIndex - 1
        headerMenuItem.OptionLabelRef:SetText(appearanceTable.headers[headerIndex])
        headerMenuItem.OptionSelector.values = appearanceTable.headers

        -- Setup appearance menu item
        appearanceMenuItem.OptionSelector.index = appIndex - 1
        appearanceMenuItem.OptionLabelRef:SetText(menuController.list.parsedApps[appIndex])
        appearanceMenuItem.OptionSelector.values = menuController.list.parsedApps

        SetupMenuControllerItems(this)
        UpdateMenuControllerData(headerIndex, appIndex, headerMenuItem, appearanceMenuItem)
        menuController.initialized = true
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeUpdated", function(this, attributeKey, attributeValue, doApply)
        if  menuController.initialized then

            -- If character attribute is updated
            if attributeKey == menuController.menuItem.characterAttribute then
                UpdateMenuControllerData()
                RestrictAppearanceMenuItems(menuController.character, menuController.headerMenuItem, menuController.appearanceMenuItem)
            end

            -- If header attribute is updated
            if attributeKey == menuController.menuItem.replacerAttribute then
                UpdateMenuControllerData()

                -- Prevent header options from changing in Nibbles options, when 'Character Visible' is set to 'Off' for V/Johnny, or when there is only one header value
                if menuController.character == menuController.locName.nibbles or menuController.visibleMenuIndex == 0 or menuController.data.currHeaderCount == 1 then
                    RestrictAppearanceMenuItems(menuController.character, menuController.headerMenuItem, menuController.appearanceMenuItem)
                else
                    local headerIndex = menuController.headerMenuItem.OptionSelector.index + 1
                    local entity = PMPR.modules.util.LocatePlayerPuppet(currID)
                    -- Clear appearance data
                    menuController.list.parsedApps = {}
                    menuController.list.unparsedApps = {}

                    -- Repopulate appearance data
                    for _, appearanceData in ipairs(appearanceTable.data[appearanceTable.headers[headerIndex]]) do
                        table.insert(menuController.list.parsedApps, appearanceData.parsed)
                        table.insert(menuController.list.unparsedApps, appearanceData.unparsed)
                    end

                    -- Update appearance menu item
                    menuController.appearanceMenuItem.OptionSelector.values = menuController.list.parsedApps
                    menuController.appearanceMenuItem.OptionSelector.index = 0
                    menuController.appearanceMenuItem.OptionLabelRef:SetText(menuController.list.parsedApps[1])

                    UpdateMenuControllerData((headerIndex), 1, menuController.headerMenuItem, menuController.appearanceMenuItem)
                    PMPR.modules.util.ChangeAppearance(entity, menuController.data.currUnparsedApp)
                end
            end

            -- If appearance attribute is updated
            if attributeKey == menuController.menuItem.replacerAppearanceAttribute then
                UpdateMenuControllerData()

                -- Prevent appearance options from changing in Nibbles options, when 'Character Visible' is set to 'Off' for V/Johnny, or when there is only one header value
                if menuController.character == menuController.locName.nibbles or menuController.visibleMenuIndex == 0 or menuController.data.currAppCount == 1 then
                    RestrictAppearanceMenuItems(menuController.character, menuController.headerMenuItem, menuController.appearanceMenuItem)
                else
                    local entity = PMPR.modules.util.LocatePlayerPuppet(currID)
                    UpdateMenuControllerData(nil, menuController.appearanceMenuItem.OptionSelector.index + 1, nil, menuController.appearanceMenuItem)
                    PMPR.modules.util.ChangeAppearance(entity, menuController.data.currUnparsedApp)
                end
            end
        end
    end)
end

return hooks