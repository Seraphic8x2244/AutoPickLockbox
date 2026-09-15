-- AutoPickLockbox 0.1.1
-- Vanilla WoW 1.12.1
--
-- Plain right-click on a locked bag item as a rogue:
--   1. Cast Pick Lock
--   2. Target the clicked bag slot
--
-- Hovering a locked bag item shows Blizzard's native Pick Lock cursor.
-- All other clicks fall through to Blizzard's normal bag handling.

local APL = {}

local _, playerClass = UnitClass("player")
if playerClass ~= "ROGUE" then
  return
end

-- Hidden tooltip used to detect the item's actual "Locked" tooltip line.
-- This avoids maintaining a hardcoded list of lockbox item IDs.
local scanner = CreateFrame("GameTooltip", "AutoPickLockboxTooltip", UIParent, "GameTooltipTemplate")
scanner:SetOwner(UIParent, "ANCHOR_NONE")

local LOCKED_TEXT = LOCKED or "Locked"
local PICK_LOCK_SPELL = "Pick Lock"
local PICK_LOCK_CURSOR = "PickLock.blp"
local cursorOverridden = false

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
    SetCursor(nil)
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
