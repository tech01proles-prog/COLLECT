extends Control

# MONSTRONOMIKA — Godot 4.7 MVP
# Browser-first idle / collection prototype.
# Art is loaded from res://art/* using stable IDs. Missing art falls back to placeholders.

const SAVE_PATH := "user://monstronomika_save.json"
const VERSION := 3
const VIEWPORT_SIZE := Vector2(1280, 720)

const PACK_COSTS := {1: 500, 2: 900, 3: 1300}
const DARK_PACK_COST := 20
const DARK_PACK_BOSS_CHANCE := 0.28
const NORMAL_PACK_BOSS_CHANCE := 0.08
const OFFLINE_CAP := 8.0 * 60.0 * 60.0

const RARITY_COLORS := {
    "Common": Color("#AAB4C6"),
    "Rare": Color("#51A5FF"),
    "Epic": Color("#B36CFF"),
    "Mythic": Color("#FF65B5"),
    "Legendary": Color("#FFD15A")
}

const RARITY_WEIGHTS := {"Common": 60.0, "Rare": 27.0, "Epic": 10.0, "Mythic": 3.0}
const DARK_RARITY_WEIGHTS := {"Rare": 48.0, "Epic": 37.0, "Mythic": 15.0}

var essence: int = 2500
var dark_essence: int = 28
var selected_location: int = 0
var boss_index: int = 0
var boss_hp: int = 1000
var boss_max_hp: int = 1000
var kills: int = 0
var total_essence_earned: int = 0
var last_drop: String = "—"
var auto_attacking: bool = true
var selected_hero: String = "hunter"
var hero_levels: Dictionary = {"hunter": 1, "warlock": 1, "executioner": 1}
var unlocked_heroes: Dictionary = {"hunter": true, "warlock": false, "executioner": false}
var collection: Dictionary = {}
var boss_collection: Dictionary = {}
var current_view: String = "battle"
var collection_filter: String = "All"
var last_seen_unix: float = 0.0
var last_save_msec: int = 0
var attack_tick: float = 0.0
var _ui: Dictionary = {}

var locations := [
    {"id":"ashen", "name":"ASHEN WASTES", "desc":"Fast Essence", "ess_mult":1.32, "dark":0.035, "hp":780, "accent":Color("#E18A57")},
    {"id":"marsh", "name":"BLACK MARSH", "desc":"Balanced", "ess_mult":1.00, "dark":0.105, "hp":940, "accent":Color("#62D0A6")},
    {"id":"abyss", "name":"ABYSS GATE", "desc":"Dark Essence", "ess_mult":0.82, "dark":0.235, "hp":1180, "accent":Color("#A676FF")}
]

var creatures := [
    {"id":"bone_tyrant", "name":"BONE TYRANT", "rarity":"Common", "buff":"Essence gain", "base":4.0},
    {"id":"swamp_devourer", "name":"SWAMP DEVOURER", "rarity":"Common", "buff":"Hero damage", "base":5.0},
    {"id":"cinder_beast", "name":"CINDER BEAST", "rarity":"Common", "buff":"Essence gain", "base":5.5},
    {"id":"ash_colossus", "name":"ASH COLOSSUS", "rarity":"Rare", "buff":"Boss damage", "base":8.0},
    {"id":"plague_saint", "name":"PLAGUE SAINT", "rarity":"Rare", "buff":"Dark chance", "base":7.0},
    {"id":"mire_queen", "name":"MIRE QUEEN", "rarity":"Rare", "buff":"Hero damage", "base":9.0},
    {"id":"void_reaper", "name":"VOID REAPER", "rarity":"Epic", "buff":"Essence gain", "base":14.0},
    {"id":"abyssal_warden", "name":"ABYSSAL WARDEN", "rarity":"Epic", "buff":"Boss damage", "base":18.0},
    {"id":"star_eater", "name":"STAR EATER", "rarity":"Mythic", "buff":"Pack luck", "base":14.0},
    {"id":"blood_seraph", "name":"BLOOD SERAPH", "rarity":"Mythic", "buff":"Dark chance", "base":14.0},
    {"id":"iron_widow", "name":"IRON WIDOW", "rarity":"Common", "buff":"Boss damage", "base":4.5},
    {"id":"sunless_beast", "name":"SUNLESS BEAST", "rarity":"Rare", "buff":"Essence gain", "base":10.0}
]

var bosses := [
    {"id":"ash_colossus_boss", "name":"ASH COLOSSUS", "location":0, "hp":780, "ess_mult":1.00, "dark_mult":0.80},
    {"id":"bone_tyrant_boss", "name":"BONE TYRANT", "location":0, "hp":900, "ess_mult":1.15, "dark_mult":0.90},
    {"id":"cinder_beast_boss", "name":"CINDER BEAST", "location":0, "hp":1050, "ess_mult":1.35, "dark_mult":0.85},
    {"id":"swamp_devourer_boss", "name":"SWAMP DEVOURER", "location":1, "hp":940, "ess_mult":1.00, "dark_mult":1.00},
    {"id":"plague_saint_boss", "name":"PLAGUE SAINT", "location":1, "hp":1080, "ess_mult":1.12, "dark_mult":1.15},
    {"id":"mire_queen_boss", "name":"MIRE QUEEN", "location":1, "hp":1260, "ess_mult":1.30, "dark_mult":1.20},
    {"id":"abyssal_warden_boss", "name":"ABYSSAL WARDEN", "location":2, "hp":1180, "ess_mult":1.00, "dark_mult":1.35},
    {"id":"void_abomination_boss", "name":"VOID ABOMINATION", "location":2, "hp":1380, "ess_mult":1.15, "dark_mult":1.55},
    {"id":"hollow_king_boss", "name":"THE HOLLOW KING", "location":2, "hp":1680, "ess_mult":1.50, "dark_mult":1.85}
]

