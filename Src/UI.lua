-- HUD十字线
-- 放在另开的BananaHUDFrame里面的问题是，无法置于姓名版后面，因为无法设置frameStrata为WORLD，所以这里手工在WorldFrame里面创建
local gradient_solid = CreateColor(1, 1, 1, 1)
local gradient_transparent = CreateColor(1, 1, 1, 0)
local crosshair_top = WorldFrame:CreateTexture(nil, 'BACKGROUND')
crosshair_top:SetPoint('TOP')
crosshair_top:SetPoint('BOTTOM', WorldFrame, 'CENTER')
crosshair_top:SetGradient('VERTICAL', gradient_transparent, gradient_solid)
local crosshair_bottom = WorldFrame:CreateTexture(nil, 'BACKGROUND')
crosshair_bottom:SetPoint('BOTTOM')
crosshair_bottom:SetPoint('TOP', WorldFrame, 'CENTER')
crosshair_bottom:SetGradient('VERTICAL', gradient_solid, gradient_transparent)
local crosshair_left = WorldFrame:CreateTexture(nil, 'BACKGROUND')
crosshair_left:SetPoint('LEFT')
crosshair_left:SetPoint('RIGHT', WorldFrame, 'CENTER')
crosshair_left:SetGradient('HORIZONTAL', gradient_solid, gradient_transparent)
local crosshair_right = WorldFrame:CreateTexture(nil, 'BACKGROUND')
crosshair_right:SetPoint('RIGHT')
crosshair_right:SetPoint('LEFT', WorldFrame, 'CENTER')
crosshair_right:SetGradient('HORIZONTAL', gradient_transparent, gradient_solid)
BananaOnCombatStateChanged(
    function(combat)
        local r, g, b = 0, 0, 0
        local thickness = 1
        if combat then
            r, g, b = 1, 0, 0
            thickness = 4
        end
        crosshair_top:SetColorTexture(r, g, b)
        crosshair_top:SetWidth(thickness)
        crosshair_bottom:SetColorTexture(r, g, b)
        crosshair_bottom:SetWidth(thickness)
        crosshair_left:SetColorTexture(r, g, b)
        crosshair_left:SetHeight(thickness)
        crosshair_right:SetColorTexture(r, g, b)
        crosshair_right:SetHeight(thickness)
    end
)
BananaOnUIParentToggle(
    function(shown)
        crosshair_top:SetShown(shown)
        crosshair_bottom:SetShown(shown)
        crosshair_left:SetShown(shown)
        crosshair_right:SetShown(shown)
    end
)

-- 关闭试玩订阅（升级为付费账号）面板，注意11.0为secure addon无法disable
-- Interface\AddOns\Blizzard_SubscriptionInterstitialUI\Blizzard_SubscriptionInterstitialUI.lua
-- UIParentLoadAddOn('Blizzard_SubscriptionInterstitialUI')有时候会失败
local function close_subscription()
    SubscriptionInterstitialFrame:UnregisterEvent('SHOW_SUBSCRIPTION_INTERSTITIAL')
    HideUIPanel(SubscriptionInterstitialFrame)
end
BananaOnAddonLoaded(
    'Blizzard_SubscriptionInterstitialUI',
    function()
        SubscriptionInterstitialFrame:HookScript('OnLoad', close_subscription)
        close_subscription()
    end
)

-- 禁用TalkingHead（界面编辑器里的名字是“对家特写头像”），保留语音
-- Interface\AddOns\Blizzard_FrameXML\TalkingHeadUI.lua
-- 原FrameXML里的都搬到Blizzard_FrameXML插件里来了，多此一举，吃饱撑的，该插件有LoadFirst标记，不需要再手动加载了，否则报错“Cannot manually load a LoadFirst AddOn”
TalkingHeadFrame.PlayCurrent = function(self)
    local displayInfo, cameraID, vo, duration, lineNumber, numLines, name, text, isNewTalkingHead, textureKit = C_TalkingHead.GetCurrentLineInfo()
    local textFormatted = string.format(text)
    if (displayInfo and displayInfo ~= 0) then
        local success, voHandle = PlaySound(vo, 'Talking Head', true, true)
        if (success) then
            self.voHandle = voHandle
        end
    end
end

