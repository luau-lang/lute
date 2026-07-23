
#include "system_ca.h"
#include "openssl/ssl.h"
#include "openssl/bio.h"
#include "openssl/err.h"

#include "lute/runtime.h"
#include "lute/userdatas.h"
#include "lute/uvstream.h"
#include "lute/time.h"

#include "Luau/VecDeque.h"

#include "lua.h"
#include "lualib.h"

#include <atomic>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>
#include <optional>

namespace net::client
{
struct TCPStreamHandle;

enum TCPHostnameType
{
    TCPHostnameType_IPv4,
    TCPHostnameType_IPv6,
    TCPHostnameType_Domain
};

static TCPHostnameType getHostnameType(const std::string& hostname) {
    if (hostname.find(':') != std::string::npos)
        return TCPHostnameType_IPv6;

    if (hostname.find_first_not_of("0123456789.") == std::string::npos)
        return TCPHostnameType_IPv4;

    return TCPHostnameType_Domain;
}

struct TCPOptions
{
    std::string host;
    int port;
    bool tls = false;
};

struct TCPWaiter : std::enable_shared_from_this<TCPWaiter> {
    std::shared_ptr<TCPStreamHandle> handle;
    ResumeToken token;
    std::optional<uv_timer_t*> timeout;
    bool invalid = false;

    virtual std::string getTimeoutErrorMessage() const {
        return "Operation timed out";
    }

    TCPWaiter(std::shared_ptr<TCPStreamHandle> handle, ResumeToken token, std::optional<uv_timer_t*> timeout = std::nullopt)
        : handle(std::move(handle)), token(std::move(token)), timeout(timeout)
    { }

    void addTimeout(double timeoutSeconds);
    void complete(std::function<int(lua_State*)> cont);
    void fail(std::string error);
    void stopTimeout();

    virtual ~TCPWaiter() {
        stopTimeout();
    }
};

struct TCPReadWaiter : TCPWaiter {
    size_t amount;

    virtual std::string getTimeoutErrorMessage() const override {
        return "Read timed out";
    }

    TCPReadWaiter(std::shared_ptr<TCPStreamHandle> handle, ResumeToken token, size_t amount)
        : TCPWaiter(std::move(handle), std::move(token)), amount(amount)
    { }
};

struct TCPConnectWaiter : TCPWaiter {
    using TCPWaiter::TCPWaiter;
};
struct TCPHandshakeWaiter : TCPConnectWaiter {
    using TCPConnectWaiter::TCPConnectWaiter;
};

struct TCPCloseWaiter : TCPWaiter {
    using TCPWaiter::TCPWaiter;
};

struct TCPStreamSSLContext
{
    SSL* ssl = nullptr;
    BIO* networkIn = nullptr;
    BIO* networkOut = nullptr;
    bool handshakeCompleted = false;

    TCPStreamSSLContext(std::string_view host) {
        SSL_CTX* ctx = getSSLContext();
        ssl = SSL_new(ctx);
        if (!ssl) {
            throw std::runtime_error("Failed to create SSL object");
        }

        if (!SSL_set_tlsext_host_name(ssl, host.data())) {
            SSL_free(ssl);
            throw std::runtime_error("Failed to set TLS host name");
        }

        if (!SSL_set1_host(ssl, host.data())) {
            SSL_free(ssl);
            throw std::runtime_error("Failed to set SNI host name");
        }

        networkIn = BIO_new(BIO_s_mem());
        networkOut = BIO_new(BIO_s_mem());
        if (!networkIn || !networkOut) {
            if (networkIn) BIO_free(networkIn);
            if (networkOut) BIO_free(networkOut);
            SSL_free(ssl);
            throw std::runtime_error("Failed to create BIO objects");
        }

        SSL_set_bio(ssl, networkIn, networkOut);
        SSL_set_connect_state(ssl);
    }

