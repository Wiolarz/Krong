#ifndef DATA_H
#define DATA_H

#ifdef WIN32
#include "windows.h"
#endif

#include <stdint.h>
#include <array>
#include <algorithm>
#include <string>

#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/string.hpp"


struct Position {
    uint8_t x;
    uint8_t y;

    inline Position() : x(0), y(0) {};
    inline Position(uint8_t x, uint8_t y) : x(x), y(y) {};
    inline Position(godot::Vector2i p) : x(p.x), y(p.y) {};

    inline Position operator+(const Position& other) const {
        return Position(x + other.x, y + other.y);
    }

    inline Position operator-(const Position& other) const {
        return Position(x - other.x, y - other.y);
    }

    inline bool operator==(const Position other) const {
        return x == other.x && y == other.y;
    }
};


class Symbol {
/// Should be kept in sync with Symbol in global_enums.gd singleton
    enum class Type: uint8_t {
        EMPTY,
        ATTACK_WITH_COUNTER,
        ATTACK,
        SHIELD,
        BOW,
        PUSH
    } type;
public:
    Symbol() = default;
    Symbol(int i) : type(Type(i)) {}
    Symbol(Type i) : type(i) {}

    inline int get_attack_force() {
        switch(type) {
            case Symbol::Type::ATTACK:
            case Symbol::Type::ATTACK_WITH_COUNTER:
                return 1;
            default:
                return 0;
        }
    }

    inline int get_counter_force() {
        switch(type) {
            case Symbol::Type::ATTACK_WITH_COUNTER:
                return 1;
            default:
                return 0;
        }
    }

    inline int get_defense_force() {
        switch(type) {
            // Note - also update MIN_SHIELD_DEFENSE constant when changing these values
            case Symbol::Type::SHIELD:
                return 1;
            case Symbol::Type::EMPTY:
                return -2;
            default:
                return 0;
        }
    }

    inline int get_bow_force() {
        switch(type) {
            case Symbol::Type::BOW:
                return 1;
            default:
                return 0;
        }
    }
    
    inline int pushes() {
        return type == Symbol::Type::PUSH;
    }

    inline void print() {
        printf("%d%d%d", get_attack_force(), get_counter_force(), get_defense_force());
    }
};

enum class UnitStatus: uint8_t {
    SUMMONING,
    ALIVE,
    DEAD
};

enum class BattleState: uint8_t {
    INITIALIZING,
    SUMMONING,
    ONGOING,
    FINISHED
};

class Tile {
    static const uint8_t PASSABLE = 0x1;
    static const uint8_t WALL = 0x2;
    static const uint8_t SWAMP = 0x4;
    static const uint8_t FORBIDDEN = 0x8;

    uint8_t flags;
    int8_t spawning_army;
    uint8_t spawning_direction;

public:
    Tile() : flags(FORBIDDEN), spawning_army(-1) {}
    Tile(bool passable, bool wall, bool swamp, int army, unsigned direction) :
        flags(
            (passable ? PASSABLE : 0)
          | (wall ? WALL : 0)
          | (swamp ? SWAMP : 0)
        ),
        spawning_army(army),
        spawning_direction(direction)
    {}
    
    inline bool is_passable() {
        return (flags & PASSABLE) != 0;
    }

    inline bool is_wall() {
        return (flags & WALL) != 0;
    }

    inline int get_spawning_army() {
        return spawning_army;
    }

    inline int get_spawn_rotation() {
        return spawning_direction;
    }
};

const int MIN_SHIELD_DEFENSE = 1;
const std::array<Position, 6> DIRECTIONS = {
	Position(-1, 0),
	Position(0, -1),
	Position(1, -1),
	Position(1, 0),
	Position(0, 1),
	Position(-1, 1),
};


inline int get_rotation(Position origin, Position relative) {
    auto pos = relative - origin;
    for(int i = 0; i < 6; i++) {
        if(DIRECTIONS[i] == pos) {
            return i;
        }
    }
    return 6;
    //auto it = std::find(DIRECTIONS.begin(), DIRECTIONS.end(), relative - origin);
    //return it - DIRECTIONS.begin();
}

inline int flip(int rot) {
    return (rot + 3) % 6;
}

#endif
