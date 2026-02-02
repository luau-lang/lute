#include "lute/luau.h"

#include "lute/configresolver.h"
#include "lute/moduleresolver.h"
#include "lute/userdatas.h"
#include "lute/type.h"

#include "Luau/Ast.h"
#include "Luau/BuiltinDefinitions.h"
#include "Luau/Compiler.h"
#include "Luau/Frontend.h"
#include "Luau/Location.h"
#include "Luau/NotNull.h"
#include "Luau/ParseOptions.h"
#include "Luau/Parser.h"
#include "Luau/ParseResult.h"
#include "Luau/ToString.h"

#include "lua.h"
#include "lualib.h"

#include <cstddef>
#include <cstring>
#include <iterator>
#include <memory>
#include <string>

namespace luau
{

struct StatResult
{
    std::shared_ptr<Luau::Allocator> allocator;
    std::shared_ptr<Luau::AstNameTable> names;

    Luau::ParseResult parseResult;
};

static StatResult parse(std::string& source)
{
    auto allocator = std::make_shared<Luau::Allocator>();
    auto names = std::make_shared<Luau::AstNameTable>(*allocator);

    Luau::ParseOptions options;
    options.captureComments = true;
    options.allowDeclarationSyntax = false;
    options.storeCstData = true;

    auto parseResult = Luau::Parser::parse(source.data(), source.size(), *names, *allocator, options);

    return StatResult{allocator, names, std::move(parseResult)};
}

struct ExprResult
{
    std::shared_ptr<Luau::Allocator> allocator;
    std::shared_ptr<Luau::AstNameTable> names;

    Luau::ParseNodeResult<Luau::AstExpr> parseResult;
};

static ExprResult parseExpr(std::string& source)
{
    auto allocator = std::make_shared<Luau::Allocator>();
    auto names = std::make_shared<Luau::AstNameTable>(*allocator);

    Luau::ParseOptions options;
    options.captureComments = true;
    options.allowDeclarationSyntax = false;
    options.storeCstData = true;

    auto parseResult = Luau::Parser::parseExpr(source.data(), source.size(), *names, *allocator, options);

    return ExprResult{allocator, names, std::move(parseResult)};
}

static std::vector<size_t> computeLineOffsets(std::string_view content)
{
    std::vector<size_t> result{};
    result.emplace_back(0);

    for (size_t i = 0; i < content.size(); i++)
    {
        auto ch = content[i];
        if (ch == '\r' || ch == '\n')
        {
            if (ch == '\r' && i + 1 < content.size() && content[i + 1] == '\n')
            {
                i++;
            }
            result.push_back(i + 1);
        }
    }
    return result;
}

static std::vector<Luau::Comment> commentsWithinSpan(const std::vector<Luau::Comment> comments, Luau::Location span)
{
    // TODO: O(n), we could probably binary search if there are a lot of comments
    std::vector<Luau::Comment> result;

    for (const auto& comment : comments)
        if (span.encloses(comment.location))
            result.emplace_back(comment);

    return result;
}

struct Trivia
{
    enum TriviaKind
    {
        Whitespace,
        SingleLineComment,
        MultiLineComment,
    };

    TriviaKind kind;
    Luau::Location location;
    std::string_view text;
};

// the userdata version of `Luau::Location` because exposing this as a table was, unfortunately, very impractical
// it happens too much all over the entire AST to do reasonably.
struct Span
{
    uint32_t beginLine;
    uint32_t beginColumn;
    uint32_t endLine;
    uint32_t endColumn;
};

static int createSpan(lua_State* L)
{
    int argumentCount = lua_gettop(L);
    if (argumentCount != 1)
        luaL_error(L, "%s: expected 1 argument, but got %d", kSpanCreateName, argumentCount);

    // read all three of the required fields out of the table
    lua_getfield(L, 1, "beginline");
    lua_getfield(L, 1, "begincolumn");
    lua_getfield(L, 1, "endline");
    lua_getfield(L, 1, "endcolumn");

    double beginline = luaL_checknumber(L, 2);
    double begincolumn = luaL_checknumber(L, 3);
    double endline = luaL_checknumber(L, 4);
    double endcolumn = luaL_checknumber(L, 5);

    Span* span = static_cast<Span*>(lua_newuserdatatagged(L, sizeof(Span), kSpanTag));

    span->beginLine = static_cast<uint32_t>(beginline);
    span->beginColumn = static_cast<uint32_t>(begincolumn);
    span->endLine = static_cast<uint32_t>(endline);
    span->endColumn = static_cast<uint32_t>(endcolumn);

    luaL_getmetatable(L, kSpanType);
    lua_setmetatable(L, -2);

    return 1;
}

static int makeSpanLibrary(lua_State* L)
{
    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, luau::createSpan, "create");
    lua_setfield(L, -2, "create");

    lua_setreadonly(L, -1, 1);

    return 1;
}

static int indexSpan(lua_State* L)
{
    const Span* span = static_cast<Span*>(luaL_checkudata(L, 1, kSpanType));

    const char* fieldName = luaL_checkstring(L, 2);

    if (std::strcmp(fieldName, "beginline") == 0)
    {
        lua_pushnumber(L, span->beginLine);
        return 1;
    }
    else if (std::strcmp(fieldName, "begincolumn") == 0)
    {
        lua_pushnumber(L, span->beginColumn);
        return 1;
    }
    else if (std::strcmp(fieldName, "endline") == 0)
    {
        lua_pushnumber(L, span->endLine);
        return 1;
    }
    else if (std::strcmp(fieldName, "endcolumn") == 0)
    {
        lua_pushnumber(L, span->endColumn);
        return 1;
    }

    return 0;
}

static int ltSpan(lua_State* L)
{
    const Span* lhs = static_cast<Span*>(luaL_checkudata(L, 1, kSpanType));
    const Span* rhs = static_cast<Span*>(luaL_checkudata(L, 2, kSpanType));

    // Compare beginnings, and if they're equal, compare ends
    if (lhs->beginLine < rhs->beginLine || (lhs->beginLine == rhs->beginLine && lhs->beginColumn < rhs->beginColumn))
        lua_pushboolean(L, 1);
    else if (lhs->beginLine == rhs->beginLine && lhs->beginColumn == rhs->beginColumn)
    {
        if (lhs->endLine < rhs->endLine || (lhs->endLine == rhs->endLine && lhs->endColumn < rhs->endColumn))
            lua_pushboolean(L, 1);
        else
            lua_pushboolean(L, 0);
    }
    else
        lua_pushboolean(L, 0);

    return 1;
}

struct AstSerialize : public Luau::AstVisitor
{
    lua_State* L;
    Luau::CstNodeMap cstNodeMap;
    std::string_view source;
    Luau::Position currentPosition{0, 0};
    std::vector<size_t> lineOffsets;
    std::vector<Luau::Comment> commentLocations;

    // absolute index for the table where we're storing locals
    int localTableIndex;
    // reference to previously serialized token
    int lastTokenRef = LUA_NOREF;

    AstSerialize(lua_State* L, std::string_view source, Luau::CstNodeMap cstNodeMap, std::vector<Luau::Comment> commentLocations)
        : L(L)
        , cstNodeMap(std::move(cstNodeMap))
        , source(source)
        , lineOffsets(computeLineOffsets(source))
        , commentLocations(std::move(commentLocations))
    {
        lua_createtable(L, 0, 0);
        localTableIndex = lua_absindex(L, -1);
    }

    template<typename T>
    Luau::NotNull<T> lookupCstNode(Luau::AstNode* astNode)
    {
        const auto cstNode = cstNodeMap.find(astNode);
        LUAU_ASSERT(cstNode);
        return Luau::NotNull{(*cstNode)->as<T>()};
    }

    void advancePosition(std::string_view contents)
    {
        if (contents.empty())
            return;

        size_t index = 0;
        size_t numLines = 0;
        while (true)
        {
            auto newlinePos = contents.find('\n', index);
            if (newlinePos == std::string::npos)
                break;
            numLines++;
            index = newlinePos + 1;
        }

        currentPosition.line += numLines;
        if (numLines > 0)
            currentPosition.column = unsigned(contents.size()) - index;
        else
            currentPosition.column += unsigned(contents.size());
    }

    std::vector<Trivia> extractWhitespace(const Luau::Position& newPos)
    {
        auto beginPosition = currentPosition;

        LUAU_ASSERT(currentPosition < newPos);
        LUAU_ASSERT(currentPosition.line < lineOffsets.size());
        LUAU_ASSERT(newPos.line < lineOffsets.size());
        size_t startOffset = lineOffsets[currentPosition.line] + currentPosition.column;
        size_t endOffset = lineOffsets[newPos.line] + newPos.column;

        std::string_view trivia = source.substr(startOffset, endOffset - startOffset);

        // Tokenize whitespace into smaller parts. Whitespace is separated by `\n` characters
        std::vector<Trivia> result;

        while (!trivia.empty())
        {
            auto index = trivia.find('\n');
            std::string_view part;
            if (index == std::string::npos)
                part = trivia;
            else
            {
                part = trivia.substr(0, index + 1);
                trivia.remove_prefix(index + 1);
            }

            advancePosition(part);
            result.push_back(Trivia{Trivia::Whitespace, Luau::Location{beginPosition, currentPosition}, part});
            beginPosition = currentPosition;

            if (index == std::string::npos)
                break;
        }
        LUAU_ASSERT(currentPosition == newPos);

        return result;
    }

