#include "typeserializefixture.h"

#include "doctest.h"

#include "lute/type.h"

#include "Luau/TypeArena.h"
#include "Luau/TypeFunction.h"

using namespace Luau;

static void requireStringField(lua_State* L, const char* field, const char* expected)
{
    lua_getfield(L, -1, field);
    REQUIRE(lua_isstring(L, -1));
    CHECK(std::string(lua_tostring(L, -1)) == expected);
    lua_pop(L, 1);
}

static void requireBoolField(lua_State* L, const char* field, bool expected)
{
    lua_getfield(L, -1, field);
    REQUIRE(lua_isboolean(L, -1));
    CHECK(lua_toboolean(L, -1) == expected);
    lua_pop(L, 1);
}

// Primitive Types

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_nil_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::NilType});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "nil");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_boolean_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Boolean});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "boolean");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_number_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Number});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_string_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::String});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "string");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_thread_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Thread});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "thread");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_buffer_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Buffer});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "buffer");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_any_type")
{
    TypeId ty = arena.addType(AnyType{});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "any");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_unknown_type")
{
    TypeId ty = arena.addType(UnknownType{});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "unknown");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_never_type")
{
    TypeId ty = arena.addType(NeverType{});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "never");
}

// Singleton Types

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_string_singleton")
{
    TypeId ty = arena.addType(SingletonType{StringSingleton{"hello"}});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "singleton");

    lua_getfield(L, -1, "value");
    REQUIRE(lua_isstring(L, -1));
    CHECK(std::string(lua_tostring(L, -1)) == "hello");
    lua_pop(L, 1);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_boolean_singleton")
{
    TypeId ty = arena.addType(SingletonType{BooleanSingleton{true}});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "singleton");

    requireBoolField(L, "value", true);
    lua_pop(L, 1);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_negation_type")
{
    TypeId ty = arena.addType(NegationType{arena.addType(PrimitiveType{PrimitiveType::Number})});

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "negation");

    lua_getfield(L, -1, "inner");
    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
    lua_pop(L, 1);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_union_type")
{
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});
    TypeId stringTy = arena.addType(PrimitiveType{PrimitiveType::String});

    TypeId unionTy = arena.addType(UnionType{{numberTy, stringTy}});

    Luau::serializeType(unionTy, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "union");

    lua_getfield(L, -1, "components");
    REQUIRE(lua_istable(L, -1));

    lua_rawgeti(L, -1, 1);
    requireStringField(L, "tag", "number");
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 2);
    requireStringField(L, "tag", "string");
    lua_pop(L, 1);

    lua_pop(L, 1); // components
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_intersection_type")
{
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});
    TypeId stringTy = arena.addType(PrimitiveType{PrimitiveType::String});

    TypeId intersectionTy = arena.addType(IntersectionType{{numberTy, stringTy}});

    Luau::serializeType(intersectionTy, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "intersection");

    lua_getfield(L, -1, "components");
    REQUIRE(lua_istable(L, -1));

    lua_rawgeti(L, -1, 1);
    requireStringField(L, "tag", "number");
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 2);
    requireStringField(L, "tag", "string");
    lua_pop(L, 1);

    lua_pop(L, 1); // components
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_generic_type")
{
    GenericType gtp;
    gtp.name = "T";

    TypeId ty = arena.addType(gtp);

    Luau::serializeType(ty, L);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "generic");
    requireStringField(L, "name", "T");
    requireBoolField(L, "ispack", false);
    lua_pop(L, 1);
}

// TODO: FunctionType, TableType, MetatableType, ExternType, TypePack, VariadicTypePack, GenericTypePack tests

// Non-Serialized Types

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_free_type_should_error")
{
    TypeId ty = arena.addType(FreeType{TypeLevel{1}, nullptr, nullptr});

    CHECK_THROWS_WITH_AS(Luau::serializeType(ty, L), "TypeSerialize: cannot serialize FreeType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_error_type_should_error")
{
    TypeId ty = arena.addType(ErrorType{});

    CHECK_THROWS_WITH_AS(Luau::serializeType(ty, L), "TypeSerialize: cannot serialize ErrorType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_norefine_type_should_error")
{
    TypeId ty = arena.addType(NoRefineType{});

    CHECK_THROWS_WITH_AS(Luau::serializeType(ty, L), "TypeSerialize: cannot serialize NoRefineType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_blocked_type_should_error")
{
    TypeId ty = arena.addType(BlockedType{});

    CHECK_THROWS_WITH_AS(Luau::serializeType(ty, L), "TypeSerialize: cannot serialize BlockedType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_pending_expansion_type_should_error")
{

    TypeId ty = arena.addType(PendingExpansionType{std::nullopt, AstName("fakename"), {}, {}});

    CHECK_THROWS_WITH_AS(Luau::serializeType(ty, L), "TypeSerialize: cannot serialize PendingExpansionType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_typefunctioninstance_type_should_error")
{
    TypeFunction user{"tf", nullptr};
    TypeFunctionInstanceType tftt{
        NotNull{&user},
        std::vector<TypeId>{}, // Type Function Arguments
        {},
        {AstName{"fakename"}}, // Type Function Name
        {},
    };
    TypeId ty = arena.addType(tftt);

    CHECK_THROWS_WITH_AS(Luau::serializeType(ty, L), "TypeSerialize: cannot serialize TypeFunctionInstanceType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_free_typepack_should_error")
{
    TypeLevel level = TypeLevel{1};
    TypePackId tp = arena.addTypePack(FreeTypePack{level});

    CHECK_THROWS_WITH_AS(Luau::serializeTypePack(tp, L), "TypeSerialize: cannot serialize FreeTypePack", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_error_typepack_should_error")
{
    TypePackId tp = arena.addTypePack(ErrorTypePack{});

    CHECK_THROWS_WITH_AS(Luau::serializeTypePack(tp, L), "TypeSerialize: cannot serialize ErrorTypePack", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_blocked_typepack_should_error")
{
    TypePackId tp = arena.addTypePack(BlockedTypePack{});

    CHECK_THROWS_WITH_AS(Luau::serializeTypePack(tp, L), "TypeSerialize: cannot serialize BlockedTypePack", std::exception);
}
