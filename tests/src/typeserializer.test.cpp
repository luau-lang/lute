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
    lua_pop(L, 1); // string field
}

static void requireBoolField(lua_State* L, const char* field, bool expected)
{
    lua_getfield(L, -1, field);
    REQUIRE(lua_isboolean(L, -1));
    CHECK(lua_toboolean(L, -1) == expected);
    lua_pop(L, 1); // bool field
}

// Primitive Types

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_nil_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::NilType});

    // We need to first ensure we have enough stack space to serialize.
    // The stack size corresponds to the max depth needed (see lute/type.cpp).
    lua_checkstack(L, 2);

    // { tag: "nil" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "nil");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_boolean_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Boolean});

    lua_checkstack(L, 2);

    // { tag: "boolean" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "boolean");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_number_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Number});

    lua_checkstack(L, 2);

    // { tag: "number" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_string_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::String});

    lua_checkstack(L, 2);

    // { tag: "string" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "string");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_thread_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Thread});

    lua_checkstack(L, 2);

    // { tag: "thread" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "thread");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_primitive_buffer_type")
{
    TypeId ty = arena.addType(PrimitiveType{PrimitiveType::Buffer});

    lua_checkstack(L, 2);

    // { tag: "buffer" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "buffer");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_any_type")
{
    TypeId ty = arena.addType(AnyType{});

    lua_checkstack(L, 2);

    // { tag: "any" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "any");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_unknown_type")
{
    TypeId ty = arena.addType(UnknownType{});

    lua_checkstack(L, 2);

    // { tag: "unknown" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "unknown");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_never_type")
{
    TypeId ty = arena.addType(NeverType{});

    lua_checkstack(L, 2);

    // { tag: "never" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "never");
}

// Singleton Types

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_string_singleton")
{
    TypeId ty = arena.addType(SingletonType{StringSingleton{"hello"}});

    lua_checkstack(L, 2);

    // { tag: "singleton", value: "hello" }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "singleton");
    requireStringField(L, "value", "hello");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_boolean_singleton")
{
    TypeId ty = arena.addType(SingletonType{BooleanSingleton{true}});

    lua_checkstack(L, 2);

    // { tag: "singleton", value: true }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "singleton");
    requireBoolField(L, "value", true);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_negation_type")
{
    TypeId ty = arena.addType(NegationType{arena.addType(PrimitiveType{PrimitiveType::Number})});

    lua_checkstack(L, 2);

    // { tag: "negation", inner: { tag: "number" } }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "negation");

    lua_getfield(L, -1, "inner");
    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_union_type")
{
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});
    TypeId stringTy = arena.addType(PrimitiveType{PrimitiveType::String});

    TypeId unionTy = arena.addType(UnionType{{numberTy, stringTy}});

    lua_checkstack(L, 3);

    // { tag: "union", components: { { tag: "number" }, { tag: "string" } } }
    REQUIRE_EQ(Luau::serializeType(L, unionTy), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "union");

    lua_getfield(L, -1, "components");
    REQUIRE(lua_istable(L, -1));

    lua_rawgeti(L, -1, 1);
    requireStringField(L, "tag", "number");
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 2);
    requireStringField(L, "tag", "string");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_intersection_type")
{
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});
    TypeId stringTy = arena.addType(PrimitiveType{PrimitiveType::String});

    TypeId intersectionTy = arena.addType(IntersectionType{{numberTy, stringTy}});

    lua_checkstack(L, 3); // Ensure enough stack for serialization. This would be size 3 

    // { tag: "intersection", components: { { tag: "number" }, { tag: "string" } } }
    REQUIRE_EQ(Luau::serializeType(L, intersectionTy), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "intersection");

    lua_getfield(L, -1, "components");
    REQUIRE(lua_istable(L, -1));

    lua_rawgeti(L, -1, 1);
    requireStringField(L, "tag", "number");
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 2);
    requireStringField(L, "tag", "string");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_generic_type")
{
    GenericType gtp;
    gtp.name = "T";

    TypeId ty = arena.addType(gtp);

    lua_checkstack(L, 2);

    // { tag: "generic", name: "T", ispack: false }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "generic");
    requireStringField(L, "name", "T");
    requireBoolField(L, "ispack", false);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_function_type")
{
    GenericType gtp;
    gtp.name = "T";
    TypeId genericTy = arena.addType(gtp);
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});

    TypePackId argTypes = arena.addTypePack(TypePack{{numberTy}, std::nullopt});
    TypePackId retTypes = arena.addTypePack(TypePack{{}, std::nullopt});

    FunctionType ftv{{genericTy}, {}, argTypes, retTypes};
    TypeId ty = arena.addType(ftv);

    lua_checkstack(L, 3);

    // <T>(number) -> ()
    // { tag: "function", parameters: { head: { { tag: "number" } }, tail: nil }, returns: { head: nil, tail: nil }, generics: { { tag: "generic", name: "T", ispack: false } }, genericpacks: {} }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "function");

    lua_getfield(L, -1, "parameters");
    REQUIRE(lua_istable(L, -1));

    lua_getfield(L, -1, "head");
    REQUIRE(lua_istable(L, -1));
    lua_rawgeti(L, -1, 1);
    requireStringField(L, "tag", "number");
    lua_pop(L, 2); // head[0], head

    lua_getfield(L, -1, "tail");
    REQUIRE(lua_isnil(L, -1));
    lua_pop(L, 2); // tail, parameters

    lua_getfield(L, -1, "returns");
    REQUIRE(lua_istable(L, -1));
    lua_getfield(L, -1, "head");
    REQUIRE(lua_isnil(L, -1)); // no return types
    lua_pop(L, 1); // head
    lua_getfield(L, -1, "tail");
    REQUIRE(lua_isnil(L, -1)); // no return types
    lua_pop(L, 2); // tail, returns

    lua_getfield(L, -1, "generics");
    REQUIRE(lua_istable(L, -1));
    lua_rawgeti(L, -1, 1);
    requireStringField(L, "tag", "generic");
    requireStringField(L, "name", "T");
    requireBoolField(L, "ispack", false);
    lua_pop(L, 2); // generics, function

    lua_getfield(L, -1, "genericpacks");
    REQUIRE(lua_istable(L, -1));
    REQUIRE(lua_objlen(L, -1) == 0); // no generic packs
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_table_type_with_properties")
{
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});
    TypeId stringTy = arena.addType(PrimitiveType{PrimitiveType::String});

    TableType ttv;
    Property prop;
    prop.readTy = numberTy;
    prop.writeTy = stringTy;
    ttv.props["x"] = prop;

    TypeId ty = arena.addType(ttv);

    lua_checkstack(L, 3);

    // { read x: number, write x: string }
    // { tag: "table", properties: { x: { read: { tag: "number" }, write: { tag: "string" } } } }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "table");

    lua_getfield(L, -1, "properties");
    REQUIRE(lua_istable(L, -1));

    lua_getfield(L, -1, "x");
    REQUIRE(lua_istable(L, -1));

    lua_getfield(L, -1, "read");
    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
    lua_pop(L, 1); // read

    lua_getfield(L, -1, "write");
    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "string");
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_table_type_with_nil_property")
{
    TypeId numberTy = arena.addType(PrimitiveType{PrimitiveType::Number});

    TableType ttv;
    Property prop;
    prop.readTy = numberTy;
    prop.writeTy = std::nullopt; // write type is nil
    ttv.props["x"] = prop;

    TypeId ty = arena.addType(ttv);

    lua_checkstack(L, 3);

    // { tag: "table", properties: { x: { read: { tag: "number" }, write: nil } } }
    REQUIRE_EQ(Luau::serializeType(L, ty), 1);

    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "table");

    lua_getfield(L, -1, "properties");
    REQUIRE(lua_istable(L, -1));

    lua_getfield(L, -1, "x");
    REQUIRE(lua_istable(L, -1));

    lua_getfield(L, -1, "read");
    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
    lua_pop(L, 1); // read

    lua_getfield(L, -1, "write");
    REQUIRE(lua_isnil(L, -1)); // write type is nil
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_cyclic_table_type")
{
    // Create a cyclic type: type Node = { value: number, next: Node }
    TypeId nodeType = arena.addType(TableType{});
    TableType* table = getMutable<TableType>(nodeType);
    
    // Add the 'value' property
    TypeId numberType = arena.addType(PrimitiveType{PrimitiveType::Number});
    table->props["value"] = Property::readonly(numberType);
    
    // Add the 'next' property that references itself (creating the cycle)
    table->props["next"] = Property::readonly(nodeType);

    lua_checkstack(L, 3);

    // { tag: "table", properties: { value: { read: { tag: "number" } }, next: { read: <cycle> } } }
    REQUIRE_EQ(Luau::serializeType(L, nodeType), 1);
    
    REQUIRE(lua_istable(L, -1));
    int root = lua_absindex(L, -1);

    requireStringField(L, "tag", "table");
    
    // Check properties field exists
    lua_getfield(L, -1, "properties");
    REQUIRE(lua_istable(L, -1));
    
    // Check 'value' property
    lua_getfield(L, -1, "value");
    REQUIRE(lua_istable(L, -1));
    lua_getfield(L, -1, "read");
    REQUIRE(lua_istable(L, -1));
    requireStringField(L, "tag", "number");
    lua_pop(L, 2); // pop read type and value property
    
    // Check 'next' property - this should be a cyclic reference
    lua_getfield(L, -1, "next");
    REQUIRE(lua_istable(L, -1));
    lua_getfield(L, -1, "read");
    REQUIRE(lua_istable(L, -1));
    
    REQUIRE(lua_equal(L, root, -1)); // The 'next' property's read type should be the same table as the root (cycle)
}

