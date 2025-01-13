set testmodule [file normalize tests/modules/internalsecret.so]

start_server {tags {"modules"}} {
    r module load $testmodule

    test {test internalsecret basics} {
        assert_error {*unknown command*} {r internalauth.internalcommand}
    }

    test {test internalsecret command} {
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]
        assert_equal {OK} [r internalauth.internalcommand]
    }

    test {test wrong internalsecret} {
        assert_error {*WRONGPASS invalid internal password*} {r internalauth 123}
    }

    # Additional tests to add:
        # Internal connections can bypass ACL permissions.
        # Internal connections can bypass ACL users (no authentication needed).
        # Internal connections can execute internal commands in lua scripts from internal connections.
        # Internal commands are not showed in the SlowLog, Monitor, CommandStats, and latency report (anywhere else?).
        # Slave executes internal commands from the master (arrive via the replication link).
        # AOF can execute internal commands.
        # RM_Call needs handling as well (?).

}
