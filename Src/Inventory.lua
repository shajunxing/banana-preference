-- 物品信息，取代Item、ItemLocation等table，避免内存浪费，使用item_link能获取更精确的信息
local function get_item_inventory_type(item_link)
    -- print(C_Item.GetItemInventoryTypeByID(item_link), select(9, GetItemInfo(item_link)))
    return C_Item.GetItemInventoryTypeByID(item_link)
end
local function get_item_level(item_link)
    -- print(item_link, C_Item.GetDetailedItemLevelInfo(item_link))
    return C_Item.GetDetailedItemLevelInfo(item_link)
end
local function get_item_quality(item_link)
    return C_Item.GetItemQualityByID(item_link)
end
local function does_item_exist(item_link)
    return C_Item.DoesItemExistByID(item_link)
end
local function get_item_id(item_link)
    local item_id = C_Item.GetItemInfoInstant(item_link)
    return item_id
end
local function on_item_load(item_link, callback)
    -- 加入判断item_link合法性，调用方就无需判断了
    if item_link and does_item_exist(item_link) then
        ItemEventListener:AddCallback(get_item_id(item_link), callback)
    end
end
local function for_each_bag_item(callback)
    for bag_id = 0, 4 do
        local num_slots = C_Container.GetContainerNumSlots(bag_id)
        if num_slots and num_slots > 0 then
            for slot_index = 1, num_slots do
                local item_link = C_Container.GetContainerItemLink(bag_id, slot_index)
                if item_link then
                    callback(bag_id, slot_index, item_link)
                end
            end
        end
    end
end

-- 从战团银行存钱时自动填写背包中的金币数量
-- Automatically fills in number of gold coins in backpack when depositing money from account bank
StaticPopupDialogs['BANK_MONEY_DEPOSIT'].OnShow = function(self) -- 参见StaticPopup_OnShow，OnShow是可用的
    MoneyInputFrame_SetCopper(self.moneyInputFrame, GetMoney())
end
-- 注意，经测试，试玩账号取钱必须注意，超过1000金币的都会被吃掉，此处加上警告
-- 有时候对话框里的金额会发生异常无法输入，估计是GetRestrictedAccountData()返回错误的值导致，这里改为放在PLAYER_LOGIN之后执行
BananaOnLoggedIn(
    function()
        if IsTrialAccount() or IsVeteranTrialAccount() or IsRestrictedAccount() then
            StaticPopupDialogs['BANK_MONEY_WITHDRAW'].showAlert = true
            local _, max_carry, _ = GetRestrictedAccountData()
            local fmt = GetLocale() == 'zhCN' and '注意：试玩账号持有上限为 %s，超出部分将被系统吞掉！' or 'Note: The maximum amount held by trial account is %s, excess amount will be swallowed by the system!'
            StaticPopupDialogs['BANK_MONEY_WITHDRAW'].text = '|cffff3366' .. string.format(fmt, GetMoneyString(max_carry, true)) .. '|r|n' .. BANK_MONEY_WITHDRAW_PROMPT
            BananaHookStaticPopup(
                'BANK_MONEY_WITHDRAW',
                function(which, dialog)
                    -- 参见 Interface\AddOns\Blizzard_MoneyFrame\Mainline\MoneyInputFrame.lua:122
                    local moneyFrame = dialog.moneyInputFrame
                    dialog.moneyInputFrame.onValueChangedFunc = function()
                        local max_widhdraw = max_carry - GetMoney()
                        if MoneyInputFrame_GetCopper(moneyFrame) > max_widhdraw then
                            MoneyInputFrame_SetCopper(moneyFrame, max_widhdraw)
                        end
                        -- print(moneyFrame.expectChanges)
                    end
                end
            )
        end
    end
)

-- 一键存放所有钱币至战团银行
BANANA_BANK_DEPOSIT_ALL_MONEY_BUTTON_LABEL = GetLocale() == 'zhCN' and '存放钱币' or 'Deposit money'
BANANA_BANK_DEPOSIT_ALL_MONEY_BUTTON_TOOLTIP = GetLocale() == 'zhCN' and '存放全部钱币至战团银行' or 'Deposit all money to account bank'
function BananaBankDepositAllMoneyButton_OnClick(self)
    C_Bank.DepositMoney(Enum.BankType.Account, GetMoney())
