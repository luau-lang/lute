add_library(Lute.Keyring STATIC)

target_sources(Lute.Keyring PRIVATE
    include/lute/keyring.h

    src/keyring.cpp
    src/keyring_impl.h
)

if(APPLE)
    target_sources(Lute.Keyring PRIVATE src/keyring_macos.cpp)
    target_link_libraries(Lute.Keyring PRIVATE
        "-framework CoreFoundation"
        "-framework Security"
    )
elseif(WIN32)
    target_sources(Lute.Keyring PRIVATE src/keyring_windows.cpp)
    target_link_libraries(Lute.Keyring PRIVATE advapi32)
else()
    target_sources(Lute.Keyring PRIVATE src/keyring_stub.cpp)
endif()

target_compile_features(Lute.Keyring PUBLIC cxx_std_17)
target_include_directories(Lute.Keyring PUBLIC "include")
target_link_libraries(Lute.Keyring PRIVATE Lute.Common Luau.VM)
target_compile_options(Lute.Keyring PRIVATE ${LUTE_OPTIONS})
