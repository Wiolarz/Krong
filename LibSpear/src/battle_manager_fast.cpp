#include "battle_manager_fast.hpp"
#include "godot_cpp/core/class_db.hpp"
 
#include <stdlib.h>
#include <random>
#include <csignal>


#define CHECK_UNIT(idx, ret) ERR_FAIL_COND_V_MSG(idx >= MAX_UNITS_IN_ARMY, ret, std::format("BMFast - invalid unit id {}", idx).c_str())
#define CHECK_ARMY(idx, ret) ERR_FAIL_COND_V_MSG(idx >= MAX_ARMIES, ret, std::format("BMFast - invalid army id {}", idx).c_str())

void BattleManagerFastCpp::finish_initialization() {
    if(_state == BattleState::INITIALIZING) {
        _state = BattleState::SUMMONING;
        for(int i = 0; i < _armies.size(); i++) {
            _armies[i].id = i;
            _armies[i].mana_points = 1;

            for(auto& unit: _armies[i].units) {
                if(unit.status != UnitStatus::DEAD) {
                    _result.total_scores[i] += unit.score;
                    _result.max_scores[i]   += unit.score;
                    _armies[i].mana_points += unit.mana;
                }
            }
        }

        _unit_cache.update_armies(_armies);
        _update_mana();
    }
    else {
        WARN_PRINT("BMFast already initialized");
    }
}

BattleResult BattleManagerFastCpp::play_move(Move move) {
    auto ret = _play_move(move.unit, Vector2i(move.pos.x, move.pos.y), move.spell_id);
    return ret;
}

int BattleManagerFastCpp::play_move_gd(godot::Array libspear_tuple) {
    auto ret = play_move(Move(libspear_tuple));
    return ret.winner_team;
}

int BattleManagerFastCpp::play_moves(godot::Array libspear_tuples) {
    for(int i = 0; i < libspear_tuples.size(); i++) {
        play_move_gd(libspear_tuples[i]);
    }
    return _result.winner_team;
}

BattleResult BattleManagerFastCpp::_play_move(unsigned unit_id, Vector2i pos, int8_t spell_id) {
    _moves_dirty = true;
    _heuristic_moves_dirty = true;

    _result.winner_team = -1;
    _result.score_gained.fill(0);
    _result.score_lost.fill(0);

    _previous_army = _current_army;

    ERR_FAIL_COND_V_MSG(_state == BattleState::INITIALIZING, _result, "BMFast - Please call finish_initialization() before playing a move");
    CHECK_UNIT(unit_id, _result);
    
    UnitID uid = UnitID(_current_army, unit_id);
    auto& unit = _armies[_current_army].units[unit_id];

    if(_state == BattleState::SUMMONING) {
        if(unit.status != UnitStatus::SUMMONING) {
            WARN_PRINT("BMFast - unit is not in summoning state\n");
            return _result;
        }

        if(_tiles->get_tile(pos).get_spawning_army() != _current_army) {
            WARN_PRINT("BMFast - target spawn does not belong to current army, aborting\n");
            return _result;
        }

        _move_unit(uid, pos);
        unit.rotation = _tiles->get_tile(pos).get_spawn_rotation();
        unit.status = UnitStatus::ALIVE;

        bool end_summon = true;
        for(int i = (_current_army+1) % _armies.size(); i != _current_army; i = (i+1)%_armies.size()) {
            if(_armies[i].find_unit_id_to_summon() != -1) {
                _current_army = i;
                end_summon = false;
                break;
            }
        }

        if(end_summon) {
            _current_army = 0;
            _state = BattleState::ONGOING;
        }
    }
    else if(_state == BattleState::ONGOING) {
        if(spell_id == Move::NO_SPELL) {
            auto rot_new = get_rotation(unit.pos, pos);
            auto old_pos = unit.pos;

            if(_tiles->get_tile(pos).is_pit()) {
                pos = pos + Vector2i(DIRECTIONS[rot_new].x, DIRECTIONS[rot_new].y);
            }

            if(rot_new == 6) {
                WARN_PRINT("BMFast - target position is not a neighbor\n");
                return _result;
            }

            unit.rotation = rot_new;
            _process_unit(uid, true);
            
            if(unit.status == UnitStatus::ALIVE && unit.pos == old_pos) {
                _move_unit(uid, pos);
                _process_unit(uid, true);
            }
        }
        else {
            _process_spell(uid, spell_id, pos);
        }

        _next_army();

        if(_previous_army > _current_army) {
            _armies[_cyclone_target].cyclone_timer--;
            if(_armies[_cyclone_target].cyclone_timer == 0) {
                _current_army = _cyclone_target;
                _state = BattleState::SACRIFICE;
            }
        }
    }
    else if(_state == BattleState::SACRIFICE) {
        auto& unit = _armies[_current_army].units[unit_id];
        if(unit.status != UnitStatus::ALIVE) {
            WARN_PRINT("BMFast - invalid sacrifice\n");
            return _result;
        }
        
        auto uid = UnitID(_current_army, unit_id);
        _kill_unit(uid, NO_UNIT);

        _next_army();
        _state = BattleState::ONGOING;
    }
    else {
        WARN_PRINT("BMFast - battle already ended, did not expect that\n");
        return _result;
    }

    _result.winner_team = get_winner_team();

    // Test whether all cache updates are correct
    if(_debug_internals) {
        if(!_unit_cache.self_test(_armies)) {
            _result.error = true;
        }
    }

    return _result;
}


