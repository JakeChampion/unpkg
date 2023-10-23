# This file sets a X-VCL-Route response header.
#
# X-VCL-Route has a baseline format of:
#
# pop: <value>, node: <value>, state: <value>, host: <value>, path: <value>
#
# pop  = the POP where the request is currently passing through.
# node  = whether the cache node is a delivery node or fetching node (see: https://www.integralist.co.uk/posts/fastly-varnish/#4.2).
# state = internal fastly variable that reports state flow as well as whether a request waited for request collapsing or whether it was clustered.
# host  = the full host name, without the path or query parameters.
# path   = the full path, including query parameters.
#
# Additional to this baseline we include information relevant to the subroutine state.

sub debug_info_recv {
	declare local var.context STRING;
	set var.context = "";

	if (req.restarts > 0) {
		set var.context = req.http.X-VCL-Route + ", ";
	}

	set req.http.X-VCL-Route = var.context + "VCL_RECV(" +
		"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
		"node: cluster_edge, " +
		"state: " + fastly_info.state + ", " +
		"host: " + req.http.host + ", " +
		"backend: " + req.backend + ", " +
		"path: " + req.url +
		")";
}

sub debug_info_hash {
	set req.http.X-VCL-Route = req.http.X-VCL-Route + ", VCL_HASH(" +
	"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
	"node: cluster_edge, " +
	"state: " + fastly_info.state + ", " +
	"host: " + req.http.host + ", " +
	"backend: " + req.backend + ", " +
	"path: " + req.url +
	")";
}

sub debug_info_miss {
	set req.http.X-PreFetch-Miss = ", VCL_MISS(" +
	"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) " [" server.datacenter ", " server.hostname "], " +
	"node: cluster_" + if(fastly_info.is_cluster_shield, "shield", "edge") + ", " +
	"state: " + fastly_info.state + ", " +
	"host: " + bereq.http.host + ", " +
	"backend: " + req.backend + ", " +
	"path: " + bereq.url +
	")";
}

sub debug_info_pass {
	set req.http.X-PreFetch-Pass = ", " if(fastly_info.state ~ "^HITPASS", "VCL_HIT", "VCL_PASS") "(" +
	"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
	"node: cluster_" + if(fastly_info.is_cluster_shield, "shield", "edge") + ", " +
	"state: " + fastly_info.state + ", " +
	"host: " + req.http.host + ", " +
	"backend: " + req.backend + ", " +
	"path: " + req.url + ", " +
	")";
}

sub debug_info_fetch {
	set beresp.http.X-Track-VCL-Route = req.http.X-VCL-Route;
	set beresp.http.X-PreFetch-Pass = req.http.X-PreFetch-Pass;
	set beresp.http.X-PreFetch-Miss = req.http.X-PreFetch-Miss;
	set beresp.http.X-PostFetch = ", VCL_FETCH(" +
	"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
	"node: cluster_" + if(fastly_info.is_cluster_shield, "shield", "edge") + ", " +
	"state: " + fastly_info.state + ", " +
	"host: " + req.http.host + ", " +
	"backend: " + req.backend + ", " +
	"path: " + req.url + ", " +
	"status: " + beresp.status + ", " +
	"stale: " + if(stale.exists, "exists", "none") + ", " +
	if(beresp.http.Cache-Control ~ "private", "cache_control: private, return: pass", "return: deliver") +
	")";
}

sub debug_info_error {
	declare local var.error_page BOOL;
	set var.error_page = false;

	set obj.http.X-VCL-Route = req.http.X-VCL-Route + ", VCL_ERROR(" +
	"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
	"node: cluster_" + if(fastly_info.is_cluster_shield, "shield", "edge") + ", " +
	"state: " + fastly_info.state + ", " +
	"host: " + req.http.host + ", " +
	"backend: " + req.backend.name + ", " +
	"path: " + req.url + ", " +
	"status: " + obj.status + ", " +
	"stale: " + if(stale.exists, "exists", "none") + ", " +
	")";
}

