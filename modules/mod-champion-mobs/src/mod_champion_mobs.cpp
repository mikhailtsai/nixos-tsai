/*
 * mod-champion-mobs
 *
 * 3% chance on spawn to turn any eligible mob into a Champion:
 *   - HP × 20, damage × 2.5 / 2.25 / 2.0 / 1.75 по тиру, armor × 3, scale × 1.6
 *   - Immune to stun / fear / sleep / polymorph / charm / horror / Turn Undead
 *   - Visual auras: fire ring + rune circle + golden body glow
 *   - Creature yells on aggro, chat announce in 80-yard radius on spawn and on aggro
 *   - On kill: bonus XP (level × 200 per group member) + generous gold
 *     + бонусный лут по тиру (BoE зелёные/синие/фиолетовые из DB)
 *     stacked ON TOP of the creature's normal loot
 *
 * Тиры чемпионов (все с 3% шансом):
 *   Tier 1 — Обычный   (NORMAL/RARE в открытом мире):  2–4 зелёных/синих,            HP ×20
 *   Tier 2 — Элитный   (ELITE/RAREELITE, не босс):     2–4 зелёных/синих + 1–2 epic, HP ×20
 *   Tier 3 — Босс данжа (в instance_encounters, данж): 2–4 зелёных/синих + 6–8 epic, HP ×20
 *   Tier 4 — Босс рейда (в instance_encounters, рейд,
 *                         или WORLDBOSS):               2–4 зелёных/синих + 25–30 epic, HP ×20
 *
 * Легендарные чемпионы (20% от чемпионов, ~0.6% всех мобов):
 *   - Те же тиры, но: scale ×2.0, золотые ауры, объявление на 150 ярдов
 *   - Активные способности в бою: прыжок за спину / призыв стаи / топот (стан 3с, 35 ярдов)
 *   - Двойное количество эпиков + 10% шанс на предмет legendary (orange) качества
 *
 * Боссы определяются через instance_encounters.creditEntry (creditType=0) —
 * та же таблица, по которой LFG показывает "X из Y боссов убито".
 *
 * Eligibility filter:
 *   - Skips pets, summons, totems
 *   - Skips Alliance/Horde faction NPCs (guards, vendors, quest givers)
 *   - Skips non-attackable units
 *   - Only beast, dragonkin, demon, elemental, giant, undead, humanoid, mechanical
 *   - Level >= 2
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Group.h"
#include "Chat.h"
#include "Map.h"
#include "Random.h"
#include "Log.h"
#include "LootMgr.h"
#include "DatabaseEnv.h"
#include "SharedDefines.h"
#include "DBCStores.h"
#include "RandomPlayerbotMgr.h"

#include <cmath>
#include <mutex>
#include <array>
#include <algorithm>
#include <unordered_set>
#include <vector>
#include <string>

// ══════════════════════════════════════════════════════════════════════════════
// TUNING CONSTANTS
// ══════════════════════════════════════════════════════════════════════════════

// ── Champion ──────────────────────────────────────────────────────────────────
static constexpr float  CHAMPION_CHANCE           = 3.0f;
static constexpr float  CHAMPION_HP_MULT          = 20.0f;
static constexpr float  CHAMPION_DMG_MULT         = 5.0f;   // обычные
static constexpr float  CHAMPION_DMG_MULT_ELITE   = 4.5f;  // элитные
static constexpr float  CHAMPION_DMG_MULT_DUNGEON = 4.0f;   // боссы данжа
static constexpr float  CHAMPION_DMG_MULT_RAID    = 3.5f;  // боссы рейда
static constexpr float  CHAMPION_ARMOR_MULT       = 3.0f;
static constexpr float  CHAMPION_SCALE            = 1.6f;
static constexpr uint32 CHAMPION_XP_PER_LVL       = 400;

// ── Legendary (подмножество чемпионов) ────────────────────────────────────────
static constexpr float  LEGEND_CHANCE      = 20.0f;  // % чемпионов, которые становятся легендарными
static constexpr float  LEGEND_SCALE       = 2.0f;   // итоговый множитель размера (заменяет CHAMPION_SCALE)
static constexpr float  LEGEND_HP_MULT     = 30.0f;  // HP легендарного (от базового HP моба)
static constexpr float  LEGEND_DMG_MULT    = 7.0f;   // урон легендарного (от базового, независимо от тира)

// Кулдауны способностей (мс)
static constexpr uint32 LEGEND_BLINK_CD  = 15'000; // прыжок за спину
static constexpr uint32 LEGEND_SUMMON_CD = 45'000; // призыв стаи
static constexpr uint32 LEGEND_STOMP_CD  = 60'000; // топот (Earthquake — 3с стан, 35 ярдов)

// Задержка перед первым применением (чтобы способности не срабатывали одновременно)
static constexpr uint32 LEGEND_BLINK_INIT  =  8'000;
static constexpr uint32 LEGEND_SUMMON_INIT = 25'000;
static constexpr uint32 LEGEND_STOMP_INIT  = 40'000;

static constexpr uint32 LEGEND_STOMP_SPELL = 33919; // Earthquake: 3с стан, 35 ярдов, vis=5424

// ══════════════════════════════════════════════════════════════════════════════
// SOUND IDs  (WotLK 3.3.5a)
// Проверить: .debug play sound <id>
// ══════════════════════════════════════════════════════════════════════════════

static constexpr uint32 SOUND_CHAMPION_ROAR        = 8585;   // короткий рёв
static constexpr uint32 SOUND_CHAMPION_MUSIC       = 11803;  // L70ETC рок
static constexpr uint32 SOUND_YOU_ARE_NOT_PREPARED = 11466;  // Иллидан
static constexpr uint32 SOUND_LICH_KING_SPECIAL    = 17372;  // IC_Lich King_Special02

// ══════════════════════════════════════════════════════════════════════════════
// VISUAL AURA IDs  (WotLK 3.3.5a)
// Верифицированы из Spell.dbc: Effect=APPLY_AURA, EffectAura=DUMMY,
// target=self, duration=permanent(-1), no periodic, нет скрипта в AC.
// ══════════════════════════════════════════════════════════════════════════════

// ── Обычный чемпион (красная тема) ───────────────────────────────────────────
static constexpr uint32 AURA_VERTEX_RED     = 69844;  // "Vertex Color Bright Red"     — красит модель
static constexpr uint32 AURA_RED_RADIATION  = 52679;  // "Red Radiation"                — красное излучение
static constexpr uint32 AURA_SHADOW_GLOW    = 72523;  // "Shadowmourne Visual High"     — ICC-теневое свечение
static constexpr uint32 AURA_FIERY          = 39839;  // "Fiery Aura"                   — огонь (общий)
static constexpr uint32 AURA_ENRAGE_VIS     = 42438;  // "HH Climax – Enraged Visual"   — берсерк

// ── Легендарный чемпион (золотая тема) ───────────────────────────────────────
// Проверить в игре: .npc addaura <id>
static constexpr uint32 AURA_LEGEND_GOLD         = 69845;  // кандидат: Vertex Color Yellow (рядом с 69844)
static constexpr uint32 AURA_LEGEND_RADIANCE     = 36909;  // кандидат: Holy Radiance glow
static constexpr uint32 AURA_LEGEND_BUBBLE       = 36032;  // кандидат: divine shield / bubble visual
static constexpr uint32 AURA_LEGEND_VERTEX_BLACK = 39833;  // Vertex Shade Black — затемняет модель
static constexpr uint32 AURA_LEGEND_SHADOWS_EDGE = 70504;  // Shadow's Edge Aura — аура квеста Shadowmourne

// ══════════════════════════════════════════════════════════════════════════════
// ITEM POOLS
// ══════════════════════════════════════════════════════════════════════════════

struct ChampionItemEntry { uint32 reqLevel; uint32 itemId; };

static std::vector<ChampionItemEntry> s_itemPool;       // Quality 2-3 (зелёные/синие)
static std::vector<ChampionItemEntry> s_epicPool;        // Quality 4   (фиолетовые)
static std::vector<ChampionItemEntry> s_legendaryPool;   // Quality 5   (оранжевые легендарные)

static std::unordered_set<uint32> s_bossEntries;         // из instance_encounters

// Окна уровней для подбора предметов:
//   Зелёные/синие : [level-3, level+2]
//   Фиолетовые    : [level-5, level+3]   (боссы редкие, пул должен быть достаточным)
//   Легендарные   : [level-10, level+5]  (очень мало предметов, широкое окно)

static std::vector<uint32> GetItemsForLevel(uint8 level)
{
    uint32 minLvl = level > 3 ? level - 3 : 1;
    uint32 maxLvl = level + 2;
    std::vector<uint32> result;
    for (auto const& e : s_itemPool)
        if (e.reqLevel >= minLvl && e.reqLevel <= maxLvl)
            result.push_back(e.itemId);
    return result;
}

static std::vector<uint32> GetEpicItemsForLevel(uint8 level)
{
    uint32 minLvl = level > 5 ? level - 5 : 1;
    uint32 maxLvl = level + 3;
    std::vector<uint32> result;
    for (auto const& e : s_epicPool)
        if (e.reqLevel >= minLvl && e.reqLevel <= maxLvl)
            result.push_back(e.itemId);
    return result;
}

static std::vector<uint32> GetLegendaryItemsForLevel(uint8 level)
{
    uint32 minLvl = level > 10 ? level - 10 : 1;
    uint32 maxLvl = std::min(static_cast<uint32>(level) + 5u, 80u);
    std::vector<uint32> result;
    for (auto const& e : s_legendaryPool)
        if (e.reqLevel >= minLvl && e.reqLevel <= maxLvl)
            result.push_back(e.itemId);
    return result;
}

static void LoadItemPools()
{
    // Зелёные и синие BoE
    if (QueryResult r = WorldDatabase.Query(
        "SELECT entry, RequiredLevel FROM item_template "
        "WHERE Quality IN (2, 3) AND Bonding = 2 "
        "  AND RequiredLevel BETWEEN 1 AND 80 "
        "  AND class IN (2, 4) AND InventoryType > 0 AND entry < 90000 "
        "ORDER BY RequiredLevel"))
    {
        do {
            auto f = r->Fetch();
            s_itemPool.push_back({ f[1].Get<uint32>(), f[0].Get<uint32>() });
        } while (r->NextRow());
    }
    LOG_INFO("module", "mod-champion-mobs: green/blue pool: {} items", s_itemPool.size());

    // Фиолетовые BoE
    if (QueryResult r = WorldDatabase.Query(
        "SELECT entry, RequiredLevel FROM item_template "
        "WHERE Quality = 4 AND Bonding = 2 "
        "  AND RequiredLevel BETWEEN 1 AND 80 "
        "  AND class IN (2, 4) AND InventoryType > 0 AND entry < 90000 "
        "ORDER BY RequiredLevel"))
    {
        do {
            auto f = r->Fetch();
            s_epicPool.push_back({ f[1].Get<uint32>(), f[0].Get<uint32>() });
        } while (r->NextRow());
    }
    LOG_INFO("module", "mod-champion-mobs: epic pool: {} items", s_epicPool.size());

    // Легендарные (Quality=5, любое привязывание — мы пушим напрямую в лут)
    if (QueryResult r = WorldDatabase.Query(
        "SELECT entry, RequiredLevel FROM item_template "
        "WHERE Quality = 5 "
        "  AND RequiredLevel BETWEEN 1 AND 80 "
        "  AND InventoryType > 0 AND entry < 90000 "
        "ORDER BY RequiredLevel"))
    {
        do {
            auto f = r->Fetch();
            s_legendaryPool.push_back({ f[1].Get<uint32>(), f[0].Get<uint32>() });
        } while (r->NextRow());
    }
    LOG_INFO("module", "mod-champion-mobs: legendary pool: {} items", s_legendaryPool.size());

    // Боссы по instance_encounters
    if (QueryResult r = WorldDatabase.Query(
        "SELECT creditEntry FROM instance_encounters WHERE creditType = 0"))
    {
        do {
            s_bossEntries.insert(r->Fetch()[0].Get<uint32>());
        } while (r->NextRow());
    }
    LOG_INFO("module", "mod-champion-mobs: boss entries: {}", s_bossEntries.size());
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAMPION TIER
// ══════════════════════════════════════════════════════════════════════════════

enum ChampionTier
{
    CHAMPION_TIER_NORMAL       = 0,
    CHAMPION_TIER_ELITE        = 1,
    CHAMPION_TIER_DUNGEON_BOSS = 2,
    CHAMPION_TIER_RAID_BOSS    = 3,
};

static ChampionTier GetChampionTier(Creature const* c)
{
    CreatureTemplate const* tmpl = c->GetCreatureTemplate();
    if (!tmpl)
        return CHAMPION_TIER_NORMAL;

    if (tmpl->rank == CREATURE_ELITE_WORLDBOSS)
        return CHAMPION_TIER_RAID_BOSS;

    if (s_bossEntries.count(tmpl->Entry))
        return c->GetMap()->IsRaid() ? CHAMPION_TIER_RAID_BOSS : CHAMPION_TIER_DUNGEON_BOSS;

    if (tmpl->rank == CREATURE_ELITE_ELITE || tmpl->rank == CREATURE_ELITE_RAREELITE)
        return CHAMPION_TIER_ELITE;

    return CHAMPION_TIER_NORMAL;
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAMPION REGISTRY
// ══════════════════════════════════════════════════════════════════════════════

struct ChampionData
{
    // Базовые характеристики для восстановления (RevertChampion / AutoBalance watchdog)
    uint32 targetMaxHp = 0;
    uint32 origMaxHp   = 0;
    float  origMinDmg  = 0;
    float  origMaxDmg  = 0;
    int32  origArmor   = 0;
    float  origScale   = 0;

    // Статус и агро
    bool yelled    = false;

    // Легендарный статус + таймеры способностей (0 = готово к использованию)
    bool   legendary       = false;
    uint32 blinkTimer      = 0;
    uint32 summonTimer     = 0;
    uint32 stompTimer      = 0;
    uint32 aggroSoundTimer = 0; // отложенный стингер при агро легендарного
};

static std::mutex                               s_mutex;
static std::unordered_map<uint64, ChampionData> s_champions;

static void MarkChampion(Creature const* c,
                         uint32 targetHp, uint32 origHp,
                         float origMinDmg, float origMaxDmg,
                         int32 origArmor, float origScale)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    s_champions[c->GetGUID().GetRawValue()] = {
        targetHp, origHp, origMinDmg, origMaxDmg, origArmor, origScale,
        /*yelled=*/false,
        /*legendary=*/false
    };
}