    ~TCPStreamSSLContext() {
        if (ssl) {
            SSL_free(ssl);
        }
    }

private:
    static SSL_CTX* getSSLContext() {
        static SSL_CTX* ctx = []() -> SSL_CTX* {
            SSL_CTX* ctx = SSL_CTX_new(TLS_client_method());
            if (!ctx) {
                throw std::runtime_error("Failed to create SSL_CTX");
            }

            SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, NULL);
            SSL_CTX_set_read_ahead(ctx, 1);

            applySystemCASSL(ctx);

            // if (!SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION)) {
            //     SSL_CTX_free(ctx);
            //     throw std::runtime_error("Failed to set minimum protocol version for SSL_CTX");
            // }
            return ctx;
        }();

        return ctx;
    }
};

struct TCPStreamHandle : std::enable_shared_from_this<TCPStreamHandle>
{
    uv_loop_t *loop;
    TCPOptions options;
    std::unique_ptr<uvutils::TCPStream> stream;
    std::vector<std::shared_ptr<TCPWaiter>> waiters;
    std::vector<char> readBuffer;
    std::optional<TCPStreamSSLContext> sslContext;
    std::optional<std::string> pendingError;
    bool isActive = false;
    std::shared_ptr<TCPStreamHandle> self;

    TCPStreamHandle(uv_loop_t *loop, TCPOptions options)
        : loop(loop), options(options)
    { }

    void createSSLContext() {
        if (sslContext)
            return;

        try {
            sslContext.emplace(options.host);
        } catch (const std::exception& ex) {
            tokenFail(std::string("Failed to create SSL context: ") + ex.what());
        }
    }

    void beginRead() {
        stream->read(
            [this](std::string_view data)
            {
                if (sslContext) {
                    // Write to BIO so that OpenSSL can process the data
                    BIO_write(sslContext->networkIn, data.data(), static_cast<int>(data.size()));
                    readFromSSL();
                } else {
                    readBuffer.insert(readBuffer.end(), data.begin(), data.end());
                }
                
                handleReadAwaiters();
            },
            [this](std::optional<std::string> error)
            {
                if (error) {
                    pendingError = error;
                }
            }
        );
    }

    template<typename T = TCPWaiter>
    void iterateWaiters(std::function<bool(std::shared_ptr<T>& waiter)> callback) {
        auto it = waiters.begin();
        while (!waiters.empty() && it != waiters.end()) {
            auto& waiter = *it;
            if (waiter->invalid) {
                it = waiters.erase(it);
                continue;
            }

            auto typedWaiter = std::dynamic_pointer_cast<T>(waiter);
            if (typedWaiter) {
                bool result = callback(typedWaiter);
                if (!result) {
                    break;
                }
                it = waiters.erase(it);
            } else {
                ++it;
            }
        }

    }

    void handleReadAwaiters() {
        iterateWaiters<TCPReadWaiter>(
            [this](std::shared_ptr<TCPReadWaiter>& waiter) {
                if (waiter->amount != SIZE_MAX && waiter->amount > readBuffer.size())
                    return false;

                auto amount = waiter->amount == SIZE_MAX ? readBuffer.size() : waiter->amount;
                std::vector<char> buf(readBuffer.begin(), readBuffer.begin() + amount);
                readBuffer.erase(readBuffer.begin(), readBuffer.begin() + amount);

                waiter->complete(
                    [buf = std::move(buf)](lua_State* L)
                    {
                        void* luaData = lua_newbuffer(L, buf.size());
                        std::memcpy(luaData, buf.data(), buf.size());
                        return 1;
                    }
                );

                return true;
            }
        );
    }

    int handleSSLError(const std::string& context, int ret) {
        if (!sslContext)
            return -1;
        
        int err = SSL_get_error(sslContext->ssl, ret);
        switch (err) {
            case SSL_ERROR_NONE:
            case SSL_ERROR_WANT_READ:
            case SSL_ERROR_WANT_WRITE:
                return 1;
            case SSL_ERROR_ZERO_RETURN:
                pendingError = "Connection closed by peer";
                closeTransport();
                return 0;
            case SSL_ERROR_SYSCALL:
                tokenFail(context + ": SSL syscall error: " + std::string(strerror(errno)));
                closeTransport();
                return -1;
            case SSL_ERROR_SSL:
            {
                std::string error = context + ": SSL error code - ";
                char buf[ERR_ERROR_STRING_BUF_LEN];
                auto sslErr = ERR_get_error();
                while (sslErr != 0) {
                    ERR_error_string_n(sslErr, buf, ERR_ERROR_STRING_BUF_LEN);
                    error += buf;
                    error += "; ";
                    sslErr = ERR_get_error();
                }
                tokenFail(error);
                closeTransport();
                return -1;
            }
            default:
                return -1;
        }
    }

