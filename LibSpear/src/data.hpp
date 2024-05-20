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
};

enum class UnitStatus: uint8_t {
    SUMMONING,
    ALIVE,
    DEAD
};

enum class BattleState: uint8_t {
    SUMMONING,
    ONGOING,
    FINISHED
};

class Tile {
    enum class Type: uint8_t {
        SENTINEL,
        BLUE_SPAWN,
        EMPTY,
        RED_SPAWN,
        WALL,
        SWAMP,
        HOLE,
        FORBIDDEN
    } type;

public:
    Tile() : type(Type::FORBIDDEN) {}
    Tile(godot::String& str) {
        if(str == "sentinel") {
            type = Tile::Type::SENTINEL;
        }
        if(str == "blue_spawn") {
            type = Tile::Type::BLUE_SPAWN;
        }
        if(str == "empty") {
            type = Tile::Type::EMPTY;
        }
        if(str == "red_spawn") {
            type = Tile::Type::RED_SPAWN;
        }
        if(str == "wall") {
            type = Tile::Type::WALL;
        }
        if(str == "swamp") {
            type = Tile::Type::SWAMP;
        }
        if(str == "hole") {
            type = Tile::Type::HOLE;
        }
        //printf("WARNING - unknown tile type %s\n", str.c_str());
        printf("WARNING - unknown tile type");
        type = Tile::Type::FORBIDDEN;
    }
    
    inline bool is_passable() {
        printf("TILE IS %d\n", type);
        switch(type) {
            case Tile::Type::WALL:
            case Tile::Type::SENTINEL:
            case Tile::Type::HOLE:
                return false;
            default:
                return true;
        }
    }

    inline bool is_wall() {
        printf("TILE iswall IS %d\n", type);
        switch(type) {
            case Tile::Type::WALL:
            case Tile::Type::SENTINEL:
                return true;
            default:
                return false;
        }
    }

    inline int get_spawning_team() {
        switch(type) {
            case Tile::Type::RED_SPAWN:
                return 0;
            case Tile::Type::BLUE_SPAWN:
                return 1;
            default:
                return true;
        }
    }

    inline int get_spawn_rotation() {
        switch(type) {
            case Tile::Type::RED_SPAWN:
                return 0;
            case Tile::Type::BLUE_SPAWN:
                return 3;
            default:
                return true;
        }
    }
};

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