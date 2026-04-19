/*
 * mod-random-taunts
 *
 * Гуманоидные мобы с шансом говорят смешные/угрожающие фразы в разных ситуациях:
 *
 *   OnAggro   (20%) — моб замечает игрока и вступает в бой
 *   OnDeath   (20%) — моб умирает
 *   OnKill    (25%) — моб убил игрока
 *   OnLowHP   (30%, once) — моб упал ниже 25% HP (паника)
 *
 * Только CREATURE_TYPE_HUMANOID, без боссов, без петов/саммонов.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "Player.h"
#include "Chat.h"
#include "Random.h"
#include "SharedDefines.h"

#include <unordered_set>
#include <mutex>
#include <string>

// ── Шанс срабатывания (%) ─────────────────────────────────────────────────────
static constexpr float CHANCE_AGGRO  = 1.0f;
static constexpr float CHANCE_DEATH  = 1.0f;
static constexpr float CHANCE_KILL   = 1.0f;
static constexpr float CHANCE_LOWHP  = 1.0f;
static constexpr float LOWHP_THRESHOLD = 25.0f; // % от макс. HP

// ── Трекинг "уже паниковал" (low HP срабатывает один раз на жизнь) ─────────
static std::unordered_set<uint64> s_panicked;
static std::mutex                 s_mutex;

static bool TryMarkPanicked(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    return s_panicked.insert(c->GetGUID().GetRawValue()).second;
}

static void ClearPanicked(Creature const* c)
{
    std::lock_guard<std::mutex> lk(s_mutex);
    s_panicked.erase(c->GetGUID().GetRawValue());
}

// ── Фильтр: только живые гуманоиды, не боссы, не слуги ───────────────────────
static bool IsEligible(Creature const* c)
{
    if (!c || !c->IsAlive())
        return false;
    if (c->IsPet() || c->IsSummon() || c->IsTotem())
        return false;
    CreatureTemplate const* tmpl = c->GetCreatureTemplate();
    if (!tmpl || tmpl->rank == CREATURE_ELITE_WORLDBOSS)
        return false;
    if (tmpl->type != CREATURE_TYPE_HUMANOID)
        return false;
    return c->GetLevel() >= 2;
}

// ── Фразы ──────────────────────────────────────────────────────────────────────

// %s = имя игрока
static const char* AGGRO_LINES[] = {
    "I'll kick your ass, %s!",
    "Show me your pp, %s!",
    "HEHE, YOU ARE DEAD!",
    "Omae wa mou shindeiru!",
    "Oni chan~!",
    "Go fuck yourself, %s!",
    "FOR THE POO!",
    "I want to shit but I'll fight your ass first!",
    "Gay!",
    "I'm ready to give you a gay-lesson!",
    "Prepare to get DUNKED on, %s!",
    "%s... your face looks like my ass.",
    "YOLO! LET'S GOOOOO!",
    "I'm not locked in here with YOU, %s — YOU'RE locked in here with ME!",
    "I just had Taco Bell. You don't stand a chance.",
    "LEEEEEEROYYY JENKINS!!!",
    "%s! I am your father!",
    "It's not personal, %s... actually it IS personal.",
    "Time to show you why I'm the main character!",
    "Do you feel lucky, %s? Well, do ya, punk?",
    "I've killed better people before breakfast.",
    "You shouldn't have come here, %s.",
    "Hold on, let me put on my fighting pants... okay, I'm ready.",
    "I skipped breakfast for THIS?",
    "This is awkward... I forgot to stretch.",
    "By the power of Greyskull — I shall destroy you!",
    "My mama told me not to pick on weaklings. She said nothing about YOU.",
    "Brace yourself, %s. The pain is coming.",
    "Oh great, another one. Fine, let's do this.",
    "I was having such a nice day, %s...",
    "You have chosen... poorly.",
    "I've been waiting for you, %s. Not really, but it sounded cool.",
    "Say your prayers, little one.",
    "I hope you brought a healer, %s!",
    "Last chance to run, %s. No? Okay, your funeral.",
    "My axe is literally ITCHING right now.",
    "Oh ho ho ho, you're in for it now!",
    "I've got a bad feeling about you, %s. Bad for YOU.",
    "Don't worry, I'll make it quick. JUST KIDDING.",
    "Oh look, fresh meat!",
    "Nice knowing you, %s.",
    "I was JUST about to take a nap. Thanks a lot, %s.",
    "You picked the wrong mob, pal.",
    "Oh, so YOU'RE the adventurer everyone's been talking about. Disappointing.",
    "Come on then, %s. Let's see what you've got.",
    "My grandmother fights better than you, %s. And she's dead.",
    "I didn't choose this fight... actually I did.",
    "You look tired, %s. Let me put you out of your misery.",
    "Bold move, %s. Incredibly stupid, but bold.",
    "I am ERROR.",
    "You have made a grave error, %s.",
    "Thanks for volunteering to die today, %s!",
    "Ah, a challenger! How refreshingly naive.",
    "Every time I see your kind, I think: easy gold.",
    "Did someone order a beatdown? Because I'm delivering.",
    "You couldn't beat me on your best day, %s.",
    "Huh. I was wondering when someone would be dumb enough to try.",
    "I've been doing this for thirty years, %s. You've been doing it for... how long?",
    "Scream all you want. Nobody's coming.",
    "Don't worry, %s — I'll make your corpse look pretty.",
    "You want some? Come get some.",
    "Alright, let's make this quick. I have things to do.",
    "Oh, how ADORABLE. You think you can beat me.",
    "I eat heroes like you for breakfast. With ketchup.",
    "Fun fact: I have never lost a fight. Today is not the day that changes, %s.",
    "I'm not angry. I'm just disappointed. Actually, I AM angry.",
    "Step into my office, %s... by which I mean the dirt.",
};
static constexpr size_t AGGRO_COUNT = sizeof(AGGRO_LINES) / sizeof(AGGRO_LINES[0]);

static const char* DEATH_LINES[] = {
    "oh shit... I'm dead",
    "I... suck...",
    "Fuck you, man...",
    "I'm not... gay...",
    "Mommy...",
    "I was... supposed to be... the chosen one...",
    "Tell my wife... I love her...",
    "Tell my wife... I hate her...",
    "It was a good fight... just kidding, you cheated.",
    "Unexpected...",
    "This is fine.",
    "I... regret... nothing!",
    "At least I died... doing what I loved... being killed.",
    "My only weakness... being attacked.",
    "GG no re...",
    "Pfft... lucky shot...",
    "I demand... a rematch...",
    "You haven't heard the last of me!",
    "That's... it? That's how I go?",
    "Tell the boss... I tried...",
    "Oof...",
    "Bruh...",
    "L + ratio...",
    "Mom pick me up... I'm scared...",
    "Who gave you permission... to win...",
    "I was... low on health... anyway...",
    "Not like this...",
    "I could've been... somebody...",
    "Well... poop.",
    "I should've stayed in bed today...",
    "Was it... worth it for you?",
    "At least... I'm not gay...",
    "I am... become death... oh wait, that's... me...",
    "You win... THIS time...",
    "Curse you... and your entire bloodline...",
    "I... want a rematch... tomorrow... or never...",
    "This is... not how I imagined things going...",
    "I'll be honest... I panicked...",
    "Worth it? ...No. Not really.",
    "Did I at least... look cool?",
    "I should've... called in sick today...",
    "You got lucky... next time... I'll actually try...",
    "My only regret... is everything...",
    "Ah... so this is what dying feels like. 0/10.",
    "Cold... so cold... also warm... I don't know...",
    "I leave behind... nothing. Nothing at all.",
    "Please... tell no one... how this ended...",
    "I was saving that ability... for the second phase...",
    "Heh... at least I died... being me...",
    "I always thought... I'd die in battle... oh wait...",
    "...worth every copper.",
    "Remember me... as better than I was...",
    "This is awkward...",
    "Welp.",
    "Oops.",
};
static constexpr size_t DEATH_COUNT = sizeof(DEATH_LINES) / sizeof(DEATH_LINES[0]);

// %s = имя игрока
static const char* KILL_LINES[] = {
    "HAHAHA! Get rekt, %s!",
    "Too easy. Come back when you're a man, %s.",
    "Git gud, %s!",
    "Anyone else? No? Didn't think so.",
    "And THAT is why you don't mess with me.",
    "Is that all you've got? Really, %s?",
    "Skill issue.",
    "Imagine dying to ME.",
    "Go cry about it, %s.",
    "That's what you get for existing near me.",
    "Next time bring friends. Lots of friends.",
    "Well that was disappointing, %s.",
    "Don't forget to uninstall, %s.",
    "EZ EZ EZ!",
    "Noob detected.",
    "Thanks for the workout, %s!",
    "You fell off!",
    "L + bozo, %s.",
    "Stay down, %s.",
    "Told you so.",
    "I barely even tried.",
    "Was that your best, %s? Tragic.",
    "Another one bites the dust!",
    "I should charge admission for this show.",
    "Pathetic. Absolutely pathetic.",
    "Should've logged out, %s.",
    "Don't take it personally... actually do.",
    "Gg wp. Mostly gg, not so much wp.",
    "Better luck never, %s.",
    "Delete your account, %s.",
    "Respawn and try again, %s. I'll be here.",
    "Was that your final form? Tragic.",
    "I have killed smarter things than you, %s.",
    "One down. Who's next?",
    "You put up a fight. A bad fight, but a fight.",
    "See you in your nightmares, %s.",
    "That's going in the highlight reel.",
    "Too slow, %s. Way too slow.",
    "Sent to the graveyard. Again.",
    "Don't feel bad, %s. Almost everyone loses to me.",
    "You were 60% of a challenge. Congrats.",
    "You know, %s, maybe adventuring isn't for you.",
    "I've seen better strategies from a slime.",
    "Speed run? More like speed DYING.",
    "I didn't even use my good hand.",
    "Nice try though. Seriously. Nice try.",
    "The ground suits you, %s.",
    "Sleep well, %s.",
    "Next time, bring reinforcements. A lot of them.",
    "And that is why I am still standing.",
    "Not even a warm up.",
};
static constexpr size_t KILL_COUNT = sizeof(KILL_LINES) / sizeof(KILL_LINES[0]);

static const char* LOWHP_LINES[] = {
    "PLEASE STOP HITTING ME!",
    "Okay okay, I yield! ...just kidding, I'm coming for you!",
    "Is this... is this how it ends?!",
    "I'M TOO YOUNG TO DIE!",
    "SOMEONE HELP ME!!!",
    "Ow ow ow OW!",
    "You fight dirty! I respect that!",
    "Wait wait wait — time out! TIME OUT!",
    "I may be dying but I'm still fabulous!",
    "This is NOT going according to plan!",
    "I HAVE A FAMILY!",
    "Do you KNOW who I am?! ...doesn't matter, just stop!",
    "Medic! MEDIC!!",
    "Okay I'm scared now.",
    "This was a HUGE mistake on my part.",
    "Okay I'm starting to regret this decision.",
    "Not the face! NOT THE FACE!",
    "My whole life is flashing before my eyes... it's mostly bad decisions.",
    "ABORT ABORT ABORT.",
    "I take it back! All of it!",
    "Is this... karma? Probably karma.",
    "I'm not dead yet! ...I might be soon though.",
    "SOMEBODY DO SOMETHING.",
    "This is fine. Everything is fine. Nothing is fine.",
    "I regret talking smack earlier.",
    "Can we just... start over? Please?",
    "You fight like you have a personal vendetta!",
    "WHY WON'T YOU STOP.",
    "I used to be invincible! What happened?!",
    "My life choices have led me to this moment.",
    "Less dying, more surviving — that's my new plan.",
};
static constexpr size_t LOWHP_COUNT = sizeof(LOWHP_LINES) / sizeof(LOWHP_LINES[0]);

// ── Хелпер: сказать с подстановкой имени (если %s есть) ──────────────────────
static void SayLine(Creature* c, const char* fmt, const char* playerName = nullptr)
{
    char buf[256];
    if (playerName && strstr(fmt, "%s"))
        snprintf(buf, sizeof(buf), fmt, playerName);
    else
    {
        // Безопасно копируем без форматирования
        snprintf(buf, sizeof(buf), "%s", fmt);
    }
    c->Say(buf, LANG_UNIVERSAL, nullptr);
}

static void YellLine(Creature* c, const char* fmt, const char* playerName = nullptr)
{
    char buf[256];
    if (playerName && strstr(fmt, "%s"))
        snprintf(buf, sizeof(buf), fmt, playerName);
    else
        snprintf(buf, sizeof(buf), "%s", fmt);
    c->Yell(buf, LANG_UNIVERSAL, nullptr);
}

// ── PlayerScript ──────────────────────────────────────────────────────────────

class RandomTauntsPlayer : public PlayerScript
{
public:
    RandomTauntsPlayer() : PlayerScript("random_taunts_player") {}

    // Агро: моб встретил игрока
    void OnPlayerEnterCombat(Player* player, Unit* enemy) override
    {
        Creature* c = enemy->ToCreature();
        if (!c || !IsEligible(c) || !roll_chance_f(CHANCE_AGGRO))
            return;

        YellLine(c,
            AGGRO_LINES[urand(0, static_cast<uint32>(AGGRO_COUNT - 1))],
            player->GetName().c_str());
    }

    // Смерть: моб убит игроком
    void OnPlayerCreatureKill(Player* /*killer*/, Creature* killed) override
    {
        if (!IsEligible(killed) || !roll_chance_f(CHANCE_DEATH))
            return;

        ClearPanicked(killed);
        SayLine(killed, DEATH_LINES[urand(0, static_cast<uint32>(DEATH_COUNT - 1))]);
    }

    // Победа: моб убил игрока
    void OnPlayerKilledByCreature(Creature* killer, Player* killed) override
    {
        if (!IsEligible(killer) || !roll_chance_f(CHANCE_KILL))
            return;

        YellLine(killer,
            KILL_LINES[urand(0, static_cast<uint32>(KILL_COUNT - 1))],
            killed->GetName().c_str());
    }
};

