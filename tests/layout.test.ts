import {
  BUST_LAYOUT,
  FACE_BUST,
  FACE_FULL,
  FULL_LAYOUT,
  layoutOf,
} from "../src/avatar/layout.ts";

let failed = 0;
let passed = 0;

function assert(name: string, condition: boolean, detail = ""): void {
  if (condition) {
    passed += 1;
    console.log(`ok  ${name}`);
  } else {
    failed += 1;
    console.error(`fail  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

assert("bust scale is identity", BUST_LAYOUT.faceScale === 1 && BUST_LAYOUT.mouthScale === 1);
assert("full face smaller than bust", FULL_LAYOUT.faceScale < 1 && FULL_LAYOUT.faceScale >= 0.7);
assert("full mouth smaller than head scale", FULL_LAYOUT.mouthScale < FULL_LAYOUT.faceScale);
assert("full mouthScale not a giant cover", FULL_LAYOUT.mouthScale <= 0.7 && FULL_LAYOUT.mouthScale >= 0.45);

assert("bust mouth unchanged", FACE_BUST.mouth.x === 753 && FACE_BUST.mouth.y === 404);
assert("bust eyes unchanged", FACE_BUST.eyeLeft.x === 657 && FACE_BUST.eyeRight.x === 802);

const mouth = FACE_FULL.mouth;
const eyeL = FACE_FULL.eyeLeft;
const eyeR = FACE_FULL.eyeRight;
const eyeY = (eyeL.y + eyeR.y) / 2;
const iod = eyeR.x - eyeL.x;

assert("full mouth below eyes", mouth.y > eyeY + 40, `mouth=${mouth.y} eyes=${eyeY}`);
assert("full mouth on painted smile", mouth.y >= 348 && mouth.y <= 360, `y=${mouth.y}`);
assert("full mouth x on lips", mouth.x >= 748 && mouth.x <= 764, `x=${mouth.x}`);
assert("full left iris", eyeL.x >= 678 && eyeL.x <= 694 && eyeL.y >= 286 && eyeL.y <= 298, `L=${eyeL.x},${eyeL.y}`);
assert("full right iris", eyeR.x >= 784 && eyeR.x <= 800 && eyeR.y >= 264 && eyeR.y <= 276, `R=${eyeR.x},${eyeR.y}`);
assert("full interocular", iod >= 96 && iod <= 120, `iod=${iod}`);
assert("full mouth not on chin", mouth.y < 370);
assert("layoutOf switches plates", layoutOf("full").id === "full" && layoutOf("bust").id === "bust");
assert("layoutOf does not mix sizes", layoutOf("full").h === 2304 && layoutOf("bust").h === 1024);

const bustIod = FACE_BUST.eyeRight.x - FACE_BUST.eyeLeft.x;
assert("full face tighter than bust", iod < bustIod);

console.log(`\n${passed} passed, ${failed} failed`);
if (failed) process.exit(1);
