#include "redismodule.h"
#include <errno.h>

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

/* A wrap for RM_Call that pass the 'C' flag to pass the current client. */
int rm_call_withclient(RedisModuleCtx *ctx, RedisModuleString **argv, int argc){
    if(argc < 2){
        return RedisModule_WrongArity(ctx);
    }

    const char* cmd = RedisModule_StringPtrLen(argv[1], NULL);

    RedisModuleCallReply* rep = RedisModule_Call(ctx, cmd, "vC", argv + 2, argc - 2);
    if(!rep) {
        char err[100];
        switch (errno) {
            case EACCES:
                RedisModule_ReplyWithError(ctx, "ERR NOPERM");
                break;
            case ENOENT:
                RedisModule_ReplyWithError(ctx, "ERR unknown command");
            default:
                snprintf(err, sizeof(err) - 1, "ERR errno=%d", errno);
                RedisModule_ReplyWithError(ctx, err);
                break;
        }
    } else {
        RedisModule_ReplyWithCallReply(ctx, rep);
        RedisModule_FreeCallReply(rep);
    }

    return REDISMODULE_OK;
}

int rm_call_withclient_detached_context(RedisModuleCtx *ctx, RedisModuleString **argv, int argc){
    if(argc < 2){
        return RedisModule_WrongArity(ctx);
    }

    RedisModuleCtx *detached_ctx = RedisModule_GetDetachedThreadSafeContext(ctx);
    if(!detached_ctx){
        RedisModule_ReplyWithError(ctx, "ERR failed to create detached context");
        return REDISMODULE_ERR;
    }

    const char* cmd = RedisModule_StringPtrLen(argv[1], NULL);

    RedisModuleCallReply* rep = RedisModule_Call(detached_ctx, cmd, "vC", argv + 2, argc - 2);
    if(!rep) {
        char err[100];
        switch (errno) {
            case EACCES:
                RedisModule_ReplyWithError(ctx, "ERR NOPERM");
                break;
            case ENOENT:
                RedisModule_ReplyWithError(ctx, "ERR unknown command");
            default:
                snprintf(err, sizeof(err) - 1, "ERR errno=%d", errno);
                RedisModule_ReplyWithError(ctx, err);
                break;
        }
    } else {
        RedisModule_ReplyWithCallReply(ctx, rep);
        RedisModule_FreeCallReply(rep);
    }

    RedisModule_FreeThreadSafeContext(detached_ctx);
    return REDISMODULE_OK;
}

/* Calls the command given as arguments. Registered as an internal command. */
int internall_rm_call(RedisModuleCtx *ctx, RedisModuleString **argv, int argc) {
    if(argc < 2){
        return RedisModule_WrongArity(ctx);
    }

    const char* cmd = RedisModule_StringPtrLen(argv[1], NULL);

    RedisModuleCallReply* rep = RedisModule_Call(ctx, cmd, "vC", argv + 2, argc - 2);
    if(!rep) {
        char err[100];
        switch (errno) {
            case EACCES:
                RedisModule_ReplyWithError(ctx, "ERR NOPERM");
                break;
            case ENOENT:
                RedisModule_ReplyWithError(ctx, "ERR unknown command");
            default:
                snprintf(err, sizeof(err) - 1, "ERR errno=%d", errno);
                RedisModule_ReplyWithError(ctx, err);
                break;
        }
    } else {
        RedisModule_ReplyWithCallReply(ctx, rep);
        RedisModule_FreeCallReply(rep);
    }

    return REDISMODULE_OK;
}

/* This function must be present on each Redis module. It is used in order to
 * register the commands into the Redis server. */
int RedisModule_OnLoad(RedisModuleCtx *ctx, RedisModuleString **argv, int argc) {
    REDISMODULE_NOT_USED(argv);
    REDISMODULE_NOT_USED(argc);

    if (RedisModule_Init(ctx,"testinternalsecret",1,REDISMODULE_APIVER_1)
        == REDISMODULE_ERR) return REDISMODULE_ERR;

    /* WARNING: A module should NEVER expose the internal secret - this is for
     * testing purposes only. */
    if (RedisModule_CreateCommand(ctx,"internalauth.getinternalsecret",
        InternalAuth_GetInternalSecret,"",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    if (RedisModule_CreateCommand(ctx,"internalauth.internalcommand",
        InternalAuth_InternalCommand,"internal",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    if (RedisModule_CreateCommand(ctx,"internalauth.rm_call_withclient",
        rm_call_withclient,"write",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    if (RedisModule_CreateCommand(ctx,"internalauth.rm_call_withclient_detached_context",
        rm_call_withclient_detached_context,"write",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    if (RedisModule_CreateCommand(ctx,"internalauth.internall_rm_call",
        internall_rm_call,"write internal",0,0,0) == REDISMODULE_ERR)
        return REDISMODULE_ERR;

    return REDISMODULE_OK;
}
