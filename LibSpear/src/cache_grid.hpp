#ifndef CACHE_GRID_H
#define CACHE_GRID_H

#include "battle_structs.hpp"
#include "tile_grid_fast.hpp"
#include "godot_cpp/core/error_macros.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include <format>
#include <signal.h>

using godot::Vector2i;

using UnitID = std::pair<int8_t, int8_t>;

static constexpr UnitID NO_UNIT = std::make_pair(-1, -1);
static UnitID _err_return_dummy_uid = std::make_pair(-1, -1);


class CacheGrid {
    using T = UnitID;

    std::vector<T> _grid;
    Vector2i _dims;
public:
    CacheGrid() = default;
    CacheGrid(TileGridFastCpp& tg) 
        : _dims(tg.get_dims())
    {
        _grid.resize(_dims.x * _dims.y);
    }

    inline T& operator[](Position pos) {
        unsigned idx = pos.x + pos.y * _dims.x;
        if(idx >= _grid.size()) {
            raise(SIGINT);
            ERR_FAIL_V_MSG(_err_return_dummy_uid , std::format("Position {},{} not present in CacheGrid", pos.x, pos.y).c_str());
        }
        return _grid[idx];
    }

    inline const T get(Position pos) const {
        unsigned idx = pos.x + pos.y * _dims.x;
        if(idx >= _grid.size()) {
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
                    (*this)[unit.pos] = std::make_pair(army_id, unit_id);
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
                raise(SIGINT);
                ERR_FAIL_V_MSG(false , std::format("CacheGrid mismatch").c_str());
            }
        }
        return true;
    }
};

#endif // CACHE_GRID_H