// ── AllCreatureScript — спавн/деспавн + low HP через поллинг ─────────────────
// UnitScript::OnUnitDamaged не поддерживается в этом форке AC.
// Вместо этого проверяем HP каждый тик в OnAllCreatureUpdate:
// — только гуманоиды в бою, с HP < 25%, ещё не паниковавшие в этой жизни.

class RandomTauntsCreature : public AllCreatureScript
{
public:
    RandomTauntsCreature() : AllCreatureScript("random_taunts_creature") {}

    void OnCreatureAddWorld(Creature* c) override
    {
        ClearPanicked(c);
    }

    void OnCreatureRemoveWorld(Creature* c) override
    {
        ClearPanicked(c);
    }

    void OnAllCreatureUpdate(Creature* c, uint32 /*diff*/) override
    {
        // Быстрый отсев: только живые в бою
        if (!c->IsAlive() || !c->IsInCombat())
            return;

        if (!IsEligible(c))
            return;

        if (c->GetHealthPct() > LOWHP_THRESHOLD)
            return;

        // Помечаем первыми — кость бросается ровно один раз за жизнь моба,
        // а не каждый тик до первого успеха (иначе шанс фактически ~100%).
        if (!TryMarkPanicked(c))
            return; // уже обрабатывали в этой жизни

        if (!roll_chance_f(CHANCE_LOWHP))
            return;

        YellLine(c, LOWHP_LINES[urand(0, static_cast<uint32>(LOWHP_COUNT - 1))]);
    }
};

// ── Registration ──────────────────────────────────────────────────────────────

void Addmod_random_tauntsScripts()
{
    new RandomTauntsPlayer();
    new RandomTauntsCreature();
}
