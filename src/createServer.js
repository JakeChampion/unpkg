/// <reference types="@fastly/js-compute" />

import { env } from 'fastly:env';
import { SimpleCache } from 'fastly:cache';
import { LinearRouter } from 'hono/router/linear-router'
import { Hono } from 'hono'
import { logger } from 'hono/logger'
import { cors } from 'hono/cors'
import { serveMainPage } from "./actions/serveMainPage.js";
import { serveFileMetadata } from './actions/serveFileMetadata.js';
import { serveDirectoryMetadata } from './actions/serveDirectoryMetadata.js';
import { redirectLegacyURLs } from './middleware/redirectLegacyURLs.js';
import { validateFilename } from './middleware/validateFilename.js';
import { validatePackagePathname } from './middleware/validatePackagePathname.js';
import { validatePackageName } from './middleware/validatePackageName.js';
import { validatePackageVersion } from './middleware/validatePackageVersion.js';
import { findEntry } from './middleware/findEntry.js';
import { serveFile } from './actions/serveFile.js';
import { serveModule } from './actions/serveModule.js';
import { serveDirectoryBrowser } from "./actions/serveDirectoryBrowser.js";
import { serveFileBrowser } from "./actions/serveFileBrowser.js";
import favicon from './favicon.js'

function isRunningLocally() {
    return env('FASTLY_SERVICE_VERSION') == '';
}

async function readThroughCache(c, next) {
    if (isRunningLocally()) {
        return await next()
    }
    const url = new URL(c.req.url)
    const key = url.pathname + url.search;
    const ten_minutes = 600_000;
    let bodykey = `__body__${key}`
    let headerskey = `__headers__${key}`
    try {
        let body = SimpleCache.get(bodykey);
        if (body) {
            let headers = SimpleCache.get(headerskey);
            if (headers) {
                headers = await headers.json();
                headers['server-timing'] = "hit-state;desc=hit";
                return new Response(body.body, {headers})
            }
        }
    } catch {
        //
    }
    await next();
    let [body1, body2] = c.res.body.tee();
    let res1 = new Response(body1, c.res);
    let res2 = new Response(body2, c.res);
    c.executionCtx.waitUntil(SimpleCache.getOrSet(bodykey, async () => {
        return {
            value: await res1.arrayBuffer(),
            ttl: ten_minutes
        }
    }));
    c.executionCtx.waitUntil(SimpleCache.getOrSet(headerskey, () => {
        return {
            value: JSON.stringify(Object.fromEntries(res1.headers.entries())),
            ttl: ten_minutes
        }
    }));
    c.res = res2
    c.res.headers.append('server-timing',  "hit-state;desc=miss");
}

export function createServer() {
    const app = new Hono({ router: new LinearRouter() })

    app.onError((error, c) => {
        console.error('Internal App Error:', error, error.stack, error.message);
        return c.text('Internal Server Error', 500)
    });

    app.use('*', logger());

    app.use('*', cors());

    app.use('*', async (c, next) => {
        c.res.headers.append('server-timing', "time-start-msec;dur=" + performance.now())
        await next();
        c.res.headers.append('server-timing', "time-elapsed;dur=" + performance.now())
        c.res.headers.append('server-timing', "fastly-pop;desc=" + (env("FASTLY_POP") || 'local'));
        c.header('FASTLY_SERVICE_VERSION', env('FASTLY_SERVICE_VERSION'));
        c.header("x-compress-hint", "on");
        c.header("x-trailer-server-timing", "rtt,timestamp,retrans");
        c.header("alt-svc", 'h3=":443";ma=86400,h3-29=":443";ma=86400,h3-27=":443";ma=86400');
    });

    app.get('/',
    readThroughCache,
    serveMainPage);

    app.get('/favicon.ico',
    readThroughCache,
    c => c.body(favicon, {
        headers: {
            'content-type': 'image/svg+xml',
            'cache-control': 'public, max-age=31536000',
            'strict-transport-security': 'max-age=31536000; includeSubDomains; preload',
            'x-content-type-options': 'nosniff',
            'x-compress-hint': 'on',
        }
    }));
    app.get('/favicon.svg',
    readThroughCache,
    c => c.body(favicon, {
        headers: {
            'content-type': 'image/svg+xml',
            'cache-control': 'public, max-age=31536000',
            'strict-transport-security': 'max-age=31536000; includeSubDomains; preload',
            'x-content-type-options': 'nosniff',
            'x-compress-hint': 'on',
        }
    }));

    // app.get('/api/stats', serveStats);

    app.use('*', redirectLegacyURLs);

    app.use(
        '/browse/*',
        async (c, next) => {
            c.req.browse = true;
            await next()
        },
        validatePackagePathname,
        validatePackageName,
        validatePackageVersion,
        readThroughCache,
        async (c) => {
            const path = new URL(c.req.url).pathname;
            let response;
            if (path.endsWith('/')) {
                response = await serveDirectoryBrowser(c)
            } else {
                response =  await serveFileBrowser(c)
            }
            return response
        }
    );

    // We need to route in this weird way because Express
    // doesn't have a way to route based on query params.
    app.get(
        '*',
        async (c, next) => {
            const url = new URL(c.req.url);
            const meta = url.searchParams.has('meta');
            const module = url.searchParams.has('module');
            c.req.meta = meta;
            c.req.module = module;
            if (!meta && !module) {
                // Send old */ requests to the new /browse UI.
                const path = new URL(c.req.url).pathname;
                if (path.endsWith('/')) {
                    return c.redirect('/browse' + new URL(c.req.url).pathname, 302);
                }
            }
            await next();
        },
        validatePackagePathname,
        validatePackageName,
        validatePackageVersion,
        validateFilename,
        readThroughCache,
        async (c, next) => {
            if (c.req.meta) {
                const path = new URL(c.req.url).pathname;
                if (path.endsWith('/')) {
                    return await serveDirectoryMetadata(c)
                } else {
                    return await serveFileMetadata(c)
                }
            }
            await next();
        },
        findEntry,
        async (c) => {
            if (c.req.module) {
                return await serveModule(c)
            } else {
                return await serveFile(c)
            }
        }
    );
    
    return app;
}
