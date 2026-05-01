// r2_smoke_test.cpp — verifies R2 version header and hash behavior
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include "Fingerprint.h"

static void generateSine(int16_t *buf, int n, float freq, float sampleRate)
{
    for (int i = 0; i < n; i++) {
        float v = sinf(2.0f * 3.14159265f * freq * (float)i / sampleRate);
        buf[i] = (int16_t)(v * 20000.0f);
    }
}

int main()
{
    int sampleRate = 10240;
    int numSamples = sampleRate * 3; // 3 seconds
    int16_t *wave = (int16_t*)malloc(numSamples * sizeof(int16_t));
    generateSine(wave, numSamples, 800.0f, (float)sampleRate);

    // extract v1 and v2 fingerprints of the same audio
    Fingerprint *fpV1a = ExtractFingerprint(wave, numSamples, FORMAT_VERSION_V1);
    Fingerprint *fpV1b = ExtractFingerprint(wave, numSamples, FORMAT_VERSION_V1);
    Fingerprint *fpV2a = ExtractFingerprint(wave, numSamples, FORMAT_VERSION_V2);
    Fingerprint *fpV2b = ExtractFingerprint(wave, numSamples, FORMAT_VERSION_V2);

    int fail = 0;

    // 1. v1 has no magic byte
    if (fpV1a->data[0] == FINGERPRINT_MAGIC) {
        printf("FAIL: v1 fingerprint starts with magic byte\n");
        fail++;
    } else {
        printf("PASS: v1 fingerprint has no magic byte (first byte 0x%02X)\n", fpV1a->data[0]);
    }

    // 2. v2 has magic byte + correct version triplet
    if (fpV2a->data[0] == FINGERPRINT_MAGIC &&
        fpV2a->data[1] == FORMAT_VERSION_V2 &&
        fpV2a->data[2] == HASH_PROTOCOL_V2 &&
        fpV2a->data[3] == CALIBRATION_VERSION_V2) {
        printf("PASS: v2 header correct (0x%02X %d %d %d)\n",
               fpV2a->data[0], fpV2a->data[1], fpV2a->data[2], fpV2a->data[3]);
    } else {
        printf("FAIL: v2 header wrong\n");
        fail++;
    }

    // 3. v2 is larger than v1 by exactly FINGERPRINT_HEADER_SIZE
    if (fpV2a->dataSize - fpV1a->dataSize == FINGERPRINT_HEADER_SIZE) {
        printf("PASS: v2 size = v1 size + %d bytes\n", FINGERPRINT_HEADER_SIZE);
    } else {
        printf("FAIL: v2 size delta is %d, expected %d\n",
               fpV2a->dataSize - fpV1a->dataSize, FINGERPRINT_HEADER_SIZE);
        fail++;
    }

    // 4. v1 landmark bytes and v2 landmark bytes (past header) are identical
    if (memcmp(fpV1a->data, fpV2a->data + FINGERPRINT_HEADER_SIZE, fpV1a->dataSize) == 0) {
        printf("PASS: v2 landmark bytes byte-identical to v1\n");
    } else {
        printf("FAIL: v2 landmark bytes differ from v1 (landmark layout should be unchanged)\n");
        fail++;
    }

    // 5. same-version match: v1 vs v1 returns non-zero similarity
    FingerprintSimilarity simV1 = CompareFingerprints(fpV1a, fpV1b);
    if (simV1.similarity > 0.0f) {
        printf("PASS: v1 self-match similarity = %.4f\n", simV1.similarity);
    } else {
        printf("FAIL: v1 self-match returned zero similarity\n");
        fail++;
    }

    // 6. same-version match: v2 vs v2 returns non-zero similarity
    FingerprintSimilarity simV2 = CompareFingerprints(fpV2a, fpV2b);
    if (simV2.similarity > 0.0f) {
        printf("PASS: v2 self-match similarity = %.4f\n", simV2.similarity);
    } else {
        printf("FAIL: v2 self-match returned zero similarity\n");
        fail++;
    }

    // 7. cross-version match: v1 vs v2 returns zero
    FingerprintSimilarity simCross = CompareFingerprints(fpV1a, fpV2a);
    if (simCross.similarity == 0.0f && simCross.score == 0.0f) {
        printf("PASS: cross-version compare returns zero similarity\n");
    } else {
        printf("FAIL: cross-version compare returned non-zero (sim=%.4f)\n", simCross.similarity);
        fail++;
    }

    // 8. unknown version rejected
    Fingerprint fakeFp;
    uint8_t fakeData[16] = { FINGERPRINT_MAGIC, 2, 99, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    fakeFp.data = fakeData;
    fakeFp.dataSize = 16;
    FingerprintSimilarity simBad = CompareFingerprints(&fakeFp, fpV2a);
    if (simBad.similarity == 0.0f) {
        printf("PASS: unknown hash protocol version rejected\n");
    } else {
        printf("FAIL: unknown version produced non-zero similarity\n");
        fail++;
    }

    FingerprintFree(fpV1a);
    FingerprintFree(fpV1b);
    FingerprintFree(fpV2a);
    FingerprintFree(fpV2b);
    free(wave);

    printf("\n%s: %d failures\n", (fail == 0) ? "ALL PASS" : "SOME FAILED", fail);
    return fail;
}
