#include "fast_battle_manager.hpp"
#include "godot_cpp/core/class_db.hpp"
#include "battle_mcts.hpp"
 
#include <algorithm>
#include <stdlib.h>
#include <random>
#include <csignal>

#define CHECK_UNIT(idx, val) \
    if(idx >= 5) { \
        printf("ERROR - Unknown unit id %d\n", idx);\
		::godot::_err_print_error(FUNCTION_STR, __FILE__, __LINE__, "ERROR - Unknown unit id - check stdout"); \
        return val;\
    }

#define CHECK_ARMY(idx, val) \
    if(idx >= 4) { \
        printf("ERROR - Unknown army id %d\n", idx); \
		::godot::_err_print_error(FUNCTION_STR, __FILE__, __LINE__, "ERROR - Unknown army id - check stdout"); \
        return val; \
    }

void BattleManagerFastCpp::finish_initialization() {
    if(state == BattleState::INITIALIZING) {
        state = BattleState::SUMMONING;
        for(int i = 0; i < armies.size(); i++) {
            armies[i].id = i;
            for(auto& unit: armies[i].units) {
                if(unit.status != UnitStatus::DEAD) {
                    result.total_scores[i] += unit.score;
                }
            }
        }
    }
    else {
        WARN_PRINT("BMFast already initialized");
    }
}

BattleResult BattleManagerFastCpp::play_move(Move move) {
    auto ret = _play_move(move.unit, Vector2i(move.pos.x, move.pos.y));
    return ret;
}

int BattleManagerFastCpp::play_move_gd(unsigned unit_id, Vector2i pos) {
    auto ret = _play_move(unit_id, pos);
    return ret.winner_team;
}

BattleResult BattleManagerFastCpp::_play_move(unsigned unit_id, Vector2i pos) {
    moves_dirty = true;
    heuristic_moves_dirty = true;

    result.winner_team = -1;
    result.score_gained.fill(0);
    result.score_lost.fill(0);

    previous_participant = current_participant;

    if(state == BattleState::INITIALIZING) {
        ERR_FAIL_V_MSG(result, "BMFast - Please call finish_initialization() before playing a move");
    }

    CHECK_UNIT(unit_id, result);
    auto& unit = armies[current_participant].units[unit_id];

    if(state == BattleState::SUMMONING) {
        if(unit.status != UnitStatus::SUMMONING) {
            WARN_PRINT("BMFast - unit is not in summoning state\n");
            raise(SIGINT);
            return result;
        }

        if(tiles->get_tile(pos).get_spawning_army() != current_participant) {
            WARN_PRINT("BMFast - target spawn does not belong to current army, aborting\n");
            raise(SIGINT);
            return result;
        }

        unit.pos = pos;
        unit.rotation = tiles->get_tile(pos).get_spawn_rotation();
        unit.status = UnitStatus::ALIVE;

        bool end_summon = true;
        for(int i = (current_participant+1) % armies.size(); i != current_participant; i = (i+1)%armies.size()) {
            if(armies[i].find_summon_id() != -1) {
                current_participant = i;
                end_summon = false;
                break;
            }
        }

        if(end_summon) {
            state = BattleState::ONGOING;
        }
    }
    else if(state == BattleState::ONGOING) {
        auto rot_new = get_rotation(unit.pos, pos);

        if(rot_new == 6) {
            WARN_PRINT("BMFast - target position is not a neighbor\n");
            return result;
        }

        unit.rotation = rot_new;
        _process_unit(unit, armies[current_participant], true, result);
        
        if(unit.status == UnitStatus::ALIVE) {
            unit.pos = pos;
            _process_unit(unit, armies[current_participant], true, result);
        }
        
        int limit = current_participant;
        do {
            current_participant = (current_participant+1) % armies.size();
        } while(armies[current_participant].is_defeated() && current_participant != limit);
    }
    else {
        WARN_PRINT("BMFast - battle already ended, did not expect that\n");
        return result;
    }

    result.winner_team = get_winner_team();
    return result;
}