void BattleManagerFastCpp::_process_unit(UnitID unit_id, bool process_kills) {
    auto [unit, army] = _get_unit(unit_id);

    for(int side = 0; side < 6; side++) {
        auto pos = unit->pos + DIRECTIONS[side];
        auto neighbor_id = _unit_cache.get(pos);
        auto [neighbor, enemy_army] = _get_unit(neighbor_id);

        if(!neighbor || !enemy_army || neighbor->status != UnitStatus::ALIVE || enemy_army->team == army->team) {
            continue;
        }

        auto unit_symbol = unit->symbol_when_rotated(side);
        auto neighbor_symbol = neighbor->symbol_when_rotated(flip(side));

        // counter/spear
        if(unit_symbol.dies_to(neighbor_symbol, false)) {
            _kill_unit(unit_id, neighbor_id);
            return;
        }
    }
    
    if(!process_kills) {
        return;
    }

    for(int side = 0; side < 6; side++) {
        auto pos = unit->pos + DIRECTIONS[side];
        auto neighbor_id = _unit_cache.get(pos);
        auto [neighbor, enemy_army] = _get_unit(neighbor_id);

        if(!neighbor || !enemy_army || neighbor->status != UnitStatus::ALIVE || enemy_army->team == army->team) {
            continue;
        }

        auto unit_symbol = unit->symbol_when_rotated(side);
        auto neighbor_symbol = neighbor->symbol_when_rotated(flip(side));
    
        if(neighbor_symbol.dies_to(unit_symbol, true)) {
            _kill_unit(neighbor_id, unit_id);
        }

        auto direction = neighbor->pos - unit->pos;
        auto push_force = unit_symbol.get_push_force();
        if(neighbor->status != UnitStatus::DEAD && push_force > 0) {
            _process_push(neighbor_id, unit_id, direction, push_force);
        }
    }

    _process_bow(unit_id);
}

void BattleManagerFastCpp::_process_push(UnitID pushed, UnitID pusher, Position direction, uint8_t max_power) {
    auto [pushed_unit, pushed_army] = _get_unit(pushed);
    auto pos = pushed_unit->pos;

    for(int power = 1; power <= max_power; power++) {
        pos = pos + direction;

        if(_get_unit(pos).first != nullptr || _tiles->get_tile(pos).is_pit()) {
            _kill_unit(pushed, pusher);
            return;
        }
        
        if(!(_tiles->get_tile(pos).is_passable())) {
            if(power == 1 || power < max_power) {
                _kill_unit(pushed, pusher);
                return;
            }
            else {
                pos = pos - direction;
                break;
            }
        }
    }

    _move_unit(pushed, pos);
    _process_unit(pushed, false);
}

void BattleManagerFastCpp::_process_bow(UnitID unit_id) {
    auto [unit, army] = _get_unit(unit_id);

    for(int i = 0; i < 6; i++) {
        auto symbol = unit->symbol_when_rotated(i);
        if(symbol.get_bow_force() == 0) {
            continue;
        }

        auto iter = DIRECTIONS[i];
        auto pos = unit->pos + iter;

        for(int range = 1; range <= symbol.get_reach(); range++) {
            auto other_id = _unit_cache.get(pos);
            auto [other, other_army] = _get_unit(other_id);

            if(!other && !other_army) {
                pos = pos + iter;
                continue;
            }

            if(other_army->team == army->team) {
                break;
            }

            if(other != nullptr && other->symbol_when_rotated(flip(i)).dies_to(symbol, true)) {
                _kill_unit(other_id, unit_id);
                break;
            }

            if(_tiles->get_tile(pos).is_wall()) {
                break; // Can't shoot past walls, but can shoot enemies on hills
            }
            
            pos = pos + iter;
        }
    }
}

