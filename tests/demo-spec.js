const request = require('./request');

const path = (relative) => `/${relative}`;

describe('Demo: /', () => {
  it('has status 401', () =>
    request.get(path('/')).expect(401)
  );
});
