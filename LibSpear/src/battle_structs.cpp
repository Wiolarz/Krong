
#include "battle_structs.hpp"

Unit* Army::get_unit(Position coord) {
    for(auto& unit : units) {
        if(unit.pos == coord && unit.status == UnitStatus::ALIVE) {
            return &unit;
        }
    }
    return nullptr;
}

int Army::find_unit_id_to_summon(int i) {
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