    void readFromSSL() {
        if (!sslContext)
            return;

        if (!sslContext->handshakeCompleted) {
            int ret = SSL_do_handshake(sslContext->ssl);
            flushSSL();
            if (ret == 1) {
                sslContext->handshakeCompleted = true;
                tokenComplete();
            } else {
                handleSSLError("Error during SSL handshake", ret);
                return;
            }
        }

        // Read plain text data from SSL and store it in the read buffer
        char buf[4096];
        while (true) {
            int bytesRead = SSL_read(sslContext->ssl, buf, sizeof(buf));
            flushSSL();
            if (bytesRead > 0) {
                readBuffer.insert(readBuffer.end(), buf, buf + bytesRead);
            } else if (bytesRead == 0) {
                // Connection was closed cleanly
                pendingError = "Connection closed by peer";
                closeTransport();
                break;
            } else {
                handleSSLError("Error reading from SSL", bytesRead);
                break;
            }
        }
    }

    void flushSSL(uvutils::OnStreamEnd callback = nullptr) {
        if (!sslContext)
            return;

        int amount = BIO_pending(sslContext->networkOut);
        if (amount <= 0) {
            if (callback)
                callback(std::nullopt);
            return;
        }

        char* data = new char[amount];
        int bytesRead = BIO_read(sslContext->networkOut, data, amount);
        if (bytesRead <= 0) {
            delete[] data;
            handleSSLError("Error reading from SSL network BIO", bytesRead);
            callback(pendingError);
            return;
        }

        stream->write(data, static_cast<size_t>(bytesRead), [this, data, callback](std::optional<std::string> error) {
            delete[] data;

            if (error) {
                pendingError = error;
                closeTransport();
            }

            if (callback) {
                callback(error);
            }
        });
    }

    
    void tokenFail(std::string error) {
        iterateWaiters<TCPWaiter>(
            [&error](std::shared_ptr<TCPWaiter>& waiter) {
                waiter->fail(error);
                return true;
            });
        pendingError = error;
    }
        
