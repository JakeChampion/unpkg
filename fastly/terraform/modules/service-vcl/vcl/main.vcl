# The Fastly VCL boilerplate.
include "fastly-boilerplate-begin.vcl";

include "breadcrumbs.vcl";

sub vcl_recv {
	# Sets the alt-svc header on the client response.
	# When a client connection is using a version of HTTP older than HTTP/3,
	# invoking this function triggers Fastly to advertise HTTP/3 support,
	# on the eventual client response, allowing the client to switch to HTTP/3 for future requests.
	h3.alt_svc();

	if (req.http.Fastly-Debug) {
		call breadcrumb_recv;
	}
	if (req.restarts == 0) {
		set req.backend = F_compute_at_edge;
	} else {
		set req.backend = F_fly;
	}
}

sub vcl_hash {
	if (req.http.Fastly-Debug) {
		call breadcrumb_hash;
	}
}

sub vcl_miss {
	if (req.http.Fastly-Debug) {
		call breadcrumb_miss;
	}
}

sub vcl_pass {
	if (req.http.Fastly-Debug) {
		call breadcrumb_pass;
	}
}

sub vcl_fetch {
	if (req.http.Fastly-Debug) {
		call breadcrumb_fetch;
	}

	set beresp.http.Timing-Allow-Origin = "*";

	# We end up here if
	# - The origin is HEALTHY; and
	# - It returned a valid HTTP response
	#
	# We may still not want to *use* that response, if it's an HTTP error,
	# so that's the case we need to catch here.
	if (beresp.status >= 500 && beresp.status < 600) {
		# There's a stale version available! Serve it.
		if (stale.exists) {
			return(deliver_stale);
		} else if (req.restarts == 0) {
			restart;
		}
		# Cache the error for 1s to allow it to be used for any collapsed requests
		set beresp.cacheable = true;
		set beresp.ttl = 1s;
		return(deliver);
	}
}

sub vcl_deliver {
	if (req.http.Fastly-Debug) {
		call breadcrumb_deliver;
	}

	add resp.http.Server-Timing = fastly_info.state {", fastly;desc="Edge time";dur="} time.elapsed.msec;

	if (req.http.Fastly-Debug) {
		set resp.http.Debug-Backend = req.http.Debug-Backend;
		set resp.http.Debug-Host = req.http.Host;
		set resp.http.Debug-Fastly-Restarts = req.restarts;
		set resp.http.Debug-Orig-URL = req.http.Orig-URL;
		set resp.http.Debug-VCL-Route = req.http.X-VCL-Route;
	} else {
		unset resp.http.Server;
		unset resp.http.Via;
		unset resp.http.X-Cache;
		unset resp.http.X-Cache-Hits;
		unset resp.http.X-Served-By;
		unset resp.http.X-Timer;
		unset resp.http.Fastly-Restarts;
		unset resp.http.X-PreFetch-Pass;
		unset resp.http.X-PreFetch-Miss;
		unset resp.http.X-PostFetch;
	}
}

sub vcl_error {
	if (obj.status >= 500 && obj.status < 600) {
		if (stale.exists) {
			return(deliver_stale);
		} else if (req.restarts == 0) {
			restart;
		}
		return(deliver);
	}
}

# Finally include the last bit of VCL, this _must_ be last!
include "fastly-boilerplate-end.vcl";
