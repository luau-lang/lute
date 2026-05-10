add_library(Lute.Net STATIC)

target_sources(Lute.Net PRIVATE
    include/lute/net.h

    src/client.cpp
    src/net.cpp
    src/system_ca.cpp
    src/system_ca.h
    src/wsclient.cpp
    src/wscommon.cpp
    src/wscommon.h
    src/server.cpp
)

target_compile_features(Lute.Net PUBLIC cxx_std_17)
target_include_directories(Lute.Net PUBLIC "include" ${LIBUV_INCLUDE_DIR} ${UWEBSOCKETS_INCLUDE_DIR})
target_link_libraries(Lute.Net PRIVATE Lute.Common Lute.Runtime Luau.VM uv_a libcurl uWS zlibstatic)
target_compile_options(Lute.Net PRIVATE ${LUTE_OPTIONS})