// Вызывается после MarkChampion для апгрейда до легендарного.
// Переопределяет targetMaxHp и инициализирует таймеры способностей.
static void SetLegendary(Creature const* c, uint32 newTargetHp)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    auto it = s_champions.find(c->GetGUID().GetRawValue());
    if (it == s_champions.end())
        return;
    auto& d = it->second;
    d.legendary   = true;
    d.targetMaxHp = newTargetHp;
    d.blinkTimer  = LEGEND_BLINK_INIT;
    d.summonTimer = LEGEND_SUMMON_INIT;
    d.stompTimer  = LEGEND_STOMP_INIT;
}

static bool IsChampion(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    return s_champions.count(c->GetGUID().GetRawValue()) > 0;
}

static bool IsLegendaryChampion(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    auto it = s_champions.find(c->GetGUID().GetRawValue());
    return it != s_champions.end() && it->second.legendary;
}

// Возвращает целевой HP и legendary-флаг за один lock
struct ChampionState { uint32 targetMaxHp = 0; bool legendary = false; };
static ChampionState GetChampionState(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    auto it = s_champions.find(c->GetGUID().GetRawValue());
    if (it == s_champions.end())
        return {};
    return { it->second.targetMaxHp, it->second.legendary };
}

static void UnmarkChampion(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    s_champions.erase(c->GetGUID().GetRawValue());
}