end
BankFrameMoneyFrame:SetPoint('BOTTOMRIGHT', -115, 8)
BankFrameMoneyFrameBorder:SetPoint('BOTTOMRIGHT', -118, 6)
BankFrameMoneyFrameBorder:SetPoint('TOPLEFT', BankSlotsFrame, 'BOTTOMLEFT', 90, 25)

-- 自动修理和售卖垃圾
local function sell_junk()
    for_each_bag_item(
        function(bag_id, slot_index, item_link)
            if C_Item.GetItemQualityByID(item_link) == 0 then
                C_Container.UseContainerItem(bag_id, slot_index)
            end
        end
    )
end
MerchantFrame:HookScript(
    'OnShow',
    function(self)
        if CanMerchantRepair() then
            if IsInGuild() and CanGuildBankRepair() then
                RepairAllItems(true)
            end
            RepairAllItems(false)
        end
        sell_junk()
    end
)
-- 修改售卖垃圾按钮，跳过确认，且原方法太危险，C_MerchantFrame.SellAllJunkItems会无法购回
MerchantSellAllJunkButton:SetScript('OnClick', sell_junk)

-- 增强物品显示
-- Enhanced Item Display
local overlayed_item_buttons = {}
local function item_button_prepare(button, more)
    if not overlayed_item_buttons[button] then
        local overlay = CreateFrame('FRAME', nil, button)
        overlay:SetFrameLevel(1000)
        overlay:SetAllPoints()
        local ilvlbg = overlay:CreateTexture(nil, 'BACKGROUND')
        ilvlbg:SetColorTexture(0, 0, 0)
        ilvlbg:SetPoint('TOPRIGHT', -2, -2)
        ilvlbg:Hide()
        local ilvl = overlay:CreateFontString(nil, 'OVERLAY', 'Number16Font')
        ilvl:SetPoint('TOPRIGHT', -2, -2)
        ilvl:SetJustifyH('RIGHT')
        ilvl:Hide()
        local ilvlup = overlay:CreateTexture(nil, 'OVERLAY')
        ilvlup:SetSize(8, 8)
        ilvlup:SetPoint('TOPLEFT', 2, -2)
        ilvlup:SetAtlas('poi-door-arrow-up') -- MiniMap-PositionArrowUp?
        ilvlup:Hide()
        local mog = overlay:CreateTexture(nil, 'OVERLAY')
        mog:SetSize(16, 16)
        mog:SetPoint('BOTTOMRIGHT', -2, 2)
        mog:Hide()
        overlayed_item_buttons[button] = {
            overlay = overlay,
            ilvlbg = ilvlbg,
            ilvl = ilvl,
            ilvlup = ilvlup,
            mog = mog
        }
        if more then
            more(overlayed_item_buttons[button])
        end
    end
    return overlayed_item_buttons[button]
end
local function item_button_hide_all(button)
    if overlayed_item_buttons[button] then
        overlayed_item_buttons[button].ilvlbg:Hide()
        overlayed_item_buttons[button].ilvl:Hide()
        overlayed_item_buttons[button].ilvlup:Hide()
        overlayed_item_buttons[button].mog:Hide()
    end
end
local function item_button_show_ilvl(button, item_link)
    -- https://wowpedia.fandom.com/wiki/Enum.InventoryType
    -- 不是GetItemInventoryType()
    -- local inventory_type = get_item_inventory_type(item_link)
    -- if not inventory_type or inventory_type == 0 or inventory_type == 18 then
    --     return
    -- end
    local _, _, _, _, _, class_id, subclass_id = C_Item.GetItemInfoInstant(item_link)
    if not (class_id == 2 or class_id == 4 or (class_id == 3 and subclass_id == 11)) then
        return
    end
    local level = get_item_level(item_link)
    if not level then
        return
    end
    local quality = get_item_quality(item_link)
    if not quality then
        return
    end
    local r, g, b
    if quality == 3 then -- patch深蓝和深紫色，加亮
        r, g, b = 0.1, 0.5, 1
    elseif quality == 4 then
        r, g, b = 0.9, 0.3, 1
    else
        local entry = ITEM_QUALITY_COLORS[quality]
        if entry then
            r, g, b = entry.r, entry.g, entry.b
        end
    end
    if not r then
        r, g, b = 1, 1, 1
    end
    local entry = item_button_prepare(button)
    entry.ilvl:SetText(level)
    entry.ilvl:SetTextColor(r, g, b)
    entry.ilvl:Show()
    entry.ilvlbg:SetSize(entry.ilvl:GetSize())
    entry.ilvlbg:Show()
