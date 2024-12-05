local loot_box = LootFrame.ScrollBox
local loot_elem_view = loot_box:GetView()
hooksecurefunc(
    LootFrame.ScrollBox,
    'TriggerEvent',
    function(...)
        print('LootFrame.ScrollBox:TriggerEvent', ...)
    end
)
hooksecurefunc(
    loot_box,
    'SetDataProvider',
    function()
        print('LootFrame.ScrollBox:SetDataProvider')
        -- for i, v in ipairs(loot_elem_view:GetFrames()) do
        --     if not v.animation_disabled then
        --         disable_animation_groups(v:GetAnimationGroups())
        --         v.animation_disabled = true
        --         print(i, 'disabled')
        --     else
        --         print(i, 'already disabled')
        --     end
        -- end
        for slotIndex = 1, GetNumLootItems() do
            print(GetLootSlotInfo(slotIndex))
        end
    end
)
-- LootFrame:SetScript(
--     'OnEvent',
--     function(self, event, ...)
--         if event == 'LOOT_OPENED' then
--             local isAutoLoot, acquiredFromItem = ...
--             self.isAutoLoot = isAutoLoot
--             self:Open()
--             if self:IsShown() then
--                 if acquiredFromItem then
--                     PlaySound(SOUNDKIT.UI_CONTAINER_ITEM_OPEN)
--                 elseif IsFishingLoot() then
--                     PlaySound(SOUNDKIT.FISHING_REEL_IN)
--                 elseif self.ScrollBox:GetDataProvider():IsEmpty() then
--                     PlaySound(SOUNDKIT.LOOT_WINDOW_OPEN_EMPTY)
--                 end
--             else
--                 local showUnopenableError = not self.isAutoLoot
--                 CloseLoot(showUnopenableError)
--             end
--         elseif event == 'LOOT_SLOT_CLEARED' then
--             local slotIndex = ...
--             local frame =
--                 self.ScrollBox:FindFrameByPredicate(
--                 function(frame)
--                     return frame:GetSlotIndex() == slotIndex
--                 end
--             )
--             if frame then
--                 -- PATCH：此处删掉动画
--                 print('LOOT_SLOT_CLEARED', slotIndex, frame)
--                 frame:Hide()
--             end
--         elseif event == 'LOOT_SLOT_CHANGED' then
--             local slotIndex = ...
--             local frame =
--                 self.ScrollBox:FindFrameByPredicate(
--                 function(frame)
--                     return frame:GetSlotIndex() == slotIndex
--                 end
--             )
--             if frame then
--                 -- PATCH：此处禁用
--                 print('LOOT_SLOT_CHANGED', slotIndex, frame)
--                 frame:Init()
--             end
--         elseif event == 'LOOT_CLOSED' then
--             self:Close()
--         end
--     end
-- )

-- 转移货币界面自动填写源的数量
-- BANANA_CURRENCY_TRANSFER_ALL_BUTTON_LABEL = GetLocale() == 'zhCN' and '转移全部' or 'Transfer All'
-- function BananaCurrencyTransferAllButton_OnLoad(self)
--     UIParentLoadAddOn('Blizzard_TokenUI')
--     BananaCurrencyTransferAllButton:SetParent(CurrencyTransferMenu)
--     BananaCurrencyTransferAllButton:SetPoint('TOP', 0, -150)
-- end
-- function BananaCurrencyTransferAllButton_OnClick(self)
--     -- secure tainted 无法做
--     -- C_CurrencyInfo.RequestCurrencyFromAccountCharacter(CurrencyTransferMenu:GetSourceCharacterData().characterGUID, CurrencyTransferMenu:GetCurrencyID(), CurrencyTransferMenu:GetSourceCharacterCurrencyQuantity())
--     -- secure tainted 无法做
--     CurrencyTransferMenu.AmountSelector.InputBox:SetNumber(CurrencyTransferMenu:GetSourceCharacterCurrencyQuantity())
-- end
-- 没效果
-- CurrencyTransferMenu:HookScript(
--     'OnLoad',
--     function()
--         hooksecurefunc(
--             CurrencyTransferMenu,
--             'OnCurrencyTransferSourceSelected',
--             function(self, sourceCharacterData)
--                 print('OnCurrencyTransferSourceSelected')
--                 print(self:GetSourceCharacterCurrencyQuantity(), self:GetTotalCurrencyTransferCost())
--                 -- CurrencyTransferMenu.AmountSelector.InputBox:SetNumber(amount)
--             end
--         )
--     end
-- )
-- 会导致数据都为0，是不是DynamicEventMethod只能有一个？真傻逼
-- CurrencyTransferMenu:AddDynamicEventMethod(
--     CurrencyTransferMenu,
--     CurrencyTransferMenuMixin.Event.CurrencyTransferSourceSelected,
--     function(self, sourceCharacterData)
--         print(CurrencyTransferMenu:GetSourceCharacterCurrencyQuantity())
--     end
-- )
-- <!-- <Button name="BananaCurrencyTransferAllButton" inherits="UIPanelButtonTemplate" text="BANANA_CURRENCY_TRANSFER_ALL_BUTTON_LABEL">
-- <Size x="150" y="22"/>
-- <Scripts>
--     <OnLoad function="BananaCurrencyTransferAllButton_OnLoad"/>
--     <OnClick function="BananaCurrencyTransferAllButton_OnClick"/>
-- </Scripts>
-- </Button> -->

