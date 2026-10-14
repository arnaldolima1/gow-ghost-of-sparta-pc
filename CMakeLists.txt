cmake_minimum_required(VERSION 3.20)
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" SPARTA_VERSION LIMIT_COUNT 1)
# C too: the SDL3 package for Visual Studio test-compiles a .c file to detect
# the target CPU.
project(Sparta VERSION ${SPARTA_VERSION} LANGUAGES C CXX)

# PortableKit brings the recompiler, the runtime and the system layer, and
# defines portablekit_add_game().
add_subdirectory(portablekit)

portablekit_add_game(SpartaNative
    EXTERNAL_KEYS
    PROFILE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    SOURCES host/sparta_profile.cpp host/sparta_keys.cpp)

# The NDK's clang 18 (r27) crashes in its greedy register allocator on this
# unit as --sparse-entries generates it; Apple clang compiles it. The basic
# allocator compiles it, at a small cost to this one unit. If another unit
# crashes the same way after the generator changes, add it here.
if(ANDROID)
    set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/generated/generated_unit_0069.cpp"
        APPEND PROPERTY COMPILE_OPTIONS -mllvm -regalloc=basic)
endif()
