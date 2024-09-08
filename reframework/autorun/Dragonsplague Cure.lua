-- The Dragonsplague Cure Team --

local WriteInfoLogs = false -- Set to true to enable info logging

local Re = re
local Sdk = sdk
local Log = log
local Json = json

-- Attempt to require the Hotkeys utility
local status, Hotkeys = pcall(require, "Hotkeys/Hotkeys")
local HotkeysAvailable = status  -- True if Hotkeys utility is available

-- Log Functions
local function log_info(info_message)
    if WriteInfoLogs then
        Log.info("[Mr. Boobie Buyer > Dragonsplague Cure]: " .. info_message)
    end
end

local function log_error(error_message)
    Log.error("[Mr. Boobie Buyer > Dragonsplague Cure]: " .. error_message)
end

log_info("Loaded")

local Config = {}

-- Only setup hotkeys if Hotkeys utility is available
if HotkeysAvailable then
    Config.Hotkeys = {
        ["Dragonsplague Cure Key"] = "Y",
    }

    -- Setup hotkeys if available
    Hotkeys.setup_hotkeys(Config.Hotkeys)
end

local ConfigFilePath = "Mr. Boobie\\Dragonsplague Cure.json"

local function save_config()
    local success, err = pcall(Json.dump_file, ConfigFilePath, Config)
    if not success then
        log_error("Error saving configuration: " .. tostring(err))
    end
end

local function load_config()
    local status, data = pcall(Json.load_file, ConfigFilePath)
    if not status or not data then
        Config.EnableSpecificCure = false
        Config.Prevention = true
        return
    end

    if type(data) == "table" then
        if data.Hotkeys and HotkeysAvailable then
            Config.Hotkeys = data.Hotkeys
            Hotkeys.setup_hotkeys(Config.Hotkeys)
        end

        Config.EnableSpecificCure = data.enable_specific_cure
        if Config.EnableSpecificCure == nil then
            Config.EnableSpecificCure = false
        end

        Config.Prevention = data.Prevention ~= nil and data.Prevention or true
    else
        Config.EnableSpecificCure = false
        Config.Prevention = true
    end
end

load_config()

Sdk.hook(
    Sdk.find_type_definition("app.PawnDataContext"):get_method("setPossessionLv"),
    function(args)
        if Config.Prevention then
            local arg2 = Sdk.to_managed_object(args[2])
            args[3] = Sdk.to_ptr(0)
        end
        -- If Prevention is off, do nothing and allow the original function to proceed normally
    end,
    nil
)

Sdk.hook(
    Sdk.find_type_definition("app.FacilityManager"):get_method("judgPossession"),
    nil,
    function(rtval)
        if Config.Prevention then
            rtval = Sdk.to_ptr(false)
        end
        return rtval
    end
)

local function get_pawns_status()
    local pawn_mgr = Sdk.get_managed_singleton("app.PawnManager")
    if not pawn_mgr then
        return "Manager Not Found", {}
    end

    local c_list = pawn_mgr:get_PawnCharacterList()
    if not c_list then
        return "List Not Found", {}
    end

    local PawnDataContextDefine = Sdk.find_type_definition("app.PawnDataContext")
    local typeofPawnDataContext = PawnDataContextDefine:get_runtime_type()

    local mainPawnStatus = "Not Found"
    local hiredPawnsStatus = {}

    for i = 0, c_list:get_Count() - 1 do
        local pawn_chara = c_list:get_Item(i)
        local pawn_chara_id = pawn_chara:get_CharaIDString()
        local generate_info = pawn_chara:get_GenerateInfo()
        if generate_info then
            local context_holder = generate_info:get_Context()
            local pawnDataContextInfo = context_holder.Contexts[typeofPawnDataContext]
            if pawnDataContextInfo then
                local pawnDataContext = pawnDataContextInfo:get_CurrentContext()
                if pawn_chara_id == "ch100000_00" then
                    mainPawnStatus = pawnDataContext:get_field("_PossessionLv")
                else
                    local name = pawnDataContext:get_field("_Name")
                    local possessionLevel = pawnDataContext:get_field("_PossessionLv")
                    table.insert(hiredPawnsStatus, { name = name, possessionLevel = possessionLevel })
                end
            end
        end
    end

    return mainPawnStatus, hiredPawnsStatus
end

local function set_main_pawn_possession_lv(level)
    local pawn_mgr = Sdk.get_managed_singleton("app.PawnManager")
    if not pawn_mgr then return "Manager Not Found" end

    local c_list = pawn_mgr:get_PawnCharacterList()
    if not c_list then return "List Not Found" end

    for i = 0, c_list:get_Count() - 1 do
        local pawn_chara = c_list:get_Item(i)
        if pawn_chara then
            local pawn_chara_id = pawn_chara:get_CharaIDString()
            if pawn_chara_id == "ch100000_00" then
                local generate_info = pawn_chara:get_GenerateInfo()
                if generate_info then
                    local context_holder = generate_info:get_Context()
                    if context_holder then
                        local PawnDataContextDefine = Sdk.find_type_definition("app.PawnDataContext")
                        local typeofPawnDataContext = PawnDataContextDefine:get_runtime_type()
                        local pawnDataContextInfo = context_holder.Contexts[typeofPawnDataContext]
                        if pawnDataContextInfo then
                            local pawnDataContext = pawnDataContextInfo:get_CurrentContext()
                            if pawnDataContext then
                                pawnDataContext:set_field("_PossessionLv", 7)
                                pawnDataContext:set_field("_PossessionProgressPoint", 10000)
                                log_info("Possession Level Set for Main Pawn")
                                return "Possession Level Set"
                            end
                        end
                    end
                end
            end
        end
    end
    return "Main Pawn Not Found"
