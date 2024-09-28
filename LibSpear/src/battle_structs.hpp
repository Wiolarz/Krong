#ifndef BATTLE_STRUCTS_H
#define BATTLE_STRUCTS_H

#include <stdint.h>
#include <array>
#include "godot_cpp/variant/array.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/variant.hpp"
#include "godot_cpp/core/error_macros.hpp"

#include "data.hpp"

const unsigned MAX_ARMIES = 4;
const unsigned MAX_UNITS_IN_ARMY = 5;

class BattleManagerFastCpp;
class BattleMCTSManager;

using Score = int16_t;

struct BattleResult {
    int8_t winner_team = -1;
    bool error = false;
    std::array<Score, MAX_ARMIES> max_scores{0};
    std::array<Score, MAX_ARMIES> total_scores{0};
    std::array<Score, MAX_ARMIES> score_gained{0};
    std::array<Score, MAX_ARMIES> score_lost{0};
};


struct UnitID {
    int8_t army;
    int8_t unit;

    UnitID() : army(-1), unit(-1) {}
    UnitID(int8_t _army, int8_t _unit) : army(_army), unit(_unit) {}
    bool operator==(const UnitID& other) const {
        return army == other.army && unit == other.unit;
    }
};

static const UnitID NO_UNIT = UnitID(-1,-1);
static UnitID _err_return_dummy_uid = UnitID(-1,-1);


struct Unit {
    UnitStatus status = UnitStatus::DEAD;
    Position pos{};
    uint8_t rotation{};
    uint8_t score = 1;
    uint8_t mana = 0;
    UnitID martyr_id = NO_UNIT;
    uint8_t flags = 0;
    std::array<Symbol, 6> sides{};

    static const uint8_t FLAG_VENGEANCE = 0x01;
    static const uint8_t FLAG_ON_SWAMP = 0x02;

    inline Symbol symbol_when_rotated(int side) const {
        if(flags & FLAG_ON_SWAMP) {
            return Symbol();
        }
        return sides[(6-rotation + side) % 6];
    }

    inline Symbol front_symbol() const {
        if(flags & FLAG_ON_SWAMP) {
            return Symbol();
        }
        return sides[0];
    }

    inline bool is_vengeance_active() const {
        return (flags & FLAG_VENGEANCE);
    }
};

struct Army {
    int8_t id = 0;
    int8_t team = -1;

    uint16_t mana_points;
    uint16_t cyclone_timer;

    std::array<Unit, MAX_UNITS_IN_ARMY> units{};

    Unit* get_unit(Position coord);
    int find_unit_id_to_summon(int from = 0);
    bool is_defeated();
};

using ArmyList = std::array<Army, MAX_ARMIES>;

struct Move {
    static const int8_t NO_SPELL = -1;

    int8_t spell_id = NO_SPELL;
    uint8_t unit;
    Position pos;

    Move() = default;
    Move(uint8_t _unit, Position _pos, int8_t _spell_id = NO_SPELL) : unit(_unit), pos(_pos), spell_id(_spell_id) {}
    Move(godot::Array libspear_tuple) {
        ERR_FAIL_COND_MSG(libspear_tuple.size() < 2 || libspear_tuple.size() > 3, "Invalid LibSpear tuple size");
        unit = libspear_tuple[0];
        pos = Position(libspear_tuple[1]);
        spell_id = (libspear_tuple.size() >= 3) ? int8_t(libspear_tuple[2]) : NO_SPELL;
    }

    bool operator==(const Move& other) const {
        return unit == other.unit && pos == other.pos;
    }

    godot::Array as_libspear_tuple() const {
        godot::Array ret;
        ret.push_back(unit);
        ret.push_back(godot::Vector2i(pos.x, pos.y));
        if(spell_id != NO_SPELL) {
            ret.push_back(spell_id);
        }
        return ret;
    }
};

template<>
struct std::hash<Move> {
    const std::size_t operator()(const Move& move) const {
        auto h1 = std::hash<unsigned>{}(move.unit);
        auto h2 = std::hash<unsigned>{}(move.pos.x);
        auto h3 = std::hash<unsigned>{}(move.pos.y);
        return h1 ^ (h2 << 1) ^ (h3 << 2);
    }
};


enum class TeamRelation {
    ME,
    ALLY,
    ENEMY,
    ANY
};

#endif //BATTLE_STRUCTS_H
