const beam = @import("beam.zig");
const e = @import("erl_nif.zig");

const PidError = error{ NotProcessBound, NotDelivered };

pub fn self(env: beam.env) PidError!beam.pid {
    var pid: beam.pid = undefined;
    if (e.enif_self(env, &pid)) |result| {
        return result;
    } else {
        return error.NotProcessBound;
    }
}

pub fn send(env: beam.env, dest: beam.pid, content: anytype, opts: anytype) PidError!beam.term {
    const term = beam.make(env, content, opts);
    var pid = dest;
    // disable this in sema because pid pointers are not supported

    if (beam.is_sema) {
        unreachable;
    } else {
        switch (beam.context) {
            .process_bound, .callback => {
                if (e.enif_send(env, &pid, null, term.v) == 0) return error.NotDelivered;
            },
            .threaded, .dirty, .yielding => {
                if (e.enif_send(null, &pid, env, term.v) == 0) return error.NotDelivered;
            },
        }
        return term;
    }
}
