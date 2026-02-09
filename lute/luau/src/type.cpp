#include "lute/type.h"

#include "Luau/ToString.h"
#include "Luau/Type.h"
#include "Luau/TypeFwd.h"
#include "Luau/VisitType.h"

#include "lua.h"
#include "lualib.h"

namespace Luau
{

static void checkStack(lua_State* L, int n)
{
    if (!lua_checkstack(L, n))
        luaL_error(L, "stack overflow while serializing type");
}

// Serializer for runtime types, modeled after AstSerialize but for TypeId/TypePackId
struct TypeSerialize final : public Luau::TypeVisitor
{
    lua_State* L;
    int refsTableIndex; // Reference table for handling cyclic & shared type references. Maps TypeId/TypePackId (as lightuserdata) to the corresponding serialized table on the stack.

    explicit TypeSerialize(lua_State* L)
        : Luau::TypeVisitor{"TypeSerialize", /*skipBoundTypes=*/false}
        , L(L)
    {
        // Create the refs table and store a reference to it. This table will be used to track already serialized types to handle cycles and shared references.
        lua_createtable(L, 0, 0);
        refsTableIndex = lua_gettop(L);
    }

    ~TypeSerialize()
    {
        // Pop the refs table from the stack when the serializer is destroyed
        if (refsTableIndex > 0 && lua_gettop(L) >= refsTableIndex)
            lua_remove(L, refsTableIndex);
        else
            luaL_error(L, "TypeSerialize: reference table index corrupted during serialization");
    }

    void cycle(TypeId ty) override
    {
        lua_pushlightuserdata(L, (void*)ty);
        lua_gettable(L, refsTableIndex);

        if (lua_isnil(L, -1))
        {
            luaL_error(L, "TypeSerialize: cycle detected while serializing type, but TypeId %s was not found in refs table", Luau::toString(ty).data());
        }
    }

    void cycle(TypePackId tp) override
    {
        lua_pushlightuserdata(L, (void*)tp);
        lua_gettable(L, refsTableIndex);

        if (lua_isnil(L, -1))
        {
            luaL_error(L, "TypeSerialize: cycle detected while serializing type pack, but TypePackId %s was not found in refs table", Luau::toString(tp).data());
        }
    }

    // Register this type's serialized table in the refs table, using the TypeId as the key.
    // Called after creating the serialized table for a type, but before traversing any child types.
    void registerType(TypeId ty)
    {
        checkStack(L, 3);
        lua_pushlightuserdata(L, (void*)ty); // TypeId pointer as key
        lua_pushvalue(L, -2); // Reference to the serialized type table as value
        lua_rawset(L, refsTableIndex); // refs[ty] = serializedTable
    }

    // Similar to registerType but for TypePackId
    void registerTypePack(TypePackId tp)
    {
        checkStack(L, 3);
        lua_pushlightuserdata(L, (void*)tp);
        lua_pushvalue(L, -2);
        lua_rawset(L, refsTableIndex);
    }

    // Helper to push the "tag" field that every Luau type has
    void pushTag(const char* tag)
    {
        lua_pushstring(L, tag);
        lua_setfield(L, -2, "tag");
    }

    // Helper to push a Name, Property pair into the properties table
    void pushProperty(const std::string& name, const Property& prop)
    {
        checkStack(L, 3); // 1 for key + 1 for value table + 1 for traverse/nil

        // push the Name string as the key for the property
        lua_pushstring(L, name.c_str());

        // Create property value table with read/write types
        lua_createtable(L, 0, 2);
        if (prop.readTy)
            traverse(*prop.readTy);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "read");

        if (prop.writeTy)
            traverse(*prop.writeTy);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "write");