    std::vector<Trivia> extractTrivia(const Luau::Position& newPos)
    {
        LUAU_ASSERT(currentPosition <= newPos);
        if (currentPosition == newPos)
            return {};

        std::vector<Trivia> result;

        const auto comments = commentsWithinSpan(commentLocations, Luau::Location{currentPosition, newPos});
        for (const auto& comment : comments)
        {
            if (currentPosition < comment.location.begin)
            {
                auto whitespace = extractWhitespace(comment.location.begin);
                result.insert(result.end(), whitespace.begin(), whitespace.end());
            }

            LUAU_ASSERT(comment.location.begin.line < lineOffsets.size());
            LUAU_ASSERT(comment.location.end.line < lineOffsets.size());

            size_t startOffset = lineOffsets[comment.location.begin.line] + comment.location.begin.column;
            size_t endOffset = lineOffsets[comment.location.end.line] + comment.location.end.column;

            std::string_view commentText = source.substr(startOffset, endOffset - startOffset);

            // TODO: advancePosition is more of a debug check - we can probably just set currentPosition directly here
            advancePosition(commentText);
            LUAU_ASSERT(currentPosition == comment.location.end);

            // TODO: currently the text includes the `--` / `--[[` characters, should it?
            LUAU_ASSERT(comment.type != Luau::Lexeme::BrokenComment);
            auto kind = comment.type == Luau::Lexeme::Comment ? Trivia::SingleLineComment : Trivia::MultiLineComment;
            result.emplace_back(Trivia{kind, comment.location, commentText});
        }

        if (currentPosition < newPos)
        {
            auto whitespace = extractWhitespace(newPos);
            result.insert(result.end(), whitespace.begin(), whitespace.end());
        }

        LUAU_ASSERT(currentPosition == newPos);

        return result;
    }

    // Splits a list of trivia into trailing trivia for the previous token, and leading trivia for the next token
    // The trailing trivia consists of all trivia up to and including the first '\n' character seen
    static std::pair<std::vector<Trivia>, std::vector<Trivia>> splitTrivia(std::vector<Trivia> trivia)
    {
        size_t i = 0;
        for (i = 0; i < trivia.size(); i++)
        {
            if (trivia[i].kind == Trivia::Whitespace && trivia[i].text.find('\n') != std::string::npos)
                break;
        }

        if (i == trivia.size())
            return {trivia, {}};

        auto middleIter(trivia.begin());
        std::advance(middleIter, i + 1);

        return {std::vector<Trivia>(trivia.begin(), middleIter), std::vector<Trivia>(middleIter, trivia.end())};
    }

    void serialize(Luau::Location location)
    {
        lua_rawcheckstack(L, 2);

        Span* span = static_cast<Span*>(lua_newuserdatatagged(L, sizeof(Span), kSpanTag));

        span->beginLine = location.begin.line + 1;
        span->beginColumn = location.begin.column + 1;
        span->endLine = location.end.line + 1;
        span->endColumn = location.end.column + 1;

        luaL_getmetatable(L, kSpanType);
        lua_setmetatable(L, -2);
    }

    void serialize(Luau::AstName& name)
    {
        lua_rawcheckstack(L, 1);
        lua_pushstring(L, name.value);
    }

