set testmodule [file normalize tests/modules/internalsecret.so]

start_server {tags {"modules"}} {
    r module load $testmodule

    test {Test internal command without internal connection} {
        assert_error {*unknown command*} {r internalauth.internalcommand}
    }

    test {Test wrong internalsecret} {
        assert_error {*WRONGPASS invalid internal password*} {r internalauth 123}
    }

    test {Test internal connection flow basic} {
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

    # Additional tests to add:
        # Internal connections can bypass ACL permissions.
        # Internal connections can bypass ACL users (no authentication needed).
        # Internal connections can execute internal commands in lua scripts from internal connections.
        # Internal commands are showed in the SlowLog, CommandStats, and latency report.
        # Slave executes internal commands from the master (arrive via the replication link) successfully always.
        # AOF can execute internal commands.
        # RM_Call needs handling as well (probably). We WANT to allow modules to call internal commands.
        # redis-cli does not show `INTERNALAUTH` in history.