static void ApplyChampionAuras(Creature* c, bool legendary)
{
    if (legendary)
    {
        c->AddAura(AURA_LEGEND_GOLD,         c);
        c->AddAura(AURA_LEGEND_RADIANCE,     c);
        c->AddAura(AURA_LEGEND_BUBBLE,       c);
        c->AddAura(AURA_LEGEND_VERTEX_BLACK, c);
        c->AddAura(AURA_LEGEND_SHADOWS_EDGE, c);
    }
    else
    {
        c->AddAura(AURA_VERTEX_RED,    c);
        c->AddAura(AURA_RED_RADIATION, c);
        c->AddAura(AURA_SHADOW_GLOW,   c);
    }
    c->AddAura(AURA_FIERY,      c);
    c->AddAura(AURA_ENRAGE_VIS, c);
}

static void RemoveAllChampionAuras(Creature* c)
{
    c->RemoveAura(AURA_VERTEX_RED);
    c->RemoveAura(AURA_RED_RADIATION);
    c->RemoveAura(AURA_SHADOW_GLOW);
    c->RemoveAura(AURA_LEGEND_GOLD);
    c->RemoveAura(AURA_LEGEND_RADIANCE);
    c->RemoveAura(AURA_LEGEND_BUBBLE);
    c->RemoveAura(AURA_LEGEND_VERTEX_BLACK);
    c->RemoveAura(AURA_LEGEND_SHADOWS_EDGE);
    c->RemoveAura(AURA_FIERY);
    c->RemoveAura(AURA_ENRAGE_VIS);
}

