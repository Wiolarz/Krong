#include "tile_grid_fast.hpp"
#include <algorithm>


void TileGridFastCpp::set_tile(Position pos, Tile type) {
    unsigned idx = pos.x + pos.y * _dims.x;
    if(idx >= _tiles.size()) {
        printf("ERROR - invalid tile position %d %d (idx - %d, dims - %dx%d)\n", pos.x, pos.y, idx, _dims.x, _dims.y);
        return;
    }
    auto old_team = _tiles[idx].get_spawning_army();
    auto new_team = type.get_spawning_army();
    if(old_team != -1) {
        _spawns[old_team].erase(std::find(_spawns[old_team].begin(), _spawns[old_team].end(), pos));
    }
    if(new_team != -1) {
        _spawns[new_team].push_back(pos);
    }

    if(_tiles[idx].is_mana_well()) {
        _number_of_mana_wells--;
    }

    if(type.is_mana_well()) {
        _number_of_mana_wells++;
    }

    _tiles[idx] = type;
}

void TileGridFastCpp::set_map_size(Vector2i dimensions) {
    _dims = dimensions;
    _tiles.resize(_dims.x * _dims.y);
}

void TileGridFastCpp::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_tile", "passable", "wall", "swamp", "mana_well", "pit", "army", "direction"), &TileGridFastCpp::set_tile_gd);
    ClassDB::bind_method(D_METHOD("set_map_size", "dimensions"), &TileGridFastCpp::set_map_size);
}