    int createUserData(lua_State* L) {
        auto* storage = new (static_cast<std::shared_ptr<TCPStreamHandle>*>(
            lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<TCPStreamHandle>), kTCPStreamHandleTag)
        )) std::shared_ptr<TCPStreamHandle>(shared_from_this());
        (void)storage;

        this->self.reset();

        return 1;
    }

    void tokenComplete() {
        iterateWaiters<TCPConnectWaiter>(
            [this](std::shared_ptr<TCPConnectWaiter>& waiter) {
                waiter->complete(
                    [this, waiter = std::shared_ptr<TCPConnectWaiter>(waiter)](lua_State* L) {
                        // Only create user data for the original connect waiter, not handshake
                        if (dynamic_cast<TCPHandshakeWaiter*>(waiter.get()) == nullptr) {
                            return createUserData(L);
                        }
                        return 0;
                    }
                );
                return true;
            }
        );
    }

    int connect(lua_State* L)
    {
        if (options.tls) {
            createSSLContext();
            if (!sslContext) {
                luaL_error(L, "Failed to create SSL context for TCP connection");
                return 0;
            }
        }

        struct sockaddr dest;
        switch (getHostnameType(options.host)) {
            case TCPHostnameType_IPv4:
                if (uv_ip4_addr(options.host.c_str(), options.port, (sockaddr_in*)&dest) != 0) {
                    luaL_error(L, "Invalid IPv4 address or port");
                    return 0;
                }
                break;
            case TCPHostnameType_IPv6:
            {
                if (uv_ip6_addr(options.host.c_str(), options.port, (sockaddr_in6*)&dest) != 0) {
                    luaL_error(L, "Invalid IPv6 address or port");
                    return 0;
                }
                break;
            }
            case TCPHostnameType_Domain:
            {
                uv_getaddrinfo_t resolver;
                // No callback is specified because we want it to run synchronously
                int ret = uv_getaddrinfo(loop, &resolver, nullptr, options.host.c_str(), std::to_string(options.port).c_str(), nullptr);
                if (ret != 0) {
                    luaL_error(L, "Failed to resolve hostname: %s", uv_strerror(ret));
                    return 0;
                }
                if (resolver.addrinfo == nullptr) {
                    luaL_error(L, "Hostname resolution did not return any addresses");
                    return 0;
                }
                std::memcpy(&dest, resolver.addrinfo->ai_addr, resolver.addrinfo->ai_addrlen);
                uv_freeaddrinfo(resolver.addrinfo);
                break;
            }
        }

        this->self = shared_from_this();

        stream = std::make_unique<uvutils::TCPStream>(loop, "TCPStreamHandle");
        waiters.emplace_back(std::make_shared<TCPConnectWaiter>(shared_from_this(), getResumeToken(L)));

        uv_connect_t* connectReq = new uv_connect_t;
        connectReq->data = new (std::shared_ptr<TCPStreamHandle>)(shared_from_this());

        int result = uv_tcp_connect(connectReq, stream->stream.get(), (const struct sockaddr*)&dest,
            [](uv_connect_t* req, int status)
            {
                auto* _handle = static_cast<std::shared_ptr<TCPStreamHandle>*>(req->data);
                auto handle = *_handle;
                delete _handle;
                delete req;

                if (status < 0)
                {
                    std::string error = "Connection failed: " + std::string(uv_strerror(status));
                    handle->tokenFail(error);
                    return;
                }

                handle->isActive = true;
                handle->beginRead();

                if (handle->options.tls) {
                    // Wait until the handshake is complete
                    handle->readFromSSL();
                } else {
                    handle->tokenComplete();
                }
            }
        );

        if (result < 0) {
            tokenFail("Connection initiation failed: " + std::string(uv_strerror(result)));
        }

        return lua_yield(L, 0);
    }

    int read(lua_State* L, size_t amount, double timeoutSeconds = -1) {
        // Allow reads to the connection even if the stream is closed, as long as there is enough data in the buffer.
        if (amount <= readBuffer.size()) {
            void* data = lua_newbuffer(L, amount);
            std::memcpy(data, readBuffer.data(), amount);
            readBuffer.erase(readBuffer.begin(), readBuffer.begin() + amount);
            return 1;
        }
        else {
            if (pendingError) {
                luaL_error(L, "TCP connection error: %s", pendingError->c_str());
                return 0;
            }

            if (!stream || stream->isClosed() || !isActive) {
                luaL_error(L, "TCP connection is closed");
                return 0;
            }

            if (timeoutSeconds == 0) {
                luaL_error(L, "Read timed out");
                return 0;
            }
            auto readWaiter = std::make_shared<TCPReadWaiter>(shared_from_this(), getResumeToken(L), amount);
            readWaiter->addTimeout(timeoutSeconds);
            waiters.emplace_back(std::move(readWaiter));

            return lua_yield(L, 0);
        }
    }

    int write(lua_State* L, void* data, size_t dataLen) {
        if (pendingError) {
            luaL_error(L, "TCP connection error: %s", pendingError->c_str());
            return 0;
        }

        if (!stream || stream->isClosed() || !isActive) {
            luaL_error(L, "TCP connection is closed");
            return 0;
        }

        auto token = getResumeToken(L);
        std::function<void(std::optional<std::string>)> callback = [this, token](std::optional<std::string> error) {
            if (error) {
                token->fail("Failed to write to stream: " + *error);
                closeTransport();
            }
            else {
                token->complete([](lua_State* L) {
                    return 0;
                });
            }
        };

        if (sslContext) {
            int bytesWritten = SSL_write(sslContext->ssl, data, static_cast<int>(dataLen));
            flushSSL();
            if (bytesWritten <= 0 && handleSSLError("Error writing to SSL", bytesWritten) < 0) {
                token->fail("Failed to write to SSL stream: " + (pendingError ? *pendingError : "Unknown error"));
                closeTransport();
                return lua_yield(L, 0);
            }
            flushSSL(callback);
            return lua_yield(L, 0);
        } else {
            stream->write(data, dataLen, callback);
            return lua_yield(L, 0);
        }
    }

    int close(lua_State* L) {
        if (pendingError) {
            luaL_error(L, "TCP connection error: %s", pendingError->c_str());
            return 0;
        }

        if (!stream || stream->isClosed() || !isActive) {
            luaL_error(L, "TCP connection is already closed");
            return 0;
        }

        if (sslContext) {
            int ret = SSL_shutdown(sslContext->ssl);
            if (ret == 0) {
                if (handleSSLError("Error during SSL shutdown", ret) < 0) {
                    luaL_error(L, "%s", pendingError->c_str());
                    return 0;
                }
            }
        }

        waiters.emplace_back(std::make_shared<TCPCloseWaiter>(
            shared_from_this(),
            getResumeToken(L)
        ));

        closeTransport();
        return lua_yield(L, 0);
    }

    void closeTransport() {
        isActive = false;
        if (stream && !stream->closed) {
            if (waiters.empty()) {
                // If we do the other logic in the destructor, we might get a crash, because this is gone by the time stream is closed
                stream->close([]() {});
            } else {
                stream->close([this]() {
                    iterateWaiters<TCPCloseWaiter>(
                        [](std::shared_ptr<TCPCloseWaiter>& waiter) {
                            waiter->complete([](lua_State* L) { return 0; } );
                            return true;
                        });
                    closeTransport();
                    this->self.reset();
                });
                return;
            }
        }

        if (!pendingError)
            pendingError = "Connection closed";

        iterateWaiters<TCPWaiter>(
            [this](std::shared_ptr<TCPWaiter>& waiter) {
                waiter->fail(*pendingError);
                return true;
            }
        );
        waiters.clear();
    }

    ~TCPStreamHandle()
    {
        closeTransport();
    }
};