var heroes := [
    {"id":"hunter", "name":"THE HUNTER", "role":"DPS", "base_damage":12, "unlock":0, "accent":Color("#BFD0E8")},
    {"id":"warlock", "name":"THE WARLOCK", "role":"ESSENCE", "base_damage":8, "unlock":1800, "accent":Color("#B56CFF")},
    {"id":"executioner", "name":"THE EXECUTIONER", "role":"BURST", "base_damage":25, "unlock":6500, "accent":Color("#FF6B7E")}
]

func _ready() -> void:
    randomize()
    _load_game()
    _build_ui()
    _reset_boss(false)
    _refresh_all()
    _show_offline_reward()
    _save_game()

func _process(delta: float) -> void:
    attack_tick += delta
    if auto_attacking and attack_tick >= 1.0:
        attack_tick -= 1.0
        _attack(_total_hero_damage(), false)
    if Time.get_ticks_msec() - last_save_msec > 8000:
        _save_game()

func _build_ui() -> void:
    _build_background()
    _build_topbar()
    _build_content()
    _build_modal_layer()
    _build_toast_layer()

func _build_background() -> void:
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("#070A12")
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var top_glow := ColorRect.new()
    top_glow.position = Vector2(0, 0)
    top_glow.size = Vector2(1280, 84)
    top_glow.color = Color("#0E1424")
    top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top_glow)

func _build_topbar() -> void:
    var bar := Panel.new()
    bar.position = Vector2(16, 12)
    bar.size = Vector2(1248, 62)
    bar.add_theme_stylebox_override("panel", _style(Color("#0D1320"), Color("#222B3E"), 14, 1))
    add_child(bar)

    var title := _label(bar, "MONSTRONOMIKA", Vector2(18, 10), 24, Color("#F4F2FC"))
    title.add_theme_color_override("font_shadow_color", Color("#6F56D9"))
    title.add_theme_constant_override("shadow_offset_x", 1)
    title.add_theme_constant_override("shadow_offset_y", 1)
    _label(bar, "MONSTER COLLECTION // IDLE TYCOON", Vector2(20, 38), 9, Color("#67748B"))

    _ui.essence = _resource_chip(bar, Vector2(356, 9), Vector2(164, 44), "ESSENCE", Color("#FFD267"))
    _ui.dark = _resource_chip(bar, Vector2(528, 9), Vector2(164, 44), "DARK ESSENCE", Color("#B78AFF"))
    _ui.collection = _resource_chip(bar, Vector2(700, 9), Vector2(118, 44), "COLLECTION", Color("#67D7B2"))
    _ui.kills = _resource_chip(bar, Vector2(826, 9), Vector2(94, 44), "KILLS", Color("#FF7187"))

    var tabs := [
        ["battle", "BATTLE"], ["collection", "COLLECTION"], ["heroes", "HEROES"], ["market", "MARKET"]
    ]
    var x := 934
    _ui.tabs = {}
    for item in tabs:
        var b := _button(bar, item[1], Vector2(x, 14), Vector2(76, 34), 9, true)
        b.pressed.connect(_on_tab.bind(item[0]))
        _ui.tabs[item[0]] = b
        x += 80

func _build_content() -> void:
    _ui.views = {}
    _ui.views.battle = Control.new()
    _ui.views.collection = Control.new()
    _ui.views.heroes = Control.new()
    _ui.views.market = Control.new()
    for key in _ui.views:
        var view: Control = _ui.views[key]
        view.position = Vector2(16, 88)
        view.size = Vector2(1248, 616)
        add_child(view)

    _build_battle_view(_ui.views.battle)
    _build_collection_view(_ui.views.collection)
    _build_heroes_view(_ui.views.heroes)
    _build_market_view(_ui.views.market)

