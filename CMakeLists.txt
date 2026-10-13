cmake_minimum_required(VERSION 3.20)
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" SPARTA_VERSION LIMIT_COUNT 1)
project(Sparta VERSION ${SPARTA_VERSION} LANGUAGES CXX)

# PortableKit brings the recompiler, the runtime and the system layer, and
# defines portablekit_add_game().
add_subdirectory(portablekit)

portablekit_add_game(SpartaNative
    EXTERNAL_KEYS
    PROFILE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    SOURCES host/sparta_profile.cpp host/sparta_keys.cpp)