    void serialize(Luau::AstLocal* local, bool createToken = true, std::optional<Luau::Position> colonPosition = std::nullopt)
    {
        lua_rawcheckstack(L, 2);

        lua_pushlightuserdata(L, local);
        lua_gettable(L, localTableIndex);

        if (lua_isnil(L, -1))
        {
            lua_pop(L, 1);
            lua_createtable(L, 0, 6);

            lua_pushlstring(L, "local", 5);
            lua_setfield(L, -2, "kind");

            withLocation(local->location);

            // set up reference for this local into the local table
            lua_pushlightuserdata(L, local);
            lua_pushvalue(L, -2);
            lua_settable(L, localTableIndex);

            if (createToken)
            {
                serializeToken(local->location.begin, local->name.value);
                lua_setfield(L, -2, "name");

                if (local->annotation)
                {
                    LUAU_ASSERT(colonPosition);
                    serializeToken(*colonPosition, ":");
                }
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "colon");

                if (local->annotation)
                    local->annotation->visit(this);
                else
                    lua_pushnil(L);

                lua_setfield(L, -2, "annotation");
            }

            if (local->shadow)
                serialize(local->shadow);
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "shadows");
        }
    }

    void serialize(Luau::AstExprTable::Item& item, Luau::CstExprTable::Item* cstNode)
    {
        LUAU_ASSERT(cstNode);

        lua_rawcheckstack(L, 2);


        if (item.kind == Luau::AstExprTable::Item::List)
        {
            lua_createtable(L, 0, 5);
            lua_pushstring(L, "list");
            lua_setfield(L, -2, "kind");

            lua_pushboolean(L, 1);
            lua_setfield(L, -2, "istableitem");

            withLocation(Luau::Location{item.value->location.begin, item.value->location.end});

            visit(item.value);
            lua_setfield(L, -2, "value");
        }
        else if (item.kind == Luau::AstExprTable::Item::Record)
        {
            lua_createtable(L, 0, 7);
            lua_pushstring(L, "record");
            lua_setfield(L, -2, "kind");

            lua_pushboolean(L, 1);
            lua_setfield(L, -2, "istableitem");

            withLocation(Luau::Location{item.key->location.begin, item.value->location.end});

            const auto& value = item.key->as<Luau::AstExprConstantString>()->value;
            serializeToken(item.key->location.begin, std::string(value.data, value.size).data());
            lua_setfield(L, -2, "key");

            LUAU_ASSERT(cstNode->equalsPosition);
            serializeToken(*cstNode->equalsPosition, "=");
            lua_setfield(L, -2, "equals");

            visit(item.value);
            lua_setfield(L, -2, "value");
        }
        else if (item.kind == Luau::AstExprTable::Item::General)
        {
            lua_createtable(L, 0, 9);
            lua_pushstring(L, "general");
            lua_setfield(L, -2, "kind");

            lua_pushboolean(L, 1);
            lua_setfield(L, -2, "istableitem");

            LUAU_ASSERT(cstNode->indexerOpenPosition);
            withLocation(Luau::Location{*cstNode->indexerOpenPosition, item.value->location.end});

            serializeToken(*cstNode->indexerOpenPosition, "[");
            lua_setfield(L, -2, "indexeropen");

            visit(item.key);
            lua_setfield(L, -2, "key");

            LUAU_ASSERT(cstNode->indexerClosePosition);
            serializeToken(*cstNode->indexerClosePosition, "]");
            lua_setfield(L, -2, "indexerclose");

            LUAU_ASSERT(cstNode->equalsPosition);
            serializeToken(*cstNode->equalsPosition, "=");
            lua_setfield(L, -2, "equals");

            visit(item.value);
            lua_setfield(L, -2, "value");
        }

        if (cstNode->separator)
            serializeToken(*cstNode->separatorPosition, *cstNode->separator == Luau::CstExprTable::Comma ? "," : ";");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "separator");
    }

    void withLocation(Luau::Location location)
    {
        serialize(location);
        lua_setfield(L, -2, "location");
    }

    void serialize(Luau::AstExprBinary::Op& op)
    {
        if (op == Luau::AstExprBinary::Op::Op__Count)
            luaL_error(L, "encountered illegal operator: Op__Count");

        lua_pushstring(L, Luau::toString(op).data());
    }

    // preambleSize should encode the size of the fields we're setting up for _all_ nodes. It consists of tag, kind, and location.
    static const size_t preambleSize = 3;
    void serializeNodePreamble(Luau::AstNode* node, const char* tag, const char* kind)
    {
        lua_rawcheckstack(L, 2);

        lua_pushstring(L, tag);
        lua_setfield(L, -2, "tag");

        lua_pushstring(L, kind);
        lua_setfield(L, -2, "kind");

        withLocation(node->location);
    }

    void serializeTrivia(const std::vector<Trivia>& trivia)
    {
        lua_rawcheckstack(L, 3);
        lua_createtable(L, trivia.size(), 0);

        for (size_t i = 0; i < trivia.size(); i++)
        {
            lua_createtable(L, 0, 3);

            switch (trivia[i].kind)
            {
            case Trivia::Whitespace:
                lua_pushstring(L, "whitespace");
                break;
            case Trivia::SingleLineComment:
                lua_pushstring(L, "comment");
                break;
            case Trivia::MultiLineComment:
                lua_pushstring(L, "blockcomment");
                break;
            }
            lua_setfield(L, -2, "tag");

            serialize(trivia[i].location);
            lua_setfield(L, -2, "location");

            lua_pushlstring(L, trivia[i].text.data(), trivia[i].text.size());
            lua_setfield(L, -2, "text");

            lua_rawseti(L, -2, i + 1);
        }
    }

    // For correct trivia computation, everything must end up going through serializeToken
    void serializeToken(Luau::Position position, const char* text, int nrec = 0)
    {
        lua_rawcheckstack(L, 3);
        lua_createtable(L, 0, nrec + 5);

        const auto trivia = extractTrivia(position);
        if (lastTokenRef != LUA_NOREF)
        {
            const auto [trailingTrivia, leadingTrivia] = splitTrivia(trivia);

            lua_getref(L, lastTokenRef);
            LUAU_ASSERT(lua_istable(L, -1));

            serializeTrivia(trailingTrivia);
            lua_setfield(L, -2, "trailingtrivia");
            lua_pop(L, 1);
            lua_unref(L, lastTokenRef);
            lastTokenRef = LUA_NOREF;

            serializeTrivia(leadingTrivia);
        }
        else
        {
            serializeTrivia(trivia);
        }
        LUAU_ASSERT(lua_istable(L, -2));
        lua_setfield(L, -2, "leadingtrivia");

        size_t textLength = strlen(text);

        Luau::Position endPosition{position.line, position.column + static_cast<uint32_t>(textLength)};
        serialize(Luau::Location{position, endPosition});
        lua_setfield(L, -2, "location");

        lua_pushlstring(L, text, textLength);
        lua_setfield(L, -2, "text");
        advancePosition(text);

        lua_createtable(L, 0, 0);
        lua_setfield(L, -2, "trailingtrivia");

        lua_pushboolean(L, 1);
        lua_setfield(L, -2, "istoken");

        lastTokenRef = lua_ref(L, -1);
    }

    void serializeExprs(Luau::AstArray<Luau::AstExpr*>& exprs, size_t nrec = 0)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, exprs.size, nrec);

        for (size_t i = 0; i < exprs.size; i++)
        {
            exprs.data[i]->visit(this);
            lua_rawseti(L, -2, i + 1);
        }
    }

    void serializeStats(Luau::AstArray<Luau::AstStat*>& stats, size_t nrec = 0)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, stats.size, nrec);

        for (size_t i = 0; i < stats.size; i++)
        {
            stats.data[i]->visit(this);
            lua_rawseti(L, -2, i + 1);
        }
    }

    void serializeAttributes(Luau::AstArray<Luau::AstAttr*>& attrs, size_t nrec = 0)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, attrs.size, nrec);

        for (size_t i = 0; i < attrs.size; i++)
        {
            serializeAttribute(attrs.data[i]);
            lua_rawseti(L, -2, i + 1);
        }
    }

    template<typename T>
    void serializePunctuated(Luau::AstArray<T> nodes, Luau::AstArray<Luau::Position> separators, const char* separatorText)
    {
        lua_rawcheckstack(L, 3);
        lua_createtable(L, nodes.size, 0);

        for (size_t i = 0; i < nodes.size; i++)
        {
            lua_createtable(L, 0, 2);

            nodes.data[i]->visit(this);
            lua_setfield(L, -2, "node");

            if (i < separators.size)
                serializeToken(separators.data[i], separatorText);
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "separator");

            lua_rawseti(L, -2, i + 1);
        }
    }

    void serializePunctuated(Luau::AstArray<Luau::AstTypeOrPack> nodes, Luau::AstArray<Luau::Position> separators, const char* separatorText)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, nodes.size, 0);

        for (size_t i = 0; i < nodes.size; i++)
        {
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, 2);

            if (nodes.data[i].type)
                nodes.data[i].type->visit(this);
            else
                nodes.data[i].typePack->visit(this);
            lua_setfield(L, -2, "node");

            if (i < separators.size)
                serializeToken(separators.data[i], separatorText);
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "separator");

            lua_rawseti(L, -2, i + 1);
        }
    }

    void serializePunctuated(
        Luau::AstArray<Luau::AstLocal*> nodes,
        Luau::AstArray<Luau::Position> separators,
        const char* separatorText,
        Luau::AstArray<Luau::Position> colonPositions
    )
    {
        lua_rawcheckstack(L, 3);
        lua_createtable(L, nodes.size, 0);

        for (size_t i = 0; i < nodes.size; i++)
        {
            lua_createtable(L, 0, 2);

            serialize(nodes.data[i], /* createToken=*/true, colonPositions.size > i ? std::make_optional(colonPositions.data[i]) : std::nullopt);
            lua_setfield(L, -2, "node");

            if (i < separators.size)
                serializeToken(separators.data[i], separatorText);
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "separator");

            lua_rawseti(L, -2, i + 1);
        }
    }
    void serializeAttribute(Luau::AstAttr* node)
    {
        serializeToken(node->location.begin, ("@" + std::string(node->name.value)).c_str());
        lua_rawcheckstack(L, 2);

        lua_pushstring(L, "attribute");
        lua_setfield(L, -2, "kind");

        withLocation(node->location);
    }

    void serializeEof(Luau::Position eofPosition)
    {
        serializeToken(eofPosition, "");

        lua_pushstring(L, "eof");
        lua_setfield(L, -2, "tag");
    }

    void serialize(Luau::AstExprGroup* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "group", "expr");

        serializeToken(node->location.begin, "(");
        lua_setfield(L, -2, "openparens");

        node->expr->visit(this);
        lua_setfield(L, -2, "expression");

        serializeToken(Luau::Position{node->location.end.line, node->location.end.column - 1}, ")");
        lua_setfield(L, -2, "closeparens");
    }

    void serialize(Luau::AstExprConstantNil* node)
    {
        serializeToken(node->location.begin, "nil", preambleSize);
        serializeNodePreamble(node, "nil", "expr");
    }

    void serialize(Luau::AstExprConstantBool* node)
    {
        serializeToken(node->location.begin, node->value ? "true" : "false", preambleSize + 1);
        serializeNodePreamble(node, "boolean", "expr");

        lua_pushboolean(L, node->value);
        lua_setfield(L, -2, "value");
    }

    void serialize(Luau::AstExprConstantNumber* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstExprConstantNumber>(node);

        serializeToken(node->location.begin, cstNode->value.data, preambleSize + 1);
        serializeNodePreamble(node, "number", "expr");

        lua_pushnumber(L, node->value);
        lua_setfield(L, -2, "value");
    }

    void serialize(Luau::AstExprConstantString* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstExprConstantString>(node);
        serializeToken(node->location.begin, cstNode->sourceString.data, preambleSize + 2);
        serializeNodePreamble(node, "string", "expr");

        switch (cstNode->quoteStyle)
        {
        case Luau::CstExprConstantString::QuotedSingle:
            lua_pushstring(L, "single");
            break;
        case Luau::CstExprConstantString::QuotedDouble:
            lua_pushstring(L, "double");
            break;
        case Luau::CstExprConstantString::QuotedRaw:
            lua_pushstring(L, "block");
            break;
        case Luau::CstExprConstantString::QuotedInterp:
            lua_pushstring(L, "interp");
            break;
        }
        lua_setfield(L, -2, "quotestyle");

        lua_pushnumber(L, cstNode->blockDepth);
        lua_setfield(L, -2, "blockdepth");

        // Unlike normal tokens, string content contains quotation marks that were not included during advancement
        // For simplicity, lets set the current position manually
        LUAU_ASSERT(currentPosition <= node->location.end);
        currentPosition = node->location.end;
    }

    void serialize(Luau::AstExprLocal* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "local", "expr");

        serializeToken(node->location.begin, node->local->name.value);
        lua_setfield(L, -2, "token"),

            serialize(node->local);
        lua_setfield(L, -2, "local");

        lua_pushboolean(L, node->upvalue);
        lua_setfield(L, -2, "upvalue");
    }

    void serialize(Luau::AstExprGlobal* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 1);

        serializeNodePreamble(node, "global", "expr");

        serializeToken(node->location.begin, node->name.value);
        lua_setfield(L, -2, "name");
    }

    void serialize(Luau::AstExprVarargs* node)
    {
        serializeToken(node->location.begin, "...", preambleSize);
        serializeNodePreamble(node, "vararg", "expr");
    }

    void serialize(Luau::AstExprCall* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstExprCall>(node);

        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 6);

        serializeNodePreamble(node, "call", "expr");

        node->func->visit(this);
        lua_setfield(L, -2, "func");

        if (cstNode->openParens)
            serializeToken(*cstNode->openParens, "(");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "openparens");

        serializePunctuated(node->args, cstNode->commaPositions, ",");
        lua_setfield(L, -2, "arguments");

        lua_pushboolean(L, node->self);
        lua_setfield(L, -2, "self");

        serialize(node->argLocation);
        lua_setfield(L, -2, "argLocation");

        if (cstNode->closeParens)
            serializeToken(*cstNode->closeParens, ")");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "closeparens");
    }

    void serialize(Luau::AstExprIndexName* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "indexname", "expr");

        node->expr->visit(this);
        lua_setfield(L, -2, "expression");

        serializeToken(node->opPosition, std::string(1, node->op).data());
        lua_setfield(L, -2, "accessor");

        serializeToken(node->indexLocation.begin, node->index.value);
        lua_setfield(L, -2, "index");
        serialize(node->indexLocation);
        lua_setfield(L, -2, "indexlocation");
    }

    void serialize(Luau::AstExprIndexExpr* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstExprIndexExpr>(node);

        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "index", "expr");

        node->expr->visit(this);
        lua_setfield(L, -2, "expression");

        serializeToken(cstNode->openBracketPosition, "[");
        lua_setfield(L, -2, "openbrackets");

        node->index->visit(this);
        lua_setfield(L, -2, "index");

        serializeToken(cstNode->closeBracketPosition, "]");
        lua_setfield(L, -2, "closebrackets");
    }

    enum FunctionSerializationState
    {
        AttributesAndFunctionKeywordSerialized,
        FunctionKeywordSerialized,
        NothingSerialized
    };

    // Serialization needs to happen in program-lexical order, so attributes and function keyword might have been serialized already
    void serialize(Luau::AstExprFunction* node, FunctionSerializationState state = NothingSerialized)
    {
        lua_rawcheckstack(L, 3);
        lua_createtable(L, 0, preambleSize + 17);

        serializeNodePreamble(node, "function", "expr");

        const auto cstNode = lookupCstNode<Luau::CstExprFunction>(node);

        switch (state)
        {
        case AttributesAndFunctionKeywordSerialized:
            // Attributes and function keyword are on the stack, so we just need to set them in the function expr table
            // This is only called from serialize AstStatFunction or AstStatLocalFunction, so we assume the stack has the following structure:
            // -3: attributes
            // -2: functionkeyword
            // -1: function expr table (created above)
            lua_insert(L, -3);
            lua_setfield(L, -3, "functionkeyword");
            lua_setfield(L, -2, "attributes");
            break;
        case FunctionKeywordSerialized:
            // Function keyword is on the stack, so we just need to set it in the function expr table
            // This is only called from serialize AstStatTypeFunction, so we assume the stack has the following structure:
            // -2: functionkeyword
            // -1: function expr table (created above)
            lua_insert(L, -2);
            lua_setfield(L, -2, "functionkeyword");

            lua_newtable(L);
            lua_setfield(L, -2, "attributes");
            break;
        case NothingSerialized:
            serializeAttributes(node->attributes);
            lua_setfield(L, -2, "attributes");

            serializeToken(cstNode->functionKeywordPosition, "function");
            lua_setfield(L, -2, "functionkeyword");
            break;
        }

        if (node->generics.size > 0 || node->genericPacks.size > 0)
        {
            serializeToken(cstNode->openGenericsPosition, "<");
            lua_setfield(L, -2, "opengenerics");

            auto commas = cstNode->genericsCommaPositions;
            serializePunctuated(node->generics, commas, ",");
            lua_setfield(L, -2, "generics");

            serializePunctuated(node->genericPacks, splitArray(commas, node->generics.size), ",");
            lua_setfield(L, -2, "genericpacks");

            serializeToken(cstNode->closeGenericsPosition, ">");
            lua_setfield(L, -2, "closegenerics");
        }

        if (node->self)
            serialize(node->self, /* createToken= */ false);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "self");

        if (node->argLocation)
        {
            serializeToken(node->argLocation->begin, "(");
            lua_setfield(L, -2, "openparens");
        }

        serializePunctuated(node->args, cstNode->argsCommaPositions, ",", cstNode->argsAnnotationColonPositions);
        lua_setfield(L, -2, "parameters");

        if (node->vararg)
            serializeToken(node->varargLocation.begin, "...");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "vararg");

        if (node->varargAnnotation)
            serializeToken(cstNode->varargAnnotationColonPosition, ":");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "varargcolon");

        if (node->varargAnnotation)
        {
            if (auto variadic = node->varargAnnotation->as<Luau::AstTypePackVariadic>())
                serializeTypePack(variadic, true);
            else
                node->varargAnnotation->visit(this);
        }
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "varargannotation");

        if (node->argLocation)
        {
            serializeToken(Luau::Position{node->argLocation->end.line, node->argLocation->end.column - 1}, ")");
            lua_setfield(L, -2, "closeparens");
        }

        if (node->returnAnnotation)
            serializeToken(cstNode->returnSpecifierPosition, ":");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "returnspecifier");

        if (node->returnAnnotation)
            node->returnAnnotation->visit(this);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "returnannotation");

        node->body->visit(this);
        lua_setfield(L, -2, "body");

        serializeToken(node->body->location.end, "end");
        lua_setfield(L, -2, "endkeyword");
    }

    void serialize(Luau::AstExprTable* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstExprTable>(node);

        lua_rawcheckstack(L, 3);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "table", "expr");

        serializeToken(node->location.begin, "{");
        lua_setfield(L, -2, "openbrace");

        lua_createtable(L, node->items.size, 0);
        for (size_t i = 0; i < node->items.size; i++)
        {
            serialize(node->items.data[i], &cstNode->items.data[i]);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "entries");

        serializeToken(Luau::Position{node->location.end.line, node->location.end.column - 1}, "}");
        lua_setfield(L, -2, "closebrace");
    }

    void serialize(Luau::AstExprUnary* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "unary", "expr");

        const auto cstNode = lookupCstNode<Luau::CstExprOp>(node);
        serializeToken(cstNode->opPosition, toString(node->op).data());
        lua_setfield(L, -2, "operator");

        node->expr->visit(this);
        lua_setfield(L, -2, "operand");
    }

    void serialize(Luau::AstExprBinary* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "binary", "expr");

        node->left->visit(this);
        lua_setfield(L, -2, "lhsoperand");

        const auto cstNode = lookupCstNode<Luau::CstExprOp>(node);
        serializeToken(cstNode->opPosition, Luau::toString(node->op).data());
        lua_setfield(L, -2, "operator");

        node->right->visit(this);
        lua_setfield(L, -2, "rhsoperand");
    }

    void serialize(Luau::AstExprTypeAssertion* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "cast", "expr");

        node->expr->visit(this);
        lua_setfield(L, -2, "operand");

        const auto cstNode = lookupCstNode<Luau::CstExprTypeAssertion>(node);
        serializeToken(cstNode->opPosition, "::");
        lua_setfield(L, -2, "operator");

        node->annotation->visit(this);
        lua_setfield(L, -2, "annotation");
    }

    void serialize(Luau::AstExprIfElse* node)
    {
        auto cstNode = lookupCstNode<Luau::CstExprIfElse>(node);

        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 7);

        serializeNodePreamble(node, "conditional", "expr");

        serializeToken(node->location.begin, "if");
        lua_setfield(L, -2, "ifkeyword");

        node->condition->visit(this);
        lua_setfield(L, -2, "condition");

        if (node->hasThen)
        {
            serializeToken(cstNode->thenPosition, "then");
            lua_setfield(L, -2, "thenkeyword");

            node->trueExpr->visit(this);
        }
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "thenexpr");

        lua_createtable(L, 0, preambleSize + 4);
        int i = 0;
        while (node->hasElse && node->falseExpr->is<Luau::AstExprIfElse>() && cstNode->isElseIf)
        {
            lua_createtable(L, 0, 4);

            node = node->falseExpr->as<Luau::AstExprIfElse>();
            cstNode = lookupCstNode<Luau::CstExprIfElse>(node);

            serializeToken(node->location.begin, "elseif");
            lua_setfield(L, -2, "elseifkeyword");

            node->condition->visit(this);
            lua_setfield(L, -2, "condition");

            if (node->hasThen)
            {
                serializeToken(cstNode->thenPosition, "then");
                lua_setfield(L, -2, "thenkeyword");
                node->trueExpr->visit(this);
            }
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "thenexpr");

            lua_rawseti(L, -2, i + 1);
            i++;
        }
        lua_setfield(L, -2, "elseifs");

        if (node->hasElse)
        {
            serializeToken(cstNode->elsePosition, "else");
            lua_setfield(L, -2, "elsekeyword");
            node->falseExpr->visit(this);
        }
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "elseexpr");
    }

    void serialize(Luau::AstExprInterpString* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstExprInterpString>(node);

        lua_rawcheckstack(L, 3);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "interpolatedstring", "expr");

        lua_createtable(L, node->strings.size, 0);
        lua_createtable(L, node->expressions.size, 0);

        for (size_t i = 0; i < node->strings.size; i++)
        {
            auto position = i > 0 ? cstNode->stringPositions.data[i] : node->location.begin;
            serializeToken(position, std::string(cstNode->sourceStrings.data[i].data, cstNode->sourceStrings.data[i].size).data());
            lua_rawseti(L, -3, i + 1);

            // Unlike normal tokens, interpolated string parts contain extra characters (`, } or {) that were not included during advancement
            // For simplicity, lets set the current position manually. We don't have an end position for these parts, so we must compute
            // If string part was single line, end position = current position + 2 (start and end character)
            // If string parts was multi line, end position = current position + 1 (just end character)
            if (position.line == currentPosition.line)
                currentPosition.column += 2;
            else
                currentPosition.column += 1;

            if (i < node->expressions.size)
            {
                node->expressions.data[i]->visit(this);
                lua_rawseti(L, -2, i + 1);
            }
        }
        lua_setfield(L, -3, "expressions");
        lua_setfield(L, -2, "strings");
    }

    void serialize(Luau::AstExprError* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "error", "expr");

        serializeExprs(node->expressions);
        lua_setfield(L, -2, "expressions");

        // TODO: messageIndex reference
    }

    void serializeStat(Luau::AstStatBlock* node)
    {
        const auto cstNode = cstNodeMap.find(node);
        const Luau::CstStatDo* cstDo = cstNode ? (*cstNode)->as<Luau::CstStatDo>() : nullptr;

        if (cstDo)
        {
            lua_rawcheckstack(L, 3);
            lua_createtable(L, 0, preambleSize + 3);

            serializeNodePreamble(node, "do", "stat");

            serializeToken(node->location.begin, "do");
            lua_setfield(L, -2, "dokeyword");

            // In lieu of a C++ AstStatBlock object to recurse on, manually construct a Luau AstStatBlock table
            lua_createtable(L, 0, preambleSize + 1);

            lua_pushstring(L, "block");
            lua_setfield(L, -2, "tag");

            lua_pushstring(L, "stat");
            lua_setfield(L, -2, "kind");

            Luau::Location blockLocation;
            if (node->body.size > 0)
            {
                blockLocation.begin = node->body.data[0]->location.begin;
                blockLocation.end = node->body.data[node->body.size - 1]->location.end;
            }
            else
                blockLocation = node->location;

            withLocation(blockLocation);

            serializeStats(node->body);
            lua_setfield(L, -2, "statements");

            lua_setfield(L, -2, "body");

            serializeToken(cstDo->endPosition, "end");
            lua_setfield(L, -2, "endkeyword");
        }
        else
        {
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, preambleSize + 1);

            serializeNodePreamble(node, "block", "stat");

            serializeStats(node->body);
            lua_setfield(L, -2, "statements");
        }
    }

    void serializeStat(Luau::AstStatIf* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 8);

        serializeNodePreamble(node, "conditional", "stat");

        serializeToken(node->location.begin, "if");
        lua_setfield(L, -2, "ifkeyword");

        node->condition->visit(this);
        lua_setfield(L, -2, "condition");

        serializeToken(node->thenLocation->begin, "then");
        lua_setfield(L, -2, "thenkeyword");

        node->thenbody->visit(this);
        lua_setfield(L, -2, "thenblock");

        lua_createtable(L, 0, 0);
        int i = 0;
        while (node->elsebody && node->elsebody->is<Luau::AstStatIf>())
        {
            lua_createtable(L, 0, 4);

            auto elseif = node->elsebody->as<Luau::AstStatIf>();
            serializeToken(elseif->location.begin, "elseif");
            lua_setfield(L, -2, "elseifkeyword");

            elseif->condition->visit(this);
            lua_setfield(L, -2, "condition");

            serializeToken(elseif->thenLocation->begin, "then");
            lua_setfield(L, -2, "thenkeyword");

            elseif->thenbody->visit(this);
            lua_setfield(L, -2, "thenblock");

            lua_rawseti(L, -2, i + 1);
            node = elseif;
            i++;
        }
        lua_setfield(L, -2, "elseifs");

        if (node->elsebody)
        {
            LUAU_ASSERT(node->elseLocation);
            serializeToken(node->elseLocation->begin, "else");
            lua_setfield(L, -2, "elsekeyword");

            node->elsebody->visit(this);
            lua_setfield(L, -2, "elseblock");

            serializeToken(node->elsebody->location.end, "end");
            lua_setfield(L, -2, "endkeyword");
        }
        else
        {
            lua_pushnil(L);
            lua_setfield(L, -2, "elsekeyword");

            lua_pushnil(L);
            lua_setfield(L, -2, "elseblock");

            serializeToken(node->thenbody->location.end, "end");
            lua_setfield(L, -2, "endkeyword");
        }
    }

    void serializeStat(Luau::AstStatWhile* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 5);

        serializeNodePreamble(node, "while", "stat");

        serializeToken(node->location.begin, "while");
        lua_setfield(L, -2, "whilekeyword");

        node->condition->visit(this);
        lua_setfield(L, -2, "condition");

        if (node->hasDo)
            serializeToken(node->doLocation.begin, "do");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "dokeyword");

        node->body->visit(this);
        lua_setfield(L, -2, "body");

        serializeToken(node->body->location.end, "end");
        lua_setfield(L, -2, "endkeyword");
    }

    void serializeStat(Luau::AstStatRepeat* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "repeat", "stat");

        serializeToken(node->location.begin, "repeat");
        lua_setfield(L, -2, "repeatkeyword");

        node->body->visit(this);
        lua_setfield(L, -2, "body");

        auto cstNode = lookupCstNode<Luau::CstStatRepeat>(node);
        serializeToken(cstNode->untilPosition, "until");
        lua_setfield(L, -2, "untilkeyword");

        node->condition->visit(this);
        lua_setfield(L, -2, "condition");
    }

    void serializeStat(Luau::AstStatBreak* node)
    {
        lua_rawcheckstack(L, 2);
        serializeToken(node->location.begin, "break", preambleSize);
        serializeNodePreamble(node, "break", "stat");
    }

    void serializeStat(Luau::AstStatContinue* node)
    {
        lua_rawcheckstack(L, 2);
        serializeToken(node->location.begin, "continue", preambleSize);
        serializeNodePreamble(node, "continue", "stat");
    }

    void serializeStat(Luau::AstStatReturn* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "return", "stat");

        serializeToken(node->location.begin, "return");
        lua_setfield(L, -2, "returnkeyword");

        const auto cstNode = lookupCstNode<Luau::CstStatReturn>(node);
        serializePunctuated(node->list, cstNode->commaPositions, ",");
        lua_setfield(L, -2, "expressions");
    }

    void serializeStat(Luau::AstStatExpr* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 1);

        serializeNodePreamble(node, "expression", "stat");

        node->expr->visit(this);
        lua_setfield(L, -2, "expression");
    }

    void serializeStat(Luau::AstStatLocal* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "local", "stat");

        serializeToken(node->location.begin, "local");
        lua_setfield(L, -2, "localkeyword");

        const auto cstNode = lookupCstNode<Luau::CstStatLocal>(node);
        serializePunctuated(node->vars, cstNode->varsCommaPositions, ",", cstNode->varsAnnotationColonPositions);
        lua_setfield(L, -2, "variables");

        if (node->equalsSignLocation)
            serializeToken(node->equalsSignLocation->begin, "=");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "equals");

        serializePunctuated(node->values, cstNode->valuesCommaPositions, ",");
        lua_setfield(L, -2, "values");
    }

    void serializeStat(Luau::AstStatFor* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 11);

        const auto cstNode = lookupCstNode<Luau::CstStatFor>(node);

        serializeNodePreamble(node, "for", "stat");

        serializeToken(node->location.begin, "for");
        lua_setfield(L, -2, "forkeyword");

        serialize(node->var, /* createToken= */ true, std::make_optional(cstNode->annotationColonPosition));
        lua_setfield(L, -2, "variable");

        serializeToken(cstNode->equalsPosition, "=");
        lua_setfield(L, -2, "equals");

        node->from->visit(this);
        lua_setfield(L, -2, "from");

        serializeToken(cstNode->endCommaPosition, ",");
        lua_setfield(L, -2, "tocomma");

        node->to->visit(this);
        lua_setfield(L, -2, "to");

        if (cstNode->stepCommaPosition)
        {
            serializeToken(*cstNode->stepCommaPosition, ",");
            lua_setfield(L, -2, "stepcomma");
        }

        if (node->step)
            node->step->visit(this);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "step");

        if (node->hasDo)
            serializeToken(node->doLocation.begin, "do");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "dokeyword");

        node->body->visit(this);
        lua_setfield(L, -2, "body");

        serializeToken(node->body->location.end, "end");
        lua_setfield(L, -2, "endkeyword");
    }

    void serializeStat(Luau::AstStatForIn* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 7);

        const auto cstNode = lookupCstNode<Luau::CstStatForIn>(node);

        serializeNodePreamble(node, "forin", "stat");

        serializeToken(node->location.begin, "for");
        lua_setfield(L, -2, "forkeyword");

        serializePunctuated(node->vars, cstNode->varsCommaPositions, ",", cstNode->varsAnnotationColonPositions);
        lua_setfield(L, -2, "variables");

        if (node->hasIn)
            serializeToken(node->inLocation.begin, "in");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "inkeyword");

        serializePunctuated(node->values, cstNode->valuesCommaPositions, ",");
        lua_setfield(L, -2, "values");

        if (node->hasDo)
            serializeToken(node->doLocation.begin, "do");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "dokeyword");

        node->body->visit(this);
        lua_setfield(L, -2, "body");

        serializeToken(node->body->location.end, "end");
        lua_setfield(L, -2, "endkeyword");
    }

    void serializeStat(Luau::AstStatAssign* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        const auto cstNode = lookupCstNode<Luau::CstStatAssign>(node);

        serializeNodePreamble(node, "assign", "stat");

        serializePunctuated(node->vars, cstNode->varsCommaPositions, ",");
        lua_setfield(L, -2, "variables");

        serializeToken(cstNode->equalsPosition, "=");
        lua_setfield(L, -2, "equals");

        serializePunctuated(node->values, cstNode->valuesCommaPositions, ",");
        lua_setfield(L, -2, "values");
    }

    void serializeStat(Luau::AstStatCompoundAssign* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "compoundassign", "stat");

        node->var->visit(this);
        lua_setfield(L, -2, "variable");

        const auto cstNode = lookupCstNode<Luau::CstStatCompoundAssign>(node);
        serializeToken(cstNode->opPosition, (Luau::toString(node->op) + "=").data());
        lua_setfield(L, -2, "operand");

        node->value->visit(this);
        lua_setfield(L, -2, "value");
    }

    void serializeStat(Luau::AstStatFunction* node)
    {
        lua_rawcheckstack(L, 4);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "function", "stat");

        const auto cstNode = lookupCstNode<Luau::CstStatFunction>(node);

        // Serialization needs to happen in program-lexical order, so we serialize attributes and function keyword first
        serializeAttributes(node->func->attributes);

        serializeToken(cstNode->functionKeywordPosition, "function");

        node->name->visit(this);
        lua_setfield(L, -4, "name");

        serialize(node->func, AttributesAndFunctionKeywordSerialized);
        lua_setfield(L, -2, "func");
    }

    void serializeStat(Luau::AstStatLocalFunction* node)
    {
        lua_rawcheckstack(L, 4);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "localfunction", "stat");

        // Serialization needs to happen in program-lexical order, so we serialize attributes and function keyword before the func expr
        serializeAttributes(node->func->attributes);

        const auto cstNode = lookupCstNode<Luau::CstStatLocalFunction>(node);

        serializeToken(cstNode->localKeywordPosition, "local");
        lua_setfield(L, -3, "localkeyword");

        serializeToken(cstNode->functionKeywordPosition, "function");

        serialize(node->name);
        lua_setfield(L, -4, "name");

        serialize(node->func, AttributesAndFunctionKeywordSerialized);
        lua_setfield(L, -2, "func");
    }

    static Luau::AstArray<Luau::Position> splitArray(Luau::AstArray<Luau::Position> arr, size_t index)
    {
        if (arr.size < index)
            return arr;
        return {arr.data + index, arr.size - index};
    }

    void serializeStat(Luau::AstStatTypeAlias* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 9);

        serializeNodePreamble(node, "typealias", "stat");

        const auto cstNode = lookupCstNode<Luau::CstStatTypeAlias>(node);

        if (node->exported)
            serializeToken(node->location.begin, "export");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "export");

        serializeToken(cstNode->typeKeywordPosition, "type");
        lua_setfield(L, -2, "typetoken");

        serializeToken(node->nameLocation.begin, node->name.value);
        lua_setfield(L, -2, "name");

        if (node->generics.size > 0 || node->genericPacks.size > 0)
        {
            serializeToken(cstNode->genericsOpenPosition, "<");
            lua_setfield(L, -2, "opengenerics");

            auto commas = cstNode->genericsCommaPositions;
            serializePunctuated(node->generics, commas, ",");
            lua_setfield(L, -2, "generics");

            serializePunctuated(node->genericPacks, splitArray(commas, node->generics.size), ",");
            lua_setfield(L, -2, "genericpacks");

            serializeToken(cstNode->genericsClosePosition, ">");
            lua_setfield(L, -2, "closegenerics");
        }

        serializeToken(cstNode->equalsPosition, "=");
        lua_setfield(L, -2, "equals");

        node->type->visit(this);
        lua_setfield(L, -2, "type");
    }

    void serializeStat(Luau::AstStatTypeFunction* node)
    {
        lua_rawcheckstack(L, 3);
        lua_createtable(L, 0, preambleSize + 4);

        const auto cstNode = lookupCstNode<Luau::CstStatTypeFunction>(node);

        serializeNodePreamble(node, "typefunction", "stat");

        if (node->exported)
            serializeToken(node->location.begin, "export");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "export");

        serializeToken(cstNode->typeKeywordPosition, "type");
        lua_setfield(L, -2, "type");

        serializeToken(cstNode->functionKeywordPosition, "function");

        serializeToken(node->nameLocation.begin, node->name.value);
        lua_setfield(L, -3, "name");

        serialize(node->body, FunctionKeywordSerialized);
        lua_setfield(L, -2, "body");
    }

    void serializeStat(Luau::AstStatDeclareFunction* node)
    {
        // TODO: declarations
    }

    void serializeStat(Luau::AstStatDeclareGlobal* node)
    {
        // TODO: declarations
    }

    void serializeStat(Luau::AstStatDeclareExternType* node)
    {
        // TODO: declarations
    }

    void serializeStat(Luau::AstStatError* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "error", "stat");

        serializeExprs(node->expressions);
        lua_setfield(L, -2, "expressions");

        serializeStats(node->statements);
        lua_setfield(L, -2, "statements");

        // TODO: messageIndex reference
    }

    void serializeType(Luau::AstTypeReference* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 6);

        serializeNodePreamble(node, "reference", "type");

        const auto cstNode = node->prefix || node->hasParameterList ? lookupCstNode<Luau::CstTypeReference>(node).get() : nullptr;

        if (node->prefix)
        {
            LUAU_ASSERT(node->prefixLocation);
            serializeToken(node->prefixLocation->begin, node->prefix->value);
            lua_setfield(L, -2, "prefix");

            LUAU_ASSERT(cstNode);
            LUAU_ASSERT(cstNode->prefixPointPosition);
            serializeToken(*cstNode->prefixPointPosition, ".");
            lua_setfield(L, -2, "prefixpoint");
        }

        serializeToken(node->nameLocation.begin, node->name.value);
        lua_setfield(L, -2, "name");

        if (node->hasParameterList)
        {
            LUAU_ASSERT(cstNode);
            serializeToken(cstNode->openParametersPosition, "<");
            lua_setfield(L, -2, "openparameters");

            serializePunctuated(node->parameters, cstNode->parametersCommaPositions, ",");
            lua_setfield(L, -2, "parameters");

            serializeToken(cstNode->closeParametersPosition, ">");
            lua_setfield(L, -2, "closeparameters");
        }
    }

    void serializeType(Luau::AstTypeTable* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstTypeTable>(node);

        if (cstNode->isArray)
        {
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, preambleSize + 4);

            serializeNodePreamble(node, "array", "type");

            serializeToken(node->location.begin, "{");
            lua_setfield(L, -2, "openbrace");

            if (node->indexer->accessLocation)
            {
                LUAU_ASSERT(node->indexer->access != Luau::AstTableAccess::ReadWrite);
                serializeToken(node->indexer->accessLocation->begin, node->indexer->access == Luau::AstTableAccess::Read ? "read" : "write");
            }
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "access");

            node->indexer->resultType->visit(this);
            lua_setfield(L, -2, "type");

            serializeToken(Luau::Position{node->location.end.line, node->location.end.column - 1}, "}");
            lua_setfield(L, -2, "closebrace");

            return;
        }

        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "table", "type");

        serializeToken(node->location.begin, "{");
        lua_setfield(L, -2, "openbrace");

        lua_createtable(L, cstNode->items.size, 0);
        const Luau::AstTableProp* prop = node->props.begin();
        for (size_t i = 0; i < cstNode->items.size; i++)
        {
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, 8);

            Luau::CstTypeTable::Item item = cstNode->items.data[i];

            if (item.kind == Luau::CstTypeTable::Item::Kind::Indexer)
            {
                LUAU_ASSERT(node->indexer);

                lua_pushstring(L, "indexer");
                lua_setfield(L, -2, "kind");

                if (node->indexer->accessLocation)
                {
                    LUAU_ASSERT(node->indexer->access != Luau::AstTableAccess::ReadWrite);
                    serializeToken(node->indexer->accessLocation->begin, node->indexer->access == Luau::AstTableAccess::Read ? "read" : "write");
                }
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "access");

                serializeToken(item.indexerOpenPosition, "[");
                lua_setfield(L, -2, "indexeropen");

                node->indexer->indexType->visit(this);
                lua_setfield(L, -2, "key");

                serializeToken(item.indexerClosePosition, "]");
                lua_setfield(L, -2, "indexerclose");

                serializeToken(item.colonPosition, ":");
                lua_setfield(L, -2, "colon");

                node->indexer->resultType->visit(this);
                lua_setfield(L, -2, "value");

                if (item.separator)
                    serializeToken(*item.separatorPosition, item.separator == Luau::CstExprTable::Comma ? "," : ";");
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "separator");
            }
            else
            {
                if (item.kind == Luau::CstTypeTable::Item::Kind::StringProperty)
                {
                    lua_pushstring(L, "stringproperty");
                    lua_setfield(L, -2, "kind");
                }
                else
                {
                    lua_pushstring(L, "property");
                    lua_setfield(L, -2, "kind");
                }

                if (prop->accessLocation)
                {
                    LUAU_ASSERT(prop->access != Luau::AstTableAccess::ReadWrite);
                    serializeToken(prop->accessLocation->begin, prop->access == Luau::AstTableAccess::Read ? "read" : "write");
                }
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "access");

                if (item.kind == Luau::CstTypeTable::Item::Kind::StringProperty)
                {
                    serializeToken(item.indexerOpenPosition, "[");
                    lua_setfield(L, -2, "indexeropen");

                    {
                        auto initialPosition = item.stringPosition;
                        serializeToken(item.stringPosition, item.stringInfo->sourceString.data);

                        lua_pushstring(L, "string");
                        lua_setfield(L, -2, "tag");

                        switch (item.stringInfo->quoteStyle)
                        {
                        case Luau::CstExprConstantString::QuotedSingle:
                            lua_pushstring(L, "single");
                            break;
                        case Luau::CstExprConstantString::QuotedDouble:
                            lua_pushstring(L, "double");
                            break;
                        default:
                            LUAU_ASSERT(false);
                        }
                        lua_setfield(L, -2, "quotestyle");

                        // Unlike normal tokens, string content contains quotation marks that were not included during advancement
                        // For simplicity, lets set the current position manually
                        // If string part was single line, end position = current position + 2 (start and end character)
                        // If string parts was multi line, end position = current position + 1 (just end character)
                        if (initialPosition.line == currentPosition.line)
                            currentPosition.column += 2;
                        else
                            currentPosition.column += 1;
                    }
                    lua_setfield(L, -2, "key");

                    serializeToken(item.indexerClosePosition, "]");
                    lua_setfield(L, -2, "indexerclose");
                }
                else
                {
                    serializeToken(prop->location.begin, prop->name.value);
                    lua_setfield(L, -2, "key");
                }

                serializeToken(item.colonPosition, ":");
                lua_setfield(L, -2, "colon");

                prop->type->visit(this);
                lua_setfield(L, -2, "value");

                if (item.separator)
                    serializeToken(*item.separatorPosition, item.separator == Luau::CstExprTable::Comma ? "," : ";");
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "separator");

                ++prop;
            }
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "entries");

        serializeToken(Luau::Position{node->location.end.line, node->location.end.column - 1}, "}");
        lua_setfield(L, -2, "closebrace");
    }

    void serializeType(Luau::AstTypeFunction* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 10);

        serializeNodePreamble(node, "function", "type");

        const auto cstNode = lookupCstNode<Luau::CstTypeFunction>(node);

        if (node->generics.size > 0 || node->genericPacks.size > 0)
        {
            serializeToken(cstNode->openGenericsPosition, "<");
            lua_setfield(L, -2, "opengenerics");

            auto commas = cstNode->genericsCommaPositions;
            serializePunctuated(node->generics, commas, ",");
            lua_setfield(L, -2, "generics");

            serializePunctuated(node->genericPacks, splitArray(commas, node->generics.size), ",");
            lua_setfield(L, -2, "genericpacks");

            serializeToken(cstNode->closeGenericsPosition, ">");
            lua_setfield(L, -2, "closegenerics");
        }

        serializeToken(cstNode->openArgsPosition, "(");
        lua_setfield(L, -2, "openparens");

        lua_createtable(L, node->argTypes.types.size, 0);
        for (size_t i = 0; i < node->argTypes.types.size; i++)
        {
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, 2);

            {
                lua_rawcheckstack(L, 2);
                lua_createtable(L, 0, 3);
                if (i < node->argNames.size && node->argNames.data[i].has_value())
                    serializeToken(node->argNames.data[i]->second.begin, node->argNames.data[i]->first.value);
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "name");

                if (i < cstNode->argumentNameColonPositions.size && cstNode->argumentNameColonPositions.data[i].has_value())
                    serializeToken(*cstNode->argumentNameColonPositions.data[i], ":");
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "colon");

                node->argTypes.types.data[i]->visit(this);
                lua_setfield(L, -2, "type");
            }
            lua_setfield(L, -2, "node");

            if (i < cstNode->argumentsCommaPositions.size)
                serializeToken(cstNode->argumentsCommaPositions.data[i], ",");
            else
                lua_pushnil(L);
            lua_setfield(L, -2, "separator");

            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "parameters");

        if (node->argTypes.tailType)
            node->argTypes.tailType->visit(this);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "vararg");

        serializeToken(cstNode->closeArgsPosition, ")");
        lua_setfield(L, -2, "closeparens");

        serializeToken(cstNode->returnArrowPosition, "->");
        lua_setfield(L, -2, "returnarrow");

        node->returnTypes->visit(this);
        lua_setfield(L, -2, "returntypes");
    }

    void serializeType(Luau::AstTypeTypeof* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "typeof", "type");

        serializeToken(node->location.begin, "typeof");
        lua_setfield(L, -2, "typeof");

        const auto cstNode = lookupCstNode<Luau::CstTypeTypeof>(node);
        serializeToken(cstNode->openPosition, "(");
        lua_setfield(L, -2, "openparens");

        node->expr->visit(this);
        lua_setfield(L, -2, "expression");

        serializeToken(cstNode->closePosition, ")");
        lua_setfield(L, -2, "closeparens");
    }

    void serializeType(Luau::AstTypeUnion* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstTypeUnion>(node);

        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "union", "type");

        if (cstNode->leadingPosition)
            serializeToken(*cstNode->leadingPosition, "|");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "leading");

        lua_createtable(L, node->types.size, 0);
        size_t separatorPositions = 0;
        for (size_t i = 0; i < node->types.size; i++)
        {
            lua_rawcheckstack(L, 2);
            lua_createtable(L, 0, 2);

            if (node->types.data[i]->is<Luau::AstTypeOptional>())
            {
                serializeToken(node->types.data[i]->location.begin, "?", 2);
                lua_pushstring(L, "type");
                lua_setfield(L, -2, "kind");
                lua_pushstring(L, "optional");
                lua_setfield(L, -2, "tag");
                lua_setfield(L, -2, "node");

                // Since this option is an optional type, the separator is always present unless it's the last type
                if (i < node->types.size - 1 && separatorPositions < cstNode->separatorPositions.size)
                {
                    serializeToken(cstNode->separatorPositions.data[separatorPositions], "|");
                    separatorPositions++;
                }
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "separator");
            }
            else
            {
                node->types.data[i]->visit(this);
                lua_setfield(L, -2, "node");

                // If the next type is optional, we don't have a separator token
                if (i < node->types.size - 1 && !node->types.data[i + 1]->is<Luau::AstTypeOptional>() &&
                    separatorPositions < cstNode->separatorPositions.size)
                {
                    serializeToken(cstNode->separatorPositions.data[separatorPositions], "|");
                    separatorPositions++;
                }
                else
                    lua_pushnil(L);
                lua_setfield(L, -2, "separator");
            }

            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, -2, "types");
    }

    void serializeType(Luau::AstTypeIntersection* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstTypeIntersection>(node);

        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "intersection", "type");

        if (cstNode->leadingPosition)
            serializeToken(*cstNode->leadingPosition, "&");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "leading");

        serializePunctuated(node->types, cstNode->separatorPositions, "&");
        lua_setfield(L, -2, "types");
    }

    void serializeType(Luau::AstTypeSingletonBool* node)
    {
        serializeToken(node->location.begin, node->value ? "true" : "false", preambleSize + 1);
        serializeNodePreamble(node, "boolean", "type");

        lua_pushboolean(L, node->value);
        lua_setfield(L, -2, "value");
    }

    void serializeType(Luau::AstTypeSingletonString* node)
    {
        const auto cstNode = lookupCstNode<Luau::CstTypeSingletonString>(node);
        serializeToken(node->location.begin, cstNode->sourceString.data, preambleSize + 1);
        serializeNodePreamble(node, "string", "type");

        switch (cstNode->quoteStyle)
        {
        case Luau::CstExprConstantString::QuotedSingle:
            lua_pushstring(L, "single");
            break;
        case Luau::CstExprConstantString::QuotedDouble:
            lua_pushstring(L, "double");
            break;
        default:
            LUAU_ASSERT(false);
        }
        lua_setfield(L, -2, "quotestyle");

        // Unlike normal tokens, string content contains quotation marks that were not included during advancement
        // For simplicity, lets set the current position manually
        LUAU_ASSERT(currentPosition <= node->location.end);
        currentPosition = node->location.end;
    }

    void serializeType(Luau::AstTypeGroup* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "group", "type");

        serializeToken(node->location.begin, "(");
        lua_setfield(L, -2, "openparens");

        node->type->visit(this);
        lua_setfield(L, -2, "type");

        serializeToken(Luau::Position{node->location.end.line, node->location.end.column - 1}, ")");
        lua_setfield(L, -2, "closeparens");
    }

    void serializeType(Luau::AstGenericType* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 3);

        serializeNodePreamble(node, "generic", "type");

        const auto cstNode = lookupCstNode<Luau::CstGenericType>(node);

        serializeToken(node->location.begin, node->name.value);
        lua_setfield(L, -2, "name");

        if (node->defaultValue)
            serializeToken(*cstNode->defaultEqualsPosition, "=");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "equals");

        if (node->defaultValue)
            node->defaultValue->visit(this);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "default");
    }

    void serializeType(Luau::AstGenericTypePack* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "generic", "typepack");

        const auto cstNode = lookupCstNode<Luau::CstGenericTypePack>(node);

        serializeToken(node->location.begin, node->name.value);
        lua_setfield(L, -2, "name");

        serializeToken(cstNode->ellipsisPosition, "...");
        lua_setfield(L, -2, "ellipsis");

        if (node->defaultValue)
            serializeToken(*cstNode->defaultEqualsPosition, "=");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "equals");

        if (node->defaultValue)
            node->defaultValue->visit(this);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "default");
    }

    void serializeType(Luau::AstTypeError* node)
    {
        // TODO: types
    }

    void serializeTypePack(Luau::AstTypePackExplicit* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 4);

        serializeNodePreamble(node, "explicit", "typepack");

        const auto cstNode = lookupCstNode<Luau::CstTypePackExplicit>(node);

        if (cstNode->hasParentheses)
            serializeToken(cstNode->openParenthesesPosition, "(");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "openparens");

        serializePunctuated(node->typeList.types, cstNode->commaPositions, ",");
        lua_setfield(L, -2, "types");

        if (node->typeList.tailType)
            node->typeList.tailType->visit(this);
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "tailtype");

        if (cstNode->hasParentheses)
            serializeToken(cstNode->closeParenthesesPosition, ")");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "closeparens");
    }

    void serializeTypePack(Luau::AstTypePackGeneric* node)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "generic", "typepack");

        serializeToken(node->location.begin, node->genericName.value);
        lua_setfield(L, -2, "name");

        const auto cstNode = lookupCstNode<Luau::CstTypePackGeneric>(node);
        serializeToken(cstNode->ellipsisPosition, "...");
        lua_setfield(L, -2, "ellipsis");
    }

    void serializeTypePack(Luau::AstTypePackVariadic* node, bool forVarArg = false)
    {
        lua_rawcheckstack(L, 2);
        lua_createtable(L, 0, preambleSize + 2);

        serializeNodePreamble(node, "variadic", "typepack");

        if (!forVarArg)
            serializeToken(node->location.begin, "...");
        else
            lua_pushnil(L);
        lua_setfield(L, -2, "ellipsis");

        node->variadicType->visit(this);
        lua_setfield(L, -2, "type");
    }

    bool visit(Luau::AstExpr* node) override
    {
        node->visit(this);
        return false;
    }

    bool visit(Luau::AstExprGroup* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprConstantNil* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprConstantBool* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprConstantNumber* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprConstantString* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprLocal* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprGlobal* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprVarargs* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprCall* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprIndexName* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprIndexExpr* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprFunction* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprTable* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprUnary* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprBinary* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprTypeAssertion* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprIfElse* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprInterpString* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstExprError* node) override
    {
        serialize(node);
        return false;
    }

    bool visit(Luau::AstStat* node) override
    {
        node->visit(this);
        return false;
    }

    bool visit(Luau::AstStatBlock* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatIf* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatWhile* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatRepeat* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatBreak* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatContinue* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatReturn* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatExpr* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatLocal* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatFor* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatForIn* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatAssign* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatCompoundAssign* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatFunction* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatLocalFunction* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatTypeAlias* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatTypeFunction* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatDeclareFunction* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatDeclareGlobal* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatDeclareExternType* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstStatError* node) override
    {
        serializeStat(node);
        return false;
    }

    bool visit(Luau::AstType* node) override
    {
        return true;
    }

    bool visit(Luau::AstTypeReference* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeTable* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeFunction* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeTypeof* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeUnion* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeIntersection* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeSingletonBool* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeSingletonString* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstTypeError* node) override
    {
        return true;
    }

    bool visit(Luau::AstTypePack* node) override
    {
        return true;
    }

    bool visit(Luau::AstTypePackExplicit* node) override
    {
        serializeTypePack(node);
        return false;
    }

    bool visit(Luau::AstTypePackVariadic* node) override
    {
        serializeTypePack(node);
        return false;
    }

    bool visit(Luau::AstTypePackGeneric* node) override
    {
        serializeTypePack(node);
        return false;
    }

    bool visit(Luau::AstTypeGroup* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstGenericType* node) override
    {
        serializeType(node);
        return false;
    }

    bool visit(Luau::AstGenericTypePack* node) override
    {
        serializeType(node);
        return false;
    }
};

