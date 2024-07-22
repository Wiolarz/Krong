#include "fast_battle_manager.hpp"
#include "battle_mcts.hpp"
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

void libspear_initialize(ModuleInitializationLevel level) {
    if(level != godot::MODULE_INITIALIZATION_LEVEL_SCENE)
        return;

    ClassDB::register_class<BattleMCTSManager>();
    ClassDB::register_class<BattleManagerFastCpp>();
    ClassDB::register_class<TileGridFastCpp>();
}

void libspear_terminate(ModuleInitializationLevel level) {
    if(level != godot::MODULE_INITIALIZATION_LEVEL_SCENE)
        return;
}

extern "C" {
    GDExtensionBool GDE_EXPORT libspear_init(
            GDExtensionInterfaceGetProcAddress p_get_proc_address, 
            GDExtensionClassLibraryPtr p_library, 
            GDExtensionInitialization *r_initialization
        ) 
    {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
        init_obj.register_initializer(libspear_initialize);
        init_obj.register_terminator(libspear_terminate);
        
        return init_obj.init();
    }
}
