#ifndef TILE_GRID_FAST_H
#define TILE_GRID_FAST_H

#ifdef WIN32
#include "windows.h"
#endif

#include "godot_cpp/classes/node.hpp"
#include "godot_cpp/core/class_db.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/string.hpp"
#include <stdint.h>
#include <array>
#include <vector>

#include "data.hpp"

using namespace godot;


class TileGridFastCpp : public Node {
    GDCLASS(TileGridFastCpp, Node);

    Vector2i dims;
    std::vector<Tile> tiles;
    std::array<std::vector<Position>, 2> spawns;
protected:
    static void _bind_methods();

public:
    void set_map_size(Vector2i dimensions);
    
    Tile get_tile(Position pos);
    //inline int get_tile_gd(Vector2i pos);
    
    void set_tile(Position pos, Tile tile);
    inline void set_tile_gd(Vector2i pos, bool passable, bool wall, bool swamp, int army, unsigned direction) {
        set_tile(Position(pos.x, pos.y), Tile(passable, wall, swamp, army, direction));
    }

    constexpr const std::vector<Position>& get_spawns(int army) const {
        return spawns[army];
    }
};

#endif