int luau_parse(lua_State* L)
{
    std::string source = luaL_checkstring(L, 1);

    StatResult result = parse(source);

    auto& errors = result.parseResult.errors;

    if (!errors.empty())
    {
        std::vector<std::string> locationStrings{};
        locationStrings.reserve(errors.size());

        size_t size = 0;
        for (auto error : errors)
        {
            locationStrings.emplace_back(Luau::toString(error.getLocation()));
            size += locationStrings.back().size() + 2 + error.getMessage().size() + 1;
        }

        std::string fullError;
        fullError.reserve(size);

        for (size_t i = 0; i < errors.size(); i++)
        {
            fullError += locationStrings[i];
            fullError += ": ";
            fullError += errors[i].getMessage();
            fullError += "\n";
        }

        luaL_error(L, "parsing failed:\n%s", fullError.c_str());
    }

    lua_rawcheckstack(L, 6);

    lua_createtable(L, 0, 4);

    AstSerialize serializer{L, source, result.parseResult.cstNodeMap, result.parseResult.commentLocations};
    serializer.visit(result.parseResult.root);
    lua_setfield(L, -2, "root");

    serializer.serializeEof(result.parseResult.root->location.end);
    lua_setfield(L, -2, "eof");

    lua_pushnumber(L, result.parseResult.lines);
    lua_setfield(L, -2, "lines");

    lua_createtable(L, serializer.lineOffsets.size(), 0);
    for (size_t i = 0; i < serializer.lineOffsets.size(); i++)
    {
        lua_pushinteger(L, i + 1);
        lua_pushnumber(L, serializer.lineOffsets[i]);
        lua_settable(L, -3);
    }
    lua_setfield(L, -2, "lineoffsets");

    return 1;
}