end
-- 角色面板
hooksecurefunc(
    'PaperDollItemSlotButton_Update',
    function(button)
        item_button_hide_all(button)
        local slot_id = button:GetID()
        if slot_id < 1 or slot_id > 19 then
            return
        end
        local item_link = GetInventoryItemLink('player', slot_id)
        on_item_load(
            item_link,
            function()
                item_button_show_ilvl(button, item_link)
            end
        )
    end
)
-- 目标角色面板
UIParentLoadAddOn('Blizzard_InspectUI')
hooksecurefunc(
    'InspectPaperDollItemSlotButton_Update',
    function(button)
        item_button_hide_all(button)
        local slot_id = button:GetID()
        if slot_id < 1 or slot_id > 19 then
            return
        end
        local item_link = GetInventoryItemLink(InspectFrame.unit, slot_id)
        on_item_load(
            item_link,
            function()
                item_button_show_ilvl(button, item_link)
            end
        )
    end
)
local function show_ilvlup(button, r, g, b)
    local entry = item_button_prepare(button)
    entry.ilvlup:SetVertexColor(r, g, b)
    entry.ilvlup:Show()
end
local inv_type_to_slot_id = {}
local patch_slot_id = {
    [2] = {2},
    [11] = {11, 12},
    [12] = {13, 14}
}
for inv_type = 0, 28 do
    local slot_id = C_Transmog.GetSlotForInventoryType(inv_type + 1) -- 注意+1
    if slot_id == 0 then
        inv_type_to_slot_id[inv_type] = patch_slot_id[inv_type]
    else
        inv_type_to_slot_id[inv_type] = {slot_id}
    end
end
-- print(T.ToString(inv_type_to_slot_id))
local function item_button_show_ilvlup(button, item_link)
    -- https://warcraft.wiki.gg/wiki/Enum.InventoryType
    local inv_type = get_item_inventory_type(item_link)
    -- print(inv_type)
    local slot_ids = inv_type_to_slot_id[inv_type]
    if not slot_ids then
        return
    end
    local _, source_id = C_TransmogCollection.GetItemInfo(item_link)
    local can_collect = true
    if source_id then
        _, can_collect = C_TransmogCollection.PlayerCanCollectSource(source_id)
    end
    if not can_collect then
        -- print("本职业无法幻化的")
        return
    end
    local item_level = get_item_level(item_link)
    local min_level_required = item_link and select(5, GetItemInfo(item_link))
    -- print(item_level, min_level_required)
    local r, g, b = 1, 1, 1
    if min_level_required and min_level_required > UnitLevel('player') then
        r, g, b = 1, 0, 0
    end
    for _, slot_id in ipairs(slot_ids) do
        local equipped = GetInventoryItemLink('player', slot_id)
        if not equipped then
            show_ilvlup(button, r, g, b)
        else
            on_item_load(
                equipped,
                function()
                    if get_item_level(equipped) < item_level then
                        show_ilvlup(button, r, g, b)
                    end
                end
            )
        end
    end