// TODO: MetatableType, ExternType, TypePack, VariadicTypePack, GenericTypePack tests

// Non-Serialized Types

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_free_type_should_error")
{
    TypeId ty = arena.addType(FreeType{TypeLevel{1}, nullptr, nullptr});

    CHECK_THROWS_WITH_AS(Luau::serializeType(L, ty), "TypeSerialize: cannot serialize FreeType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_error_type_should_error")
{
    TypeId ty = arena.addType(ErrorType{});

    CHECK_THROWS_WITH_AS(Luau::serializeType(L, ty), "TypeSerialize: cannot serialize ErrorType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_norefine_type_should_error")
{
    TypeId ty = arena.addType(NoRefineType{});

    CHECK_THROWS_WITH_AS(Luau::serializeType(L, ty), "TypeSerialize: cannot serialize NoRefineType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_blocked_type_should_error")
{
    TypeId ty = arena.addType(BlockedType{});

    CHECK_THROWS_WITH_AS(Luau::serializeType(L, ty), "TypeSerialize: cannot serialize BlockedType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_pending_expansion_type_should_error")
{

    TypeId ty = arena.addType(PendingExpansionType{std::nullopt, AstName("fakename"), {}, {}});

    CHECK_THROWS_WITH_AS(Luau::serializeType(L, ty), "TypeSerialize: cannot serialize PendingExpansionType", std::exception);
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

    CHECK_THROWS_WITH_AS(Luau::serializeType(L, ty), "TypeSerialize: cannot serialize TypeFunctionInstanceType", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_free_typepack_should_error")
{
    TypeLevel level = TypeLevel{1};
    TypePackId tp = arena.addTypePack(FreeTypePack{level});

    CHECK_THROWS_WITH_AS(Luau::serializeTypePack(L, tp), "TypeSerialize: cannot serialize FreeTypePack", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_error_typepack_should_error")
{
    TypePackId tp = arena.addTypePack(ErrorTypePack{});

    CHECK_THROWS_WITH_AS(Luau::serializeTypePack(L, tp), "TypeSerialize: cannot serialize ErrorTypePack", std::exception);
}

TEST_CASE_FIXTURE(TypeSerializeFixture, "serialize_blocked_typepack_should_error")
{
    TypePackId tp = arena.addTypePack(BlockedTypePack{});

    CHECK_THROWS_WITH_AS(Luau::serializeTypePack(L, tp), "TypeSerialize: cannot serialize BlockedTypePack", std::exception);
}
