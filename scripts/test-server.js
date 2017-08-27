const fs = require('fs');
const psList = require('ps-list'); // eslint-disable-line import/no-extraneous-dependencies
const { spawn } = require('child_process');
const { port } = require('../tests/request');

const args = `offline --port=${port}`.split(' ');
const logFile = `${__dirname}/test-server.log`;
const logger = console;

const findServer = () => psList().then(data => {
  const argsPattern = new RegExp(args.join(' '));
  return data.filter(({ name, cmd }) =>
    name === 'node' &&
    argsPattern.test(cmd))[0];
});

const startServer = () => new Promise((resolve, reject) => {
  const out = fs.openSync(logFile, 'w+');
  const server = spawn(`${__dirname}/../node_modules/.bin/serverless`, args, {
    cwd: `${__dirname}/../demo`,
    detached: true,
    env: Object.assign({
      demo_enableAuth: 'true',
    }, process.env),
    stdio: ['ignore', out, out],
  });
  server.unref();

  let seenBytes = 0;
  const readNext = () => {
    const stat = fs.fstatSync(out);
    const newBytes = stat.size - seenBytes;
    if (newBytes > 0) {
      const data = Buffer.alloc(newBytes);
      fs.readSync(out, data, 0, newBytes, seenBytes);
      seenBytes = stat.size;

      if (/error/i.test(data)) {
        reject(`test server: ${data}`);
        return;
      } else if (/Version: webpack \d+\.\d+\.\d+/.test(data)) {
        resolve(server.pid);
        return;
      }
    }
    setTimeout(readNext, 200);
  };
  readNext();

  server.on('close', code => {
    reject(`test server terminated with code: ${code}`);
  });
}).then(pid => {
  logger.info(`Test server started (${pid})`);
  return true;
}).catch(err => {
  logger.error(err);
  process.exit(1);
});

findServer().then(server => {
  if (server) {
    logger.info(`Stopping old test server (${server.pid})`);
    process.kill(server.pid);
  }
  startServer();
}).catch(err => {
  logger.error(err);
  process.exit(1);
});