end
local know_appearance_tex = 'Interface/AddOns/BananaPreference/Res/KnowAppearance.tga'
local unknown_tex = 'Interface/AddOns/BananaPreference/Res/Unknown.tga'
local unknowable_tex = 'Interface/AddOns/BananaPreference/Res/Unknowable.tga'
-- C_TransmogCollection.GetItemInfo(item_link)有可能返回两个nil，比如11.0前夕的物品，在canimogit插件里也提及了，这里增加一个用tooltip的方式，但是注意，内存占用会很高，打开几次背包和商人界面就涨到七八兆
CreateFrame('GameTooltip', 'BananaMogScanner', nil, 'GameTooltipTemplate') -- 必须取名，否则读到的是text是nil
BananaMogScanner:SetOwner(WorldFrame, 'ANCHOR_NONE') -- 必须，否则读到的是text是nil
local function get_item_mog_tex(item_link)
    local item_id, _, _, _, _, item_type, item_sub_type = C_Item.GetItemInfoInstant(item_link)
    -- print(item_link, item_type, item_sub_type)
    if C_ToyBox.GetToyInfo(item_id) then
        -- 玩具
        if PlayerHasToy(item_id) then
            return nil
        else
            return unknown_tex
        end
    elseif item_type == 15 and item_sub_type == 5 then
        -- 坐骑
        local mount_id = C_MountJournal.GetMountFromItem(item_id)
        if not mount_id then
            return nil
        end
        if select(11, C_MountJournal.GetMountInfoByID(mount_id)) then
            return nil
        else
            return unknown_tex
        end
    elseif item_type == 15 and item_sub_type == 2 then
        -- 战斗宠物
        local name = C_PetJournal.GetPetInfoByItemID(item_id)
        if not name then
            return nil
        end
        if select(2, C_PetJournal.FindPetIDByName(name)) then
            return nil
        else
            return unknown_tex
        end
    elseif item_type == 2 or (item_type == 4 and item_sub_type >= 0 and item_sub_type <= 6) then
        -- 因为GameTooltip方式内存占用很高，这里对item_type和item_sub_type进一步细化，以缓解内存增长。
        -- 参见 https://warcraft.wiki.gg/wiki/ItemType
        -- 11.0前夕装备“达拉然防御者的导能器”是副手物品，subtype为0，试了传家宝“发霉的失落之书”，也是0
        -- if not C_Transmog.CanTransmogItem(item_id) then -- 装饰品为false
        --     return nil
        -- end
        local quality = get_item_quality(item_link)
        -- 11.0普通物品也可幻化了，原quality < 2改为< 0
        if quality < 0 or quality > 7 then
            return nil
        end
        if C_TransmogCollection.PlayerHasTransmogByItemInfo(item_link) then -- Patch 9.1.5 (2021-11-02): Added. 好像不太可靠
            return nil
        end
        local appearance_id, source_id = C_TransmogCollection.GetItemInfo(item_link)
        if appearance_id and source_id then
            -- 11.0可跨职业收藏了，PlayerCanCollectSource估计应该都返回true，未证实，不过还没见到unknowable的情况
            if select(2, C_TransmogCollection.PlayerCanCollectSource(source_id)) then
                local known_appearance = false
                local known_source = false
                for i, v in ipairs(C_TransmogCollection.GetAllAppearanceSources(appearance_id)) do
                    local source_info = C_TransmogCollection.GetSourceInfo(v)
                    if source_info.isCollected then
                        known_appearance = true
                        if source_info.sourceID == source_id then
                            known_source = true
                            break
                        end
                    end
                end
                if known_source then
                    return nil
                elseif known_appearance then
                    return know_appearance_tex
                else
                    return unknown_tex
                end
            else
                return unknowable_tex
            end
        else
            -- 尝试用tooltip方式读取，比如11.0前夕的回响紫装没有appearance_id、source_id
            -- GameTooltip注意事项：只有GameTooltip.TextLeft1、2和Right1、2是固定成员，别的动态添加的GameTooltipTextLeftN都无法通过GameTooltip.成员方式获取
            BananaMogScanner:SetHyperlink(item_link)
            -- print(item_link, item_type, item_sub_type)
            -- for i = 1, BananaMogScanner:NumLines() do
            --     print(i, _G['BananaMogScannerTextLeft' .. i]:GetText(), _G['BananaMogScannerTextRight' .. i]:GetText())
            -- end
            local bottom_left_text = _G['BananaMogScannerTextLeft' .. BananaMogScanner:NumLines()]:GetText()
            -- print(item_link, bottom_left_text)
            if bottom_left_text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN then
                return unknown_tex
            elseif bottom_left_text == TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN then
                return know_appearance_tex
            else
                return nil
            end
        end
    else
        -- print(item_link, item_type, item_sub_type)
    end
end
local function item_button_show_mog(button, item_link)
    local tex = get_item_mog_tex(item_link)
    if not tex then
        return
    end
    local entry = item_button_prepare(button)
    entry.mog:SetTexture(tex)
    entry.mog:Show()
end
-- 背包，参见ContainerFrameMixin:UpdateItems()
local function update_container_item(button)
    item_button_hide_all(button)
    local slot_id = button:GetID()
    local bag_id = button:GetBagID()
    local item_link = C_Container.GetContainerItemLink(bag_id, slot_id)
    on_item_load(
        item_link,
        function()
            item_button_show_ilvl(button, item_link)
            item_button_show_ilvlup(button, item_link)
            if not select(11, C_Container.GetContainerItemInfo(bag_id, slot_id)) then -- 未绑定
                item_button_show_mog(button, item_link)
            end
        end
    )
end
local function update_container_frame(frame)
    -- print("Update " .. frame:GetName())
    for i = 1, frame:GetBagSize() do
        local button = frame.Items[i]
        update_container_item(button)
    end
end
for i = 1, 13 do
    local frame = _G['ContainerFrame' .. i]
    hooksecurefunc(frame, 'UpdateItems', update_container_frame)
