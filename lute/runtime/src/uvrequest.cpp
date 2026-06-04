#include "lute/uvrequest.h"

#include "uv.h"

namespace uvutils
{

// UV request cleanup specializations
template<>
void cleanup_uv_req<uv_fs_t>(uv_fs_t* req)
{
    uv_fs_req_cleanup(req);
}

} // namespace uvutils