-- 禁用EventToast（日常、场景事件、进入副本等屏幕中上方的介绍界面）
-- Interface\AddOns\Blizzard_FrameXML\EventToastManager.lua
-- 暴雪代码里面，DISPLAY_EVENT_TOASTS事件调用DisplayToast(true)，在ToastingEnded()中会再次调用DisplayToast(nil)，区别是后续调用会执行C_EventToastManager.RemoveCurrentToast()，这其实是一个循环，直到“积压”的toast全部放完为止
EventToastManagerFrame:SetScript(
    'OnEvent',
    function(self, event, ...)
        if (event == 'DISPLAY_EVENT_TOASTS') then
            -- print('DISPLAY_EVENT_TOASTS')
            while C_EventToastManager.GetNextToastToDisplay() do
                -- print('C_EventToastManager.RemoveCurrentToast()')
                C_EventToastManager.RemoveCurrentToast()
            end
        end
    end
)
EventToastManagerFrame:ReleaseToasts()
EventToastManagerFrame:Reset()

-- 禁用BossBanner（BOSS击杀后的屏幕中上方的信息界面）
-- Interface\AddOns\Blizzard_FrameXML\BossBannerToast.lua
BossBanner:UnregisterAllEvents()
BossBanner:SetScript('OnEvent', nil)

-- 禁用AlertFrame（副本里BOSS拾取之类的一堆从底向上充斥屏幕的弹出）
-- AlertFrame:UnregisterAllEvents()
local sound_handle -- 防止重叠播放
AlertFrame:SetScript(
    'OnEvent',
    function(self, event, ...)
        -- print(event, ...)
        -- 参见 https://warcraft.wiki.gg/wiki/API_PlaySoundFile https://old.wow.tools/files/#search=SealOfMight&page=1&sort=0&desc=asc
        -- 貌似文件路径的方式在8.2取消了，'sound/spells/sealofmight.ogg'不行，只能用id
        -- 在 https://old.wow.tools/dbc/?dbc=soundkitentry&build=10.0.5.47660#page=1&colFilter[2]=568274 查询对应soundKitID为1455、20173、129982，经PlaySound测试只有1、3对的，且 Interface\AddOns\Blizzard_SharedXML\Mainline\SoundKitConstants.lua 里面没有对应的名字
        local is_playing = sound_handle and C_Sound.IsPlaying(sound_handle)
        if not is_playing then
            _, sound_handle = PlaySoundFile(568274)
        end
    end
)

-- 禁用LootFrame动画
-- Interface\AddOns\Blizzard_UIPanels_Game\Mainline\LootFrame.lua
UIParentLoadAddOn('Blizzard_UIPanels_Game')
-- 狗日的ScrollingFlatPanelMixin也就LootFrame一个用，还他妈设置继承关系，有病
local function disable_animations(...)
    for i = 1, select('#', ...) do
        local anim = select(i, ...)
        anim:SetDuration(0.000000000000000001) -- 不能设为0，否则拾取框里的东西不见了
    end
end
local function disable_animation_groups(...)
    for i = 1, select('#', ...) do
        local anim_g = select(i, ...)
        disable_animations(anim_g:GetAnimations())
    end
end
disable_animation_groups(LootFrame:GetAnimationGroups())
-- 这套mvc代码恶心得一批，mixin层层叠叠，狗屎阿三
hooksecurefunc(
    LootFrame,
    'Open',
    function()
        -- print('LootFrame:Open')
        for i, v in ipairs(LootFrame.ScrollBox:GetView():GetFrames()) do
            if not v.animation_disabled then
                disable_animation_groups(v:GetAnimationGroups())
                v.animation_disabled = true
            end
        end
    end
)
-- 删掉右滑动画
LootFrame:HookScript(
    'OnEvent',
    function(self, event, ...)
        if event == 'LOOT_SLOT_CLEARED' then
            local slotIndex = ...
            local frame =
                self.ScrollBox:FindFrameByPredicate(
                function(frame)
                    return frame:GetSlotIndex() == slotIndex
                end
            )
            if frame then
                if self.isAutoLoot and frame.SlideOutRightAnim then
                    frame.SlideOutRightAnim:Stop()
                end
            end
        end
    end
)

-- 聊天框左右移动光标无需按alt键
-- Interface\AddOns\Blizzard_ChatFrameBase\Mainline\ChatFrame.lua
hooksecurefunc(
    'ChatEdit_ActivateChat',
    function(editBox)
        editBox:SetAltArrowKeyMode(false)
    end
)

-- 屏蔽某些令人厌恶的声音，比如德鲁伊变形乌鸦的聒噪的叫声
-- Mute certain annoying sounds such as druid crow form shapeshifting
for i = 1570532, 1570536 do
    MuteSoundFile(i)
end
for i = 1570545, 1570546 do
    MuteSoundFile(i)