static void RevertChampion(Creature* c)
{
    ChampionData data;
    {
        std::lock_guard<std::mutex> lk(s_mutex);
        auto it = s_champions.find(c->GetGUID().GetRawValue());
        if (it == s_champions.end())
            return;
        data = it->second;
        s_champions.erase(it);
    }

    // HP — пропорциональное восстановление
    uint32 curHp    = c->GetHealth();
    uint32 curMaxHp = c->GetMaxHealth();
    float  ratio    = curMaxHp > 0 ? float(curHp) / float(curMaxHp) : 1.0f;
    c->SetCreateHealth(data.origMaxHp);
    c->SetMaxHealth(data.origMaxHp);
    c->SetHealth(uint32(float(data.origMaxHp) * ratio));

    // Урон
    c->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, data.origMinDmg);
    c->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, data.origMaxDmg);
    c->UpdateDamagePhysical(BASE_ATTACK);

    // Броня и размер
    c->SetArmor(data.origArmor);
    c->SetObjectScale(data.origScale);

    // CC-иммунитеты
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_STUN,      false);
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_FEAR,      false);
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_SLEEP,     false);
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_POLYMORPH, false);
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_CHARM,     false);
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_HORROR,    false);
    c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_TURN,      false);

    RemoveAllChampionAuras(c);

    c->SetUInt32Value(UNIT_NPC_EMOTESTATE, EMOTE_ONESHOT_NONE);

    LOG_INFO("module", "mod-champion-mobs: {} reverted to normal (solo bot attack)", c->GetName());
}

static void SetAggroSoundTimer(Creature const* c, uint32 ms)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    auto it = s_champions.find(c->GetGUID().GetRawValue());
    if (it != s_champions.end())
        it->second.aggroSoundTimer = ms;
}

// Сбрасывает флаг yell (после evade, чтобы при следующем агро крикнул снова)
static void ResetYell(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    auto it = s_champions.find(c->GetGUID().GetRawValue());
    if (it != s_champions.end())
    {
        it->second.yelled = false;
        it->second.aggroSoundTimer = 0;
    }
}

// Помечает первое агро, возвращает true только при первом вызове
static bool TryMarkYelled(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    auto it = s_champions.find(c->GetGUID().GetRawValue());
    if (it == s_champions.end() || it->second.yelled)
        return false;
    it->second.yelled = true;
    return true;
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

static void AnnounceNearby(Creature const* c, float radius, std::string const& msg)
{
    Map::PlayerList const& plist = c->GetMap()->GetPlayers();
    for (auto it = plist.begin(); it != plist.end(); ++it)
        if (Player* p = it->GetSource(); p && p->GetDistance(c) < radius)
            ChatHandler(p->GetSession()).PSendSysMessage("%s", msg.c_str());
}

static void PlaySoundNearby(Creature* c, float radius, uint32 soundId)
{
    Map::PlayerList const& plist = c->GetMap()->GetPlayers();
    for (auto it = plist.begin(); it != plist.end(); ++it)
        if (Player* p = it->GetSource(); p && p->GetDistance(c) < radius)
            c->PlayDirectSound(soundId, p);
}

static void PushBonusItem(Loot& loot, uint32 itemId)
{
    if (!sObjectMgr->GetItemTemplate(itemId))
        return;
    LootItem item;
    item.itemid            = itemId;
    item.count             = 1;
    item.is_looted         = false;
    item.is_blocked        = false;
    item.freeforall        = false;
    item.is_underthreshold = false;
    item.is_counted        = false;
    item.needs_quest       = false;
    item.follow_loot_rules = false;
    item.itemIndex         = uint32(loot.items.size());
    loot.items.push_back(item);
    ++loot.unlootedCount;
}

// ══════════════════════════════════════════════════════════════════════════════
// ELIGIBILITY
// ══════════════════════════════════════════════════════════════════════════════

static bool IsEligible(Creature const* c)
{
    if (!c || !c->IsAlive())
        return false;
    if (c->IsPet() || c->IsSummon() || c->IsTotem())
        return false;
    if (c->HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NON_ATTACKABLE))
        return false;

    CreatureTemplate const* tmpl = c->GetCreatureTemplate();
    if (!tmpl)
        return false;

    if (FactionTemplateEntry const* ft = sFactionTemplateStore.LookupEntry(c->GetFaction()))
    {
        constexpr uint32 PLAYER_GROUPS = FACTION_MASK_PLAYER | FACTION_MASK_ALLIANCE | FACTION_MASK_HORDE;
        if (ft->friendlyMask & PLAYER_GROUPS)
            return false;
    }

    switch (tmpl->type)
    {
        case CREATURE_TYPE_BEAST:
        case CREATURE_TYPE_DRAGONKIN:
        case CREATURE_TYPE_DEMON:
        case CREATURE_TYPE_ELEMENTAL:
        case CREATURE_TYPE_GIANT:
        case CREATURE_TYPE_UNDEAD:
        case CREATURE_TYPE_HUMANOID:
        case CREATURE_TYPE_MECHANICAL:
            break;
        default:
            return false;
    }

    return c->GetLevel() >= 2;
}