void BattleManagerFastCpp::_process_spell(UnitID uid, int8_t spell_id, Position target) {
    auto& spell = _spells[spell_id];
    auto uid2 = _unit_cache.get(target);
    auto caster_team = get_army_team(uid.army);

    switch(spell.state) {
        case BattleSpell::State::FIREBALL:
            {
                // const size array - enough to hold target's surroundings
                std::array<UnitID, 7> ally_targets;
                int last_ally_target = 0;

                if(uid2 != NO_UNIT) {
                    if(get_army_team(uid2.army) == caster_team) {
                        ally_targets[last_ally_target++] = uid2;
                    }
                    else {
                        _kill_unit(uid2, uid);
                    }
                }

                for(auto i : DIRECTIONS) {
                    auto pos = target + i;
                    auto neighbor_id = _unit_cache.get(pos);
                    if(neighbor_id != NO_UNIT) {
                        if(get_army_team(neighbor_id.army) == caster_team) {
                            ally_targets[last_ally_target++] = neighbor_id;
                        }
                        else {
                            _kill_unit(neighbor_id, uid);
                        }
                    }
                }

                if(get_winner_team() < 0) {
                    for(auto ally_id : ally_targets) {
                        if(ally_id == NO_UNIT) {
                            break;
                        }
                        _kill_unit(ally_id, uid);
                    }
                }
            }
            break;
        case BattleSpell::State::TELEPORT:
            _move_unit(uid, target);
            _process_unit(uid, true);
            break;
        case BattleSpell::State::VENGEANCE:
            _get_unit(uid2).first->flags |= Unit::FLAG_VENGEANCE;
            break;
        case BattleSpell::State::MARTYR:
            _get_unit(uid2).first->martyr_id = uid;
            _get_unit(uid).first->martyr_id = uid2;
            break;
        case BattleSpell::State::NONE:
        case BattleSpell::State::SENTINEL:
            WARN_PRINT("Invalid spell id chosen in a move");
            return;
        default:
            WARN_PRINT("Invalid spell type");
            return;
    }
    spell.state = BattleSpell::State::NONE;
    spell.unit = NO_UNIT;
}

void BattleManagerFastCpp::_update_mana() {
    int best_idx = -1, worst_idx = -1;

    for(int i = 0; i < _armies.size(); i++) {
        if(!_armies[i].is_defeated()) {
            worst_idx = i;
            break;
        }
    }

    for(int i = _armies.size()-1; i >= 0; i--) {
        if(!_armies[i].is_defeated()) {
            best_idx = i;
            break;
        }
    }

    for(int i = 0; i < _armies.size(); i++) {
        if(_armies[i].is_defeated()) {
            continue;
        }
        
        if(_armies[i].mana_points > _armies[best_idx].mana_points) {
            best_idx = i;
        }

        if(_armies[i].mana_points < _armies[worst_idx].mana_points) {
            worst_idx = i;
        }
    }

    auto mana_difference = _armies[best_idx].mana_points - _armies[worst_idx].mana_points;
    auto cyclone_mult = (1 > 5-mana_difference) ? 1 : 5-mana_difference;
    auto new_cyclone_counter = (_tiles->get_number_of_mana_wells() * 10) * cyclone_mult;

    if(_tiles->get_number_of_mana_wells()) {
        new_cyclone_counter = 999;
    }
    
    // Cyclone killed a unit - now resetting
    if(_armies[worst_idx].cyclone_timer == 0 || _armies[worst_idx].cyclone_timer > new_cyclone_counter) {
        _armies[worst_idx].cyclone_timer = new_cyclone_counter;
    }

    _cyclone_target = worst_idx;
}

int BattleManagerFastCpp::get_winner_team() {

    if(_state == BattleState::SUMMONING) {
        return -1;
    }

    int last_team_alive = -2;
    int teams_alive = MAX_ARMIES;
    std::array<int, MAX_ARMIES> armies_in_teams_alive = {0,0,0,0};

    for(int i = 0; i < _armies.size(); i++) {
        if(!_armies[i].is_defeated()) {
            armies_in_teams_alive[_armies[i].team] += 1;
        }
    }
    
    for(int i = 0; i < MAX_ARMIES; i++) {
        if(armies_in_teams_alive[i] == 0) {
            teams_alive--;
        }
        else {
            last_team_alive = i;
        }
    }

    if(teams_alive == 0) {
        ERR_PRINT("C++ Assertion failed: no teams alive after battle, should not be possible");
        _state = BattleState::FINISHED;
        _result.error = true;
        return -2;
    }

    if(teams_alive == 1) {
        _state = BattleState::FINISHED;
        return last_team_alive;
    }

    return -1;
}