func _build_battle_view(parent: Control) -> void:
    # Left: locations
    var left := _panel(parent, Vector2(0, 0), Vector2(220, 616), "FARM LOCATIONS")
    _label(left, "Choose your resource profile.", Vector2(16, 43), 10, Color("#758198"))
    _ui.location_buttons = []
    for i in locations.size():
        var y := 70 + i * 106
        var b := _button(left, locations[i].name, Vector2(13, y), Vector2(194, 86), 11, false)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(_select_location.bind(i))
        _ui.location_buttons.append(b)
        _label(b, locations[i].desc, Vector2(12, 31), 9, locations[i].accent)
        _label(b, "Essence x%.2f" % float(locations[i].ess_mult), Vector2(12, 51), 9, Color("#9AA6BB"))
        _label(b, "Dark %.1f%%" % (float(locations[i].dark) * 100.0), Vector2(98, 51), 9, Color("#9AA6BB"))
    var tip := _panel(left, Vector2(13, 400), Vector2(194, 74), "BUILD")
    _label(tip, "Location bonuses are the first
way to specialize your farm.", Vector2(12, 27), 10, Color("#A9B4C5"))
    _ui.location_note = _label(left, "", Vector2(16, 502), 10, Color("#7E8AA0"))
    _ui.location_note.size = Vector2(188, 78)
    _ui.location_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    # Center battle
    var center := _panel(parent, Vector2(232, 0), Vector2(684, 616), "CURRENT TARGET")
    _ui.boss_name = _label(center, "", Vector2(24, 43), 22, Color("#F5F2FB"))
    _ui.boss_meta = _label(center, "", Vector2(26, 70), 10, Color("#7E8BA1"))

    var hp_bg := ColorRect.new()
    hp_bg.position = Vector2(24, 95)
    hp_bg.size = Vector2(636, 16)
    hp_bg.color = Color("#1B2231")
    hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(hp_bg)
    _ui.hp_bar = ColorRect.new()
    _ui.hp_bar.position = Vector2(24, 95)
    _ui.hp_bar.size = Vector2(636, 16)
    _ui.hp_bar.color = Color("#D96481")
    _ui.hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_ui.hp_bar)
    _ui.hp_text = _label(center, "", Vector2(24, 116), 9, Color("#8B97AC"))

    var arena := _panel(center, Vector2(24, 145), Vector2(636, 346), "")
    _ui.arena = arena
    var atmosphere := ColorRect.new()
    atmosphere.position = Vector2(1, 1)
    atmosphere.size = Vector2(634, 344)
    atmosphere.color = Color("#101625")
    atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
    arena.add_child(atmosphere)
    _ui.boss_art = TextureRect.new()
    _ui.boss_art.position = Vector2(112, 15)
    _ui.boss_art.size = Vector2(410, 310)
    _ui.boss_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _ui.boss_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _ui.boss_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    arena.add_child(_ui.boss_art)
    _ui.boss_tag = _label(arena, "", Vector2(22, 304), 9, Color("#9EABC0"))

    _ui.attack_btn = _button(center, "ATTACK", Vector2(24, 510), Vector2(402, 54), 18, false)
    _ui.attack_btn.pressed.connect(_manual_attack)
    _ui.auto_btn = _button(center, "AUTO: ON", Vector2(440, 510), Vector2(220, 54), 11, true)
    _ui.auto_btn.pressed.connect(_toggle_auto)
    _ui.combat_line = _label(center, "", Vector2(24, 575), 10, Color("#9CA8BA"))

    # Right: summon / drops
    var right := _panel(parent, Vector2(928, 0), Vector2(320, 616), "SUMMON & COLLECTION")
    _label(right, "Spend Essence to open 1–3 cards.", Vector2(16, 43), 10, Color("#758198"))

    _ui.pack_buttons = {}
    var pack_rows := [[1, "1 CARD", "500 ESSENCE"], [2, "2 CARDS", "900 ESSENCE"], [3, "3 CARDS", "1300 ESSENCE"]]
    for i in pack_rows.size():
        var item = pack_rows[i]
        var y := 72 + i * 72
        var b := _button(right, item[1], Vector2(14, y), Vector2(292, 58), 12, false)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(_open_essence_pack.bind(item[0]))
        _label(b, item[2], Vector2(174, 20), 9, Color("#9AA6BB"))
        _ui.pack_buttons[item[0]] = b

    _ui.dark_pack = _button(right, "DARK PACK", Vector2(14, 291), Vector2(292, 64), 13, false)
    _ui.dark_pack.pressed.connect(_open_dark_pack)
    _label(right, "RARE / EPIC / MYTHIC + BOSS DROPS", Vector2(25, 362), 8, Color("#9A7EC5"))

    var drop_panel := _panel(right, Vector2(14, 390), Vector2(292, 95), "LAST DROP")
    _ui.last_drop = _label(drop_panel, "—", Vector2(12, 29), 12, Color("#D6C8F2"))
    _ui.last_drop.size = Vector2(266, 56)
    _ui.last_drop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var progress_panel := _panel(right, Vector2(14, 500), Vector2(292, 100), "COLLECTION PROGRESS")
    _ui.progress = _label(progress_panel, "", Vector2(12, 28), 10, Color("#AEB9CA"))
    _ui.progress.size = Vector2(268, 62)
    _ui.progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    # Simple hero strip inside center-bottom area is represented in battle by hero summary.
    _ui.hero_summary = _label(parent, "", Vector2(248, 580), 9, Color("#6F7C92"))
    _ui.hero_summary.size = Vector2(652, 34)
    _ui.hero_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_collection_view(parent: Control) -> void:
    var sidebar := _panel(parent, Vector2(0, 0), Vector2(220, 616), "ARCHIVE")
    _label(sidebar, "Cards are passive bonuses.", Vector2(16, 43), 10, Color("#758198"))
    _ui.filter_buttons = {}
    var filters := ["All", "Common", "Rare", "Epic", "Mythic"]
    for i in filters.size():
        var b := _button(sidebar, filters[i], Vector2(14, 70 + i * 48), Vector2(192, 38), 10, true)
        b.pressed.connect(_set_collection_filter.bind(filters[i]))
        _ui.filter_buttons[filters[i]] = b

    var note := _panel(sidebar, Vector2(14, 330), Vector2(192, 138), "LEVELS")
    _label(note, "Common / Rare\n2 → 5 → 10\n\nEpic\n2 → 3 → 5\n\nMythic: 2\nLegendary: unique", Vector2(12, 27), 10, Color("#A9B4C5"))
    _ui.collection_hint = _label(sidebar, "", Vector2(16, 492), 9, Color("#738097"))
    _ui.collection_hint.size = Vector2(188, 92)
    _ui.collection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var grid_panel := _panel(parent, Vector2(232, 0), Vector2(1016, 616), "CREATURE COLLECTION")
    _ui.collection_grid = GridContainer.new()
    _ui.collection_grid.position = Vector2(16, 52)
    _ui.collection_grid.size = Vector2(980, 548)
    _ui.collection_grid.columns = 5
    _ui.collection_grid.add_theme_constant_override("h_separation", 12)
    _ui.collection_grid.add_theme_constant_override("v_separation", 12)
    grid_panel.add_child(_ui.collection_grid)

func _build_heroes_view(parent: Control) -> void:
    var header := _panel(parent, Vector2(0, 0), Vector2(1248, 108), "HERO COMMAND")
    _ui.hero_total_damage = _label(header, "", Vector2(18, 44), 20, Color("#F3F0FA"))
    _ui.hero_command_note = _label(header, "Heroes deal the damage. Cards only modify the build.", Vector2(18, 74), 10, Color("#78859A"))
    _ui.hero_roster = HBoxContainer.new()
    _ui.hero_roster.position = Vector2(0, 128)
    _ui.hero_roster.size = Vector2(1248, 330)
    _ui.hero_roster.add_theme_constant_override("separation", 14)
    parent.add_child(_ui.hero_roster)

    var tips := _panel(parent, Vector2(0, 478), Vector2(1248, 138), "TEAM BUILDING")
    _label(tips, "Active team is additive: every unlocked hero contributes DPS.\nSelect a hero to upgrade it. The visual language is icon + attack VFX — no hero animation required.\nLater: skills, gear and 3-slot team presets can be added without changing the combat core.", Vector2(18, 28), 11, Color("#AAB5C6"))