// ══════════════════════════════════════════════════════════════════════════════
// LEGENDARY ABILITIES
// ══════════════════════════════════════════════════════════════════════════════

// Структура возвращаемых флагов — какие способности готовы в этом тике
struct LegendaryAbilityResult
{
    bool doBlink  = false;
    bool doSummon = false;
    bool doStomp  = false;
};

// Обновляет таймеры способностей под мьютексом, возвращает что нужно выполнить.
// Выполнение самих способностей — снаружи мьютекса.
static LegendaryAbilityResult TickLegendaryAbilities(Creature const* c, uint32 diff)
{
    LegendaryAbilityResult result;
    std::lock_guard<std::mutex> lk(s_mutex);

    auto it = s_champions.find(c->GetGUID().GetRawValue());
    if (it == s_champions.end() || !it->second.legendary)
        return result;

    auto& d = it->second;

    // Обновляет один таймер: если истёк — сбрасывает на кулдаун и выставляет флаг
    auto tick = [diff](uint32& timer, uint32 cooldown, bool& out)
    {
        if (timer <= diff) { timer = cooldown; out = true; }
        else               { timer -= diff; }
    };

    tick(d.blinkTimer,  LEGEND_BLINK_CD,  result.doBlink);
    tick(d.summonTimer, LEGEND_SUMMON_CD, result.doSummon);
    tick(d.stompTimer,  LEGEND_STOMP_CD,  result.doStomp);

    return result;
}

// ── Прыжок за спину ──────────────────────────────────────────────────────────
// Телепортирует легендарного за спину его текущей цели.
static void DoBlinkBehindTarget(Creature* c)
{
    Unit* victim = c->GetVictim();
    if (!victim)
        return;

    // Позиция за спиной цели (напротив направления взгляда)
    float ori  = victim->GetOrientation();
    float dist = 2.0f;
    float bx   = victim->GetPositionX() - dist * std::cos(ori);
    float by   = victim->GetPositionY() - dist * std::sin(ori);
    float bz   = victim->GetPositionZ();

    // После телепорта смотрим на цель (тот же угол ori)
    c->NearTeleportTo(bx, by, bz, ori);
}

// ── Топот (Earthquake) ───────────────────────────────────────────────────────
// Кастует Earthquake (33919): 3с стан, 35 ярдов вокруг чемпиона.
static void DoStomp(Creature* c)
{
    c->CastSpell(c, LEGEND_STOMP_SPELL, false);
}

// ── Призыв стаи ──────────────────────────────────────────────────────────────
// Призывает 3 обычных моба того же entry вокруг легендарного.
// IsSummon() == true для TempSummon → IsEligible() вернёт false → они не станут чемпионами.
static void DoSummonMinions(Creature* c)
{
    static constexpr int   COUNT    = 3;
    static constexpr float DIST     = 5.0f;
    static constexpr uint32 LIFETIME = 60'000; // 60с

    for (int i = 0; i < COUNT; ++i)
    {
        float angle = float(i) / COUNT * 2.0f * float(M_PI);
        float x = c->GetPositionX() + DIST * std::cos(angle);
        float y = c->GetPositionY() + DIST * std::sin(angle);
        c->SummonCreature(c->GetEntry(), x, y, c->GetPositionZ(),
                          c->GetOrientation(), TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, LIFETIME);
    }

    AnnounceNearby(c, 80.0f,
        "|cffFF8000[Legendary Champion]|r " + c->GetName() + " calls for reinforcements!");
}

// ══════════════════════════════════════════════════════════════════════════════
// LOOT
// ══════════════════════════════════════════════════════════════════════════════