const std::vector<Move>& BattleManagerFastCpp::get_legal_moves() {
    if(_moves_dirty) {
        _refresh_legal_moves();
        _moves_dirty = false;
    }
    return _moves;
}

const std::vector<Move>& BattleManagerFastCpp::get_heuristically_good_moves() {
    if(_heuristic_moves_dirty) {
        _refresh_heuristically_good_moves();
        _heuristic_moves_dirty = false;
    }
    if(_heuristic_moves.empty()) {
        return get_legal_moves();
    }
    return _heuristic_moves;
}

void BattleManagerFastCpp::_next_army() {
    int limit = _current_army;
    do {
        _current_army = (_current_army+1) % _armies.size();
    } while(_armies[_current_army].is_defeated() && _current_army != limit);
}

void BattleManagerFastCpp::_refresh_legal_moves() {
    _moves.clear();
    _moves.reserve(64);

    auto& army = _armies[_current_army];
    auto& spawns = _tiles->get_spawns(_current_army);

    Move move;

    if(_state == BattleState::SUMMONING) {
        for(auto& spawn : spawns) {
            if(is_occupied(spawn, army, TeamRelation::ALLY)) {
                continue;
            }

            for(int i = 0; i < army.units.size(); i++) {
                if(army.units[i].status != UnitStatus::SUMMONING) {
                    continue;
                }

                move.unit = i;
                move.pos = spawn;
                _moves.push_back(move);
            }
        }
    }
    else if(_state == BattleState::ONGOING) {

        for(int unit_id = 0; unit_id < army.units.size(); unit_id++) {
            auto& unit = army.units[unit_id];
            if(unit.status != UnitStatus::ALIVE) {
                continue;
            }

            for(int side = 0; side < 6; side++) {
                move.unit = unit_id;
                move.pos = unit.pos + DIRECTIONS[side];

                bool going_across_pit = _tiles->get_tile(move.pos).is_pit();
                if(going_across_pit) {
                    if(side == unit.rotation) {
                        move.pos = move.pos + DIRECTIONS[side];
                    }
                    else {
                        continue;
                    }
                }

                auto tile = _tiles->get_tile(move.pos);
                if(!(tile.is_passable()) && !(tile.is_hill() && side == unit.rotation)) {
                    continue;
                }
                
                auto [other_unit, other_army] = _get_unit(move.pos);
                if(other_unit && other_army) {
                    if(other_army->team == army.team || going_across_pit) {
                        continue;
                    }

                    auto neighbor_symbol = other_unit->symbol_when_rotated(flip(side));
                    auto unit_symbol = unit.front_symbol();

                    if(neighbor_symbol.holds_ground_against(unit_symbol, true)) {
                        continue;
                    }
                }

                // Align so that it is consistent with GDScript moves
                if(going_across_pit) {
                    move.pos = move.pos - DIRECTIONS[side];
                }

                _moves.push_back(move);
            }
        }
        _spells_append_moves();
    }
    else if(_state == BattleState::SACRIFICE) {
        move.pos = Position();
        for(int i = 0; i < army.units.size(); i++) {
            if(army.units[i].status == UnitStatus::ALIVE) {
                move.unit = i;
                _moves.push_back(move);
            }
        }
    }
    // else battle finished, no moves possible
}

void BattleManagerFastCpp::_spells_append_moves() {
    for(int i = 0; i < _spells.size(); i++) {
        auto& spell = _spells[i];
        auto [unit, _army] = _get_unit(spell.unit);
        if(spell.unit.army != _current_army) {
            continue;
        }
        if(spell.state == BattleSpell::State::SENTINEL) {
            break;
        }
        if(unit->status == UnitStatus::DEAD) {
            spell.state = BattleSpell::State::NONE;
        }

        switch(spell.state) {
            case BattleSpell::State::TELEPORT:
                _append_moves_line(spell.unit, i, unit->pos, unit->rotation, 1, 3);
                break;
            case BattleSpell::State::FIREBALL:
                _append_moves_all_tiles(spell.unit, i, true);
                break;
            case BattleSpell::State::VENGEANCE:
                _append_moves_unit(spell.unit, i, TeamRelation::ME, true);
                break;
            case BattleSpell::State::MARTYR:
                _append_moves_unit(spell.unit, i, TeamRelation::ME, false);
                break;
            case BattleSpell::State::NONE:
            case BattleSpell::State::SENTINEL:
                break;
        }
    }
}

