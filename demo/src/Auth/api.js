const elmServerless = require('elm-serverless');
const rc = require('strip-debug-loader!shebang-loader!rc'); // eslint-disable-line

const elm = require('./API.elm');

// Use AWS Lambda environment variables to override these values
// See the npm rc package README for more details
const config = rc('demoAuth', {
  auth: {
    secret: 'secret',
  },
});

module.exports.handler = elmServerless.httpApi({
  handler: elm.Auth.API,
  config,
});
