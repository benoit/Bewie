import { deflateSync } from "node:zlib";
import { mkdir, writeFile } from "node:fs/promises";

// Deterministic, dependency-free PNG artwork, shared by every app profile.
const width = 1200, height = 630, pixels = Buffer.alloc((width * 4 + 1) * height);
for (let y = 0; y < height; y++) {
  for (let x = 0; x < width; x++) {
    const i = y * (width * 4 + 1) + 1 + x * 4;
    pixels.set([24, 27, 35, 255], i);
  }
}
function rectangle(x, y, w, h, color) {
  for (let py = y; py < y + h; py++) for (let px = x; px < x + w; px++) {
    if (px >= 0 && py >= 0 && px < width && py < height) pixels.set([...color, 255], py * (width * 4 + 1) + 1 + px * 4);
  }
}
for (const cx of [440, 600, 760]) {
  for (let y = 175; y < 305; y++) for (let x = cx - 65; x < cx + 65; x++) {
    if ((x - cx) ** 2 + (y - 240) ** 2 < 62 ** 2) rectangle(x, y, 1, 1, [238, 218, 175]);
  }
}
const glyphs = {
  B: ["11110","10001","10001","11110","10001","10001","11110"],
  L: ["10000","10000","10000","10000","10000","10000","11111"],
  E: ["11111","10000","10000","11110","10000","10000","11111"],
  S: ["01111","10000","10000","01110","00001","00001","11110"],
  I: ["11111","00100","00100","00100","00100","00100","11111"],
  N: ["10001","11001","11001","10101","10011","10011","10001"],
  G: ["01111","10000","10000","10111","10001","10001","01111"],
  K: ["10001","10010","10100","11000","10100","10010","10001"],
  T: ["11111","00100","00100","00100","00100","00100","00100"],
};
const title = "BLESSINGKIT", scale = 12;
const left = (width - (title.length * 6 - 1) * scale) / 2;
for (let i = 0; i < title.length; i++) glyphs[title[i]].forEach((row, y) => {
  [...row].forEach((pixel, x) => { if (pixel === "1") rectangle(left + (i * 6 + x) * scale, 365 + y * scale, scale, scale, [246, 246, 244]); });
});
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const name = Buffer.from(type), length = Buffer.alloc(4), crc = Buffer.alloc(4);
  length.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([length, name, data, crc]);
}
const header = Buffer.alloc(13); header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 6;
const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk("IHDR", header), chunk("IDAT", deflateSync(pixels)), chunk("IEND", Buffer.alloc(0))]);
await mkdir(new URL("../public/assets/", import.meta.url), { recursive: true });
await writeFile(new URL("../public/assets/preview.png", import.meta.url), png);