void BattleManagerFastCpp::_refresh_heuristically_good_moves() {
    _heuristic_moves.clear();
    _heuristic_moves.reserve(64);

    if(_state == BattleState::SUMMONING) {
        _refresh_heuristically_good_summon_moves();
        return;
    }

    auto& army = _armies[_current_army];

    bool killing_move_found = false;

    for(auto& m : get_legal_moves()) {
        auto bm = *this;
        auto result = bm.play_move(m);
        
        // Always win the game if possible and avoid defeats
        if(result.winner_team == army.team) {
            _heuristic_moves.clear();
            _heuristic_moves.push_back(m);
            return;
        }
        else if(result.winner_team != -1) {
            continue;
        }

        // If a move kills an enemy unit, prioritize killing move
        if(result.score_gained[_current_army] > 0) {
            if(!killing_move_found) {
                killing_move_found = true;
                _heuristic_moves.clear();
            }
            _heuristic_moves.push_back(m);
        }

        // If no killing move found, prioritize moves that don't result in a loss
        if(result.score_lost[_current_army] == 0 && !killing_move_found) {
            _heuristic_moves.push_back(m);
        }
    }
}

void BattleManagerFastCpp::_refresh_heuristically_good_summon_moves() {
    auto& army = _armies[_current_army];

    bool enemy_has_unsummoned_bowman = false;
    for(auto& enemy_army : _armies) {
        if(enemy_army.team == army.team) {
            continue;
        }

        for(auto& enemy : enemy_army.units) {
            if(enemy.status == UnitStatus::SUMMONING && enemy.front_symbol().get_bow_force() > 0) {
                enemy_has_unsummoned_bowman = true;
                break;
            }
        }
    }

    // Avoid enemy bowman/find free bowman kills
    for(auto& m : get_legal_moves()) {
        auto& unit = army.units[m.unit];

        bool is_bowman = unit.front_symbol().get_bow_force() > 0;
        // Behavior when the spawn position is empty
        // At this moment assumes every spawn is not safe from bowman - good for now, but TODO?
        
        // Default - empty tile
        int move_score = (enemy_has_unsummoned_bowman || is_bowman) ? 0 : 1;

        for(int enemy_army_id = 0; enemy_army_id < _armies.size(); enemy_army_id++) {
            auto& enemy_army = _armies[enemy_army_id];

            if(enemy_army.team == army.team) {
                continue;
            }

            for(auto& enemy : enemy_army.units) {
                bool can_shoot_enemy      = unit.front_symbol().protects_against(enemy.front_symbol(), true);
                bool enemy_can_shoot_unit = enemy.front_symbol().protects_against(unit.front_symbol(), true);

                if(enemy.status != UnitStatus::ALIVE || !m.pos.is_in_line_with(enemy.pos)) {
                    continue;
                }
                if(enemy_can_shoot_unit && !(can_shoot_enemy && _current_army > enemy_army_id) ) {
                    move_score = -100000;
                    break;
                }
                // otherwise a normal enemy that's a free kill/not a threat
                if(!is_bowman || can_shoot_enemy) {
                    move_score++;
                }
            }

        }
        if(move_score > 0) {
            _heuristic_moves.push_back(m);
        }
    }
}


std::pair<Move, bool> BattleManagerFastCpp::get_random_move(float heuristic_probability) {
    static thread_local std::random_device rand_dev;
    static thread_local std::minstd_rand rand_engine{rand_dev()};
    static thread_local std::uniform_real_distribution heur_dist(0.0f, 1.0f);

    auto heur_chosen = heur_dist(rand_engine) < heuristic_probability;
    auto moves_arr = heur_chosen ? get_heuristically_good_moves() : get_legal_moves();

    ERR_FAIL_COND_V_MSG(moves_arr.size() == 0, std::make_pair(Move{}, false), "BMFast - get_random_move has 0 moves to choose");
    
    std::uniform_int_distribution dist{0, int(moves_arr.size() - 1)};
    auto move = dist(rand_engine);

    return std::make_pair(moves_arr[move], heur_chosen);
}

int BattleManagerFastCpp::get_move_count() {
    return get_legal_moves().size();
}

godot::Array BattleManagerFastCpp::get_legal_moves_gd() {
    auto& moves_arr = get_legal_moves();
    godot::Array arr{};
    
    for(auto& i: moves_arr) {
        arr.push_back(i.as_libspear_tuple());
    }

    return arr;
}

void BattleManagerFastCpp::_append_moves_unit(UnitID uid, int8_t spell_id, TeamRelation relation, bool include_self) {
    auto [_a, army] = _get_unit(uid);
    for(auto& other_army : _armies) {
        if(skip_army(*army, other_army, relation)) {
            continue;
        }

        for(int i = 0; i < other_army.units.size(); i++) {
            auto& unit = other_army.units[i];
            if(unit.status != UnitStatus::ALIVE || (!include_self && i == uid.unit)) {
                continue;
            }

            _moves.emplace_back(uid.unit, unit.pos, spell_id);
        }
    }
}