void TCPWaiter::addTimeout(double timeoutSeconds) {
    if (timeoutSeconds > 0) {
        auto timer = new uv_timer_t;
        timer->data = new (std::shared_ptr<TCPWaiter>)(this->shared_from_this());
        uv_timer_init(this->handle->loop, timer);
        uv_timer_start(timer, [](uv_timer_t* timer) {
            if (timer->data) {
                auto waiter_ptr = static_cast<std::shared_ptr<TCPWaiter>*>(timer->data);
                auto& waiter = *waiter_ptr;
                waiter->timeout = std::nullopt;
                waiter->fail(waiter->getTimeoutErrorMessage());
            } else {
                uv_timer_stop(timer);
                uv_close((uv_handle_t*)timer, [](uv_handle_t* handle) {
                    auto* timer = reinterpret_cast<uv_timer_t*>(handle);
                    delete timer;
                });
            }
        }, static_cast<uint64_t>(timeoutSeconds * 1000), 0);
        this->timeout = timer;
    }
}

void TCPWaiter::complete(std::function<int(lua_State*)> cont) {
    if (invalid)
        return;

    auto tokenCopy = token;
    invalid = true;
    stopTimeout();

    tokenCopy->complete(std::move(cont));
}

void TCPWaiter::fail(std::string error) {
    if (invalid)
        return;

    auto tokenCopy = token;
    invalid = true;
    stopTimeout();

    tokenCopy->fail(std::move(error));
}

void TCPWaiter::stopTimeout()
{
    if (timeout && *timeout) {
        auto timer = *timeout;
        timeout = std::nullopt;

        auto waiter_ptr = static_cast<std::shared_ptr<TCPWaiter>*>(timer->data);
        if (waiter_ptr) {
            auto& waiter = *waiter_ptr;
            waiter->timeout = std::nullopt;
            delete waiter_ptr;
        }

        uv_timer_stop(timer);
        uv_close((uv_handle_t*)timer, [](uv_handle_t* handle) {
            auto* timer = reinterpret_cast<uv_timer_t*>(handle);
            delete timer;
        });
    }
}

