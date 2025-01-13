#include "redismodule.h"

int InternalAuth_GetInternalSecret(RedisModuleCtx *ctx, RedisModuleString **argv, int argc) {
    REDISMODULE_NOT_USED(argv);
    REDISMODULE_NOT_USED(argc);

    size_t len;
    const char *secret = RedisModule_GetInternalSecret(ctx, &len);
    RedisModule_ReplyWithStringBuffer(ctx, secret, len);
    return REDISMODULE_OK;
}

int InternalAuth_InternalCommand(RedisModuleCtx *ctx, RedisModuleString **argv, int argc) {
    REDISMODULE_NOT_USED(argv);
    REDISMODULE_NOT_USED(argc);

    RedisModule_ReplyWithSimpleString(ctx, "OK");
    return REDISMODULE_OK;
}

/* This function must be present on each Redis module. It is used in order to
 * register the commands into the Redis server. */
int RedisModule_OnLoad(RedisModuleCtx *ctx, RedisModuleString **argv, int argc) {
    REDISMODULE_NOT_USED(argv);
    REDISMODULE_NOT_USED(argc);

    if (RedisModule_Init(ctx,"testinternalsecret",1,REDISMODULE_APIVER_1)
        == REDISMODULE_ERR) return REDISMODULE_ERR;

    /* WARNING: A module shoule NEVER expose the internal secret - this is for
     * testing purposes only. */
    if (RedisModule_CreateCommand(ctx,"internalauth.getinternalsecret",
        InternalAuth_GetInternalSecret,"",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    /* */
    if (RedisModule_CreateCommand(ctx,"internalauth.internalcommand",
        InternalAuth_InternalCommand,"internal",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    return REDISMODULE_OK;
}