func _build_market_view(parent: Control) -> void:
    var left := _panel(parent, Vector2(0, 0), Vector2(810, 616), "PLAYER MARKET")
    _label(left, "LOCAL MOCK — server marketplace comes later.", Vector2(16, 43), 10, Color("#D2A95C"))
    _label(left, "Buy cards other players listed. Duplicate cards can be sold to keep Essence moving.", Vector2(16, 64), 10, Color("#758198"))
    _ui.market_list = VBoxContainer.new()
    _ui.market_list.position = Vector2(16, 96)
    _ui.market_list.size = Vector2(778, 490)
    _ui.market_list.add_theme_constant_override("separation", 10)
    left.add_child(_ui.market_list)

    var right := _panel(parent, Vector2(828, 0), Vector2(420, 616), "ECONOMY NOTES")
    _label(right, "Essence sink", Vector2(16, 46), 11, Color("#F1D17B"))
    _label(right, "Packs remove Essence from the economy.\nMarket fees later remove a second share.", Vector2(16, 68), 10, Color("#A9B4C5"))
    _label(right, "Legendary supply", Vector2(16, 132), 11, Color("#FFD15A"))
    _label(right, "Legendary creatures are global unique assets.\nThe server decides ownership — never the client.", Vector2(16, 154), 10, Color("#A9B4C5"))
    _label(right, "Prototype status", Vector2(16, 222), 11, Color("#67D7B2"))
    _label(right, "This screen is intentionally local.\nWhen backend is added, this UI can become a real marketplace without changing the collection model.", Vector2(16, 244), 10, Color("#A9B4C5"))

func _build_modal_layer() -> void:
    _ui.modal = Control.new()
    _ui.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _ui.modal.z_index = 100
    _ui.modal.visible = false
    add_child(_ui.modal)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.01, 0.02, 0.05, 0.88)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _ui.modal.add_child(shade)

    var card := _panel(_ui.modal, Vector2(250, 88), Vector2(780, 542), "PACK OPENED")
    _ui.reveal_panel = card
    _ui.reveal_title = _label(card, "", Vector2(26, 46), 22, Color("#F5F2FB"))
    _ui.reveal_cards = HBoxContainer.new()
    _ui.reveal_cards.position = Vector2(24, 90)
    _ui.reveal_cards.size = Vector2(732, 350)
    _ui.reveal_cards.add_theme_constant_override("separation", 12)
    card.add_child(_ui.reveal_cards)
    _ui.close_reveal = _button(card, "CLOSE", Vector2(300, 466), Vector2(180, 44), 10, false)
    _ui.close_reveal.pressed.connect(func(): _ui.modal.visible = false)

func _build_toast_layer() -> void:
    _ui.toast = Label.new()
    _ui.toast.position = Vector2(360, 620)
    _ui.toast.size = Vector2(560, 50)
    _ui.toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _ui.toast.add_theme_font_size_override("font_size", 14)
    _ui.toast.visible = false
    _ui.toast.z_index = 120
    add_child(_ui.toast)

func _refresh_all() -> void:
    _refresh_resources()
    _refresh_battle()
    _refresh_locations()
    _refresh_collection()
    _refresh_heroes()
    _refresh_market()
    _refresh_tabs()

func _refresh_resources() -> void:
    _ui.essence.text = "ESSENCE\n%s" % _fmt(essence)
    _ui.dark.text = "DARK ESSENCE\n%s" % _fmt(dark_essence)
    _ui.collection.text = "COLLECTION\n%d/%d" % [_collection_unlocked_count(), creatures.size()]
    _ui.kills.text = "KILLS\n%s" % _fmt(kills)

func _refresh_tabs() -> void:
    for key in _ui.tabs:
        var b: Button = _ui.tabs[key]
        b.modulate = Color("#E7E8EE") if key == current_view else Color("#7A879D")
    for key in _ui.views:
        _ui.views[key].visible = key == current_view

func _refresh_locations() -> void:
    for i in locations.size():
        var b: Button = _ui.location_buttons[i]
        var loc: Dictionary = locations[i]
        if i == selected_location:
            b.modulate = loc.accent
        else:
            b.modulate = Color("#E4E7EF")
    _ui.location_note.text = _location_description(selected_location)

func _refresh_battle() -> void:
    var boss: Dictionary = _current_boss()
    var loc: Dictionary = locations[selected_location]
    _ui.boss_name.text = boss.name
    _ui.boss_meta.text = "%s  ·  %s  ·  +%d Essence on kill" % [loc.name, loc.desc, _essence_reward()]
    var hp_ratio := clampf(float(boss_hp) / float(boss_max_hp), 0.0, 1.0)
    _ui.hp_bar.size.x = 636.0 * hp_ratio
    _ui.hp_text.text = "%s / %s HP" % [_fmt(boss_hp), _fmt(boss_max_hp)]
    _ui.boss_art.texture = _load_art("bosses", boss.id, "boss_placeholder.svg")
    _ui.boss_tag.text = "BOSS CARD %s  ·  TAP DAMAGE ×3  ·  AUTO %s" % [_boss_collection_status(boss.id), "ON" if auto_attacking else "OFF"]
    _ui.auto_btn.text = "AUTO: ON" if auto_attacking else "AUTO: OFF"
    _ui.last_drop.text = last_drop
    _ui.progress.text = "Creatures: %d/%d\nBosses discovered: %d/%d\n\nGoal: build a specialized farm, then chase rare drops." % [_collection_unlocked_count(), creatures.size(), boss_collection.size(), bosses.size()]
    _ui.hero_summary.text = "TEAM DPS: %s/sec   ·   Selected: %s   ·   %s" % [_fmt(_total_hero_damage()), _hero_name(selected_hero), _hero_role(selected_hero)]

