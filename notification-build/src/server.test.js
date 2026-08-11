const request = require('supertest');
const { create } = require('./server');
const client = require('prom-client');

// ✅ Clear metrics before each test (important for Jest)
beforeEach(() => {
    client.register.clear();
});

describe('root', () => {

    it('request root, returns html', async () => {
        const app = await create();

        const res = await request(app)
            .get('/')
            .expect(200);

        expect(res.text).toContain('Welcome to Express');
    });

    it('request api, returns json', async () => {
        const app = await create();

        const res = await request(app)
            .get('/api/hello')
            .expect(200);

        expect(res.body).toEqual({ hello: 'goodbye' });
    });

    it('request invalid path, returns 404', async () => {
        const app = await create();

        const invalidPath = '/invalid-path';

        const res = await request(app)
            .get(invalidPath)
            .expect(404);

        expect(res.text).toContain(`Cannot GET ${invalidPath}`);
    });

    it('request /live, returns 200', async () => {
    const app = await create();

    const res = await request(app)
        .get('/live')
        .expect(200);

    expect(res.body).toEqual({ status: 'ok' });
    });

    it('request /ready, returns 200', async () => {
    const app = await create();

    const res = await request(app)
        .get('/ready')
        .expect(200);

    expect(res.body).toEqual({ status: 'ready' });
    });

    it('request /metrics, returns metrics', async () => {
    const app = await create();

    const res = await request(app)
        .get('/metrics')
        .expect(200);

    expect(res.text).toContain('process_cpu');
    });
});