std::shared_ptr<TCPStreamHandle>* getTCPStreamHandle(lua_State* L, int index)
{
    return static_cast<std::shared_ptr<TCPStreamHandle>*>(lua_touserdatatagged(L, index, kTCPStreamHandleTag));
}

int tcp_read(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->pendingError)
    {
        std::string error = "";
        if (handleStorage && *handleStorage && (*handleStorage)->pendingError)
            error += ": " + (*handleStorage)->pendingError.value();
        luaL_error(L, "Invalid or closed TCP connection: %s", error.c_str());
        return 0;
    }

    TCPStreamHandle* handle = (*handleStorage).get();

    // A nil amount means to read everything currently in the buffer
    int _amount = -1;
    if (lua_isnumber(L, 2)) {
        _amount = lua_tointeger(L, 2);
    }
    size_t amount = _amount < 0 ? SIZE_MAX : static_cast<size_t>(_amount);
    
    double timeoutSeconds = -1;
    if (_amount < 0 && lua_isuserdata(L, 2)) {
        // Didn't read a number at index 2, but there is a userdata, which must be the duration
        timeoutSeconds = getSecondsFromTimespec(getTimespecFromDuration(L, 2));
    } else if (lua_isuserdata(L, 3)) {
        timeoutSeconds = getSecondsFromTimespec(getTimespecFromDuration(L, 3));
    }

    return handle->read(L, amount, timeoutSeconds);
}

int tcp_write(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->pendingError)
    {
        std::string error = "";
        if (handleStorage && *handleStorage && (*handleStorage)->pendingError)
            error += ": " + (*handleStorage)->pendingError.value();
        luaL_error(L, "Invalid or closed TCP connection: %s", error.c_str());
    }

    size_t dataLen;
    void* data;

    if (lua_isstring(L, 2))
    {
        data = (void*)lua_tolstring(L, 2, &dataLen);
    }
    else if (lua_isbuffer(L, 2))
    {
        data = luaL_checkbuffer(L, 2, &dataLen);
    } else {
        luaL_error(L, "Data must be a string or buffer");
        return 0;
    }

    TCPStreamHandle* handle = (*handleStorage).get();
    return handle->write(L, data, dataLen);
}

int tcp_close(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage))
        luaL_error(L, "Invalid TCP connection");
    if ((*handleStorage)->stream->closed)
        luaL_error(L, "TCP connection already closed");

    return (*handleStorage)->close(L);
}

int tcp_handshake(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->pendingError)
    {
        std::string error = "";
        if (handleStorage && *handleStorage && (*handleStorage)->pendingError)
            error += ": " + (*handleStorage)->pendingError.value();
        luaL_error(L, "Invalid or closed TCP connection: %s", error.c_str());
        return 0;
    }

    TCPStreamHandle* handle = (*handleStorage).get();
    if (handle->sslContext) {
        luaL_error(L, "Handshake has already been completed for this connection");
        return 0;
    }

    handle->createSSLContext();
    if (!handle->sslContext) {
        luaL_error(L, "Failed to create SSL context");
        return 0;
    }

    handle->waiters.emplace_back(std::make_shared<TCPHandshakeWaiter>(
        handle->shared_from_this(),
        getResumeToken(L),
        std::nullopt
    ));

    handle->readFromSSL();
    
    return lua_yield(L, 0);
}

int connect(lua_State* L)
{
    TCPOptions options;
    if (lua_istable(L, 1)) {
        lua_getfield(L, 1, "hostname");
        options.host = luaL_checkstring(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 1, "port");
        options.port = luaL_optinteger(L, -1, -1);
        lua_pop(L, 1);
        
        lua_getfield(L, 1, "tls");
        options.tls = lua_toboolean(L, -1);
        lua_pop(L, 1);
    } else {
        options.host = luaL_checkstring(L, 1);
        options.port = luaL_optinteger(L, 2, -1);
        options.tls = false;
    }

    if (options.port < 0 || options.port > 65535) {
        luaL_error(L, "Invalid port number");
        return 0;
    }

    auto* loop = getRuntimeLoop(L);
    auto token = getResumeToken(L);

    auto handle = std::make_shared<TCPStreamHandle>(loop, options);
    return handle->connect(L);
}

} // namespace net::client
