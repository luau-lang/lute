#include "lute/type.h"

#include "Luau/Type.h"
#include "Luau/TypeFwd.h"
#include "Luau/VisitType.h"

#include "lua.h"

namespace Luau
{

// Serializer for runtime types, modeled after AstSerialize but for TypeId/TypePackId
struct TypeSerialize : public Luau::TypeVisitor
{
    lua_State* L;
    const char* tag;

    explicit TypeSerialize(lua_State* L)
        : Luau::TypeVisitor{"TypeSerialize", /*skipBoundTypes=*/false}
        , L(L)
    {
    }

    // Helper to push the "tag" field
    void pushTag(const char* tag)
    {
        lua_pushstring(L, tag);
        lua_setfield(L, -2, "tag");
    }

    // Helper to set the "properties" field for table and extern types
    void setPropertiesFields(std::map<Name, Property> props)
    {
        lua_createtable(L, 0, props.size());
        for (const auto& [name, prop] : props)
        {
            // Create singleton type for the property name
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, 2);
            pushTag("singleton");
            lua_pushstring(L, name.c_str());
            lua_setfield(L, -2, "value");

            // Create property value table with read/write types
            lua_createtable(L, 0, 2);
            if (prop.readTy)
            {
                traverse(*prop.readTy);
                lua_setfield(L, -2, "read");
            }
            else
            {
                lua_pushnil(L);
                lua_setfield(L, -2, "read");
            }

            if (prop.writeTy)
            {
                traverse(*prop.writeTy);
                lua_setfield(L, -2, "write");
            }
            else
            {
                lua_pushnil(L);
                lua_setfield(L, -2, "write");
            }

            lua_settable(L, -3);
        }
        lua_setfield(L, -2, "properties");
    }

    // Luau type
    // tag: "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string" | "buffer" | "thread" | "singleton" | "negation" | "union" | "intersection" | "table" | "function" | "extern" | "generic"
    void serialize(TypeId ty, const PrimitiveType& ptv)
    {
        lua_rawcheckstack(L, 2);
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
            LUAU_UNREACHABLE();
        }

        pushTag(tag);
    }

    void serialize(TypeId ty, const AnyType& atv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 1);

        pushTag("any");
    }

    void serialize(TypeId ty, const UnknownType& utv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 1);

        pushTag("unknown");
    }

    void serialize(TypeId ty, const NeverType& ntv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 1);

        pushTag("never");
    }

    // Luau singleton type:
    // value: string | boolean | nil
    void serialize(TypeId ty, const SingletonType& stv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 2);

        pushTag("singleton");

        if (auto boolSingleton = get<BooleanSingleton>(&stv))
        {
            lua_pushboolean(L, boolSingleton->value);
            lua_setfield(L, -2, "value");
        }
        else if (auto strSingleton = get<StringSingleton>(&stv))
        {
            lua_pushstring(L, strSingleton->value.c_str());
            lua_setfield(L, -2, "value");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "value");
        }     
    }

    // Luau negation type:
    // inner: type
    void serialize(TypeId ty, const NegationType& ntv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 2);

        pushTag("negation");

        traverse(ntv.ty);
        lua_setfield(L, -2, "inner");
    }

    // Luau union type:
    // components: { type }
    void serialize(TypeId ty, const UnionType& utv)
    {
        lua_rawcheckstack(L, 2);
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
        lua_rawcheckstack(L, 2);
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
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 3);

        pushTag("generic");

        if (!gtv.name.empty())
        {
            lua_pushstring(L, gtv.name.c_str());
            lua_setfield(L, -2, "name");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "name");
        }

        lua_pushboolean(L, false); // GenericType is not a pack
        lua_setfield(L, -2, "ispack");
    }

    // Luau function type:
    // parameters: { head: {type}?, tail: type? },
    // returns: { head: {type}?, tail: type? },
    // generics: {type},
    void serialize(TypeId ty, const FunctionType& ftv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 4);

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
        lua_setfield(L, -2, "generics"); // do we need to serialize genericpacks?
    }

    // Luau table type:
    // properties: { [type]: { read: type?, write: type? } },
    // indexer: { index: type, readresult: type, writeresult: type }?,
    // readindexer: { (self: type) -> { index: type, result: type } }?,
    // writeindexer: { (self: type) -> { index: type, result: type } }?,
    void serialize(TypeId ty, const TableType& ttv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 4);

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

            traverse(ttv.indexer->indexResultType);
            lua_setfield(L, -2, "readresult");

            traverse(ttv.indexer->indexResultType);
            lua_setfield(L, -2, "writeresult");

            lua_setfield(L, -2, "indexer");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "indexer");
        }
    }

    // Luau metatable type:
    // metatable: type?
    void serialize(TypeId ty, const MetatableType& mtv)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 2);

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
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 3);

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
        {
            traverse(*etv.parent);
            lua_setfield(L, -2, "parent");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "parent");
        }

        // Metatable
        if (etv.metatable)
        {
            traverse(*etv.metatable);
            lua_setfield(L, -2, "metatable"); 
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "metatable");
        }
    }

    // Luau TypePack is { head: {type}?, tail: type? }
    void serialize(TypePackId tp, const TypePack& pack)
    {
        lua_rawcheckstack(L, 2);
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
            lua_setfield(L, -2, "head");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "head");
        }

        // Tail
        if (pack.tail)
        {
            traverse(*pack.tail);
            lua_setfield(L, -2, "tail");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "tail");
        }
    }

    // Luau VariadicTypePack is { head: nil, tail: type }
    void serialize(TypePackId tp, const VariadicTypePack& vtp)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 2);

        // Head is nil
        lua_pushnil(L);
        lua_setfield(L, -2, "head");

        // Tail is the type
        traverse(vtp.ty);
        lua_setfield(L, -2, "tail");
    }

    // Luau GenericTypePack is { head: nil, tail: generic type with ispack=true }
    void serialize(TypePackId tp, const GenericTypePack& gtp)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, 3);

        // Head is nil
        lua_pushnil(L);
        lua_setfield(L, -2, "head");

        // Tail is generic type
        lua_createtable(L, 0, 3);
        lua_pushstring(L, "generic");
        lua_setfield(L, -2, "tag");
        if (!gtp.name.empty())
        {
            lua_pushstring(L, gtp.name.c_str());
            lua_setfield(L, -2, "name");
        }
        lua_pushboolean(L, true); // ispack = true for generic type packs
        lua_setfield(L, -2, "ispack");
        lua_setfield(L, -2, "tail");
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

void serializeType(TypeId ty, lua_State* L)
{
    TypeSerialize serializer(L);
    serializer.traverse(ty);
}

void serializeTypePack(TypePackId tp, lua_State* L)
{
    TypeSerialize serializer(L);
    serializer.traverse(tp);
}

} // namespace Luau