end
MuteSoundFile(1570541)
-- Headless Horseman Voices
-- https://old.wow.tools/files/#search=Horseman%2Ctype%3Aogg&page=1&sort=0&desc=asc
for i = 551670, 551706 do
    MuteSoundFile(i)
end

-- 屏蔽周围玩家的成就通告，以及团队里别人的拾取信息、说话、大喊、表情、密语等垃圾信息
local function chat_filter(frame, event, ...)
    -- print(event, ...)
    return select(12, ...) ~= UnitGUID('player')
end
local function group_chat_filter(frame, event, ...)
    -- print(event, ...)
    return IsInGroup() and select(12, ...) ~= UnitGUID('player')
end
ChatFrame_AddMessageEventFilter('CHAT_MSG_ACHIEVEMENT', chat_filter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_LOOT', group_chat_filter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_SAY', group_chat_filter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_YELL', group_chat_filter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_EMOTE', group_chat_filter)
ChatFrame_AddMessageEventFilter('CHAT_MSG_WHISPER', group_chat_filter)

-- 弹出对话框贴顶并移除边框
-- StaticPopup_DisplayedFrames变为局部变量了，原先代码不可用
-- 另外不能用UIParent了，因为已改为GetFullscreenFrame()，未必是UIParent，比如在Blizzard_PerksProgram就会修改，应该是商栈界面？
-- 测试代码：/run StaticPopup_Show("ERROR_CINEMATIC");StaticPopup_Show("CONFIRM_RESET_INSTANCES");message("foo")
hooksecurefunc(
    'StaticPopup_Show',
    function()
        for _, dialog in BananaStaticPopupIterator() do
            if dialog:IsShown() then
                local point, relative_to, relative_point, offset_x, offset_y = dialog:GetPointByName('TOP')
                if relative_point == 'TOP' then
                    dialog:SetPoint(point, relative_to, relative_point, offset_x, 0)
                end
            end
        end
    end
)
-- DialogBorderTemplate里的边框
local border_names = {
    'TopEdge',
    'BottomEdge',
    'LeftEdge',
    'RightEdge',
    'TopLeftCorner',
    'TopRightCorner',
    'BottomLeftCorner',
    'BottomRightCorner'
}
local function hide_borders(frame)
    for _, v in ipairs(border_names) do
        frame[v]:Hide()
    end
end
for _, dialog in BananaStaticPopupIterator() do
    hide_borders(dialog.Border)
end
BasicMessageDialog:ClearAllPoints()
BasicMessageDialog:SetPoint('TOP')
hide_borders(BasicMessageDialog.Border)

-- 提示信息置顶
UIErrorsFrame:SetPoint('TOP', UIParent, 0, 0)
ZoneTextFrame:SetPoint('TOP', UIParent, 0, 0)
RaidWarningFrame:SetPoint('TOP', UIParent, 0, 0)
RaidBossEmoteFrame:SetPoint('TOP', UIParent, 0, 0)

-- 目标或焦点血量低警告
local last_health_percent_table = {}
local health_percent_alarm_threshold = 0.2
BananaRegisterEvent(
    'UNIT_HEALTH',
    function(event, unit)
        if unit == 'target' or unit == 'focus' then
            local hp = UnitHealth(unit) / UnitHealthMax(unit)
            local last_hp = last_health_percent_table[unit]
            if last_hp and last_hp >= health_percent_alarm_threshold and hp < health_percent_alarm_threshold then
                -- print(unit, last_hp, hp)
                FlashClientIcon()
            end
            last_health_percent_table[unit] = hp
        end
    end
)

-- 增大迷你地图部件
MinimapCluster.IndicatorFrame:SetScale(2) -- 邮件提醒

-- 搜索TopBannerManager_Show，用到的地方比如9.0圣所、艾泽里特、名望、世界任务等
-- 会造成右侧世界任务物品无法使用，提示“...已被禁用...”对话框，已确认，因为会有污染，右侧任务列表里的物品按钮应该是secure的
-- hooksecurefunc(
--     'TopBannerManager_Show',
--     function(frame, data, isExclusiveQueued)
--         frame:StopBanner()
--     end
-- )

-- 角色面板增加伤害和移动速度
-- 在 Interface\AddOns\Blizzard_UIPanels_Game\Mainline\PaperDollFrame.lua 里面其实都有预定义
table.insert(PAPERDOLL_STATCATEGORIES[1].stats, {stat = 'ATTACK_DAMAGE'})
table.insert(PAPERDOLL_STATCATEGORIES[1].stats, {stat = 'MOVESPEED'})
