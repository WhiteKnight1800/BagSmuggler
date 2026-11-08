# Changelog

## 1.4.5
- Fix (WoW Forever): right-clicking items in your bags to use them (potions, food, quest items, opening containers) was blocked. Item buttons now hand the bag to the game the secure way.

## 1.4.4
- Fix (WoW Forever): the gold money bar at the bottom of the Default Bags skin was drawn from the wrong part of the bag art. It now uses the right piece on Forever.

## 1.4.3
- Fix (WoW Forever): the bag window stopped growing part-way through, so items spilled outside the frame and the title, gold and Junk section were missing. Money display now uses the modern API on Forever.

## 1.4.2
- Fix: the credits at the bottom of the settings sidebar overlapped the window border in the Blizzard skins.

## 1.4.1
- New BagSmuggler logo (a masked smuggler's coin pouch). Shown in the AddOns list, the settings window and the About page.

## 1.4.0 - BagSmuggler
- Renamed to **BagSmuggler** (the name Stash was already taken). Commands: /bsm or /bagsmuggler. Settings start fresh under the new name.
- New **Default Bags** skin (now the default): built from the game's own bag art so it looks like the normal Blizzard bags, just one big bag. Portrait, title bar, gold X, stone edges, real slot cells behind every item and the gold money bar.
- The previous Blizzard look is still there as **Blizzard Dialog**, alongside Sleek, Glass and Onyx.

## 1.3.0
- New **Blizzard** skin (now the default): classic dialog border with title banner, red close button, classic item slots with quality glow, red panel buttons, input boxes, checkboxes and sliders. Sleek, Glass and Onyx are still available under Settings > Look > Skin.
- Fix: items could stop responding to right-click after your bags changed during combat (e.g. drinking a potion). Item buttons are no longer moved in combat; they repaint in place and the full layout runs as soon as combat ends.
- Fix: a merged stack tile now always uses an unlocked stack, and if the stack under a tile runs out in combat, another stack of the same item is moved into its slot so you can keep clicking it.
- The bag layout is kept up to date while the window is closed, so it is ready if you open it mid-fight.

## 1.2.0 - Stash
- Renamed from WKSatchel to **Stash**. Commands are now /stash. (Settings start fresh under the new name.)
- Complete visual redesign: rounded panels with soft shadow, accent glow line, custom monochrome icon set, rounded item tiles with masked icons and quality-tinted backgrounds.
- New section headers: colour bar, small caps title, count, chevron and divider.
- Footer capacity bar that turns orange then red as your bags fill.
- Skins: Sleek, Glass, Onyx. Accent colours: Ice Blue, Fel Green, Gold, Void Purple, Rose, Class Colour.
- Redesigned settings with tabs (General, Look, Categories, About), toggle switches, sliders and selectors.
- About page with credits and copyable Discord name.

## 1.1.0
- Merged stacks, collapsible categories, Restack, junk value on header, upgrade arrows, BoE tags, smart search.

## 1.0.0
- First release.