end
hooksecurefunc(ContainerFrameCombinedBags, 'UpdateItems', update_container_frame)
-- 银行界面，非银行背包
hooksecurefunc(
    'BankFrameItemButton_Update',
    function(button)
        if not button.isBag then
            update_container_item(button)
        end
    end
)
-- 商人
hooksecurefunc(
    'MerchantFrame_Update',
    function()
        -- 注意有bug，button.link在buyback页面是没有设置的，会导致切换到buyback，button.link没变
        local num_per_page = MerchantFrame.selectedTab == 1 and MERCHANT_ITEMS_PER_PAGE or BUYBACK_ITEMS_PER_PAGE
        for i = 1, num_per_page do
            local button = _G['MerchantItem' .. i .. 'ItemButton']
            item_button_hide_all(button)
            local item_link
            if MerchantFrame.selectedTab == 1 then
                item_link = GetMerchantItemLink((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE + i)
            elseif MerchantFrame.selectedTab == 2 then
                item_link = GetBuybackItemLink(i)
            end
            if item_link then
                on_item_load(
                    item_link,
                    function()
                        item_button_show_ilvl(button, item_link)
                        item_button_show_ilvlup(button, item_link)
                        item_button_show_mog(button, item_link)
                    end
                )
            end
        end
        -- 第一个标签的回购按钮
        item_button_hide_all(MerchantBuyBackItemItemButton)
        local item_link = GetBuybackItemLink(GetNumBuybackItems())
        if item_link then
            on_item_load(
                item_link,
                function()
                    item_button_show_ilvl(MerchantBuyBackItemItemButton, item_link)
                    item_button_show_ilvlup(MerchantBuyBackItemItemButton, item_link)
                    item_button_show_mog(MerchantBuyBackItemItemButton, item_link)
                end
            )
        end
    end
)
-- 冒险指南
-- LoadAddOn会在进入游戏出错（reload不出错）
BananaOnAddonLoaded(
    'Blizzard_EncounterJournal',
    function()
        hooksecurefunc(
            EncounterJournal.encounter.info.LootContainer.ScrollBox,
            'Update',
            function(scrollBox)
                scrollBox:ForEachFrame(
                    function(button)
                        item_button_hide_all(button)
                        on_item_load(
                            button.link,
                            function()
                                item_button_prepare(
                                    button,
                                    function(entry)
                                        entry.overlay:ClearAllPoints()
                                        entry.overlay:SetAllPoints(button.icon)
                                    end
                                )
                                item_button_show_ilvl(button, button.link)
                                item_button_show_ilvlup(button, button.link)
                                item_button_show_mog(button, button.link)
                            end
                        )
                    end
                )
            end
        )
    end
)
-- 专业技能面板
UIParentLoadAddOn('Blizzard_Professions')
hooksecurefunc(
    ProfessionsFrame.CraftingPage.RecipeList.ScrollBox,
    'Update',
    function(scrollBox)
        scrollBox:ForEachFrame(
            function(button)
                item_button_hide_all(button)
                local GetElementData = button.GetElementData
                if not GetElementData then
                    return
                end
                local data = button:GetElementData().data
                if not data then
                    return
                end
                local recipeInfo = data.recipeInfo
                if not recipeInfo then
                    return
                end
                local item_link = recipeInfo.hyperlink
                if not item_link then
                    return
                end
                on_item_load(
                    item_link,
                    function()
                        item_button_prepare(
                            button,
                            function(entry)
                                entry.mog:ClearAllPoints()
                                entry.mog:SetPoint('RIGHT', 2, 0)
                                entry.mog:SetSize(12, 12)
                            end
                        )
                        item_button_show_mog(button, item_link)
                    end
                )
            end
        )
    end
)
hooksecurefunc(
    Professions,
    'SetupOutputIconCommon',
    function(button, _, _, _, item_link, _)
        item_button_hide_all(button)
        on_item_load(
            item_link,
            function()
                item_button_prepare(
                    button,
                    function(entry)
                        entry.overlay:SetPoint('TOPLEFT', -5, 5)
                        entry.overlay:SetPoint('BOTTOMRIGHT', 5, -5)
                    end
                )
                item_button_show_ilvl(button, item_link)
                item_button_show_ilvlup(button, item_link)
                item_button_show_mog(button, item_link)
            end
        )
    end
)
-- 训练师面板
UIParentLoadAddOn('Blizzard_TrainerUI')
hooksecurefunc(
    ClassTrainerFrame.ScrollBox,
    'Update',
    function(scrollBox)
        scrollBox:ForEachFrame(
            function(button)
                item_button_hide_all(button)
                local skill_index = button:GetElementData().skillIndex
                local item_link = GetTrainerServiceItemLink(skill_index)
                on_item_load(
                    item_link,
                    function()
                        item_button_prepare(
                            button,
                            function(entry)
                                entry.overlay:ClearAllPoints()
                                entry.overlay:SetAllPoints(button.icon)
                            end
                        )
                        item_button_show_ilvl(button, item_link)
                        item_button_show_ilvlup(button, item_link)
                        item_button_show_mog(button, item_link)
                    end
                )
            end
        )
    end
)
-- 公会银行
UIParentLoadAddOn('Blizzard_GuildBankUI')
hooksecurefunc(
    GuildBankFrame,
    'Update',
    function()
        local tab = GetCurrentGuildBankTab()
        for column = 1, 7 do
            for index = 1, 14 do
                local slot = (column - 1) * 14 + index
                -- print(column, index, slot)
                local item_link = GetGuildBankItemLink(tab, slot)
                -- print(column, index, slot, item_link)
                local button = GuildBankFrame.Columns[column].Buttons[index]
                item_button_hide_all(button)
                on_item_load(
                    item_link,
                    function()
                        item_button_show_ilvl(button, item_link)
                        item_button_show_ilvlup(button, item_link)
                        item_button_show_mog(button, item_link)
                    end
                )
            end
        end
    end
)
-- 拍卖行
UIParentLoadAddOn('Blizzard_AuctionHouseUI')
hooksecurefunc(
    AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox,
    'Update',
    function(scrollBox)
        if not scrollBox:GetView() then
            return
        end
        scrollBox:ForEachFrame(
            function(button)
                item_button_hide_all(button)
                if button.rowData and button.rowData.itemKey and button.rowData.itemKey.itemID then
                    local item_id = button.rowData.itemKey.itemID
                    on_item_load(
                        item_id,
                        function()
                            local _, item_link = GetItemInfo(item_id)
                            item_button_prepare(
                                button,
                                function(entry)
                                    entry.overlay:ClearAllPoints()
                                    entry.overlay:SetAllPoints(button.cells[2])
                                    entry.mog:ClearAllPoints()
                                    entry.mog:SetPoint('RIGHT', -2, 0)
                                    entry.mog:SetSize(12, 12)
                                end
                            )
                            item_button_show_mog(button, item_link)
                        end
                    )
                end
            end
        )
    end
)

-- “售卖全部”按钮
BANANA_SELL_ALL_BUTTON_TOOLTIP = GetLocale() == 'zhCN' and '售卖全部' or 'Sell All'
function BananaSellAllButtonTemplate_OnLoad(self)
    local container_name = self:GetName():match('(ContainerFrame%d)SellAllButton')
    local container = container_name and getglobal(container_name) or ContainerFrameCombinedBags
    -- NineSlice的FrameLevel为500，TitleContainer为510在更前面
    self:SetParent(container)
    self:SetFrameLevel(520)
    self:SetPoint('TOPLEFT', 36, -8)
    -- container.TitleContainer.TitleText:SetJustifyH('RIGHT')
end
function BananaSellAllButtonTemplate_OnClick(self, button, down)
    if not MerchantFrame:IsShown() then
        return
    end
    -- 经过实测，ContainerFrame2-5的id是可变的，参考 Interface\AddOns\Blizzard_UIPanels_Game\Mainline\ContainerFrame.xml:289，真垃圾
    local container = self:GetParent()
    local from_bag_id, to_bag_id
    if container == ContainerFrameCombinedBags then
        from_bag_id, to_bag_id = 0, NUM_BAG_FRAMES
    else
        local id = container:GetID()
        from_bag_id, to_bag_id = id, id
    end
    BananaAddTask(
        coroutine.create(
            function()
                for bag_id = from_bag_id, to_bag_id do
                    for slot_index = 1, C_Container.GetContainerNumSlots(bag_id) do
                        if not (MerchantFrame:IsShown() and container:IsShown()) then
                            print('Cancelled')
                            return
                        end
                        local item_link = C_Container.GetContainerItemLink(bag_id, slot_index)
                        if item_link then
                            print('Sell', bag_id, slot_index, item_link)
                            C_Container.UseContainerItem(bag_id, slot_index)
                            coroutine.yield(0.2)
                        end
                    end
                end
                print('Done')
            end
        )
    )
end
