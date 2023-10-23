# The Fastly VCL boilerplate.
include "breadcrumbs.vcl";

sub vcl_recv {
	call debug_info_recv;
	#FASTLY RECV

	# Give every request a unique ID.
	if (!req.http.X-Request-Id) {
		set req.http.X-Request-Id = digest.hash_sha256(now randomstr(64) req.http.host req.url req.http.Fastly-Client-IP server.identity);
	}

	# Enable API key authentication for URL purge requests
	if ( req.method == "FASTLYPURGE" ) {
		set req.http.Fastly-Purge-Requires-Auth = "1";
	}

	# Sets the alt-svc header on the client response.
	# When a client connection is using a version of HTTP older than HTTP/3,
	# invoking this function triggers Fastly to advertise HTTP/3 support,
	# on the eventual client response, allowing the client to switch to HTTP/3 for future requests.
	h3.alt_svc();

	if (req.restarts == 0) {
		set req.backend = F_compute_at_edge;
	} else {
		set req.backend = F_fly;
	}

	if (req.method != "HEAD" && req.method != "GET" && req.method != "FASTLYPURGE") {
		return (pass);
	}

	return (lookup);
}

sub vcl_hash {
	#FASTLY hash

	set req.hash += req.url;
	set req.hash += req.http.host;

	call debug_info_hash;

	return(hash);
}

sub vcl_miss {
	#FASTLY miss
	call debug_info_miss;
	return (fetch);
}

sub vcl_pass {
	#FASTLY pass
	call debug_info_pass;
}

sub vcl_fetch {
	#FASTLY fetch
	call debug_info_fetch;

	# Serve stale objects on a backend error.
	if (http_status_matches(beresp.status, "500,502,503,504")) {
		if (stale.exists) {
			return(deliver_stale);
		}

		if (req.restarts < 1 && (req.method == "GET" || req.method == "HEAD")) {
			restart;
		}
	}


	if (req.restarts > 0) {
		set beresp.http.Fastly-Restarts = req.restarts;
	}


	return (deliver);
}

sub vcl_deliver {
	call debug_info_deliver;
	call debug_info_send;

	#FASTLY deliver
	return (deliver);
}

sub vcl_error {
	#FASTLY error
	call debug_info_error;

	if (http_status_matches(obj.status, "500,502,503,504")) {
		if (stale.exists) {
			return(deliver_stale);
		} else if (req.restarts == 0) {
			restart;
		}
		return(deliver);
	}
}

sub vcl_log {
#FASTLY log
}