int luau_parseexpr(lua_State* L)
{
    std::string source = luaL_checkstring(L, 1);

    ExprResult result = parseExpr(source);

    auto& errors = result.parseResult.errors;

    if (!errors.empty())
    {
        std::vector<std::string> locationStrings{};
        locationStrings.reserve(errors.size());

        size_t size = 0;
        for (auto error : errors)
        {
            locationStrings.emplace_back(Luau::toString(error.getLocation()));
            size += locationStrings.back().size() + 2 + error.getMessage().size() + 1;
        }

        std::string fullError;
        fullError.reserve(size);

        for (size_t i = 0; i < errors.size(); i++)
        {
            fullError += locationStrings[i];
            fullError += ": ";
            fullError += errors[i].getMessage();
            fullError += "\n";
        }

        luaL_error(L, "parsing failed:\n%s", fullError.c_str());
    }

    AstSerialize serializer{L, source, result.parseResult.cstNodeMap, result.parseResult.commentLocations};
    serializer.visit(result.parseResult.root);

    return 1;
}

inline int check_int_field(lua_State* L, int obj_idx, const char* field_name, int default_value)
{
    if (lua_getfield(L, obj_idx, field_name) == LUA_TNIL)
        return default_value;

    int is_num;
    int value = lua_tointegerx(L, -1, &is_num);

    if (!is_num)
        luaL_errorL(L, "Expected number for field \"%s\"", field_name);

    return value;
}

