local frame = CreateFrame('Frame')

local subscriptions = {}
frame:SetScript(
    'OnEvent',
    function(self, event, ...)
        if subscriptions[event] then
            for callback, _ in pairs(subscriptions[event]) do
                if callback ~= 'count' then
                    xpcall(callback, geterrorhandler(), event, ...)
                end
            end
        end
    end
)
-- callback的参数为(event, ...)，保留event是为了可以设置为print函数直接打印
function BananaRegisterEvent(event, callback)
    assert(type(callback) == 'function')
    local need_register = false
    if not subscriptions[event] then
        subscriptions[event] = {count = 0}
        need_register = true
    end
    if not subscriptions[event][callback] then
        subscriptions[event][callback] = true
        subscriptions[event].count = subscriptions[event].count + 1
    end
    if need_register then
        -- print('frame:RegisterEvent', event)
        frame:RegisterEvent(event)
    end
    -- DevTools_Dump(subscriptions)
end
function BananaRegisterEventOnce(event, callback)
    -- 如果用local f = function()，那么必须先定义local f，参见 https://www.lua.org/pil/6.2.html
    local function run_once(...)
        BananaUnregisterEvent(event, run_once)
        callback(...)
    end
    BananaRegisterEvent(event, run_once)
end
function BananaUnregisterEvent(event, callback)
    assert(type(callback) == 'function')
    local need_unregister = false
    if subscriptions[event] then
        if subscriptions[event][callback] then
            subscriptions[event][callback] = nil
            subscriptions[event].count = subscriptions[event].count - 1
        end
        if subscriptions[event].count < 1 then
            subscriptions[event] = nil
            need_unregister = true
        end
    end
    if need_unregister then
        -- print('frame:UnregisterEvent', event)
        frame:UnregisterEvent(event)
    end
    -- DevTools_Dump(subscriptions)
end
-- BananaRegisterEvent('ADDON_LOADED', print)
-- BananaRegisterEventOnce('ADDON_LOADED', ConsoleAddMessage)
-- BananaUnregisterEvent('ADDON_LOADED', print)

function BananaOnAddonLoaded(name, callback)
    assert(type(callback) == 'function')
    loaded, finished = C_AddOns.IsAddOnLoaded(name)
    if loaded and finished then
        callback()
    else
        local function f(ev, n)
            if n == name then
                BananaUnregisterEvent('ADDON_LOADED', f)
                callback()
            end
        end
        BananaRegisterEvent('ADDON_LOADED', f)
    end
end
-- BananaOnAddonLoaded('Blizzard_EncounterJournal', nil)

local function seq_num_widget_iter_func(prefix, index)
    index = index + 1
    local widget = _G[prefix .. index]
    if widget then
        return index, widget
    end
end
function BananaStaticPopupIterator()
    return seq_num_widget_iter_func, 'StaticPopup', 0
end
-- callback的参数为(which, dialog)，保留which是为了方便设置为print打印
function BananaHookStaticPopup(which, callback)
    -- 不再hook StaticPopup_Show，避免每次循环的消耗
    -- 总共4个内置对话框，参见 Interface\AddOns\Blizzard_StaticPopup_Frame\Mainline\StaticPopupDialogFrames.xml
    local function hook(dialog)
        if dialog.which == which then
            xpcall(callback, geterrorhandler(), which, dialog)
        end
    end
    for _, dialog in BananaStaticPopupIterator() do
        dialog:HookScript('OnShow', hook)
    end
end
-- BananaHookStaticPopup('BANK_MONEY_WITHDRAW', print)

-- SlashCmdList_AddSlashCommand函数不存在
function BananaAddSlashCommand(callback, ...)
    local nargs = select('#', ...)
    assert(nargs > 0)
    local name = select(1, ...)
    if string.sub(name, 1, 1) == '/' then
        name = string.sub(name, 2)
    end
    name = string.upper(name)
    SlashCmdList[name] = callback
    for i = 1, nargs do
        setglobal('SLASH_' .. name .. i, select(i, ...))
    end
end

-- 搜索全局字符串
BananaAddSlashCommand(
    function(pattern)
        for k, v in pairs(_G) do
            if type(v) == 'string' then
                if string.match(k, pattern) or string.match(v, pattern) then
                    print(k, v)
                end
            end
        end
    end,
    '/find'
)

function BananaOnCombatStateChanged(callback)
    BananaRegisterEvent(
        'PLAYER_REGEN_DISABLED',
        function()
            callback(true)
        end
    )
    BananaRegisterEvent(
        'PLAYER_REGEN_ENABLED',
        function()
            callback(false)
        end
    )
    callback(UnitAffectingCombat('player'))
end

function BananaOnUIParentToggle(callback)
    UIParent:HookScript(
        'OnShow',
        function()
            callback(true)
        end
    )
    UIParent:HookScript(
        'OnHide',
        function()
            callback(false)
        end
    )
    callback(UIParent:IsShown())
end

function BananaOnLoggedIn(callback)
    assert(type(callback) == 'function')
    if IsLoggedIn() then
        callback()
    else
        BananaRegisterEventOnce('PLAYER_LOGIN', callback)
    end
end

local tasks = {}
-- callback是函数或协程，返回值为下一次执行间隔时间，nil则在tasks中自动删除，也就是停止执行
function BananaAddTask(callback, after)
    local typ = type(callback)
    assert(typ == 'function' or typ == 'thread')
    if not after then
        after = 0
    end
    tasks[callback] = after
end
frame:SetScript(
    'OnUpdate',
    function(self, elapsed)
        for callback, after in pairs(tasks) do
            if after > 0 then
                tasks[callback] = after - elapsed
            else
                local typ = type(callback)
                local status, result
                -- pcall与coroutine.resume的行为模式相同
                if typ == 'function' then
                    status, result = pcall(callback)
                elseif typ == 'thread' then
                    status, result = coroutine.resume(callback)
                end
                if status then
                    tasks[callback] = result
                else
                    tasks[callback] = nil
                    HandleLuaError(result)
                end
            end
        end
    end
)
