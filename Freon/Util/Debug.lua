return {
    Errors = {
        EmptyInitialTable = "Freon.new() was called with empty default state.",
        AttemptGetOnExpiredKey = "Attempt to get an expired key (%s) | Expired %i second(s) ago.",
        AttemptToPushNonReplicableState = "Attempted to Push State (Key: %s) to client, but recipients are not defined.",
        DuplicateKey = "Key '%s' is already defined.",
        MaxAwaitTimeoutReached = "Maximum Waiting Period Reached for await(%s). This will return nil.",
        AttemptedPushFromClient = "Attempt to push Key (%s) from client. Client should never be trusted with state.",
        AttemptDirectChange = "Attempted to modify read only variable. Use functions to modify state."
    },

    Warn = function(Error: string, ...)
        warn("[Freon] " .. Error:format(...))
    end,

    Error = function(Error: string, ...)
        error("[Freon] " .. Error:format(...))
        warn(debug.traceback(3))
    end
}