void BattleManagerFastCpp::_process_unit(Unit& unit, Army& army, bool process_kills, BattleResult& out_result) {

    for(auto& enemy_army : armies) {

        if(enemy_army.team == army.team) {
            continue;
        }

        for(auto& neighbor : enemy_army.units) {
            
            if(neighbor.status != UnitStatus::ALIVE) {
                continue;
            }

            auto rot_unit_to_neighbor = get_rotation(unit.pos, neighbor.pos);
            auto rot_neighbor_to_unit = flip(rot_unit_to_neighbor);

            // Skip non-neighbors
            if( rot_unit_to_neighbor == 6 ) {
                continue;
            }
            
            auto unit_symbol = unit.symbol_at_side(rot_unit_to_neighbor);
            auto neighbor_symbol = neighbor.symbol_at_side(rot_neighbor_to_unit);

            // counter/spear
            if(neighbor_symbol.get_counter_force() > 0 && unit_symbol.get_defense_force() < neighbor_symbol.get_counter_force()) {
                unit.kill(enemy_army.id, army.id, out_result);
                return;
            }

            if(process_kills) {
                if(unit_symbol.get_attack_force() > 0 && neighbor_symbol.get_defense_force() < unit_symbol.get_attack_force()) {
                    neighbor.kill(army.id, enemy_army.id, out_result);
                }

                if(unit_symbol.pushes()) {
                    auto new_pos = neighbor.pos + neighbor.pos - unit.pos;
                    if(!(tiles->get_tile(new_pos).is_passable()) || _get_unit(new_pos) != nullptr) {
                        neighbor.kill(army.id, enemy_army.id, out_result);
                    }
                    neighbor.pos = new_pos;
                    _process_unit(neighbor, enemy_army, false, out_result);
                }
            }
        }

        if(process_kills) {
            _process_bow(unit, army, enemy_army, out_result);
        }
    }
}

void BattleManagerFastCpp::_process_bow(Unit& unit, Army& army, Army& enemy_army, BattleResult& out_result) {
    for(int i = 0; i < 6; i++) {
        auto force = unit.symbol_at_side(i).get_bow_force();
        if(force == 0) {
            continue;
        }

        auto iter = DIRECTIONS[i];

        for(auto pos = unit.pos + iter; !(tiles->get_tile(pos).is_wall()); pos = pos + iter) {
            if(is_occupied(pos, army.team, TeamRelation::ALLY)) {
                break;
            }

            auto other = enemy_army.get_unit(pos);
            if(other != nullptr && other->symbol_at_side(flip(i)).get_defense_force() < force) {
                other->kill(army.id, enemy_army.id, out_result);
                break;
            }
        }
    }
}

int BattleManagerFastCpp::get_winner_team() {

    if(state == BattleState::SUMMONING) {
        return -1;
    }

    int last_team_alive = -2;
    int teams_alive = 4;
    std::array<int, 4> armies_in_teams_alive = {0,0,0,0};

    for(int i = 0; i < armies.size(); i++) {
        if(!armies[i].is_defeated()) {
            armies_in_teams_alive[armies[i].team] += 1;
        }
    }
    
    for(int i = 0; i < 4; i++) {
        if(armies_in_teams_alive[i] == 0) {
            teams_alive--;
        }
        else {
            last_team_alive = i;
        }
    }

    if(teams_alive == 0) {
        ERR_PRINT("C++ Assertion failed: no teams alive after battle, should not be possible");
        state = BattleState::FINISHED;
        return -2;
    }

    if(teams_alive == 1) {
        state = BattleState::FINISHED;
        return last_team_alive;
    }

    return -1;
}


const std::vector<Move>& BattleManagerFastCpp::get_legal_moves() {
    if(moves_dirty) {
        _refresh_legal_moves();
        moves_dirty = false;
    }
    return moves;
}

const std::vector<Move>& BattleManagerFastCpp::get_heuristically_good_moves() {
    if(heuristic_moves_dirty) {
        _refresh_heuristically_good_moves();
        heuristic_moves_dirty = false;
    }
    if(heuristic_moves.empty()) {
        return get_legal_moves();
    }
    return heuristic_moves;
}