func _refresh_collection() -> void:
    for child in _ui.collection_grid.get_children():
        child.queue_free()
    var shown := 0
    for c in creatures:
        if collection_filter != "All" and c.rarity != collection_filter:
            continue
        shown += 1
        _make_collection_card(c)
    _ui.collection_hint.text = "%d cards shown\nMissing cards can be chased through themed packs.\nDark packs remove Common from the pool." % shown
    for f in _ui.filter_buttons:
        _ui.filter_buttons[f].modulate = Color("#E8EAEE") if f == collection_filter else Color("#8D99AE")

func _refresh_heroes() -> void:
    for child in _ui.hero_roster.get_children():
        child.queue_free()
    _ui.hero_total_damage.text = "TOTAL TEAM DPS  %s" % _fmt(_total_hero_damage())
    for h in heroes:
        _make_hero_card(h)

func _refresh_market() -> void:
    for child in _ui.market_list.get_children():
        child.queue_free()
    var offers := [
        {"id":"void_reaper", "seller":"Player_071", "price":2400},
        {"id":"plague_saint", "seller":"NightMarket", "price":1750},
        {"id":"ash_colossus", "seller":"AshTrader", "price":2100},
        {"id":"star_eater", "seller":"VoidWhale", "price":9800}
    ]
    for offer in offers:
        var c := _creature_by_id(offer.id)
        var row := _panel(_ui.market_list, Vector2.ZERO, Vector2(778, 92), "")
        var tex := TextureRect.new()
        tex.position = Vector2(8, 8)
        tex.size = Vector2(76, 76)
        tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex.texture = _load_art("creatures", c.id, "creature_placeholder.svg")
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(tex)
        _label(row, c.name, Vector2(100, 14), 11, RARITY_COLORS[c.rarity])
        _label(row, "%s  ·  Seller %s" % [c.rarity.to_upper(), offer.seller], Vector2(100, 38), 9, Color("#7C889F"))
        var buy := _button(row, "BUY  %s" % _fmt(int(offer.price)), Vector2(592, 24), Vector2(166, 40), 10, false)
        buy.pressed.connect(_buy_market_card.bind(c.id, int(offer.price)))

func _make_collection_card(c: Dictionary) -> Control:
    var rarity: String = c.rarity
    var count := int(collection.get(c.id, 0))
    var lvl := _card_level(c)
    var next_req := _next_requirement(c, lvl)
    var card := _panel(_ui.collection_grid, Vector2.ZERO, Vector2(184, 248), "")
    card.custom_minimum_size = Vector2(184, 248)
    card.add_theme_stylebox_override("panel", _style(Color("#0D1421"), RARITY_COLORS[rarity], 12, 2))
    var tex := TextureRect.new()
    tex.position = Vector2(28, 14)
    tex.size = Vector2(128, 128)
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex.texture = _load_art("creatures", c.id, "creature_placeholder.svg")
    tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(tex)
    _label(card, c.name, Vector2(12, 150), 10, Color("#E7EAF0"))
    _label(card, rarity.to_upper(), Vector2(12, 172), 8, RARITY_COLORS[rarity])
    _label(card, "%s  +%d" % [c.buff, int(round(float(c.base) * _card_multiplier(rarity, lvl)))], Vector2(12, 194), 8, Color("#8996AA"))
    var prog := "%d copies" % count
    if next_req > 0:
        prog += "  →  %d" % next_req
    else:
        prog += "  ·  MAX"
    _label(card, prog, Vector2(12, 218), 8, Color("#BBC4D2"))
    return card

func _make_hero_card(h: Dictionary) -> Control:
    var id: String = h.id
    var unlocked: bool = bool(unlocked_heroes.get(id, false))
    var lv := int(hero_levels.get(id, 1))
    var card := _panel(_ui.hero_roster, Vector2.ZERO, Vector2(400, 320), "")
    card.custom_minimum_size = Vector2(400, 320)
    card.add_theme_stylebox_override("panel", _style(Color("#0D1421"), h.accent if unlocked else Color("#30394D"), 14, 2))
    var tex := TextureRect.new()
    tex.position = Vector2(18, 24)
    tex.size = Vector2(128, 128)
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex.texture = _load_art("heroes", id, "hero_placeholder.svg")
    tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(tex)
    _label(card, h.name, Vector2(162, 28), 13, h.accent if unlocked else Color("#6A768B"))
    _label(card, h.role, Vector2(162, 52), 9, Color("#7F8BA0"))
    var damage := _hero_damage(h)
    _label(card, "%s DMG/s" % _fmt(damage), Vector2(162, 80), 18, Color("#F0F2F7"))
    _label(card, "LEVEL %d" % lv, Vector2(162, 110), 9, Color("#8794A8"))
    if unlocked:
        var cost := _hero_upgrade_cost(id)
        var up := _button(card, "UPGRADE  %s" % _fmt(cost), Vector2(18, 186), Vector2(364, 48), 10, false)
        up.pressed.connect(_upgrade_hero.bind(id))
        var select := _button(card, "SELECT", Vector2(18, 246), Vector2(176, 42), 9, true)
        select.pressed.connect(_select_hero.bind(id))
        var current := _label(card, "ACTIVE" if selected_hero == id else "", Vector2(208, 258), 9, h.accent)
    else:
        var unlock := _button(card, "UNLOCK  %s" % _fmt(int(h.unlock)), Vector2(18, 186), Vector2(364, 48), 10, false)
        unlock.pressed.connect(_unlock_hero.bind(id))
        _label(card, "Locked hero", Vector2(18, 248), 9, Color("#606C80"))
    return card

func _manual_attack() -> void:
    _attack(_total_hero_damage() * 3, true)

func _attack(amount: int, manual: bool) -> void:
    if amount <= 0:
        return
    boss_hp -= amount
    _combat_vfx(amount, manual)
    if boss_hp <= 0:
        _kill_boss()
    else:
        _refresh_battle()

