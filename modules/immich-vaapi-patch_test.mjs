// Test voor modules/immich-vaapi-patch.nix: genereert met Immich's eigen BaseConfig de
// ffmpeg-filters voor VAAPI en controleert dat format=nv12 vóór hwupload staat waar nodig.
// Gebruik: node immich-vaapi-patch_test.mjs <dist-gepatcht> <dist-origineel>
const [patched, orig] = process.argv.slice(2);
const load = async (dist) => ({
  BaseConfig: (await import(`${dist}/utils/media.js`)).BaseConfig,
  defaults: (await import(`${dist}/dtos/config.dto.js`)).defaults,
});
const P = await load(patched);
const O = await load(orig);

const stream = (w, h, codecName = 'h264') => ({
  index: 0, width: w, height: h, codecName, frameCount: 75, isHDR: false, bitrate: 0,
  pixelFormat: 'yuv420p', rotation: 0,
});
const vf = ({ BaseConfig, defaults }, accel, accelDecode, s) => {
  const cfg = { ...defaults.ffmpeg, accel, accelDecode };
  const out = BaseConfig.create(cfg, { dri: ['renderD128'], mali: false })
    .getCommand('VIDEO', s, undefined).outputOptions;
  const i = out.indexOf('-vf');
  return i < 0 ? '' : out[i + 1];
};

let fail = 0;
const check = (name, ok, got) => {
  console.log(`${ok ? 'ok  ' : 'FOUT'} ${name}: ${got}`);
  if (!ok) fail++;
};

const small = stream(640, 360), big = stream(1920, 1080), hevc4k = stream(3840, 2160, 'hevc');

let f = vf(O, 'vaapi', false, small);
check('origineel, klein, sw-decode: hwupload zonder nv12 (de bug)', f === 'hwupload=extra_hw_frames=64', f);
f = vf(P, 'vaapi', false, small);
check('gepatcht, klein, sw-decode: format=nv12 vóór hwupload', f === 'format=nv12,hwupload=extra_hw_frames=64', f);
f = vf(P, 'vaapi', false, big);
check('gepatcht, 1080p, sw-decode: nv12 + hwupload + scale_vaapi',
  f.startsWith('format=nv12,hwupload=extra_hw_frames=64,scale_vaapi=') && f.endsWith('format=nv12'), f);
for (const [n, s] of [['klein', small], ['1080p', big], ['4K HEVC', hevc4k]]) {
  const a = vf(P, 'vaapi', true, s), b = vf(O, 'vaapi', true, s);
  check(`hw-decode ${n}: ongewijzigd t.o.v. origineel`, a === b && !a.includes('hwupload'), a || '(geen -vf)');
}
for (const [n, s] of [['klein', small], ['1080p', big]]) {
  const a = vf(P, 'qsv', false, s), b = vf(O, 'qsv', false, s);
  check(`QSV sw-decode ${n}: ongewijzigd`, a === b, a);
}
const a = vf(P, 'disabled', false, big), b = vf(O, 'disabled', false, big);
check('CPU (accel uit): ongewijzigd', a === b, a);

process.exit(fail ? 1 : 0);