sub debug_info_deliver {
	# only track the previous route flow if we've come from vcl_fetch
	# otherwise we'll end up displaying the uncached request flow as
	# part of this cache hit request flow (which would be confusing).
	if (resp.http.X-Track-VCL-Route && fastly_info.state ~ "^(MISS|PASS)") {
		set req.http.X-VCL-Route = resp.http.X-Track-VCL-Route;

		if (resp.http.X-PreFetch-Pass) {
			set req.http.X-VCL-Route = req.http.X-VCL-Route + resp.http.X-PreFetch-Pass;
		}

		if (resp.http.X-PreFetch-Miss) {
			set req.http.X-VCL-Route = req.http.X-VCL-Route + resp.http.X-PreFetch-Miss;
		}

		if (resp.http.X-PostFetch) {
			set req.http.X-VCL-Route = req.http.X-VCL-Route + resp.http.X-PostFetch;
		}
	} elseif (fastly_info.state ~ "^ERROR") {
		# otherwise track in the request object any request flow information that has occurred from an error request flow
		# which should include either the original vcl_fetch flow or the vcl_hit flow.
		set req.http.X-VCL-Route = resp.http.X-VCL-Route;
	} elseif (fastly_info.state ~ "^HIT($|-)") {
		# otherwise track the initial vcl_hit request flow.
		set req.http.X-VCL-Route = req.http.X-VCL-Route + ", VCL_HIT(" +
		"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
		"node: cluster_shield, " +
		"state: " + fastly_info.state + ", " +
		"host: " + req.http.host + ", " +
		"backend: " + req.backend.name + ", " +
		"path: " + req.url + ", " +
		"status: " + resp.status + ", " +
		"cacheable: true, " +
		"return: deliver" +
		")";
	}

	# used to extend the baseline X-VCL-Route (set below)
	declare local var.context STRING;
	set var.context = "";

	# there is one state subroutine that we have no way of tracking information for: vcl_hit
	# this is because the only object we have available with R/W access is the req object
	# and modifications to the req object don't persiste from cluster node to edge node (e.g. vcl_deliver)
	# this means we need to utilise fastly's internal state to see if we came from vcl_hit.
	#
	# we also use this internal state variable to help identify other states progressions such as
	# STALE (stale content found in case of an error) and ERROR (we've arrived to vcl_deliver from vcl_error).
	#
	# Documentation (fastly_info.state):
	# https://support.fastly.com/hc/en-us/community/posts/360040168391/comments/360004718351
	if (fastly_info.state ~ "^HITPASS") {
		set var.context = ", cacheable: uncacheable, return: pass";
	} elseif (fastly_info.state ~ "^ERROR") {
		set var.context = ", custom_error_page: " + resp.http.CustomErrorPage;
	}

	set req.http.X-VCL-Route = req.http.X-VCL-Route + ", VCL_DELIVER(" +
	"pop: " + if(req.backend.is_shield, "edge", if(fastly.ff.visits_this_service < 2, "edge", "shield")) + " [" + server.datacenter + ", " + server.hostname + "], " +
	"node: cluster_edge, " +
	"state: " + fastly_info.state + ", " +
	"host: " + req.http.host + ", " +
	"backend: " + req.backend.name + ", " +
	"path: " + req.url + ", " +
	"status: " + resp.status + ", " +
	"stale: " + if(stale.exists, "exists", "none") +
	var.context +
	")";
}

# this subroutine must be placed BEFORE the vcl_deliver macro `#FASTLY deliver`
# otherwise the setting of Fastly-Debug within this subroutine will have no effect.
sub debug_info_send {
	unset resp.http.X-Track-VCL-Route;
	unset resp.http.X-VCL-Route;
	unset resp.http.X-PreFetch-Miss;
	unset resp.http.X-PreFetch-Pass;
	unset resp.http.X-PostFetch;

	if (req.http.X-Debug) {
		# ensure that when Fastly's own VCL executes it will be able to identify
		# the Fastly-Debug request header as enabled.
		set req.http.Fastly-Debug = "true";

		# other useful debug information
		set resp.http.Fastly-State = fastly_info.state;
		set resp.http.X-VCL-Route = req.http.X-VCL-Route;
	}
}