void BattleManagerFastCpp::_refresh_legal_moves() {
    moves.clear();
    moves.reserve(64);

    auto& army = armies[current_participant];
    auto& spawns = tiles->get_spawns(current_participant);

    Move move;

    if(state == BattleState::SUMMONING) {
        for(auto& spawn : spawns) {
            if(is_occupied(spawn, army.team, TeamRelation::ALLY)) {
                continue;
            }

            for(int i = 0; i < army.units.size(); i++) {
                if(army.units[i].status != UnitStatus::SUMMONING) {
                    continue;
                }

                move.unit = i;
                move.pos = spawn;
                moves.push_back(move);
            }
        }
    }
    else if(state == BattleState::ONGOING) {

        for(int unit_id = 0; unit_id < army.units.size(); unit_id++) {
            auto& unit = army.units[unit_id];
            if(unit.status != UnitStatus::ALIVE) {
                continue;
            }

            for(int side = 0; side < 6; side++) {
                move.unit = unit_id;
                move.pos = unit.pos + DIRECTIONS[side];

                if(!tiles->get_tile(move.pos).is_passable()) {
                    continue;
                }
                
                bool discard = false;

                for(auto& other_army : armies) {
                    for(auto& other_unit : other_army.units) {
                        if( !(other_unit.status == UnitStatus::ALIVE && other_unit.pos == move.pos) ) {
                            continue;
                        }

                        if(other_army.team == army.team) {
                            discard = true;
                        }

                        auto rot_neighbor_to_unit = get_rotation(other_unit.pos, unit.pos);
                        auto neighbor_symbol = other_unit.symbol_at_side(rot_neighbor_to_unit);

                        if(neighbor_symbol.get_defense_force() >= MIN_SHIELD_DEFENSE) {
                            discard = true;
                        }
                    }
                }

                if(discard) {
                    continue;
                }

                moves.push_back(move);
            }
        }
    }
}

void BattleManagerFastCpp::_refresh_heuristically_good_moves() {
    heuristic_moves.clear();
    heuristic_moves.reserve(64);

    auto& army = armies[current_participant];

    std::vector<BattleResult> move_results;
    bool killing_move_found = false;

    for(int i = 0; i < moves.size(); i++) {
        auto& m = moves[i];
        auto bm = *this;
        auto result = bm.play_move(m);
        
        // Always win the game if possible and avoid defeats
        if(result.winner_team == army.team) {
            heuristic_moves.clear();
            heuristic_moves.push_back(m);
            return;
        }
        else if(result.winner_team != -1) {
            continue;
        }

        // If a move kills an enemy unit, prioritize killing move
        if(result.score_gained[current_participant] > 0) {
            if(!killing_move_found) {
                killing_move_found = true;
                heuristic_moves.clear();
            }
            heuristic_moves.push_back(m);
        }

        // If no killing move found, prioritize moves that don't result in a loss
        if(result.score_lost[current_participant] == 0 && !killing_move_found) {
            heuristic_moves.push_back(m);
        }
    }

    // TODO: potential heuristics:
    // - summon archer such that it can shoot unprotected unit on first turn or as a last unit
    // - if opponent has archers, summon units such that the (eventually) summoned archer cannot kill them (account for shields)
}


Move BattleManagerFastCpp::get_random_move(float heuristic_probability) {
    static thread_local std::mt19937 rand_engine;
    static thread_local std::uniform_real_distribution heur_dist(0.0f, 1.0f);

    auto moves_arr = ( !heuristic_moves.empty() && heur_dist(rand_engine) < heuristic_probability )
        ? get_heuristically_good_moves() 
        : get_legal_moves();

    if(moves_arr.size() == 0) {
		::godot::_err_print_error(FUNCTION_STR, __FILE__, __LINE__, "ERROR - a random move requested, but 0 moves are possible"); \
        raise(SIGINT);
    }
    
    std::uniform_int_distribution dist{0, int(moves_arr.size() - 1)};
    auto move = dist(rand_engine);

    return moves_arr[move];
}

int BattleManagerFastCpp::get_move_count() {
    return get_legal_moves().size();
}

godot::Array BattleManagerFastCpp::get_legal_moves_gd() {
    auto& moves_arr = get_legal_moves();
    godot::Array arr{};
    
    for(auto& i: moves_arr) {
        godot::Array val{};
        val.push_back(i.unit);
        val.push_back(Vector2i(i.pos.x, i.pos.y));
        arr.push_back(val);
    }

    return arr;
}

bool BattleManagerFastCpp::is_occupied(Position pos, int team, TeamRelation relation) const {
    for(auto& army : armies) {
        if( (army.team == team) != (relation == TeamRelation::ALLY) ) {
            continue;
        }

        for(auto& unit : army.units) {
            if(unit.status == UnitStatus::ALIVE && unit.pos == pos) {
                return true;
            }
        }
    }
    return false;
}

