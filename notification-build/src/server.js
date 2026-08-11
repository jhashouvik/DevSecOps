const express = require('express');
const client = require('prom-client');
const favicon = require('serve-favicon');
const path = require('path');
const utils = require('./utils');

// ✅ Prevent duplicate metrics registration
let metricsInitialized = false;

// fn to create express server
const create = async () => {

    const app = express();

    app.use(favicon(path.join(__dirname, '../public', 'favicon.ico')));

    // Log request
    app.use(utils.appLogger);

    // API route
    app.get('/api/hello', (req, res) => {
        res.json({ hello: 'goodbye' });
    });

    // liveness check
    app.get('/live', (req, res) => {
        res.status(200).json({ status: 'ok' });
    });

    // readiness check
    app.get('/ready', async (req, res) => {
        try {
            res.status(200).json({ status: 'ready' });
        } catch (error) {
            res.status(503).json({ status: 'not ready', error: error.message });
        }
    });

    // ✅ Initialize Prometheus metrics only once
    if (!metricsInitialized || client.register.getMetricsAsArray().length === 0) {
    client.collectDefaultMetrics();
    metricsInitialized = true;
    }

    // metrics endpoint
    app.get('/metrics', async (req, res) => {
        res.set("Content-Type", client.register.contentType);
        res.end(await client.register.metrics());
    });

    // root route - serve static file
    app.get('/', (req, res) => {
        return res.sendFile(path.join(__dirname, '../public/client.html'));
    });

    // Error handling
    app.use(utils.logErrors);
    app.use(utils.clientError404Handler);
    app.use(utils.clientError500Handler);
    app.use(utils.errorHandler);

    return app;
};

module.exports = {
    create
};