int compile_luau(lua_State* L)
{
    size_t source_size;
    const char* source = luaL_checklstring(L, 1, &source_size);

    Luau::CompileOptions opts{};

    if (lua_type(L, 2) == LUA_TTABLE)
    {
        opts.optimizationLevel = check_int_field(L, 2, "optimizationlevel", 1);
        opts.debugLevel = check_int_field(L, 2, "debuglevel", 1);
        opts.coverageLevel = check_int_field(L, 2, "coveragelevel", 1);
    }

    std::string bytecode = Luau::compile(std::string(source, source_size), opts);

    std::string* userdata = static_cast<std::string*>(lua_newuserdatadtor(
        L,
        sizeof(std::string),
        [](void* ptr)
        {
            std::destroy_at(static_cast<std::string*>(ptr));
        }
    ));

    new (userdata) std::string(std::move(bytecode));

    luaL_getmetatable(L, kCompileResultType);
    lua_setmetatable(L, -2);

    return 1;
}

static int indexCompileResult(lua_State* L)
{
    const std::string* bytecode_string = static_cast<std::string*>(luaL_checkudata(L, 1, kCompileResultType));

    if (std::strcmp(luaL_checkstring(L, 2), "bytecode") == 0)
    {
        lua_pushlstring(L, bytecode_string->c_str(), bytecode_string->size());

        return 1;
    }

    return 0;
}