func _kill_boss() -> void:
    var boss: Dictionary = _current_boss()
    var loc: Dictionary = locations[selected_location]
    var reward := _essence_reward()
    essence += reward
    total_essence_earned += reward
    kills += 1
    var dark_gain := 0
    var dark_chance := float(loc.dark) * float(boss.dark_mult)
    var dark_bonus: float = float(_card_buffs()["dark"])
    dark_chance = min(0.80, dark_chance + float(dark_bonus))
    if randf() < dark_chance:
        dark_gain = 1
        if randf() < 0.20:
            dark_gain += 1
        dark_essence += dark_gain
    boss_index += 1
    _reset_boss(false)
    var reward_text := "+%s ESSENCE" % _fmt(reward)
    if dark_gain > 0:
        reward_text += "   +%d DARK" % dark_gain
    _show_toast(reward_text, Color("#F1D37B"))
    _refresh_all()

func _reset_boss(show_toast: bool = true) -> void:
    var boss := _current_boss()
    boss_max_hp = int(boss.hp) + int(boss_index / 6) * 350
    boss_hp = boss_max_hp
    if show_toast:
        _show_toast(boss.name, locations[selected_location].accent)

func _open_essence_pack(count: int) -> void:
    var cost := int(PACK_COSTS[count])
    if essence < cost:
        _show_toast("Need %s more Essence" % _fmt(cost - essence), Color("#FF7387"))
        return
    essence -= cost
    var drops: Array = []
    for i in count:
        drops.append(_draw_pack_item(false))
    _show_reveal("ESSENCE PACK  ·  %d CARDS" % count, drops)
    _refresh_all()

func _open_dark_pack() -> void:
    if dark_essence < DARK_PACK_COST:
        _show_toast("Need %d more Dark Essence" % (DARK_PACK_COST - dark_essence), Color("#FF7387"))
        return
    dark_essence -= DARK_PACK_COST
    var drops: Array = [_draw_pack_item(true)]
    _show_reveal("DARK PACK  ·  NO COMMON", drops)
    _refresh_all()

func _draw_pack_item(dark_only: bool) -> Dictionary:
    var boss_chance := DARK_PACK_BOSS_CHANCE if dark_only else NORMAL_PACK_BOSS_CHANCE
    if randf() < boss_chance:
        var boss: Dictionary = bosses[randi() % bosses.size()]
        boss_collection[boss.id] = 1
        return {"kind":"boss", "id":boss.id, "name":boss.name, "rarity":"Boss", "new":true}

    var weights: Dictionary = DARK_RARITY_WEIGHTS if dark_only else RARITY_WEIGHTS
    var pool: Array = []
    for c in creatures:
        if not weights.has(c.rarity):
            continue
        pool.append(c)
    var total := 0.0
    for c in pool:
        total += float(weights[c.rarity])
    var roll := randf() * total
    for c in pool:
        roll -= float(weights[c.rarity])
        if roll <= 0.0:
            var before := int(collection.get(c.id, 0))
            collection[c.id] = before + 1
            var new_card := before == 0
            return {"kind":"creature", "id":c.id, "name":c.name, "rarity":c.rarity, "new":new_card}
    return {"kind":"creature", "id":pool[0].id, "name":pool[0].name, "rarity":pool[0].rarity, "new":false}

func _show_reveal(title: String, drops: Array) -> void:
    _ui.reveal_title.text = title
    for child in _ui.reveal_cards.get_children():
        child.queue_free()
    for drop in drops:
        _ui.reveal_cards.add_child(_make_reveal_card(drop))
    _ui.modal.visible = true
    last_drop = _format_drop_line(drops)
    if not drops.is_empty():
        var first: Dictionary = drops[0]
        _show_toast("NEW CARD" if bool(first.new) else "CARD ACQUIRED", _drop_color(first))

func _make_reveal_card(drop: Dictionary) -> Control:
    var card := Panel.new()
    card.custom_minimum_size = Vector2(228, 330)
    card.add_theme_stylebox_override("panel", _style(Color("#111827"), _drop_color(drop), 14, 2))
    var folder := "bosses" if drop.kind == "boss" else "creatures"
    var placeholder := "boss_placeholder.svg" if drop.kind == "boss" else "creature_placeholder.svg"
    var art_id := String(drop.id)
    var tex := TextureRect.new()
    tex.position = Vector2(22, 18)
    tex.size = Vector2(184, 184)
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex.texture = _load_art(folder, art_id, placeholder)
    tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(tex)
    _label(card, drop.name, Vector2(14, 220), 10, Color("#EFF1F6"))
    _label(card, String(drop.rarity).to_upper(), Vector2(14, 244), 9, _drop_color(drop))
    _label(card, "NEW" if bool(drop.new) else "DUPLICATE", Vector2(14, 272), 9, Color("#8E9AAF"))
    return card

func _format_drop_line(drops: Array) -> String:
    var lines: Array[String] = []
    for drop in drops:
        var extra := "NEW" if bool(drop.new) else "DUP"
        lines.append("%s [%s] · %s" % [drop.name, String(drop.rarity).to_upper(), extra])
    return "\n".join(lines)

func _buy_market_card(id: String, price: int) -> void:
    if essence < price:
        _show_toast("Need %s more Essence" % _fmt(price - essence), Color("#FF7387"))
        return
    essence -= price
    collection[id] = int(collection.get(id, 0)) + 1
    var c := _creature_by_id(id)
    _show_toast("BOUGHT  ·  %s" % c.name, RARITY_COLORS[c.rarity])
    _refresh_all()

func _select_hero(id: String) -> void:
    if not bool(unlocked_heroes.get(id, false)):
        return
    selected_hero = id
    _show_toast("SELECTED  ·  %s" % _hero_name(id), _hero_by_id(id).accent)
    _refresh_all()

func _upgrade_hero(id: String) -> void:
    if not bool(unlocked_heroes.get(id, false)):
        return
    var cost := _hero_upgrade_cost(id)
    if essence < cost:
        _show_toast("Need %s more Essence" % _fmt(cost - essence), Color("#FF7387"))
        return
    essence -= cost
    hero_levels[id] = int(hero_levels.get(id, 1)) + 1
    _show_toast("%s  LEVEL %d" % [_hero_name(id), int(hero_levels[id])], _hero_by_id(id).accent)
    _refresh_all()

