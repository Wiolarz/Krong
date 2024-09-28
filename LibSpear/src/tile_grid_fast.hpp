#ifndef TILE_GRID_FAST_H
#define TILE_GRID_FAST_H

#ifdef WIN32
#include "windows.h"
#endif

#include "godot_cpp/classes/node.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include "godot_cpp/variant/string.hpp"
#include "godot_cpp/core/defs.hpp"
#include <stdint.h>
#include <array>
#include <vector>

#include "data.hpp"
#include "battle_structs.hpp"

using namespace godot;


class TileGridFastCpp : public Node {
    GDCLASS(TileGridFastCpp, Node);

    Vector2i _dims;
    unsigned _number_of_mana_wells = 0;
    std::vector<Tile> _tiles;
    std::array<std::vector<Position>, MAX_ARMIES> _spawns;
protected:
    static void _bind_methods();

public:
    void set_map_size(Vector2i dimensions);
    
    _FORCE_INLINE_ Tile get_tile(Position pos) {
        int idx = pos.x + pos.y * _dims.x;
        if(pos.x < 0 || pos.x >= _dims.x || pos.y < 0 || pos.y >= _dims.y) {
            return Tile();
        }
        return _tiles[idx];
    }

    void set_tile(Position pos, Tile tile);
    inline void set_tile_gd(
            Vector2i pos, bool passable, bool wall, bool swamp, 
            bool mana_well, bool pit, bool hill, int army, unsigned direction
    ) {
        set_tile(Position(pos.x, pos.y), Tile(passable, wall, swamp, mana_well, pit, hill, army, direction));
    }

    constexpr const std::vector<Position>& get_spawns(int army) const {
        return _spawns[army];
    }

    const inline Vector2i get_dims() const {
        return _dims;
    }

    const inline unsigned get_number_of_mana_wells() const {
        return _number_of_mana_wells;
    }
};

#endif