end

local function cure_pawns()
    local pawn_mgr = Sdk.get_managed_singleton("app.PawnManager")
    if not pawn_mgr then
        log_error("Manager Not Found")
        return
    end

    local c_list = pawn_mgr:get_PawnCharacterList()
    if not c_list then
        log_error("List Not Found")
        return
    end

    local PawnDataContextDefine = Sdk.find_type_definition("app.PawnDataContext")
    local typeofPawnDataContext = PawnDataContextDefine:get_runtime_type()

    for i = 0, c_list:get_Count() - 1 do
        local pawn_chara = c_list:get_Item(i)
        local pawn_chara_id = pawn_chara:get_CharaIDString()

        if not Config.EnableSpecificCure or (Config.EnableSpecificCure and pawn_chara_id == "ch100000_00") then
            local generate_info = pawn_chara:get_GenerateInfo()
            local context_holder = generate_info:get_Context()
            local pawnDataContextInfo = context_holder.Contexts[typeofPawnDataContext]
            if pawnDataContextInfo then
                local pawnDataContext = pawnDataContextInfo:get_CurrentContext()
                pawnDataContext:setPossessionLv(0)
                log_info("Cured pawn with ID: " .. tostring(pawn_chara_id))
            end
        end
    end
end

Re.on_frame(function()
    if HotkeysAvailable and Hotkeys.check_hotkey("Dragonsplague Cure Key", false, true) then
        local PawnDataContextDefine = Sdk.find_type_definition("app.PawnDataContext")
        local typeofPawnDataContext = PawnDataContextDefine:get_runtime_type()
        local pawn_mgr = Sdk.get_managed_singleton("app.PawnManager")
        local c_list = pawn_mgr:get_PawnCharacterList()
        local size = c_list:get_Count()

        if Config.EnableSpecificCure then
            log_info("Curing specific pawn (ch100000_00) only.")
        else
            log_info("Curing all pawns.")
        end

        for i = 0, size - 1 do
            local pawn_chara = c_list:get_Item(i)
            local pawn_chara_id = pawn_chara:get_CharaIDString()

            if not Config.EnableSpecificCure or (Config.EnableSpecificCure and pawn_chara_id == "ch100000_00") then
                local generate_info = pawn_chara:get_GenerateInfo()
                local context_holder = generate_info:get_Context()
                local pawnDataContextInfo = context_holder.Contexts[typeofPawnDataContext]

                if pawnDataContextInfo ~= nil then
                    local pawnDataContext = pawnDataContextInfo:get_CurrentContext()
                    pawnDataContext:setPossessionLv(0)
                    log_info("Curing pawn with ID: " .. tostring(pawn_chara_id))
                end
            end
        end
    end
end)

Re.on_draw_ui(function()
    if imgui.tree_node("Dragonsplague Cure") then
        local configChanged = false

        -- Button for Curing Pawns
        local buttonWidth = 75
        local buttonHeight = 30
        local buttonSize = { buttonWidth, buttonHeight }
        if imgui.button("Cure", buttonSize) then
            cure_pawns()
        end

        -- Pawn Status Tree
        if imgui.tree_node("Pawn Status") then
            local mainPawnStatus, hiredPawnsStatus = get_pawns_status()

            -- Display Main Pawn Status
            imgui.text("Main Pawn Infection Level: " .. tostring(mainPawnStatus))

            -- Display Hired Pawn Status
            for _, pawn in ipairs(hiredPawnsStatus) do
                if pawn.name and pawn.possessionLevel then
                    imgui.text(pawn.name .. "'s Infection Level: " .. tostring(pawn.possessionLevel))
                end
            end

            -- Button for Infecting Main Pawn
            if imgui.button("Infect Main Pawn") then
                local setResult = set_main_pawn_possession_lv()
                log_info(setResult)
            end

            imgui.tree_pop()
        end

        -- Dragonsplague Cure Config Tree
        if imgui.tree_node("Dragonsplague Cure Config") then
            -- Checkbox for "Main Pawn Only"
            local checkBoxChanged, checkBoxValue = imgui.checkbox("Enable Main Pawn Only", Config.EnableSpecificCure)
            if checkBoxChanged then
                Config.EnableSpecificCure = checkBoxValue
                configChanged = true
            end

            -- Checkbox for "Prevention"
            local preventionChanged, preventionValue = imgui.checkbox("Prevention", Config.Prevention)
            if preventionChanged then
                Config.Prevention = preventionValue
                configChanged = true
            end

        -- Hotkey setter (only if Hotkeys are available)
        if HotkeysAvailable then
            local hotkeyChanged = Hotkeys.hotkey_setter("Dragonsplague Cure Key")
            if hotkeyChanged then
                Config.Hotkeys["Dragonsplague Cure Key"] = Hotkeys.get_hotkey("Dragonsplague Cure Key")
                configChanged = true
            end
        end

            imgui.tree_pop()
        end

        if configChanged then
            save_config()
        end

        imgui.tree_pop()
    end
end)
