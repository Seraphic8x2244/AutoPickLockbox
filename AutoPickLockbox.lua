-- AutoPickLockbox 0.1.5
-- Vanilla WoW 1.12.1
--
-- Plain right-click on a locked bag item as a rogue:
--   1. Cast Pick Lock
--   2. Target the clicked bag slot
--
-- Hovering a locked bag item shows Blizzard's native Pick Lock cursor.
-- Known lockboxes in mailbox tooltips show a colour-coded Pickable line.
-- All other clicks fall through to Blizzard's normal bag handling.

local APL = {}

local _, playerClass = UnitClass("player")
if playerClass ~= "ROGUE" then
  return
end

-- Hidden tooltip used to detect the item's actual "Locked" tooltip line.
-- This avoids maintaining a hardcoded list of lockbox item IDs for bag behaviour.
local scanner = CreateFrame("GameTooltip", "AutoPickLockboxTooltip", UIParent, "GameTooltipTemplate")
scanner:SetOwner(UIParent, "ANCHOR_NONE")

local LOCKED_TEXT = LOCKED or "Locked"
local PICK_LOCK_SPELL = "Pick Lock"
local PICK_LOCK_CURSOR = "LOCK_CURSOR"
local cursorOverridden = false

-- Vanilla lock requirements. vMaNGOS resolves these through each item's
-- lock_id and the 1.12.1 Lock.dbc; this table mirrors those values for mail,
-- where the normal item instance/lock tooltip information is not available.
local MAIL_LOCKBOX_REQUIREMENTS = {
  ["Battered Junkbox"] = 1,
  ["Worn Junkbox"] = 70,
  ["Sturdy Junkbox"] = 175,
  ["Heavy Junkbox"] = 250,
  ["Ornate Bronze Lockbox"] = 1,
  ["Heavy Bronze Lockbox"] = 25,
  ["Iron Lockbox"] = 70,
  ["Strong Iron Lockbox"] = 125,
  ["Steel Lockbox"] = 175,
  ["Reinforced Steel Lockbox"] = 225,
  ["Mithril Lockbox"] = 225,
  ["Thorium Lockbox"] = 225,
  ["Eternium Lockbox"] = 225,
}

local PICKABLE_COLOURS = {
  red     = RED_FONT_COLOR or { r = 1.00, g = 0.10, b = 0.10 },
  orange  = { r = 1.00, g = 0.50, b = 0.25 },
  yellow  = { r = 1.00, g = 1.00, b = 0.00 },
  green   = { r = 0.25, g = 0.75, b = 0.25 },
  grey    = { r = 0.50, g = 0.50, b = 0.50 },
}

local function GetLockpickingSkill()
  for i = 1, GetNumSkillLines() do
    local name, _, _, rank = GetSkillLineInfo(i)
    if name == "Lockpicking" then
      return tonumber(rank) or 0
    end
  end

  return 0
end

local function GetPickableColour(skill, required)
  local colour

  -- Match vMaNGOS gathering-skill difficulty thresholds:
  -- orange = requirement, yellow = +25, green = +50, grey = +100.
  if skill < required then
    colour = PICKABLE_COLOURS.red
  elseif skill < required + 25 then
    colour = PICKABLE_COLOURS.orange
  elseif skill < required + 50 then
    colour = PICKABLE_COLOURS.yellow
  elseif skill < required + 100 then
    colour = PICKABLE_COLOURS.green
  else
    colour = PICKABLE_COLOURS.grey
  end

  return colour.r, colour.g, colour.b
end

local function AddMailboxPickableLine(index, attachIndex)
  if not index then
    return
  end

  local itemName = GetInboxItem(index, attachIndex or 1)
  local required = itemName and MAIL_LOCKBOX_REQUIREMENTS[itemName]
  if not required then
    return
  end

  local r, g, b = GetPickableColour(GetLockpickingSkill(), required)
  GameTooltip:AddLine("Pickable", r, g, b)
  GameTooltip:Show()
end

local function IsLockedBagItem(bag, slot)
  if not GetContainerItemLink(bag, slot) then
    return false
  end

  scanner:ClearLines()
  scanner:SetBagItem(bag, slot)

  for i = 1, scanner:NumLines() do
    local left = getglobal("AutoPickLockboxTooltipTextLeft" .. i)
    local right = getglobal("AutoPickLockboxTooltipTextRight" .. i)

    if left and left:GetText() == LOCKED_TEXT then
      return true
    end

    if right and right:GetText() == LOCKED_TEXT then
      return true
    end
  end

  return false
end

local function GetBagAndSlot(button)
  if not button or not button.GetParent or not button.GetID then
    return nil, nil
  end

  local parent = button:GetParent()
  if not parent or not parent.GetID then
    return nil, nil
  end

  return parent:GetID(), button:GetID()
end

local function ResetLockpickCursor()
  if cursorOverridden then
    ResetCursor()
    cursorOverridden = false
  end
end

local function UpdateLockpickCursor(button)
  local bag, slot = GetBagAndSlot(button)
  if bag == nil or slot == nil then
    ResetLockpickCursor()
    return
  end

  if IsLockedBagItem(bag, slot) then
    SetCursor(PICK_LOCK_CURSOR)
    cursorOverridden = true
  else
    ResetLockpickCursor()
  end
end

local function TryPickLock(button)
  -- Only replace a normal right-click.
  if button ~= "RightButton" then
    return false
  end

  -- Preserve modified-click behaviour.
  if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
    return false
  end

  if CursorHasItem() or SpellIsTargeting() then
    return false
  end

  local bag, slot = GetBagAndSlot(this)
  if bag == nil or slot == nil then
    return false
  end

  if not IsLockedBagItem(bag, slot) then
    return false
  end

  CastSpellByName(PICK_LOCK_SPELL)

  -- PickupContainerItem applies a targeting spell to this bag slot when
  -- the cursor is in spell-targeting mode.
  if SpellIsTargeting() then
    PickupContainerItem(bag, slot)
    ResetLockpickCursor()
    return true
  end

  -- If Pick Lock could not be cast for some reason, allow the normal
  -- right-click handler to run instead of swallowing the click.
  return false
end

-- pfUI uses ContainerFrameItemButtonTemplate for normal bag slots too,
-- so these hooks cover both Blizzard bags and pfUI bags.
local OriginalContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
local OriginalContainerFrameItemButton_OnEnter = ContainerFrameItemButton_OnEnter
local OriginalContainerFrameItemButton_OnLeave = ContainerFrameItemButton_OnLeave

function ContainerFrameItemButton_OnClick(button, ignoreShift)
  if TryPickLock(button) then
    return
  end

  return OriginalContainerFrameItemButton_OnClick(button, ignoreShift)
end

function ContainerFrameItemButton_OnEnter()
  if OriginalContainerFrameItemButton_OnEnter then
    OriginalContainerFrameItemButton_OnEnter()
  end

  UpdateLockpickCursor(this)
end

function ContainerFrameItemButton_OnLeave()
  if OriginalContainerFrameItemButton_OnLeave then
    OriginalContainerFrameItemButton_OnLeave()
  end

  ResetLockpickCursor()
end

-- Mailbox tooltips do not reliably expose whether a specific lockbox has
-- already been unlocked. Add only "Pickable", with its colour indicating
-- lockpicking difficulty relative to the Rogue's current skill.
local OriginalGameTooltip_SetInboxItem = GameTooltip.SetInboxItem

function GameTooltip:SetInboxItem(index, attachIndex)
  OriginalGameTooltip_SetInboxItem(self, index, attachIndex)
  AddMailboxPickableLine(index, attachIndex)
end
