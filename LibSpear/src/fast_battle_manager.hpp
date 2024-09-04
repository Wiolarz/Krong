#ifndef FAST_BATTLE_MANAGER_H
#define FAST_BATTLE_MANAGER_H

#ifdef WIN32
#include "windows.h"
#endif

#include "godot_cpp/classes/node.hpp"
#include "godot_cpp/core/class_db.hpp"
#include "godot_cpp/variant/vector2i.hpp"
#include <stdint.h>
#include <array>
#include <vector>
#include <algorithm>

#include "data.hpp"
#include "battle_structs.hpp"
#include "cache_grid.hpp"
#include "tile_grid_fast.hpp"


using godot::Node;
using godot::Vector2i;

// idea - BattleManagerFastWrapper as multiple inheritance of internal BattleManagerFastCpp and godot Node if it turns out that Node itself is expensive
class BattleManagerFastCpp : public Node {
    GDCLASS(BattleManagerFastCpp, Node);

    int8_t _current_army;
    int8_t _previous_army;
    BattleState _state = BattleState::INITIALIZING;
    ArmyList _armies{};
    TileGridFastCpp* _tiles;

    BattleResult _result;

    CacheGrid _unit_cache;
    std::vector<Move> _moves{};
    std::vector<Move> _heuristic_moves{};
    bool _moves_dirty = true;
    bool _heuristic_moves_dirty = true;


    void _process_unit(UnitID uid, bool process_kills);
    void _process_bow(UnitID uid);

    void _refresh_legal_moves();
    void _refresh_heuristically_good_moves();
    void _refresh_heuristically_good_summon_moves();

    void _move_unit(UnitID id, Position pos);
    void _kill_unit(UnitID id, int killer_team);

    BattleResult _play_move(unsigned unit, Vector2i move);

protected:
    static void _bind_methods();

public:
    BattleManagerFastCpp() = default;
    ~BattleManagerFastCpp() = default;

    void insert_unit(int army, int idx, Vector2i pos, int rotation, bool is_summoning); /// Add a unit in a summoning state
    void set_army_team(int army, int team); /// Set army's team - required
    void set_unit_symbol(int army, int unit, int symbol, int symbol_id); /// Add symbol for a specified unit
    void set_tile_grid(TileGridFastCpp* tilegrid);
    void set_current_participant(int army);
    void finish_initialization();
    void force_battle_ongoing();
    
    BattleResult play_move(Move move);
    int play_move_gd(unsigned unit, Vector2i move);
    
    /// Get winner team, or -1 if the battle has not yet ended. On error returns -2.
    int get_winner_team();
    inline BattleResult get_result() {return _result;}

    const std::vector<Move>& get_legal_moves();
    /// Get legal moves in an array of arrays [[unit, position], ...]
    godot::Array get_legal_moves_gd();
    /// Return a random move with a custom bias towards heuristically sensible moves, and whether such a move was chosen
    std::pair<Move, bool> get_random_move(float heuristic_probability);
    int get_move_count();

    /// Get moves that are likely to increase score/win the game/avoid losses. If there are no notable moves, returns all moves
    const std::vector<Move>& get_heuristically_good_moves();

    bool is_occupied(Position pos, int team, TeamRelation relation) const;
    godot::Array get_unit_id_on_position(Vector2i pos) const;

    // Getters, primarily for testing correctness with regular BattleManager
    inline Vector2i get_unit_position(int army, int unit) const {
        auto p = _armies[army].units[unit].pos; 
        return Vector2i(p.x, p.y);
    }

    inline int get_unit_rotation(int army, int unit) const {
        return _armies[army].units[unit].rotation;
    }

    inline bool is_unit_alive(int army, int unit) const {
        return _armies[army].units[unit].status == UnitStatus::ALIVE;
    }

    inline bool is_unit_being_summoned(int army, int unit) const {
        return _armies[army].units[unit].status == UnitStatus::SUMMONING;
    }

    inline int get_current_participant() const {
        return _current_army;
    }

    inline int get_previous_participant() const {
        return _previous_army;
    }

    inline bool is_battle_finished() const {
        return _state == BattleState::FINISHED;
    }

    inline int get_army_team(int army) const {
        return _armies[army].team;
    }
private:
    std::pair<Unit*, Army*> _get_unit(UnitID id) {
        if(id == NO_UNIT) {
            return std::make_pair(nullptr, nullptr);
        }
        return std::make_pair(&_armies[id.first].units[id.second], &_armies[id.first]);
    }

    std::pair<Unit*, Army*> _get_unit(Position coord) {
        return _get_unit(_unit_cache.get(coord));
    }
};


#endif
