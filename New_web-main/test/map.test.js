const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

test('user-position marker identifies and points to the supplied location', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'js', 'map.js'),
    'utf8',
  );
  const sandbox = {
    L: {
      tileLayer: () => ({}),
      divIcon: (options) => options,
      marker: (point, options) => ({
        point,
        options,
        popup: null,
        bindPopup(text) {
          this.popup = text;
          return this;
        },
      }),
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);

  const marker = vm.runInContext(
    'MapView.createUserLocationMarker([12.36, -1.52])',
    sandbox,
  );

  assert.deepEqual(Array.from(marker.point), [12.36, -1.52]);
  assert.equal(marker.options.title, 'Votre position');
  assert.equal(marker.popup, 'Votre position');
  assert.match(marker.options.icon.html, /aria-label="Votre position"/);
});
