vcl 4.0;

backend default {
    .host = "127.0.0.1";
    .port = "8080";  # Port where HAProxy listens
}

sub vcl_backend_response {
    # Cache /long_dummy route for 60 seconds
    if (bereq.url ~ "^/long_dummy") {
        set beresp.ttl = 60s;
        set beresp.uncacheable = false;
        return (deliver);
    }
}