int load_luau(lua_State* L)
{
    const std::string* bytecodeString = static_cast<std::string*>(luaL_checkudata(L, 1, kCompileResultType));
    const char* chunkname = luaL_checkstring(L, 2);
    int envIndex = lua_isnoneornil(L, 3) ? 0 : 3;

    if (luau_load(L, chunkname, bytecodeString->c_str(), bytecodeString->length(), envIndex) != 0)
        lua_error(L);

    return 1;
}

int typeofmodule_luau(lua_State* L)
{
    std::string modulePath = luaL_checkstring(L, 1);

    Luau::LuteModuleResolver moduleResolver;
    Luau::LuteConfigResolver configResolver(Luau::Mode::NoCheck);
    Luau::FrontendOptions fopts;
    fopts.retainFullTypeGraphs = true;

    Luau::Frontend frontend(&moduleResolver, &configResolver, fopts);
    Luau::registerBuiltinGlobals(frontend, frontend.globals);
    Luau::freeze(frontend.globals.globalTypes);

    frontend.check(modulePath);

    Luau::ModulePtr modulePtr = frontend.moduleResolver.getModule(modulePath);
    if (!modulePtr)
    {
        lua_pushnil(L);
        return 1;
    }

    // Serialize and push the return type
    serializeTypePack(modulePtr->returnType, L);

    // check the table was created and set it read-only
    lua_rawcheckstack(L, 1);
    lua_setreadonly(L, -1, 1);

    return 1;
}