static void BuildChampionLoot(Creature* champion, bool isLegendary)
{
    uint8  level     = champion->GetLevel();
    Loot&  loot      = champion->loot;
    ChampionTier tier = GetChampionTier(champion);

    // Бонусное золото
    uint32 goldMult;
    switch (tier)
    {
        case CHAMPION_TIER_DUNGEON_BOSS: goldMult = isLegendary ?  50u : 10u; break;
        case CHAMPION_TIER_RAID_BOSS:    goldMult = isLegendary ? 125u : 62u; break;
        default:                         goldMult = isLegendary ?   5u :  1u; break;
    }
    loot.gold += uint32(level) * urand(250u, 1000u) * goldMult;

    // Зелёные/синие — для всех чемпионов
    std::vector<uint32> pool = GetItemsForLevel(level);
    if (!pool.empty())
    {
        uint32 n = urand(2u, 4u);
        for (uint32 i = 0; i < n; ++i)
            PushBonusItem(loot, pool[urand(0u, uint32(pool.size()) - 1u)]);
    }

    // Фиолетовые — по тиру; легендарные получают вдвое больше (+базу для обычного тира)
    uint32 numEpics = 0;
    if (isLegendary)
    {
        switch (tier)
        {
            case CHAMPION_TIER_RAID_BOSS:    numEpics = urand(30u, 40u); break;
            case CHAMPION_TIER_DUNGEON_BOSS: numEpics = urand(12u, 18u); break;
            case CHAMPION_TIER_ELITE:        numEpics = urand(6u,  10u); break;
            default:                         numEpics = urand(4u,   6u); break;
        }
    }
    else
    {
        switch (tier)
        {
            case CHAMPION_TIER_RAID_BOSS:    numEpics = urand(25u, 30u); break;
            case CHAMPION_TIER_DUNGEON_BOSS: numEpics = urand(6u,   8u); break;
            case CHAMPION_TIER_ELITE:        numEpics = urand(1u,   2u); break;
            default: break;
        }
    }

    if (numEpics > 0)
    {
        std::vector<uint32> epicPool = GetEpicItemsForLevel(level);
        if (!epicPool.empty())
            for (uint32 i = 0; i < numEpics; ++i)
                PushBonusItem(loot, epicPool[urand(0u, uint32(epicPool.size()) - 1u)]);
    }

    // Легендарные предметы (Quality=5) — только для легендарных чемпионов.
    // Шанс и количество по тиру:
    //   Обычный:           10% → 1
    //   Элитный:           50% → 1
    //   Босс данжа/рейда: 100% → 2–3
    if (isLegendary)
    {
        uint32 legChance = 10;
        uint32 legCount  = 1;
        switch (tier)
        {
            case CHAMPION_TIER_RAID_BOSS:
            case CHAMPION_TIER_DUNGEON_BOSS:
                legChance = 100;
                legCount  = urand(2u, 3u);
                break;
            case CHAMPION_TIER_ELITE:
                legChance = 50;
                break;
            default:
                break;
        }

        if (roll_chance_i(legChance))
        {
            std::vector<uint32> legPool = GetLegendaryItemsForLevel(level);
            if (!legPool.empty())
                for (uint32 i = 0; i < legCount; ++i)
                    PushBonusItem(loot, legPool[urand(0u, uint32(legPool.size()) - 1u)]);
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCRIPTS
// ══════════════════════════════════════════════════════════════════════════════

// ── WorldScript — загрузка пулов при старте ───────────────────────────────────

class ChampionWorld : public WorldScript
{
public:
    ChampionWorld() : WorldScript("champion_world") {}

    void OnStartup() override { LoadItemPools(); }
};

// ── AllCreatureScript — спавн / деспавн / обновление ─────────────────────────

class ChampionAllCreature : public AllCreatureScript
{
public:
    ChampionAllCreature() : AllCreatureScript("champion_all_creature") {}

    // -----------------------------------------------------------------
    void OnCreatureAddWorld(Creature* c) override
    {
        if (!IsEligible(c) || IsChampion(c) || !roll_chance_f(CHAMPION_CHANCE))
            return;

        ChampionTier tier = GetChampionTier(c);

        // ── HP ────────────────────────────────────────────────────────
        uint32 baseHp = c->GetMaxHealth();
        uint32 newHp  = uint32(float(baseHp) * CHAMPION_HP_MULT);
        c->SetCreateHealth(newHp);
        c->SetMaxHealth(newHp);
        c->SetHealth(newHp);

        // ── Damage ────────────────────────────────────────────────────
        // GetWeaponDamageRange читает m_weaponDamage[] — сырое значение
        // до вклада attack power. UNIT_FIELD_MINDAMAGE уже включает AP,
        // что приводило к двойному учёту AP в UpdateDamagePhysical.
        float origMinDmg = c->GetWeaponDamageRange(BASE_ATTACK, MINDAMAGE);
        float origMaxDmg = c->GetWeaponDamageRange(BASE_ATTACK, MAXDAMAGE);
        float dmgMult;
        switch (tier)
        {
            case CHAMPION_TIER_ELITE:        dmgMult = CHAMPION_DMG_MULT_ELITE;   break;
            case CHAMPION_TIER_DUNGEON_BOSS: dmgMult = CHAMPION_DMG_MULT_DUNGEON; break;
            case CHAMPION_TIER_RAID_BOSS:    dmgMult = CHAMPION_DMG_MULT_RAID;    break;
            default:                         dmgMult = CHAMPION_DMG_MULT;         break;
        }
        c->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, origMinDmg * dmgMult);
        c->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, origMaxDmg * dmgMult);
        c->UpdateDamagePhysical(BASE_ATTACK);

        // ── Armor ─────────────────────────────────────────────────────
        int32 origArmor = c->GetArmor();
        c->SetArmor(int32(float(origArmor) * CHAMPION_ARMOR_MULT));

        // ── CC immunity ───────────────────────────────────────────────
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_STUN,      true);
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_FEAR,      true);
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_SLEEP,     true);
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_POLYMORPH, true);
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_CHARM,     true);
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_HORROR,    true);
        c->ApplySpellImmune(0, IMMUNITY_MECHANIC, MECHANIC_TURN,      true);

        // ── Visual ────────────────────────────────────────────────────
        float origScale = c->GetObjectScale();
        c->SetObjectScale(origScale * CHAMPION_SCALE);
        ApplyChampionAuras(c, /*legendary=*/false);
        c->SetUInt32Value(UNIT_NPC_EMOTESTATE, EMOTE_STATE_READY1H);

        MarkChampion(c, newHp, baseHp, origMinDmg, origMaxDmg, origArmor, origScale);

        // ── Легендарный апгрейд (5% от чемпионов) ────────────────────
        if (roll_chance_f(LEGEND_CHANCE))
        {
            // HP ×30 от базового (переопределяем champion HP ×20)
            uint32 legHp = uint32(float(baseHp) * LEGEND_HP_MULT);
            c->SetCreateHealth(legHp);
            c->SetMaxHealth(legHp);
            c->SetHealth(legHp);

            // Урон ×7 от базового (переопределяем tier-зависимый множитель чемпиона)
            c->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, origMinDmg * LEGEND_DMG_MULT);
            c->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, origMaxDmg * LEGEND_DMG_MULT);
            c->UpdateDamagePhysical(BASE_ATTACK);

            // Размер — переопределяем на LEGEND_SCALE от оригинала
            c->SetObjectScale(origScale * LEGEND_SCALE);

            // Заменяем ауры обычного чемпиона на легендарные
            RemoveAllChampionAuras(c);
            ApplyChampionAuras(c, /*legendary=*/true);

            SetLegendary(c, legHp);

            std::string msg =
                "|cffFF8000[!! LEGENDARY CHAMPION !!]|r |cffFFD700" + c->GetName() +
                "|r (lvl " + std::to_string(c->GetLevel()) + ") has appeared! "
                "A true legend walks the land \xe2\x80\x94 great glory awaits the brave!";
            AnnounceNearby(c, 150.0f, msg);

            LOG_INFO("module", "mod-champion-mobs: {} LEGENDARY (entry={} guid={:#x} lvl={})",
                c->GetName(), c->GetEntry(), c->GetGUID().GetRawValue(), c->GetLevel());
        }
        else
        {
            std::string msg =
                "|cffFFD700[Champion]|r |cffFF8C00" + c->GetName() +
                "|r (lvl " + std::to_string(c->GetLevel()) + ") has appeared nearby. "
                "Far more dangerous than usual \xe2\x80\x94 but the reward is worth it.";
            AnnounceNearby(c, 80.0f, msg);
            c->PlayDirectSound(SOUND_CHAMPION_ROAR);

            LOG_INFO("module", "mod-champion-mobs: {} champion (entry={} guid={:#x} lvl={})",
                c->GetName(), c->GetEntry(), c->GetGUID().GetRawValue(), c->GetLevel());
        }
    }

    // -----------------------------------------------------------------
    void OnCreatureRemoveWorld(Creature* c) override
    {
        if (IsChampion(c))
            LOG_WARN("module",
                "mod-champion-mobs: [REMOVE] {} (entry={} guid={:#x}) removed while ALIVE",
                c->GetName(), c->GetEntry(), c->GetGUID().GetRawValue());
        UnmarkChampion(c);
    }

    // -----------------------------------------------------------------
    // Watchdog — срабатывает каждый тик для всех существ.
    // Для не-чемпионов: один lookup в map и выход.
    void OnAllCreatureUpdate(Creature* c, uint32 diff) override
    {
        if (!c->IsAlive())
            return;

        ChampionState state = GetChampionState(c);
        if (!state.targetMaxHp)
            return; // не чемпион

        // ── HP watchdog: AutoBalance может перезаписать HP при смене
        //    числа игроков в данже. Восстанавливаем если нужно.
        uint32 curMaxHp = c->GetMaxHealth();
        if (curMaxHp < state.targetMaxHp)
        {
            uint32 curHp  = c->GetHealth();
            float  ratio  = curMaxHp > 0 ? float(curHp) / float(curMaxHp) : 1.0f;
            c->SetCreateHealth(state.targetMaxHp);
            c->SetMaxHealth(state.targetMaxHp);
            c->SetHealth(uint32(float(state.targetMaxHp) * ratio));
        }

        // ── Aura watchdog: evade вызывает RemoveAllAuras().
        //    Восстанавливаем только вне боя (в бою ауры свежие от спауна/агро).
        if (!c->IsInCombat() && !c->HasAura(AURA_FIERY))
        {
            ApplyChampionAuras(c, state.legendary);
            c->SetUInt32Value(UNIT_NPC_EMOTESTATE, EMOTE_STATE_READY1H);
            ResetYell(c);
        }

        // ── Отложенный стингер при агро легендарного ─────────────────
        if (state.legendary)
        {
            bool playStinger = false;
            {
                std::lock_guard<std::mutex> lk(s_mutex);
                auto it = s_champions.find(c->GetGUID().GetRawValue());
                if (it != s_champions.end() && it->second.aggroSoundTimer > 0)
                {
                    if (it->second.aggroSoundTimer <= diff)
                    {
                        it->second.aggroSoundTimer = 0;
                        playStinger = true;
                    }
                    else
                        it->second.aggroSoundTimer -= diff;
                }
            }
            if (playStinger)
                PlaySoundNearby(c, 100.0f, 17458);
        }

        // ── Legendary abilities (только в бою и при наличии цели) ─────
        if (state.legendary && c->IsInCombat() && c->GetVictim())
        {
            LegendaryAbilityResult ab = TickLegendaryAbilities(c, diff);
            if (ab.doBlink)  DoBlinkBehindTarget(c);
            if (ab.doSummon) DoSummonMinions(c);
            if (ab.doStomp)  DoStomp(c);
        }
    }
};

