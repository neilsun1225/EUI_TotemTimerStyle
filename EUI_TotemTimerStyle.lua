-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Ballyh (B站八厉害)
-- Display-only companion for EllesmereUI on WoW Forever.
local eui = _G.EllesmereUI
local ns = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIResourceBars
if not (eui and eui.IS_FOREVER and ns) then return end

local SIZE = 14
local R, G, B = 1, 212 / 255, 90 / 255 -- #FFD45A
local _, class = UnitClass("player")
local fontStrings = setmetatable({}, {__mode = "k"})
local cooldowns = setmetatable({}, {__mode = "k"})
local applying = false
local callFontHooked = false
local runtimeHooked = false
local queued = false

local function Settings(call)
    local db = ns.ERB and ns.ERB.db
    local profile = db and db.profile
    local s = profile and profile[call and "callTotemBar" or "totemBar"]
    if not s or s.showTimer == false then return end
    if call then
        if class ~= "SHAMAN" or not s.enabled then return end
    elseif not (s.enabledClasses and s.enabledClasses[class]) then
        return
    end
    return s
end

local function Style(target, call)
    if applying then return end
    local s = Settings(call)
    if not s or not target or (target.IsForbidden and target:IsForbidden()) then return end
    -- Match EUI's own scale compensation: active icons are natively 37 units,
    -- while the call bar's buttons are 30. Keep the module's selected typeface.
    local scale = (s.iconSize or 30) / (call and 30 or 37)
    local size = math.max(6, math.floor(SIZE / scale + 0.5))
    applying = true
    target:SetFont(eui.GetFontPath("resourceBars"), size, "THICKOUTLINE")
    target:SetTextColor(R, G, B, 1)
    target:SetShadowColor(0, 0, 0, 1)
    target:SetShadowOffset(1, -1)
    applying = false
end

local function TrackCooldown(cd)
    if not cd or (cd.IsForbidden and cd:IsForbidden()) then return end
    if not cooldowns[cd] then
        cooldowns[cd] = true
        -- Native countdown text may be created when EUI first shows numbers.
        hooksecurefunc(cd, "SetHideCountdownNumbers", TrackCooldown)
    end
    for _, fs in ipairs({cd:GetRegions()}) do
        if fs.GetObjectType and fs:GetObjectType() == "FontString" then
            if not fontStrings[fs] then
                fontStrings[fs] = true
                local function Restyle() Style(fs, false) end
                -- EUI's local layout function repaints font and white text on
                -- every refresh. Hook only this countdown instance's setters.
                hooksecurefunc(fs, "SetFont", Restyle)
                hooksecurefunc(fs, "SetFontObject", Restyle)
                hooksecurefunc(fs, "SetTextColor", Restyle)
            end
            Style(fs, false)
            break -- same native countdown FontString EUI uses
        end
    end
end

local function Refresh()
    if Settings(false) and _G.TotemFrame then
        for _, button in ipairs({_G.TotemFrame:GetChildren()}) do
            TrackCooldown(button.Icon and button.Icon.Cooldown)
        end
    end
    -- This font object belongs exclusively to EUI's Call Totem Bar. Changing
    -- it also covers every flyout page without touching shared UI fonts.
    local font = _G.ERB_CallTotemCountdownFont
    if font then
        if not callFontHooked then
            callFontHooked = true
            hooksecurefunc(font, "SetFont", function() Style(font, true) end)
        end
        Style(font, true)
    end
end

local function Setup()
    if runtimeHooked then return end
    runtimeHooked = true
    hooksecurefunc(ns.ERB, "ApplyAll", Refresh)
    if eui.LayoutTotemBar then hooksecurefunc(eui, "LayoutTotemBar", Refresh) end
    if ns.CT_Apply then hooksecurefunc(ns, "CT_Apply", Refresh) end
    if _G.TotemFrame then
        hooksecurefunc(_G.TotemFrame, "Update", Refresh)
        _G.TotemFrame:HookScript("OnShow", Refresh)
    end
end

local function ScheduleRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Setup()
        Refresh()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TOTEM_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", ScheduleRefresh)
