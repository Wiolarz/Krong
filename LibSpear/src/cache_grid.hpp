#ifndef CACHE_GRID_H
#define CACHE_GRID_H

#include "battle_structs.hpp"
#include "tile_grid_fast.hpp"
#include "godot_cpp/core/error_macros.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include <format>

using godot::Vector2i;


class CacheGrid {
    using T = UnitID;

    std::vector<T> _grid{};
    Vector2i _dims{};
public:
    CacheGrid() = default;
    CacheGrid(TileGridFastCpp& tg) 
        : _dims(tg.get_dims())
    {
        _grid.resize(_dims.x * _dims.y);
    }

    _FORCE_INLINE_ T& operator[](Position pos) {
        unsigned idx = pos.x + pos.y * _dims.x;
        if(pos.x < 0 || pos.x >= _dims.x || pos.y < 0 || pos.y >= _dims.y) {
            ERR_FAIL_V_MSG(_err_return_dummy_uid , std::format("Position {},{} not present in CacheGrid", pos.x, pos.y).c_str());
        }
        return _grid[idx];
    }

    _FORCE_INLINE_ const T get(Position pos) const {
        unsigned idx = pos.x + pos.y * _dims.x;
        if(pos.x < 0 || pos.x >= _dims.x || pos.y < 0 || pos.y >= _dims.y) {
            return NO_UNIT;
        }
        return _grid[idx];
    }

    inline void update_armies(ArmyList& armies) {
        for(auto& i: _grid) {
            i = NO_UNIT;
        }

        for(int army_id = 0; army_id < armies.size(); army_id++) {
            auto& army = armies[army_id];

            for(int unit_id = 0; unit_id < army.units.size(); unit_id++) {
                auto& unit = army.units[unit_id];

                if(unit.status == UnitStatus::ALIVE) {
                    (*this)[unit.pos] = UnitID(army_id, unit_id);
                }
            }
        }
    }

    inline void move(Position old, Position newpos) {
        (*this)[newpos] =  (*this)[old];
        (*this)[old] = NO_UNIT;
    }

    inline bool self_test(ArmyList& armies) {
        CacheGrid new_cache = *this;
        new_cache.update_armies(armies);
        for(int i = 0; i < _grid.size(); i++) {
            if(new_cache._grid[i] != _grid[i]) {
                ERR_FAIL_V_MSG(false , std::format("CacheGrid mismatch").c_str());
            }
        }
        return true;
    }
};

#endif // CACHE_GRID_H