void BattleManagerFastCpp::_append_moves_all_tiles(UnitID uid, int8_t spell_id, bool include_impassable) {
    auto dims = _tiles->get_dims();
    for(int y = 0; y < dims.y; y++) {
        for(int x = 0; x < dims.x; x++) {
            auto pos = Position(x,y);
            if(include_impassable || (_tiles->get_tile(pos).is_passable() && _unit_cache.get(pos) == NO_UNIT)) {
                _moves.emplace_back(uid.unit, pos, spell_id);
            }
        }
    }
}

void BattleManagerFastCpp::_append_moves_lines(UnitID uid, int8_t spell_id, Position center, int range_min, int range_max) {
    int range_min_real = (range_min >= 1) ? range_min : 1;
    if(range_min == 0 && _tiles->get_tile(center).is_passable()) {
        _moves.emplace_back(uid.unit, center, spell_id);
    }

    for(int dir = 0; dir < 6; dir++) {
        _append_moves_line(uid, spell_id, center, dir, range_min, range_max);
    }
}

void BattleManagerFastCpp::_append_moves_line(UnitID uid, int8_t spell_id, Position center, uint8_t dir, int range_min, int range_max) {
    for(int r = range_min; r <= range_max; r++) {
        Position pos = center + DIRECTIONS[dir] * r;
        
        if(_tiles->get_tile(pos).is_passable() && _unit_cache.get(pos) == NO_UNIT) {
            _moves.emplace_back(uid.unit, pos, spell_id);
        }
    }
}

bool BattleManagerFastCpp::is_occupied(Position pos, const Army& army, TeamRelation relation) const {
    for(auto& other_army : _armies) {
        if(skip_army(army, other_army, relation)) {
            continue;
        }

        for(auto& unit : other_army.units) {
            if(unit.status == UnitStatus::ALIVE && unit.pos == pos) {
                return true;
            }
        }
    }
    return false;
}

void BattleManagerFastCpp::_move_unit(UnitID id, Position pos) {
    auto [unit, army] = _get_unit(id);

    if(unit == nullptr || unit->status == UnitStatus::DEAD) {
        _result.error = true;
        ERR_FAIL_MSG("Trying to move a dead or non-existent unit");
    }

    if(_unit_cache.get(pos) != NO_UNIT) {
        _result.error = true;
        ERR_FAIL_MSG("Unexpected unit during moving - units should be killed manually");
    }

    if(unit->status == UnitStatus::ALIVE) {
        _unit_cache[unit->pos] = NO_UNIT;
    }

    unit->pos = pos;
    _unit_cache[pos] = id;
    if(_tiles->get_tile(pos).is_swamp()) {
        unit->flags |= Unit::FLAG_ON_SWAMP;
    }
    else {
        unit->flags &= ~Unit::FLAG_ON_SWAMP;
    }
}

void BattleManagerFastCpp::_kill_unit(UnitID id, UnitID killer_id) {
    auto [unit, army] = _get_unit(id);
    if(unit == nullptr || unit->status != UnitStatus::ALIVE) {
        _result.error = true;
        ERR_FAIL_COND_MSG(unit == nullptr, "Trying to kill a dead or non-existent unit");
    }
    auto victim_team = army->team;


    if(unit->martyr_id != NO_UNIT) {
        auto [martyr, _] = _get_unit(unit->martyr_id);
        
        if(martyr == nullptr) {
            WARN_PRINT("Invalid martyr id");
            return;
        }

        auto pos = martyr->pos;
        auto martyr_id = unit->martyr_id;

        unit->martyr_id = NO_UNIT;
        martyr->martyr_id = NO_UNIT;
        _kill_unit(martyr_id, killer_id);
        _move_unit(id, pos);
        return;
    }

    _unit_cache[unit->pos] = NO_UNIT;
    unit->status = UnitStatus::DEAD;

    for(int i = 0; i < MAX_ARMIES; i++) {
        if(_armies[i].team == victim_team) {
            _result.score_lost[victim_team] -= unit->score;
            _result.total_scores[victim_team] -= unit->score;
        }
        else {
            _result.score_gained[i] += unit->score;
        }
    }

    if(unit->mana > 0) {
        army->mana_points -= unit->mana;
        _update_mana();
    }

    if(unit->is_vengeance_active() && killer_id != NO_UNIT && get_winner_team() == -1) {
        _kill_unit(killer_id, NO_UNIT);
    }
}


