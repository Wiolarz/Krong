#ifndef BATTLE_MCTS_HPP
#define BATTLE_MCTS_HPP

#ifdef WIN32
#include "windows.h"
#endif

#include "battle_manager_fast.hpp"
#include <unordered_map>

#include "godot_cpp/core/object.hpp"


#define DEFINE_MCTS_PARAMETER(type, name, unset_value) \
    type name = unset_value; \
    inline type get_##name () const {return name;} \
    inline void set_##name (const type new_##name) {name = new_##name;} 

#define BIND_MCTS_PARAMETER(variant, name) \
    ClassDB::bind_method(D_METHOD("set_" #name, "new_" #name), &BattleMCTSManager::set_##name); \
    ClassDB::bind_method(D_METHOD("get_" #name), &BattleMCTSManager::get_##name); \
    ADD_PROPERTY(PropertyInfo(variant, #name), "set_" #name, "get_" #name); 


class BattleMCTSManager;

class BattleMCTSNode {
    BattleMCTSManager* _manager = nullptr;
    BattleMCTSNode* _parent = nullptr;
    std::unordered_map<Move, BattleMCTSNode> _children{};
    BattleManagerFastCpp _bm;
    Move _move;

    unsigned _mcts_iterations = 0;
    float _reward = 0.0f;
    float _visits = 0.0f;
    unsigned _draws = 0;
    unsigned _wins = 0;
    unsigned _loses = 0;

    friend class BattleMCTSManager;

public:
    BattleMCTSNode(BattleManagerFastCpp bm, BattleMCTSManager* manager, BattleMCTSNode* parent, Move _move);
    ~BattleMCTSNode() = default;

    float uct() const;
    bool is_explored();

    void iterate(int iterations);

    /// Select the currently best child. May return nullptr as the second return value
    std::pair<Move, BattleMCTSNode*> select();
    /// Find a new child node
    void expand();
    /// Simulate a number of complete playouts in parallel
    BattleResult simulate(int max_sim_iterations, int simulations);
    /// Backpropagate the result
    void backpropagate(BattleResult& result, int new_visits);
};


class BattleMCTSManager : public Node {
    GDCLASS(BattleMCTSManager, Node);

    DEFINE_MCTS_PARAMETER(int, max_sim_iterations, -1);
    DEFINE_MCTS_PARAMETER(float, heuristic_probability, -1);
    DEFINE_MCTS_PARAMETER(float, heuristic_prior_reward_per_iteration, -1);
    DEFINE_MCTS_PARAMETER(int, max_playouts_per_visit, -1);
    DEFINE_MCTS_PARAMETER(bool, debug_bmfast_internals, false);
    DEFINE_MCTS_PARAMETER(bool, debug_print_move_lists, false);
    DEFINE_MCTS_PARAMETER(int, debug_max_saved_fail_replays, -1);

    // i wanted it to not be a pointer, but c++ was stronger
    BattleMCTSNode* root = nullptr;
    int army_team;
    int army_id;
    godot::Array error_playouts;


    friend BattleResult _simulate_thread(BattleManagerFastCpp bmnew, BattleMCTSManager& mcts, const BattleMCTSNode& node);
    friend class BattleMCTSNode;
    
protected:
    static void _bind_methods();

public:
    BattleMCTSManager() = default;
    virtual ~BattleMCTSManager() override;

    void set_root(BattleManagerFastCpp* bm);

    void iterate(int iterations = 1);

    /// Get the optimal move. Return zero unit/position on fail. 
    /// The 'reward_per_visit_dither' parameter is described in ai_battle_bot_mcts.gd
    Move get_optimal_move(float reward_per_visit_dither);
    godot::Array get_optimal_move_gd(float reward_per_visit_dither);

    /// Add an error playout, based on a node and a list of extra moves from a playout
    void add_error_playout(const BattleMCTSNode& node, std::vector<Move> extra_moves);
    
    /// Return an array of arrays of moves (as LibSpear tuples) of playouts that encountered internal errors
    godot::Array get_error_replays();

    void print_move_list();

    inline bool should_save_replays() {
        return error_playouts.size() < debug_max_saved_fail_replays;
    }
};



#endif