// ── PlayerScript — уведомление при агро ──────────────────────────────────────

class ChampionPlayer : public PlayerScript
{
public:
    ChampionPlayer() : PlayerScript("champion_player") {}

    void OnPlayerEnterCombat(Player* player, Unit* enemy) override
    {
        Creature* c = enemy->ToCreature();
        if (!c || !IsChampion(c))
            return;

        // Соло-бот без живых игроков в группе → откатить чемпиона
        if (sRandomPlayerbotMgr.IsRandomBot(player->GetGUID().GetCounter()) && !player->GetGroup())
        {
            RevertChampion(c);
            return;
        }

        bool isLegendary = IsLegendaryChampion(c);
        ChampionTier tier = GetChampionTier(c);

        // ── Yell + sound (только при первом агро) ────────────────────
        if (TryMarkYelled(c))
        {
            static const char* yells[] = {
                "Don't you dare challenge me, punk!",
                "You have sealed your fate, adventurer!",
                "I have crushed stronger heroes than you!",
                "Your bones will decorate this place!",
                "Champions are not born \xe2\x80\x94 they are forged in your defeat!",
            };
            c->Yell(yells[urand(0u, 4u)], LANG_UNIVERSAL, player);

            if (isLegendary)
            {
                bool isBoss = (tier == CHAMPION_TIER_DUNGEON_BOSS || tier == CHAMPION_TIER_RAID_BOSS);
                PlaySoundNearby(c, 100.0f, SOUND_LICH_KING_SPECIAL);
                if (isBoss)
                    PlaySoundNearby(c, 100.0f, SOUND_CHAMPION_MUSIC);
                else
                    SetAggroSoundTimer(c, 5000);
            }
            else
            {
                switch (tier)
                {
                    case CHAMPION_TIER_RAID_BOSS:
                    case CHAMPION_TIER_DUNGEON_BOSS:
                        PlaySoundNearby(c, 100.0f, SOUND_CHAMPION_MUSIC);         break;
                    case CHAMPION_TIER_ELITE:
                        PlaySoundNearby(c, 100.0f, SOUND_YOU_ARE_NOT_PREPARED);   break;
                    default:
                        PlaySoundNearby(c, 100.0f, SOUND_CHAMPION_ROAR);          break;
                }
            }
        }

        // ── HUD-сообщение для игрока ──────────────────────────────────
        const char* dmgStr;
        if (isLegendary)
        {
            dmgStr = "7";
        }
        else
        {
            switch (tier)
            {
                case CHAMPION_TIER_ELITE:        dmgStr = "4.5"; break;
                case CHAMPION_TIER_DUNGEON_BOSS: dmgStr = "4.0"; break;
                case CHAMPION_TIER_RAID_BOSS:    dmgStr = "3.5"; break;
                default:                         dmgStr = "5";   break;
            }
        }

        std::string rewardLine = "|cffFFD700Reward:|r bonus XP + gold + green/blue gear";
        switch (tier)
        {
            case CHAMPION_TIER_ELITE:
                rewardLine += " |cffA335EE+ 1\xe2\x80\x932 epic|r";               break;
            case CHAMPION_TIER_DUNGEON_BOSS:
                rewardLine += " |cffA335EE+ 6\xe2\x80\x938 epic (BOSS!)|r";       break;
            case CHAMPION_TIER_RAID_BOSS:
                rewardLine += " |cffA335EE+ 25\xe2\x80\x9330 epic (RAID BOSS!)|r"; break;
            default: break;
        }
        if (isLegendary)
            rewardLine += " |cffFF8000+ LEGENDARY LOOT|r";

        std::string dangerLine =
            std::string("|cffFF4444Danger:|r HP x") + (isLegendary ? "30" : "20") +
            "  /  Damage x" + dmgStr +
            "  /  Armor x3  |cffAAAAAA(CC immune)|r";
        if (isLegendary)
            dangerLine += "  |cffFF8000[Blink / Summon / Stomp]|r";

        std::string header = isLegendary
            ? "|cffFF8000[!! LEGENDARY CHAMPION !!]|r |cffFFD700"
            : "|cffFFD700[!! CHAMPION !!]|r |cffFF8C00";

        std::string hud = header + c->GetName() +
            "|r (lvl " + std::to_string(c->GetLevel()) + ")\n" +
            dangerLine + "\n" + rewardLine;

        ChatHandler(player->GetSession()).SendSysMessage(hud.c_str());
    }
};