func _unlock_hero(id: String) -> void:
    var h := _hero_by_id(id)
    var cost := int(h.unlock)
    if essence < cost:
        _show_toast("Need %s more Essence" % _fmt(cost - essence), Color("#FF7387"))
        return
    essence -= cost
    unlocked_heroes[id] = true
    _show_toast("HERO UNLOCKED  ·  %s" % h.name, h.accent)
    _refresh_all()

func _select_location(idx: int) -> void:
    if idx == selected_location:
        return
    selected_location = idx
    boss_index = 0
    _reset_boss(false)
    _show_toast(locations[idx].name, locations[idx].accent)
    _refresh_all()

func _toggle_auto() -> void:
    auto_attacking = not auto_attacking
    _show_toast("AUTO ATTACK ON" if auto_attacking else "AUTO ATTACK OFF", Color("#79D6B4"))
    _refresh_battle()

func _on_tab(view_name: String) -> void:
    current_view = view_name
    _refresh_tabs()

func _set_collection_filter(filter_name: String) -> void:
    collection_filter = filter_name
    _refresh_collection()

func _total_hero_damage() -> int:
    var total := 0
    for h in heroes:
        if bool(unlocked_heroes.get(h.id, false)):
            total += _hero_damage(h)
    var buffs := _card_buffs()
    total = int(round(float(total) * (1.0 + float(buffs.damage) / 100.0)))
    return max(1, total)

func _hero_damage(h: Dictionary) -> int:
    var lv := int(hero_levels.get(h.id, 1))
    return int(round(float(h.base_damage) * (1.0 + float(lv - 1) * 0.18)))

func _hero_upgrade_cost(id: String) -> int:
    var lv := int(hero_levels.get(id, 1))
    return 160 + lv * lv * 90

func _essence_reward() -> int:
    var boss := _current_boss()
    var loc: Dictionary = locations[selected_location]
    var base := 34.0 * float(loc.ess_mult) * float(boss.ess_mult)
    var buffs := _card_buffs()
    var mult := 1.0 + float(buffs.ess) / 100.0 + float(buffs.global) / 100.0
    return max(1, int(round(base * mult)))

func _card_buffs() -> Dictionary:
    var out := {"ess":0.0, "damage":0.0, "dark":0.0, "luck":0.0, "global":0.0}
    for c in creatures:
        var lvl := _card_level(c)
        if lvl <= 0:
            continue
        var value := float(c.base) * _card_multiplier(c.rarity, lvl)
        match String(c.buff):
            "Essence gain": out.ess += value
            "Hero damage": out.damage += value
            "Boss damage": out.damage += value * 1.1
            "Dark chance": out.dark += value / 100.0
            "Pack luck": out.luck += value
    return out

func _card_multiplier(rarity: String, lvl: int) -> float:
    match rarity:
        "Common": return 1.0 + float(max(0, lvl - 1)) * 0.75
        "Rare": return 1.0 + float(max(0, lvl - 1)) * 0.90
        "Epic": return 1.0 + float(max(0, lvl - 1)) * 1.10
        "Mythic": return 1.0 + float(max(0, lvl - 1)) * 1.60
        "Legendary": return 5.0
        _: return 1.0

func _card_level(c: Dictionary) -> int:
    var copies := int(collection.get(c.id, 0))
    match String(c.rarity):
        "Common", "Rare":
            if copies >= 17: return 4
            if copies >= 7: return 3
            if copies >= 2: return 2
            return 1 if copies > 0 else 0
        "Epic":
            if copies >= 10: return 4
            if copies >= 5: return 3
            if copies >= 2: return 2
            return 1 if copies > 0 else 0
        "Mythic":
            return 2 if copies >= 2 else (1 if copies > 0 else 0)
        "Legendary":
            return 1 if copies > 0 else 0
        _: return 0

func _next_requirement(c: Dictionary, lvl: int) -> int:
    match String(c.rarity):
        "Common", "Rare":
            return [0, 2, 7, 17][lvl] if lvl >= 0 and lvl < 4 else 0
        "Epic":
            return [0, 2, 5, 10][lvl] if lvl >= 0 and lvl < 4 else 0
        "Mythic":
            return 2 if lvl == 1 else 0
        _: return 0

func _current_boss() -> Dictionary:
    var pool: Array = []
    for b in bosses:
        if int(b.location) == selected_location:
            pool.append(b)
    if pool.is_empty():
        return bosses[0]
    return pool[boss_index % pool.size()]

func _boss_collection_status(id: String) -> String:
    return "UNLOCKED" if boss_collection.has(id) else "UNSEEN"

func _location_description(idx: int) -> String:
    match idx:
        0: return "FAST ESSENCE: best place to save for the 1300 Essence pack. Dark Essence is scarce."
        1: return "BALANCED: solid Essence with a meaningful Dark Essence chance."
        _: return "DARK FARM: slower basic income, highest chance to pull Dark Essence."

func _collection_unlocked_count() -> int:
    var n := 0
    for c in creatures:
        if int(collection.get(c.id, 0)) > 0:
            n += 1
    return n

func _creature_by_id(id: String) -> Dictionary:
    for c in creatures:
        if c.id == id:
            return c
    return creatures[0]

func _hero_by_id(id: String) -> Dictionary:
    for h in heroes:
        if h.id == id:
            return h
    return heroes[0]

func _hero_name(id: String) -> String:
    return String(_hero_by_id(id).name)

func _hero_role(id: String) -> String:
    return String(_hero_by_id(id).role)

func _drop_color(drop: Dictionary) -> Color:
    if drop.kind == "boss":
        return Color("#F2BB55")
    return RARITY_COLORS[String(drop.rarity)]

func _load_art(folder: String, id: String, placeholder: String) -> Texture2D:
    var exts := ["png", "webp", "jpg", "jpeg"]
    for ext in exts:
        var path := "res://art/%s/%s.%s" % [folder, id, ext]
        if ResourceLoader.exists(path):
            return load(path) as Texture2D
    var fallback := "res://art/placeholders/%s" % placeholder
    return load(fallback) as Texture2D