// perform type mt registration, etc
static int initLuauLibrary(lua_State* L)
{
    luaL_newmetatable(L, kCompileResultType);

    // Set __type
    lua_pushstring(L, kCompileResultType);
    lua_setfield(L, -2, "__type");

    lua_pushcfunction(L, luau::indexCompileResult, "CompilerResult.__index");
    lua_setfield(L, -2, "__index");

    lua_setreadonly(L, -1, 1);

    lua_pop(L, 1);

    luaL_newmetatable(L, kSpanType);

    // Set __type
    lua_pushstring(L, kSpanType);
    lua_setfield(L, -2, "__type");

    lua_pushcfunction(L, luau::indexSpan, "span.__index");
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, luau::ltSpan, "span.__lt");
    lua_setfield(L, -2, "__lt");

    lua_setreadonly(L, -1, 1);

    lua_pop(L, 1);

    return 1;
}

} // namespace luau

int luaopen_luau(lua_State* L)
{
    luaL_register(L, "luau", luau::lib);

    return luau::initLuauLibrary(L);
}

int luteopen_luau(lua_State* L)
{
    lua_createtable(L, 0, std::size(luau::lib) + std::size(luau::properties));

    // span library
    luau::makeSpanLibrary(L);
    lua_setfield(L, -2, luau::kSpanType);

    for (auto& [name, func] : luau::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return luau::initLuauLibrary(L);
}