// ── UnitScript — смерть и выдача лута ────────────────────────────────────────

class ChampionUnit : public UnitScript
{
public:
    ChampionUnit() : UnitScript("champion_unit") {}

    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        Creature* c = unit->ToCreature();
        if (!c || !IsChampion(c))
            return;

        Player* responsible = killer
            ? killer->GetCharmerOrOwnerPlayerOrPlayerItself()
            : nullptr;

        // Проверяем легендарность ДО UnmarkChampion — после записи уже нет
        bool isLegendary = IsLegendaryChampion(c);
        UnmarkChampion(c);
        BuildChampionLoot(c, isLegendary);

        LOG_WARN("module",
            "mod-champion-mobs: [SLAIN] {}{} (guid={:#x} lvl={}) — killer type={} responsible={}",
            isLegendary ? "LEGENDARY " : "",
            c->GetName(), c->GetGUID().GetRawValue(), c->GetLevel(),
            killer ? killer->GetTypeId() : 0,
            responsible ? responsible->GetName() : "none");

        if (!responsible)
            return;

        // Бонусный XP + сообщение о победе — игроку и его группе
        // Легендарные чемпионы дают в 2 раза больше опыта
        ChampionTier xpTier = GetChampionTier(c);
        uint32 xpMult;
        switch (xpTier)
        {
            case CHAMPION_TIER_DUNGEON_BOSS: xpMult = isLegendary ?  50u : 10u; break;
            case CHAMPION_TIER_RAID_BOSS:    xpMult = isLegendary ? 125u : 62u; break;
            default:                         xpMult = isLegendary ?   5u :  1u; break;
        }
        uint32 xpBonus = uint32(c->GetLevel()) * CHAMPION_XP_PER_LVL * xpMult;

        std::string victoryMsg =
            "|cffFFD700[Champion Slain!]|r " + c->GetName() +
            " defeated! Loot the corpse \xe2\x80\x94 bonus items and gold await.";

        auto Reward = [&](Player* p)
        {
            if (!p || !p->IsAlive()
                   || p->GetMap()       != c->GetMap()
                   || p->GetDistance(c) >= 100.0f)
                return;
            p->GiveXP(xpBonus, nullptr);
            ChatHandler(p->GetSession()).PSendSysMessage("%s", victoryMsg.c_str());
        };

        Reward(responsible);
        if (Group* grp = responsible->GetGroup())
            for (GroupReference* ref = grp->GetFirstMember(); ref; ref = ref->next())
                if (ref->GetSource() != responsible)
                    Reward(ref->GetSource());
    }
};

// ══════════════════════════════════════════════════════════════════════════════
// REGISTRATION
// ══════════════════════════════════════════════════════════════════════════════

void Addmod_champion_mobsScripts()
{
    new ChampionWorld();
    new ChampionAllCreature();
    new ChampionPlayer();
    new ChampionUnit();
}