func _combat_vfx(amount: int, manual: bool) -> void:
    var center := Vector2(562, 322)
    var dmg := _label(self, "-%s" % _fmt(amount), center + Vector2(randf_range(-35, 35), 0), 18 if manual else 14, Color("#FFF0F4"))
    dmg.z_index = 140
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(dmg, "position", dmg.position + Vector2(randf_range(-28, 28), -60), 0.42)
    t.tween_property(dmg, "modulate:a", 0.0, 0.42)
    t.chain().tween_callback(dmg.queue_free)
    var flash := ColorRect.new()
    flash.position = Vector2(350, 235)
    flash.size = Vector2(416, 316)
    flash.color = Color(1, 1, 1, 0.11 if manual else 0.06)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.z_index = 130
    add_child(flash)
    var ft := create_tween()
    ft.tween_property(flash, "modulate:a", 0.0, 0.08)
    ft.tween_callback(flash.queue_free)
    if _ui.has("boss_art"):
        var art: TextureRect = _ui.boss_art
        var original := art.scale
        art.scale = original * (1.035 if manual else 1.018)
        var at := create_tween()
        at.tween_property(art, "scale", original, 0.10)

func _show_toast(text_value: String, color: Color) -> void:
    _ui.toast.text = text_value
    _ui.toast.modulate = color
    _ui.toast.modulate.a = 1.0
    _ui.toast.visible = true
    _ui.toast.position = Vector2(360, 622)
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(_ui.toast, "position", Vector2(360, 595), 0.42)
    t.tween_property(_ui.toast, "modulate:a", 0.0, 0.42)
    t.chain().tween_callback(func(): _ui.toast.visible = false)

func _show_offline_reward() -> void:
    if last_seen_unix <= 0.0:
        return
    var elapsed := clampf(Time.get_unix_time_from_system() - last_seen_unix, 0.0, OFFLINE_CAP)
    if elapsed < 30.0:
        return
    var offline_rate := float(_essence_reward())
    var gained := int(round(elapsed * offline_rate * 0.45))
    if gained <= 0:
        return
    essence += gained
    _show_toast("OFFLINE INCOME  +%s ESSENCE" % _fmt(gained), Color("#79D6B4"))

func _save_game() -> void:
    last_seen_unix = Time.get_unix_time_from_system()
    var data := {
        "version": VERSION,
        "essence": essence,
        "dark_essence": dark_essence,
        "selected_location": selected_location,
        "boss_index": boss_index,
        "kills": kills,
        "total_essence_earned": total_essence_earned,
        "auto_attacking": auto_attacking,
        "selected_hero": selected_hero,
        "hero_levels": hero_levels,
        "unlocked_heroes": unlocked_heroes,
        "collection": collection,
        "boss_collection": boss_collection,
        "last_seen_unix": last_seen_unix
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()
        last_save_msec = Time.get_ticks_msec()

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    essence = int(parsed.get("essence", essence))
    dark_essence = int(parsed.get("dark_essence", dark_essence))
    selected_location = clampi(int(parsed.get("selected_location", selected_location)), 0, locations.size() - 1)
    boss_index = max(0, int(parsed.get("boss_index", boss_index)))
    kills = max(0, int(parsed.get("kills", kills)))
    total_essence_earned = max(0, int(parsed.get("total_essence_earned", total_essence_earned)))
    auto_attacking = bool(parsed.get("auto_attacking", auto_attacking))
    selected_hero = String(parsed.get("selected_hero", selected_hero))
    hero_levels = parsed.get("hero_levels", hero_levels)
    unlocked_heroes = parsed.get("unlocked_heroes", unlocked_heroes)
    collection = parsed.get("collection", collection)
    boss_collection = parsed.get("boss_collection", boss_collection)
    last_seen_unix = float(parsed.get("last_seen_unix", 0.0))
    for h in heroes:
        if not hero_levels.has(h.id):
            hero_levels[h.id] = 1
        if not unlocked_heroes.has(h.id):
            unlocked_heroes[h.id] = false
    for c in creatures:
        if not collection.has(c.id):
            collection[c.id] = 0

func _panel(parent: Control, pos: Vector2, size: Vector2, header: String) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size
    p.add_theme_stylebox_override("panel", _style(Color("#0C121E"), Color("#202A3D"), 12, 1))
    parent.add_child(p)
    if header != "":
        _label(p, header, Vector2(16, 14), 10, Color("#6D7890"))
    return p

func _resource_chip(parent: Control, pos: Vector2, size: Vector2, title: String, color: Color) -> Label:
    var p := Panel.new()
    p.position = pos
    p.size = size
    p.add_theme_stylebox_override("panel", _style(Color("#111827"), Color("#202A3D"), 9, 1))
    parent.add_child(p)
    var value := _label(p, title + "\n—", Vector2(10, 5), 9, color)
    return value

func _button(parent: Control, text_value: String, pos: Vector2, size: Vector2, font_size: int, flat: bool) -> Button:
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", font_size)
    var base_color := Color("#141C2B") if not flat else Color("#111827")
    var normal := _style(base_color, Color("#2B3850"), 9, 1)
    var hover := _style(Color("#1D2940"), Color("#53627D"), 9, 1)
    var pressed := _style(Color("#2D2445"), Color("#7C63B4"), 9, 1)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    parent.add_child(b)
    return b

func _label(parent: Control, text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text_value
    l.position = pos
    l.add_theme_font_size_override("font_size", font_size)
    l.modulate = color
    parent.add_child(l)
    return l

func _style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(width)
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    return s

func _fmt(value: int) -> String:
    var s := str(value)
    var out := ""
    var count := 0
    for i in range(s.length() - 1, -1, -1):
        out = s[i] + out
        count += 1
        if count == 3 and i > 0:
            out = "," + out
            count = 0
    return out