void BattleManagerFastCpp::insert_unit(int army, int idx, Vector2i pos, int rotation, bool is_summoning) {
    CHECK_UNIT(idx,);
    CHECK_ARMY(army,);
    _armies[army].units[idx].pos = pos;
    _armies[army].units[idx].rotation = rotation;
    _armies[army].units[idx].status = is_summoning ? UnitStatus::SUMMONING : UnitStatus::ALIVE;
    if(_tiles->get_tile(pos).is_swamp()) {
        _armies[army].units[idx].flags |= Unit::FLAG_ON_SWAMP;
    }
}

void BattleManagerFastCpp::set_unit_symbol(
        int army, int unit, int side, 
        int attack_strength, int defense_strength, int ranged_reach,
        bool is_counter, int push_force, bool parries
) {
    CHECK_UNIT(unit,);
    CHECK_ARMY(army,);

    uint8_t flags = (Symbol::FLAG_PARRY & parries) 
                  | (Symbol::FLAG_COUNTER_ATTACK & is_counter);

    _armies[army].units[unit].sides[side] = Symbol(attack_strength, defense_strength, push_force, ranged_reach, flags);
}

void BattleManagerFastCpp::set_army_team(int army, int team) {
    CHECK_ARMY(army,);
    _armies[army].team = team;
}

void BattleManagerFastCpp::set_army_cyclone_timer(int army, int timer) {
    CHECK_ARMY(army,);
    _armies[army].cyclone_timer = timer;
}

void BattleManagerFastCpp::set_unit_score(int army, int unit, int score) {
    CHECK_UNIT(unit,);
    CHECK_ARMY(army,);

    _armies[army].units[unit].score = score;
}

void BattleManagerFastCpp::set_unit_mana(int army, int unit, int mana) {
    CHECK_UNIT(unit,);
    CHECK_ARMY(army,);

    _armies[army].units[unit].mana = mana;
}

void BattleManagerFastCpp::set_unit_vengeance(int army, int idx) {
    CHECK_UNIT(idx,);
    CHECK_ARMY(army,);
    
    _armies[army].units[idx].flags |= Unit::FLAG_VENGEANCE;
}

void BattleManagerFastCpp::set_unit_martyr(int army, int idx, int martyr_idx) {
    CHECK_UNIT(idx,);
    CHECK_ARMY(army,);
    
    _armies[army].units[idx].martyr_id = UnitID(army, martyr_idx);
    _armies[army].units[martyr_idx].martyr_id = UnitID(army, idx);
}

void BattleManagerFastCpp::set_current_participant(int army) {
    CHECK_ARMY(army,);
    _current_army = army;
}

void BattleManagerFastCpp::set_tile_grid(TileGridFastCpp* tg) {
    _tiles = tg;
    _unit_cache = CacheGrid(*tg);
}

void BattleManagerFastCpp::force_battle_ongoing() {
    if(_state == BattleState::INITIALIZING) {
        ERR_FAIL_MSG("Must finish_initialization() before calling force_battle_ongoing()");
    }
    _state = BattleState::ONGOING;
}

void BattleManagerFastCpp::force_battle_sacrifice() {
    if(_state == BattleState::INITIALIZING) {
        ERR_FAIL_MSG("Must finish_initialization() before calling force_battle_sacrifice()");
    }
    _state = BattleState::SACRIFICE;
}


godot::Array BattleManagerFastCpp::get_unit_id_on_position(Vector2i pos) const {
    godot::Array ret{};
    auto [army_id, unit_id] = _unit_cache.get(pos);
    ret.push_back(army_id);
    ret.push_back(unit_id);
    return ret;
}

int BattleManagerFastCpp::count_spell(godot::String name) {
    int i = 0;
    for(auto& spell : _spells) {
        if(spell.state == BattleSpell(name, NO_UNIT).state) {
            i++;
        }
    }
    return i;
}

int BattleManagerFastCpp::get_unit_spell_count(int army, int idx) const {
    int i = 0;
    for(auto& spell : _spells) {
        if(spell.state != BattleSpell::State::NONE 
           && spell.state != BattleSpell::State::SENTINEL
           && spell.unit == UnitID(army, idx)
        ) {
                i++;
        }
    }
    return i;
}

void BattleManagerFastCpp::insert_spell(int army, int unit, int spell_id, godot::String str) {
    CHECK_UNIT(unit,);
    CHECK_ARMY(army,);
    ERR_FAIL_COND_MSG(spell_id >= MAX_SPELLS, "Invalid spell id when inserting spell");

    _spells[spell_id] = BattleSpell(str, UnitID(army, unit));
}

