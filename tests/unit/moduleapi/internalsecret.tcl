set testmodule [file normalize tests/modules/internalsecret.so]

start_server {tags {"modules"}} {
    r module load $testmodule

    test {Internal command without internal connection fails} {
        assert_error {*unknown command*} {r internalauth.internalcommand}
    }

    test {Wrong internalsecret fails authentication} {
        assert_error {*WRONGPASS invalid internal password*} {r internalauth 123}
    }

    test {Internal connection basic flow} {
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]
        assert_equal {OK} [r internalauth.internalcommand]
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {Test `COMMAND *` commands with\without internal connections} {
        # ------------------ Non-internal connection ------------------
        # `COMMAND DOCS <cmd>` returns empty response.
        assert_equal {} [r command docs internalauth.internalcommand]

        # `COMMAND INFO <cmd>` should reply with null for the internal command
        assert_equal {{}} [r command info internalauth.internalcommand]

        # `COMMAND GETKEYS/GETKEYSANDFLAGS <cmd> <args>` returns an invalid command error
        assert_error {*Invalid command specified*} {r command getkeys internalauth.internalcommand}
        assert_error {*Invalid command specified*} {r command getkeysandflags internalauth.internalcommand}

        # -------------------- Internal connection --------------------
        # Non-empty response for non-internal connections.
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]

        # `COMMAND DOCS <cmd>` returns a correct response.
        assert_match {*internalauth.internalcommand*} [r command docs internalauth.internalcommand]

        # `COMMAND INFO <cmd>` should reply with a full response for the internal command
        assert_match {*internalauth.internalcommand*} [r command info internalauth.internalcommand]

        # `COMMAND GETKEYS/GETKEYSANDFLAGS <cmd> <args>` returns a key error (not related to the internal connection)
        assert_error {*ERR The command has no key arguments*} {r command getkeys internalauth.internalcommand}
        assert_error {*ERR The command has no key arguments*} {r command getkeysandflags internalauth.internalcommand}
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {No authentication needed for internal connections} {
        # Authenticate with a user that does not have permissions to any command
        r acl setuser David on >123 &* ~* -@all +internalauth +internalauth.getinternalsecret
        assert_equal {OK} [r auth David 123]

        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]
        assert_equal {OK} [r internalauth.internalcommand]
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {RM_Call of internal commands succeeds only for internal connections} {
        # Fail before authenticating as an internal connection.
        assert_error {*unknown command*} {r internalauth.rm_call_withclient internalauth.internalcommand}

        # Authenticate as an internal connection.
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]

        # Succeed
        assert_equal {OK} [r internalauth.rm_call_withclient internalauth.internalcommand]
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {RM_Call with the `C` flag after setting thread-safe-context should fail} {
        # New threadSafeContexts do not inherit the internal flag.
        assert_error {*unknown command*} {r internalauth.rm_call_withclient_detached_context internalauth.internalcommand}
    }
}

start_server {tags {"modules"} overrides {save {}}} {
    r module load $testmodule

    r config set appendonly yes
    r config set auto-aof-rewrite-percentage 0 ; # Disable auto-rewrite.
    waitForBgrewriteaof r

    test {AOF executes internal commands successfully} {
        # Authenticate as an internal connection
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]

        # Call an internal writing command
        assert_equal {OK} [r internalauth.internall_rm_call set x 5]

        r bgrewriteaof
        waitForBgrewriteaof r

        # Reload the server from the AOF
        r debug loadaof

        # Check if the internal command was executed successfully
        assert_equal {5} [r get x]
    }
}
