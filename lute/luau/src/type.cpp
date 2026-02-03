#include "lute/type.h"

#include "Luau/Type.h"
#include "Luau/TypeFwd.h"
#include "Luau/VisitType.h"

#include "lua.h"

namespace Luau
{

// Serializer for runtime types, modeled after AstSerialize but for TypeId/TypePackId
struct TypeSerialize final : public Luau::TypeVisitor
{
    lua_State* L;

    explicit TypeSerialize(lua_State* L)
        : Luau::TypeVisitor{"TypeSerialize", /*skipBoundTypes=*/false}
        , L(L)
    {
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
        lua_checkstack(L, 2); // 1 for key + 1 for value table

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
        lua_checkstack(L, 1); // 1 for properties table
        lua_createtable(L, 0, props.size());

        for (const auto& [name, prop] : props)
            pushProperty(name, prop);

        lua_setfield(L, -2, "properties");
    }

    // Luau primitive type
    // tag: "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string" | "buffer" | "thread" | "singleton" | "negation" | "union" | "intersection" | "table" | "function" | "extern" | "generic"
    void serialize(TypeId ty, const PrimitiveType& ptv)
    {
        lua_checkstack(L, 2); // 1 for table + 1 for space to push/set remaining fields
        lua_createtable(L, 0, 1);

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
            lua_error(L);
        }

        pushTag(tag);
    }

    void serialize(TypeId ty, const AnyType& atv)
    {
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 1);

        pushTag("any");
    }

    void serialize(TypeId ty, const UnknownType& utv)
    {
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 1);

        pushTag("unknown");
    }

    void serialize(TypeId ty, const NeverType& ntv)
    {
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 1);

        pushTag("never");
    }

    // Luau singleton type:
    // value: string | boolean | nil
    void serialize(TypeId ty, const SingletonType& stv)
    {
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 2);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 2);

        pushTag("negation");

        traverse(ntv.ty);
        lua_setfield(L, -2, "inner");
    }

    // Luau union type:
    // components: { type }
    void serialize(TypeId ty, const UnionType& utv)
    {
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 2);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 2);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 3);

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
        lua_checkstack(L, 2); // 1 for table + 1 for space to push/set remaining fields
        lua_createtable(L, 0, 5);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 3);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 3);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 4);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 2);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 2);

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
        lua_checkstack(L, 2);
        lua_createtable(L, 0, 3);
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