void BattleManagerFastCpp::insert_unit(int army, int idx, Vector2i pos, int rotation, bool is_summoning) {
    CHECK_UNIT(idx,)
    CHECK_ARMY(army,)
    armies[army].units[idx].pos = pos;
    armies[army].units[idx].rotation = rotation;
    armies[army].units[idx].status = is_summoning ? UnitStatus::SUMMONING : UnitStatus::ALIVE;
}

void BattleManagerFastCpp::set_unit_symbol(int army, int unit, int side, int symbol) {
    CHECK_UNIT(unit,)
    CHECK_ARMY(army,)
    armies[army].units[unit].sides[side] = Symbol(symbol);
}

void BattleManagerFastCpp::set_army_team(int army, int team) {
    CHECK_ARMY(army,)
    armies[army].team = team;
}

void BattleManagerFastCpp::set_current_participant(int army) {
    CHECK_ARMY(army,)
    current_participant = army;
}

void BattleManagerFastCpp::set_tile_grid(TileGridFastCpp* tg) {
    tiles = tg;
}

void BattleManagerFastCpp::force_battle_ongoing() {
    if(state == BattleState::INITIALIZING) {
        ERR_FAIL_MSG("Must finish_initialization() before calling force_battle_ongoing()");
    }
    state = BattleState::ONGOING;
}

Unit* BattleManagerFastCpp::_get_unit(Position coord) {
    for(auto army : armies) {
        auto unit = army.get_unit(coord);
        if(unit != nullptr && unit->pos == coord) {
            return unit;
        }
    }
    return nullptr;
}


void BattleManagerFastCpp::_bind_methods() {
    ClassDB::bind_method(D_METHOD("insert_unit"), &BattleManagerFastCpp::insert_unit, "army", "index", "position", "rotation", "is_summoning");
    ClassDB::bind_method(D_METHOD("set_unit_symbol"), &BattleManagerFastCpp::set_unit_symbol, "army", "index", "symbol_slot", "symbol_type");
    ClassDB::bind_method(D_METHOD("set_army_team"), &BattleManagerFastCpp::set_army_team, "army", "team");
    ClassDB::bind_method(D_METHOD("set_tile_grid"), &BattleManagerFastCpp::set_tile_grid, "tilegrid");
    ClassDB::bind_method(D_METHOD("set_current_participant"), &BattleManagerFastCpp::set_current_participant, "army");
    ClassDB::bind_method(D_METHOD("force_battle_ongoing"), &BattleManagerFastCpp::force_battle_ongoing);
    ClassDB::bind_method(D_METHOD("finish_initialization"), &BattleManagerFastCpp::finish_initialization);
    ClassDB::bind_method(D_METHOD("play_move"), &BattleManagerFastCpp::play_move_gd, "unit", "position");

    ClassDB::bind_method(D_METHOD("get_unit_position"), &BattleManagerFastCpp::get_unit_position, "army", "unit");
    ClassDB::bind_method(D_METHOD("get_unit_rotation"), &BattleManagerFastCpp::get_unit_rotation, "army", "unit");
    ClassDB::bind_method(D_METHOD("is_unit_alive"), &BattleManagerFastCpp::is_unit_alive, "army", "unit");
    ClassDB::bind_method(D_METHOD("is_unit_being_summoned"), &BattleManagerFastCpp::is_unit_being_summoned, "army", "unit");
    ClassDB::bind_method(D_METHOD("get_current_participant"), &BattleManagerFastCpp::get_current_participant);
    ClassDB::bind_method(D_METHOD("get_legal_moves"), &BattleManagerFastCpp::get_legal_moves_gd);

}

Unit* Army::get_unit(Position coord) {
    for(auto& unit : units) {
        if(unit.pos == coord && unit.status == UnitStatus::ALIVE) {
            return &unit;
        }
    }
    return nullptr;
}

int Army::find_summon_id(int i) {
    for(; i < 5; i++) {
        if(units[i].status == UnitStatus::SUMMONING) {
            return i;
        }
    }
    return -1;
}

bool Army::is_defeated() {
    for(auto& unit: units) {
        if(unit.status == UnitStatus::ALIVE) {
            return false;
        }
    }
    return true;
}
