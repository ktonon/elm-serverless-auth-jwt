const jwt = require('jsonwebtoken');
const should = require('should');

const request = require('./request');

const path = (relative) => `/${relative}`;
const secret = 'secret';

describe('Demo: /', () => {
  it('with a valid token and secret has status 200', () =>
    request
      .get(path('/'))
      .set('Authorization', `Bearer ${jwt.sign('"my payload"', secret)}`)
      .expect(200).then(res => {
        should(res.text).equal('my payload');
      })
  );
  it('without auth header has status 401', () =>
    request.get(path('/')).expect(401).then(res => {
      should(res.text).equal('Authorization header missing');
    })
  );
  it('without "Bearer TOKEN" has status 401', () =>
    request
      .get(path('/'))
      .set('Authorization', 'foobar')
      .expect(401).then(res => {
        should(res.text).startWith('Unsupported Authorization header');
      })
  );
  it('with malformed token has status 401', () =>
    request
      .get(path('/'))
      .set('Authorization', 'Bearer foobar')
      .expect(401).then(res => {
        should(res.text).startWith('Invalid JWT provided');
      })
  );
  it('with malformed payload has status 400', () =>
    request
      .get(path('/'))
      .set('Authorization', `Bearer ${jwt.sign('5', secret)}`)
      .expect(400)
  );
  it('with invalid secret has status 401', () =>
    request
      .get(path('/'))
      .set('Authorization', `Bearer ${jwt.sign('"payload"', 'wrong')}`)
      .expect(401).then(res => {
        should(res.text).equal('JWT validation failed');
      })
  );
});
