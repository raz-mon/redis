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
        assert_error {*unknown command*} {r internalauth.internall_rm_call 0 internalauth.internalcommand}

        # Authenticate as an internal connection.
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]

        # Succeed
        assert_equal {OK} [r internalauth.internall_rm_call 0 internalauth.internalcommand]
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {RM_Call with the `C` flag after setting thread-safe-context should fail} {
        # New threadSafeContexts do not inherit the internal flag.
        assert_error {*unknown command*} {r internalauth.internall_rm_call 1 internalauth.internalcommand}
    }
}

start_server {tags {"modules"} overrides {save {}}} {
    r module load $testmodule

    r config set appendonly yes
    r config set appendfsync always
    waitForBgrewriteaof r

    test {AOF executes internal commands successfully} {
        # Authenticate as an internal connection
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]

        # Call an internal writing command
        assert_equal {OK} [r internalauth.internall_rm_call 2 set x 5]

        # Reload the server from the AOF
        r debug loadaof

        # Check if the internal command was executed successfully
        assert_equal {5} [r get x]
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {Internal commands are not allowed from scripts} {
        # Internal commands are not allowed from scripts
        assert_error {*not allowed from script*} {r eval {redis.call('internalauth.internalcommand')} 0}

        # Even after authenticating as an internal connection
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]
        assert_error {*not allowed from script*} {r eval {redis.call('internalauth.internalcommand')} 0}

        # Internal commands ARE shown in monitor output
        set rd [redis_deferring_client]
        $rd monitor
        $rd read ; # Discard the OK
        catch {r eval {redis.call('internalauth.internalcommand')} 0} err
        assert_match "*not allowed from script*" $err
        assert_match {*eval*internalauth.internalcommand*} [$rd read]
        # No following log, since the command failed.
        $rd close
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {Setup master} {
        # Authenticate as an internal connection
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]
    }

    start_server {tags {"modules"}} {
        set master [srv -1 client]
        set master_host [srv -1 host]
        set master_port [srv -1 port]
        set slave [srv 0 client]
        $slave module load $testmodule

        test {Slaves successfully execute internal commands} {
            $slave slaveof $master_host $master_port
            wait_for_condition 50 100 {
                [s 0 master_link_status] eq {up}
            } else {
                fail "Replication not started."
            }

            # Execute internal command in master, that will set `x` to `5`.
            assert_equal {OK} [$master internalauth.internall_rm_call 2 set x 5]
            wait_for_ofs_sync $master $slave

            # See that the slave has the same value for `x`.
            assert_equal {5} [$slave get x]
        }
    }
}

start_server {tags {"modules"}} {
    r module load $testmodule

    test {Internal commands are reported in the slowlog} {
        # Authenticate as an internal connection
        set reply [r internalauth.getinternalsecret]
        assert_equal {OK} [r internalauth $reply]

        # Set up slowlog to log all commands
        r config set slowlog-log-slower-than 0

        # Execute an internal command
        r slowlog reset
        r internalauth.internalcommand

        # The slow-log should contain the internal command
        set log [r slowlog get 1]
        assert_match {*internalauth.internalcommand*} $log
    }

    test {Internal commands are reported in the monitor output} {
        # Execute an internal command
        set rd [redis_deferring_client]
        $rd monitor
        $rd read ; # Discard the OK
        r internalauth.internalcommand
        assert_match {*internalauth.internalcommand*} [$rd read]
        $rd close
    }

    test {Internal commands are reported in the latency report} {
        # The latency report should contain the internal command
        set report [r latency histogram internalauth.internalcommand]
        assert_match {*internalauth.internalcommand*} $report
    }

    test {Internal commands are reported in the command stats report} {
        # Execute an internal command
        r internalauth.internalcommand

        # The INFO report should contain the internal command
        set report [r info commandstats]
        assert_match {*internalauth.internalcommand*} $report

        set report [r info latencystats]
        assert_match {*internalauth.internalcommand*} $report
    }
}
