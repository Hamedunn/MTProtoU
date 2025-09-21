const express = require('express');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const fs = require('fs').promises;
const path = require('path');
const net = require('net');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Function to get a random port
async function getRandomPort() {
  const minPort = 49152;
  const maxPort = 65535;
  let port;
  do {
    port = Math.floor(Math.random() * (maxPort - minPort + 1)) + minPort;
  } while (await isPortInUse(port));
  return port;
}

async function isPortInUse(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once('error', () => resolve(true));
    server.once('listening', () => {
      server.close();
      resolve(false);
    });
    server.listen(port);
  });
}

// Get installed services
app.get('/api/services', async (req, res) => {
  try {
    const services = [];
    const types = ['Official', 'Python', 'Golang'];
    for (const type of types) {
      const script = type === 'Official' ? 'MTProtoProxyOfficialInstall.sh' :
                     type === 'Python' ? 'MTProtoProxyInstall.sh' : 'MTGInstall.sh';
      const { stdout } = await execPromise(`bash ${script} 1`);
      if (stdout.includes('tg://')) {
        const lines = stdout.split('\n').filter(line => line.startsWith('tg://'));
        services.push({
          type,
          status: (await execPromise(`systemctl is-active ${type.toLowerCase() === 'official' ? 'MTProxy' : type.toLowerCase() === 'python' ? 'mtprotoproxy' : 'mtg'}`)).stdout.trim(),
          port: (await execPromise(`bash ${script} 1 | grep -oP 'port=\\d+' | cut -d'=' -f2`)).stdout.trim() || 'Unknown',
          links: lines
        });
      }
    }
    res.json(services);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Handle actions (start, stop, restart, uninstall)
app.post('/api/action', async (req, res) => {
  const { action, service } = req.body;
  const serviceName = service === 'Official' ? 'MTProxy' : service === 'Python' ? 'mtprotoproxy' : 'mtg';
  try {
    if (action === 'uninstall') {
      const script = service === 'Official' ? 'MTProtoProxyOfficialInstall.sh' :
                     service === 'Python' ? 'MTProtoProxyInstall.sh' : 'MTGInstall.sh';
      await execPromise(`bash ${script} ${service === 'Official' ? '9' : service === 'Python' ? '10' : '6'} <<< 'y'`);
    } else {
      await execPromise(`systemctl ${action} ${serviceName}`);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Handle installation
app.post('/api/install', async (req, res) => {
  const { type, port, secrets, tag, workers, tlsDomain, nat, publicIp, privateIp, customArgs, secureMode } = req.body;
  const script = type === 'Official' ? 'MTProtoProxyOfficialInstall.sh' :
                 type === 'Python' ? 'MTProtoProxyInstall.sh' : 'MTGInstall.sh';
  let args = '';
  if (type === 'Official') {
    args += port === -1 ? '' : `--port ${port}`;
    secrets.forEach(s => {
      args += s.secret ? ` --secret ${s.secret}` : ` --secret $(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)`;
    });
    if (tag) args += ` --tag ${tag}`;
    if (workers) args += ` --workers ${workers}`;
    if (tlsDomain) args += ` --tls "${tlsDomain}"`;
    if (nat === 'y') args += ` --nat-info ${privateIp}:${publicIp}`;
    if (customArgs) args += ` --custom-args "${customArgs}"`;
  } else if (type === 'Python') {
    args += port === -1 ? '' : `${port}`;
    secrets.forEach(s => {
      args += ` ${s.username} ${s.secret || "$(hexdump -vn '16' -e ' /1 \"%02x\"' /dev/urandom)"}`;
    });
    args += ` ${tag} ${secureMode} ${tlsDomain}`;
  } else {
    args += port === -1 ? '' : `${port}`;
    args += secrets[0].secret ? ` ${secrets[0].secret}` : ` $(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)`;
    if (tag) args += ` ${tag}`;
    if (tlsDomain) args += ` 3 ${tlsDomain}`;
  }
  try {
    await execPromise(`bash ${script} ${args}`);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

(async () => {
  const port = await getRandomPort();
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
    console.log(`Access the UI at http://localhost:${port}`);
  });
})();