        lua_settable(L, -3);
    }

    // Helper to set the "properties" field for table and extern types
    void setPropertiesFields(const std::map<Name, Property>& props)
    {
        checkStack(L, 1); // 1 for properties table
        lua_createtable(L, 0, props.size());

        for (const auto& [name, prop] : props)
            pushProperty(name, prop);

        lua_setfield(L, -2, "properties");
    }

    // Luau primitive type
    // tag: "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string" | "buffer" | "thread" | "singleton" | "negation" | "union" | "intersection" | "table" | "function" | "extern" | "generic"
    void serialize(TypeId ty, const PrimitiveType& ptv)
    {
        checkStack(L, 2); // 1 for table + 1 for space to push/set remaining fields
        lua_createtable(L, 0, 1);
        registerType(ty);

        const char* tag = nullptr;
        switch (ptv.type)
        {
        case PrimitiveType::NilType:
            tag = "nil";
            break;
        case PrimitiveType::Boolean:
            tag = "boolean";
            break;
        case PrimitiveType::Number:
            tag = "number";
            break;
        case PrimitiveType::String:
            tag = "string";
            break;
        case PrimitiveType::Thread:
            tag = "thread";
            break;
        case PrimitiveType::Buffer:
            tag = "buffer";
            break;
        default:
            luaL_error(L, "unexpected primitive type");
        }

        pushTag(tag);
    }

    void serialize(TypeId ty, const AnyType& atv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 1);
        registerType(ty);

        pushTag("any");
    }

    void serialize(TypeId ty, const UnknownType& utv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 1);
        registerType(ty);

        pushTag("unknown");
    }

    void serialize(TypeId ty, const NeverType& ntv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 1);
        registerType(ty);

        pushTag("never");
    }

    // Luau singleton type:
    // value: string | boolean | nil
    void serialize(TypeId ty, const SingletonType& stv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 2);
        registerType(ty);

        pushTag("singleton");

        if (auto boolSingleton = get<BooleanSingleton>(&stv))
            lua_pushboolean(L, boolSingleton->value);
        else if (auto strSingleton = get<StringSingleton>(&stv))
            lua_pushstring(L, strSingleton->value.c_str());
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "value");
    }

    // Luau negation type:
    // inner: type
    void serialize(TypeId ty, const NegationType& ntv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 2);
        registerType(ty);

        pushTag("negation");

        traverse(ntv.ty);
        lua_setfield(L, -2, "inner");
    }

    // Luau union type:
    // components: { type }
    void serialize(TypeId ty, const UnionType& utv)
    {
        checkStack(L, 3); // 1 for table + 1 for components table + 1 for traverse
        lua_createtable(L, 0, 2);
        registerType(ty);

        pushTag("union");

        lua_createtable(L, utv.options.size(), 0);
        for (size_t i = 0; i < utv.options.size(); i++)
        {
            traverse(utv.options[i]);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "components");
    }

    // Luau intersection type:
    // components: { type }
    void serialize(TypeId ty, const IntersectionType& itv)
    {
        checkStack(L, 3); // 1 for table + 1 for components table + 1 for traverse
        lua_createtable(L, 0, 2);
        registerType(ty);

        pushTag("intersection");

        lua_createtable(L, itv.parts.size(), 0);
        for (size_t i = 0; i < itv.parts.size(); i++)
        {
            traverse(itv.parts[i]);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "components");
    }

    // Luau generic type:
    // name: string?
    // ispack: boolean
    void serialize(TypeId ty, const GenericType& gtv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 3);
        registerType(ty);

        pushTag("generic");

        if (!gtv.name.empty())
            lua_pushstring(L, gtv.name.c_str());
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "name");

        lua_pushboolean(L, false); // GenericType is not a pack
        lua_setfield(L, -2, "ispack");
    }

    // Luau function type:
    // parameters: { head: {type}?, tail: type? },
    // returns: { head: {type}?, tail: type? },
    // generics: {type},
    // genericpacks: {typepack}
    void serialize(TypeId ty, const FunctionType& ftv)
    {
        checkStack(L, 3); // max 1 for table + 1 for subtable + 1 for traverse
        lua_createtable(L, 0, 5);
        registerType(ty);

        pushTag("function");

        // Parameters
        traverse(ftv.argTypes);
        lua_setfield(L, -2, "parameters");

        // Returns
        traverse(ftv.retTypes);
        lua_setfield(L, -2, "returns");

        // Generics
        lua_createtable(L, ftv.generics.size(), 0);
        for (size_t i = 0; i < ftv.generics.size(); i++)
        {
            traverse(ftv.generics[i]);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "generics");

        // Generic packs
        lua_createtable(L, ftv.genericPacks.size(), 0);
        for (size_t i = 0; i < ftv.genericPacks.size(); i++)
        {
            traverse(ftv.genericPacks[i]);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "genericpacks");
    }

    // Luau table type:
    // properties: { string: { read: type?, write: type? } },
    // indexer: { index: type, readresult: type, writeresult: type }?,
    // [TODO] readindexer: { index: type, result: type } }?,
    // [TODO] writeindexer: { index: type, result: type } }?,
    void serialize(TypeId ty, const TableType& ttv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 3);
        registerType(ty);

        pushTag("table");

        // Properties
        if (!ttv.props.empty())
        {
            setPropertiesFields(ttv.props);
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "properties");
        }

        // Indexer
        if (ttv.indexer)
        {
            lua_createtable(L, 0, 3);
            traverse(ttv.indexer->indexType);
            lua_setfield(L, -2, "index");

            lua_setfield(L, -2, "indexer");

            // TODO: implement readindexer and writeindexer from ttv.indexer->indexResultType
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "indexer");
        }
    }

    // Luau metatable type:
    // table: type,
    // metatable: type?
    void serialize(TypeId ty, const MetatableType& mtv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 3);
        registerType(ty);

        pushTag("metatable");

        traverse(mtv.table);
        lua_setfield(L, -2, "table");

        traverse(mtv.metatable);
        lua_setfield(L, -2, "metatable");
    }

    // Luau extern type:
    // 'properties', 'metatable' are shared with table type
    // parent: type?
    void serialize(TypeId ty, const ExternType& etv)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 4);
        registerType(ty);

        pushTag("extern");

        // Properties
        if (!etv.props.empty())
        {
            setPropertiesFields(etv.props);
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "properties");
        }

        // Parent
        if (etv.parent)
            traverse(*etv.parent);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "parent");

        // Metatable
        if (etv.metatable)
            traverse(*etv.metatable);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "metatable"); 
    }

    // Luau TypePack is { head: {type}?, tail: type? }
    void serialize(TypePackId tp, const TypePack& pack)
    {
        checkStack(L, 3); // 1 for root table + 1 for subtable + 1 for traverse
        lua_createtable(L, 0, 2);
        registerTypePack(tp);

        // Head
        if (!pack.head.empty())
        {
            lua_createtable(L, int(pack.head.size()), 0);
            for (size_t i = 0; i < pack.head.size(); i++)
            {
                traverse(pack.head[i]);
                lua_rawseti(L, -2, int(i + 1));
            }
        }
        else
        {
            lua_pushnil(L);
        }
        lua_setfield(L, -2, "head");

        // Tail
        if (pack.tail)
            traverse(*pack.tail);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "tail");
    }

    // Luau VariadicTypePack is { head: nil, tail: type }
    void serialize(TypePackId tp, const VariadicTypePack& vtp)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 2);
        registerTypePack(tp);

        // Head is nil
        lua_pushnil(L);
        lua_setfield(L, -2, "head");

        // Tail is the type
        traverse(vtp.ty);
        lua_setfield(L, -2, "tail");
    }

    // Luau GenericTypePack is
    // name: string?
    // ispack: boolean
    void serialize(TypePackId tp, const GenericTypePack& gtp)
    {
        checkStack(L, 2);
        lua_createtable(L, 0, 3);
        registerTypePack(tp);

        pushTag("generic");

        if (!gtp.name.empty())
            lua_pushstring(L, gtp.name.c_str());
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "name");

        lua_pushboolean(L, true); // GenericTypePack is a pack
        lua_setfield(L, -2, "ispack");
    }

    // Luau Type visitors
    bool visit(TypeId ty, const PrimitiveType& ptv) override
    {
        serialize(ty, ptv);
        return false;
    }

    bool visit(TypeId ty, const AnyType& atv) override
    {
        serialize(ty, atv);
        return false;
    }

    bool visit(TypeId ty, const UnknownType& utv) override
    {
        serialize(ty, utv);
        return false;
    }

    bool visit(TypeId ty, const NeverType& ntv) override
    {
        serialize(ty, ntv);
        return false;
    }
    
    bool visit(TypeId ty, const SingletonType& stv) override
    {
        serialize(ty, stv);
        return false;
    }

    bool visit(TypeId ty, const NegationType& ntv) override
    {
        serialize(ty, ntv);
        return false;
    }

    bool visit(TypeId ty, const UnionType& utv) override
    {
        serialize(ty, utv);
        return false;
    }

    bool visit(TypeId ty, const IntersectionType& itv) override
    {
        serialize(ty, itv);
        return false;
    }

    bool visit(TypeId ty, const GenericType& gtv) override
    {
        serialize(ty, gtv);
        return false;
    }

    bool visit(TypeId ty, const FunctionType& ftv) override
    {
        serialize(ty, ftv);
        return false;
    }

    bool visit(TypeId ty, const TableType& ttv) override
    {
        serialize(ty, ttv);
        return false;
    }

    bool visit(TypeId ty, const MetatableType& mtv) override
    {
        serialize(ty, mtv);
        return false;
    }

    bool visit(TypeId ty, const ExternType& etv) override
    {
        serialize(ty, etv);
        return false;
    }

    // Luau TypePack visitors
    bool visit(TypePackId tp, const TypePack& pack) override
    {
        serialize(tp, pack);
        return false;
    }

    bool visit(TypePackId tp, const VariadicTypePack& vtp) override
    {
        serialize(tp, vtp);
        return false;
    }

    bool visit(TypePackId tp, const GenericTypePack& gtp) override
    {
        serialize(tp, gtp);
        return false;
    }

    // Non-Serialized Types

    bool visit(TypeId ty) override
    {
        // NOTE: `TypeSerialize` should explicitly visit _all_ types and type packs,
        // otherwise it's prone to serializing types that should not be serialized.
        LUAU_ASSERT(false);
        LUAU_UNREACHABLE();
    }

    bool visit(TypeId ty, const BoundType& btv) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize BoundType");
        return false;
    }

    bool visit(TypeId ty, const FreeType& ftv) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize FreeType");
        return false;
    }

    bool visit(TypeId ty, const ErrorType& etv) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize ErrorType");
        return false;
    }

    bool visit(TypeId ty, const NoRefineType& nrt) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize NoRefineType");
        return false;
    }

    bool visit(TypeId ty, const BlockedType& btv) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize BlockedType");
        return false;
    }

    bool visit(TypeId ty, const PendingExpansionType& petv) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize PendingExpansionType");
        return false;
    }

    bool visit(TypeId ty, const TypeFunctionInstanceType& tfit) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize TypeFunctionInstanceType");
        return false;
    }

    bool visit(TypePackId tp) override
    {
        // NOTE: `TypeSerialize` should explicitly visit _all_ types and type packs,
        // otherwise it's prone to serializing type packs that should not be serialized.
        LUAU_ASSERT(false);
        LUAU_UNREACHABLE();
    }

    bool visit(TypePackId tp, const BoundTypePack& btp) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize BoundTypePack");
        return false;
    }

    bool visit(TypePackId tp, const FreeTypePack& ftp) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize FreeTypePack");
        return false;
    }

    bool visit(TypePackId tp, const ErrorTypePack& etp) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize ErrorTypePack");
        return false;
    }

    bool visit(TypePackId tp, const BlockedTypePack& btp) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize BlockedTypePack");
        return false;
    }

    bool visit(TypePackId tp, const TypeFunctionInstanceTypePack& tfitp) override
    {
        luaL_error(L, "TypeSerialize: cannot serialize TypeFunctionInstanceTypePack");
        return false;
    }
};

int serializeType(lua_State* L, TypeId ty)
{
    TypeSerialize serializer(L);
    serializer.traverse(ty);
    lua_setreadonly(L, -1, 1);
    return 1;
}

int serializeTypePack(lua_State* L, TypePackId tp)
{
    TypeSerialize serializer(L);
    serializer.traverse(tp);
    lua_setreadonly(L, -1, 1);
    return 1;
}

} // namespace Luau