void BattleManagerFastCpp::_bind_methods() {
    ClassDB::bind_method(D_METHOD("insert_unit", "army", "index", "position", "rotation", "is_summoning"), &BattleManagerFastCpp::insert_unit);
    ClassDB::bind_method(D_METHOD(
        "set_unit_symbol_cpp", "army", "unit", "side", 
        "attack_strength", "defense_strength", "ranged_reach",
        "is_counter", "push_force", "parries"
 ), &BattleManagerFastCpp::set_unit_symbol);
    ClassDB::bind_method(D_METHOD("set_army_team", "army", "team"), &BattleManagerFastCpp::set_army_team);
    ClassDB::bind_method(D_METHOD("set_unit_score", "army", "unit", "score"), &BattleManagerFastCpp::set_unit_score);
    ClassDB::bind_method(D_METHOD("set_unit_mana", "army", "unit", "mana"), &BattleManagerFastCpp::set_unit_mana);
    ClassDB::bind_method(D_METHOD("set_unit_vengeance", "army", "unit"), &BattleManagerFastCpp::set_unit_vengeance);
    ClassDB::bind_method(D_METHOD("set_unit_martyr", "army", "unit", "martyr_id"), &BattleManagerFastCpp::set_unit_martyr);
    ClassDB::bind_method(D_METHOD("set_army_cyclone_timer", "army", "timer"), &BattleManagerFastCpp::set_army_cyclone_timer);
    ClassDB::bind_method(D_METHOD("set_tile_grid", "tilegrid"), &BattleManagerFastCpp::set_tile_grid);
    ClassDB::bind_method(D_METHOD("set_current_participant", "army"), &BattleManagerFastCpp::set_current_participant);
    ClassDB::bind_method(D_METHOD("insert_spell", "army", "index", "spell"), &BattleManagerFastCpp::insert_spell);
    ClassDB::bind_method(D_METHOD("force_battle_ongoing"), &BattleManagerFastCpp::force_battle_ongoing);
    ClassDB::bind_method(D_METHOD("force_battle_sacrifice"), &BattleManagerFastCpp::force_battle_sacrifice);
    ClassDB::bind_method(D_METHOD("finish_initialization"), &BattleManagerFastCpp::finish_initialization);
    ClassDB::bind_method(D_METHOD("play_move", "libspear_tuple"), &BattleManagerFastCpp::play_move_gd);
    ClassDB::bind_method(D_METHOD("play_moves", "libspear_tuples"), &BattleManagerFastCpp::play_moves);

    ClassDB::bind_method(D_METHOD("get_unit_position", "army", "unit"), &BattleManagerFastCpp::get_unit_position);
    ClassDB::bind_method(D_METHOD("get_unit_rotation", "army", "unit"), &BattleManagerFastCpp::get_unit_rotation);
    ClassDB::bind_method(D_METHOD("is_unit_alive", "army", "unit"), &BattleManagerFastCpp::is_unit_alive);
    ClassDB::bind_method(D_METHOD("is_unit_being_summoned", "army", "unit"), &BattleManagerFastCpp::is_unit_being_summoned);
    ClassDB::bind_method(D_METHOD("get_current_participant"), &BattleManagerFastCpp::get_current_participant);
    ClassDB::bind_method(D_METHOD("get_legal_moves"), &BattleManagerFastCpp::get_legal_moves_gd);
    ClassDB::bind_method(D_METHOD("get_unit_id_on_position", "position"), &BattleManagerFastCpp::get_unit_id_on_position);
    ClassDB::bind_method(D_METHOD("is_in_sacrifice_phase"), &BattleManagerFastCpp::is_in_sacrifice_phase);
    ClassDB::bind_method(D_METHOD("is_in_summoning_phase"), &BattleManagerFastCpp::is_in_summoning_phase);
    ClassDB::bind_method(D_METHOD("get_unit_vengeance", "army", "unit"), &BattleManagerFastCpp::get_unit_vengeance);
    ClassDB::bind_method(D_METHOD("get_unit_martyr_id", "army", "unit"), &BattleManagerFastCpp::get_unit_martyr_id);
    ClassDB::bind_method(D_METHOD("get_unit_martyr_team", "army", "unit"), &BattleManagerFastCpp::get_unit_martyr_team);
    ClassDB::bind_method(D_METHOD("count_spell", "name"), &BattleManagerFastCpp::count_spell);
    ClassDB::bind_method(D_METHOD("get_unit_spell_count", "army", "unit"), &BattleManagerFastCpp::get_unit_spell_count);
    ClassDB::bind_method(D_METHOD("get_max_units_in_army"), &BattleManagerFastCpp::get_max_units_in_army);

    ClassDB::bind_method(D_METHOD("set_debug_internals", "name"), &BattleManagerFastCpp::set_debug_internals);
}
